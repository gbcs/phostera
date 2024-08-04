
//  CamServer.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/14/23.

import Foundation
import Network
import Combine
import PhosteraShared

extension NSNotification.Name {
    class Server {
        static let removeCommandConnection = Notification.Name("removeCommandConnection")
        static let removeStreamConnection = Notification.Name("removeStreamConnection")
    }
}

actor CommandServer {
    static var shared = CommandServer()
    private var listener:NWListener?
    private var connections:[String:CommandServerConnection] = [String:CommandServerConnection]()
    private var removeConnectionPub = NotificationCenter.default.publisher(for: Notification.Name.Server.removeCommandConnection)
    private var removeConnectionSub:AnyCancellable?
    
    func removeConnection(key:String) {
        connections.removeValue(forKey: key)
    }
    
    func removeConnection(connection:CommandServerConnection) {
        Task(priority: .userInitiated, operation: { [weak self] in
            guard let self else { return }
            let key = await connection.getSessionKey()
            await removeConnection(key: key)
        })
    }
    
    func connectionWithDirector(directorPublicKey:Data, completion: @escaping ((CommandServerConnection?)) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            for sessionKey in await connections.keys {
                if let connection = await connections[sessionKey] {
                    if await connection.getPublicKey()?.bytes == directorPublicKey.bytes {
                        completion(connection)
                        return
                    }
                }
            }
            completion(nil)
        }
    }
    
    func connectionWithDirector(directorUUID:String, completion: @escaping ((CommandServerConnection?)) -> Void) {
        Task { [weak self] in
            guard let self else { return }
            for sessionKey in await connections.keys {
                if let connection = await connections[sessionKey] {
                    if await connection.getDirectorUUID() == directorUUID {
                        completion(connection)
                        return
                    }
                }
            }
            completion(nil)
        }
    }
    
    func connectionWithSessionKey(sessionkey:String, completion: @escaping (CommandServerConnection?) -> Void) {
        Task(priority: .userInitiated, operation: { [weak self] in
            guard let self else { return }
            var conn:CommandServerConnection? = nil
            for c in await connections.values {
                if await c.getSessionKey().compare(sessionkey) == .orderedSame {
                    conn = c
                    break
                }
            }
            completion(conn)
        })
    }
    
    func listenerState() -> NWListener.State? {
        return listener?.state
    }
    
    static func createTLSParameters(queue: DispatchQueue) -> NWParameters {
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
    
    func checkAppSupportDirectory() {
        let appSupport = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true, attributes: nil)
        
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            Logger.shared.error("Unable to create app support directory.")
        }
    }

    func returnNextServerSequenceNumber() -> Int {
        checkAppSupportDirectory()
        let serverSequenceFile = URL.applicationSupportDirectory.appendingPathComponent("serverSequence", conformingTo: .propertyList)
        
        func write(sequence:Int) {
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(sequence)
                try data.write(to: serverSequenceFile)
            } catch {
                
            }
        }
        
        if FileManager.default.fileExists(atPath: serverSequenceFile.path) {
            if let contents:Data = FileManager.default.contents(atPath: serverSequenceFile.path) {
                let decoder = JSONDecoder()
                do {
                    var x = try decoder.decode(Int.self, from: contents)
                    x += 1
                    if x > 999 { x = 0 }
                    write(sequence: x)
                    return x
                } catch {
                    return -1
                }
            }
        }
        
        let x:Int = 1
        write(sequence: x)
        return x
    }
    
    func appendSequenceNumber(serverUUID:String) -> String {
        let x = returnNextServerSequenceNumber()
        let s = String(format: "%03d", x)
        return serverUUID + s
    }
    
    func update(uuid:String, connection:CommandServerConnection) {
        connections[uuid] = connection
    }
    
    func start() {
        if listener != nil {
            Logger.shared.info("CommandServer already listening at start.")
            return
        }
        
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

        let a = NWTXTRecord(["app" : "phostera" ])
        let service = NWListener.Service(name: appendSequenceNumber(serverUUID: SettingsService.shared.settings.serverUUID), type: "_phostera._tcp", domain: "local", txtRecord: a)
        let params: NWParameters = CommandServer.createTLSParameters(queue: .global(qos: .userInitiated))
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true
        
        let commandOptions = NWProtocolFramer.Options(definition: CommandProtocol.definition)
        params.defaultProtocolStack.applicationProtocols.insert(commandOptions, at: 0)
        
        listener = try? NWListener(service: service, using: params)
            guard let  listener else {
                Logger.shared.error("Failed to create command listener.")
                return
            }
            
            listener.newConnectionHandler = { connection in
                Task { [weak self] in
                    guard let self else { return }
                    let commandConnection = CommandServerConnection(connection: connection, server: self)
                    await update(uuid: commandConnection.sessionKey, connection: commandConnection)
                    Logger.shared.info("server did open connection")
                }
            }
            
            listener.stateUpdateHandler = { state in
                switch state {
                case .waiting:
                    break
                case .ready:
                    if SettingsService.shared.settings.allowNetworking == false {
                        SettingsService.shared.settings.allowNetworking = true
                        SettingsService.shared.save()
                        Logger.shared.info("Setting allowNetworking true")
                        DispatchQueue.main.async { NotificationCenter.default.post(name: .networkAccessChanged, object: nil) }
                    }
                case .failed(let error):
                    Logger.shared.info("CommandServer listener failed:\(error.localizedDescription)")
                case .cancelled:
                    break
                case .setup:
                    break
                @unknown default:
                    Logger.shared.info("CommandServer listener unknown state")
                }
            }
            
            listener.start(queue: .global(qos: .userInitiated))
        
    }
    
    func standbyMode(isOn:Bool) {
        Task {
            for connection in connections.values {
                if await connection.getDirectorUUID() != "" {
                    await connection.standbyMode(isOn: isOn)
                }
            }
        }
    }
    
    func standbyModeOps(isRunning:Bool) {
        Task {
            for connection in connections.values {
                if await connection.getDirectorUUID() != "" {
                    await connection.standbyModeOps(isRunning: isRunning)
                }
            }
        }
    }
    
    func sendTakeList(project:DirectorProjectModel) {
        Task { [weak self] in
            guard let self else { return }
            let list = CameraTakeService.getTakeList(forProject: project.uuid)
            do {
                let data = try JSONEncoder().encode(list)
                for connection in await connections.values {
                    if await connection.getDirectorUUID() == project.directorUUID {
                        await connection.sendTaskList(data: data)
                    }
                }
            } catch {
                Logger.shared.info("Unable to create take list for project:\(project.uuid)")
            }
        }
    }
    
    func sendAACCookie(aacCookie:Data) {
        Task {
            let response:CameraResponse = CameraResponse(status: .success, command: .aacCookie, data: aacCookie)
            let encoder = JSONEncoder()
            let data:Data = try encoder.encode(response)
            for connection in connections.values {
                await connection.sendToDirector(data, messsageType: .camera)
            }
        }
    }
    
    func eraseListener() {
        listener = nil
    }
    
    func removeAllConnections() {
        connections.removeAll(keepingCapacity:false)
    }
    
    func stop() {
            if let listener = self.listener {
               
                Task { [weak self] in
                    guard let self else { return }
                    listener.cancel()
                    for c in await self.connections.values { await c.cancel() }
                    await removeAllConnections()
                    await eraseListener()
                }
            } else {
                Logger.shared.info("Listener not listening at stop.")
            }
    }
}
