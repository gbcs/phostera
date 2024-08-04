//
//  AudioStreamServer.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 9/8/23.
//

import Foundation
import Network
import Combine
import PhosteraShared

enum AudioStreamServerErrors: Error {
    case tlsSetup
}

actor AudioStreamServer {
    static var shared = AudioStreamServer()
    private var listener:NWListener?
    private var listener_quic:NWListener?
    private var removeConnectionPub = NotificationCenter.default.publisher(for: Notification.Name.Server.removeStreamConnection)
    private var removeConnectionSub:AnyCancellable?
    private var connections:[String:AudioStreamServerConnection] = [String:AudioStreamServerConnection]()
    private var startupConnections:[AudioStreamServerConnection] = []
    
    private var dataTimer:DispatchSourceTimer?
    private var isSendingFrame:Bool = false
    
    private func startDataTimer() {
        let nextExecution = DispatchTime.now().advanced(by: DispatchTimeInterval.milliseconds(33))
        
        dataTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        
        guard let dataTimer else { return }
        
        dataTimer.schedule(deadline: nextExecution, repeating: .milliseconds(33))
        
        dataTimer.setEventHandler {
            Task { [weak self] in
                guard let self else { return }
                if await isSendingFrame { return }
                let connections = await connections.values
                let connectionCount = connections.count
                if connectionCount < 1 { return }
                await nowSendingFrames(isOn: true)
                let chunks = await CamTool.shared.audioFifo.dequeueAll()
                for chunk in chunks {
                    connections.forEach({ connection in
                        connection.sendPreviewFrame(chunk, messsageType: .audio)
                    })
                }
                await nowSendingFrames(isOn: false)
            }
        }
        
        dataTimer.resume()
    }
    
    func nowSendingFrames(isOn:Bool) {
        isSendingFrame = isOn
    }
   
    func connectionFor(sessionKey:String) -> AudioStreamServerConnection? {
        return connections[sessionKey]
    }
    
    private func removeConnection(connection:AudioStreamServerConnection) {
        connections.removeValue(forKey: connection.getSessionKey())
    }
    
    let audioSkipFactor:Int = 3
    var audioSkipCurrent:Int = 0
    

    func quicPort() -> UInt16 {
        return listener_quic?.port?.rawValue ?? 0
    }
    
    func tcpPort() -> UInt16 {
        return listener?.port?.rawValue ?? 0
    }
    
    static func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolTLS.Options()
        do {
            let secIdentity = try ServerKeys.keysForServer()
            guard let identity = sec_identity_create(secIdentity) else { return NWParameters(tls: options) }
            sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
            sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)
            sec_protocol_options_append_tls_ciphersuite( options.securityProtocolOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_AES_128_GCM_SHA256))! )
        } catch {
            return NWParameters(tls: options)
        }
        
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var answer = false
            var publicKey:Data?
            
            if let secKey = SecTrustCopyKey(trust) {
                var error: Unmanaged<CFError>?
                if let cfData = SecKeyCopyExternalRepresentation(secKey, &error) {
                    publicKey = cfData as Data
                }
            }
            
            if let publicKey {
                if !SettingsService.shared.settings.allowNewDirectorToConnect {
                    if PublicKeyManager.shared.comparePublicKey(from: publicKey) {
                        answer = true
                    }
                } else {
                    answer = true
                }
            }
            
//  Not sure there is any value keeping this, but let the comment hang around until sure.
//            var error: CFError?
//            _ = SecTrustEvaluateWithError(trust, &error)
            
            sec_protocol_verify_complete(answer)
        }, queue)
        
        let tcpOpts = NWProtocolTCP.Options()
        tcpOpts.disableECN         = true    // Explicit Congestion Notification
        tcpOpts.enableKeepalive    = false   // Send Keep-Alive packets
        tcpOpts.connectionTimeout  = 5       // Connection handshake timeout (seconds)
        tcpOpts.connectionDropTime = 5       // Seconds TCP will do packet retransmission
        
        
        return NWParameters(tls: options, tcp: tcpOpts)
    }
    
    
    static func createQUICParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolQUIC.Options(alpn: ["phostera"])
        //options.isDatagram = false
       // options.maxDatagramFrameSize = 65535
        options.idleTimeout = 120000
        options.direction = .bidirectional
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var answer = false
            var publicKey:Data?
            
            if let secKey = SecTrustCopyKey(trust) {
                var error: Unmanaged<CFError>?
                if let cfData = SecKeyCopyExternalRepresentation(secKey, &error) {
                    publicKey = cfData as Data
                }
            }
            
            if let publicKey {
                if !SettingsService.shared.settings.allowNewDirectorToConnect {
                    if PublicKeyManager.shared.comparePublicKey(from: publicKey) {
                        answer = true
                    }
                } else {
                    answer = true
                }
            }
            
//  Not sure there is any value keeping this, but let the comment hang around until sure.
//            var error: CFError?
//            _ = SecTrustEvaluateWithError(trust, &error)
            
            sec_protocol_verify_complete(answer)
        }, queue)
        
        return NWParameters(quic: options)
    }
    
    func start() {
       
        if self.listener != nil {
            Logger.shared.info("AudioStreamServer already listening at start.")
            return
        }
        startListener(quic: false)
        //startListener(quic: true)
        removeConnectionSub = removeConnectionPub.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            if let v = value.userInfo?["sessionKey"] as? String {
                Task { [weak self] in
                    guard let self else { return }
                    if let c = await connections[v] {
                        await removeConnection(connection: c)
                    }
    
                }
            }
        }
        startDataTimer()
    }
    
    private func removeStartupConnection(connection:AudioStreamServerConnection) {
        startupConnections.removeAll { c in
            c == connection
        }
    }

    private func addStartupConnection(connection:AudioStreamServerConnection) {
        startupConnections.append(connection)
    }
    
    func moveStartupToConnections(connection:AudioStreamServerConnection) {
        connections[connection.getSessionKey()] = connection
        removeStartupConnection(connection: connection)
        Logger.shared.info("Upgraded audio stream connection with authorized sessionKey.")
    }
    
    private func startListener(quic:Bool) {
        //let a = NWTXTRecord(["app" : "phostera" ])
        
        var params:NWParameters?
        
        if quic {
            params = AudioStreamServer.createQUICParameters(allowInsecure: true, queue: .global(qos: .userInitiated))
        } else {
            params = AudioStreamServer.createTLSParameters(allowInsecure: true, queue: .global(qos: .userInitiated))
        }
        
        if let params {
            params.allowLocalEndpointReuse = true
            params.includePeerToPeer = true
            
            let StreamOptions = NWProtocolFramer.Options(definition: StreamProtocol.definition)
            params.defaultProtocolStack.applicationProtocols.insert(StreamOptions, at: 0)
            
            if quic {
                do {
                    self.listener_quic = try NWListener(using: params)
                    guard let listener_quic else {
                        Logger.shared.info("Unable to create listener. quic=\(quic)")
                        return
                    }
                    
            
                    listener_quic.newConnectionHandler = { [weak self] connection in
                        guard let self else { return }
                        Task { [weak self] in
                            guard let self else { return }
                            let stream = AudioStreamServerConnection(connection: connection, server: self)
                            await addStartupConnection(connection: stream)
                            Logger.shared.info("server did open connection (quic)")
                        }
                    }
                    
                    listener_quic.stateUpdateHandler = { state in
                        Logger.shared.info("AudioStreamServer listener state:\(String(describing:state))")
                    }
                    
                    listener_quic.start(queue: .global(qos: .userInitiated))
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                        if quic {
                            Logger.shared.info("Audio-Stream-quic listening on port: \(String(describing: listener_quic.port))")
                        } else {
                            Logger.shared.info("Audio-Stream-tcp listening on port: \(String(describing: listener_quic.port))")
                        }
                    })
                }  catch {
                    Logger.shared.info("Unable to use listener. quic=\(quic)")
                }
            } else {
                do {
                    self.listener = try NWListener(using: params)
                    guard let listener else {
                        Logger.shared.info("Unable to create listener. quic=\(quic)")
                        return
                    }
                    
                    listener.newConnectionHandler = { [weak self] connection in
                        guard let self else { return }
                        Task { [weak self] in
                            guard let self else { return }
                            let stream = AudioStreamServerConnection(connection: connection, server: self)
                            await addStartupConnection(connection: stream)
                            Logger.shared.info("server did open connection")
                        }
                    }
                    
                    listener.stateUpdateHandler = { state in
                        Logger.shared.info("AudioStreamServer listener state:\(String(describing:state))")
                    }
                    
                    listener.start(queue: .global(qos: .userInitiated))
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                        if quic {
                            Logger.shared.info("Audio-Stream-quic listening on port: \(String(describing: listener.port))")
                        } else {
                            Logger.shared.info("Audio-Stream-tcp listening on port: \(String(describing: listener.port))")
                        }
                    })
                }  catch {
                    Logger.shared.info("Unable to use listener. quic=\(quic)")
                }
            }
            
        }
    }
    
    func stop() {
        if let listener = self.listener {
            listener.cancel()
            for c in self.connections.values { c.stop() }
            self.connections.removeAll(keepingCapacity:false)
            self.listener = nil
        } else {
            Logger.shared.info("Listener wasn't listening.")
        }
        
        if let listener_quic = self.listener_quic {
            listener_quic.cancel()
            for c in self.connections.values { c.stop() }
            self.connections.removeAll(keepingCapacity:false)
            self.listener_quic = nil
        } else {
            Logger.shared.info("Listener-quic wasn't listening.")
        }
    }
}
