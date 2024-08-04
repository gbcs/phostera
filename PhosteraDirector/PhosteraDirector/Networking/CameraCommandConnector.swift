//
//  CameraConnector.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/20/23.
//

import UIKit
import Network
import AVFoundation
import PhosteraShared
import CryptoKit
import DeviceKit

class CameraStatus {
    @Published var whiteBalanceMode:AVCaptureDevice.WhiteBalanceMode = .autoWhiteBalance
    @Published var adjustingWhiteBalance:Bool = false
    @Published var whiteBalanceTemperature: Float = 0.0
    @Published var whiteBalanceTint: Float = 0.0
    @Published var adjustingExposure:Bool = false
    @Published var exposureMode:AVCaptureDevice.ExposureMode = .continuousAutoExposure
    @Published var exposurePOI:CGPoint = .zero
    @Published var exposureISO:Float = 0
    @Published var exposureShutter:CMTime = .zero
    @Published var focusPOI:CGPoint = .zero
    @Published var focusMode:AVCaptureDevice.FocusMode = .continuousAutoFocus
    @Published var adjustingFocus:Bool = false
    @Published var lensPosition: Float = .zero
    @Published var recordingState:Bool = false
    @Published var horizonPreviewAngle:CGFloat = .zero
    @Published var sessionResolution:CGSize = .zero
    @Published var sessionFrameRate:CMTime = .zero
    @Published var modeName: String = ""
    @Published var modeOutputName: String = ""
    @Published var pressureState: AVCaptureDevice.SystemPressureState.Level = .nominal
    @Published var cameraStart: Bool = false
    @Published var cameraStop: Bool = false
    @Published var beginRecording: Bool = false
    @Published var endRecording:  Bool = false
    @Published var togglePreview:  Bool = false
    @Published var gotoSettings: Bool = false
    @Published var gotoLibrary: Bool = false
    @Published var orientationChange:   Bool = false
    @Published var appActive: Bool = false
    @Published var newMode:  Bool = false
    @Published var showTorchUI: Bool = false
    @Published var showVizToolsUI:  Bool = false
    @Published var appBackground:  Bool = false
    @Published var appForeground: Bool = false
    @Published var thermalStateChange: Bool = false
    @Published var sessionRuntimeError:  Bool = false
    @Published var sessionWasInterrupted:  Bool = false
    @Published var sessionInterruptionEnded:   Bool = false
    @Published var flashScreen: Bool = false
    @Published var batteryLevel:Float = 0.0
    @Published var batteryState:UIDevice.BatteryState = .unknown
    @Published var diskFree:Int64 = 0
    @Published var frontCamera:Bool = false
}

actor CameraCommandConnector: NSObject {
    var connection: NWConnection?
    var endpoint: NWEndpoint?
    var uuid:String = ""
    var streamTCP:UInt16 = 0
    var streamQUIC:UInt16 = 0
    var audioStreamTCP:UInt16 = 0
    var audioStreamQUIC:UInt16 = 0
    var status:CameraStatus = CameraStatus()
    var sessionKey:String = ""

    private var screenshotsRequested:Bool = false
    
    func requestScreenshot() {
        let request = CameraRequest(command: .screenshot, uuid: uuid, sesionKey: sessionKey, dataUUID: "")
        requestFromCamera(content: request)
    }
    
    func getUUID() -> String {
        return uuid
    }
    
    func updateSessionKey(key:Data, signature:Data, serverSessionPublicKey:Data, serverAgreementPublicKey:Data) {
        if let serverAgreementKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: serverAgreementPublicKey) {
            if let serverSigningKey = try? P256.Signing.PublicKey(rawRepresentation: serverSessionPublicKey) {
                if let keyData = try? SessionKeyEncryptor.shared.decryptAndVerify(remoteSigningPublicKey: serverSigningKey,
                                                                                remoteAgreementPublicKey: serverAgreementKey,
                                                                                cipherText: key,
                                                                                  signature: signature) {
                    sessionKey = String(bytes: keyData, encoding: .utf8) ?? ""
                }
            }
        }
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
            sec_protocol_verify_complete(true)
        }, queue)
        return NWParameters(tls: options)
    }
    
    deinit {
        connection = nil
        endpoint = nil
    }
    
    func updatePorts(streamTCPIn:UInt16, streamQUICIn:UInt16, audioStreamTCPIn:UInt16, audioStreamQUICIn:UInt16) {
        streamTCP = streamTCPIn
        streamQUIC = streamQUICIn
        audioStreamTCP = audioStreamTCPIn
        audioStreamQUIC = audioStreamQUICIn
    }

    func setEndpoint(ep:NWEndpoint) {
        self.endpoint = ep
        
        let tcpOpts = NWProtocolTCP.Options()
        tcpOpts.disableECN         = true    // Explicit Congestion Notification
        tcpOpts.enableKeepalive    = false   // Send Keep-Alive packets
        tcpOpts.connectionTimeout  = 5       // Connection handshake timeout (seconds)
        tcpOpts.connectionDropTime = 5       // Seconds TCP will do packet retransmission

        let params = CameraCommandConnector.createTLSParameters(allowInsecure: true, queue: .global(qos: .userInitiated))

        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true

        let commandOptions = NWProtocolFramer.Options(definition: CommandProtocol.definition)
        params.defaultProtocolStack.applicationProtocols.insert(commandOptions, at: 0)
        
        let connection = NWConnection(to: ep, using: params)
        self.connection = connection
    }
    
    func stop() {
        connection?.cancel()
        connection = nil
        endpoint = nil
    }
  
    func cancel() {
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }
    
    func connectionReady() {
        requestAuth()
    }

    func startConnection(uuid:String) {
        Logger.shared.info("Starting connection to \(uuid)")
        self.uuid = uuid
        guard let connection = connection else {
            return
        }

        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                Logger.shared.info("\(connection) established")
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await receiveNextMessage()
                    await connectionReady()
                })
      

            case .failed(let error):
                Logger.shared.error("\(connection) failed with \(error)")
                connection.cancel()
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await connectionFailed()
                })
            default:
                break
            }
        }

        Task {
            connection.start(queue: .global())
        }
    }
    
    func sendProject() {
        if let project = DirectorProjectService.currentProject() {
            guard let connection = connection else {
                return
            }
            
            Logger.shared.info("Sending project: codec:\(project.codec) - colorspace:\(project.colorspace)")
            
            let message = NWProtocolFramer.Message(commandMessageType: .project)
            let context = NWConnection.ContentContext(identifier: "message",  metadata: [message])
            Task {
                let encoder = JSONEncoder()
                do {
                    let data = try encoder.encode(project)
                    Logger.shared.info("Sending project: \(data.count) bytes to camera")
                    
                    connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
                } catch {
                    Logger.shared.error("send project encoder error \(error)")
                }
            }
        }
    }

    func requestFromCamera(content:CameraRequest) {
        guard let connection = connection else {
            return
        }

        let message = NWProtocolFramer.Message(commandMessageType: .camera)
        let context = NWConnection.ContentContext(identifier: "message",  metadata: [message])
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(content)
            Logger.shared.info("Sending \(data.count) bytes to camera")
            
            connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        } catch {
            Logger.shared.error("request camera encoder error \(error)")
        }
    }
    
    func requestStandby(isOn:Bool) {
        guard let connection = connection else {
            return
        }

        let message = NWProtocolFramer.Message(commandMessageType: .standbyMode)
        let context = NWConnection.ContentContext(identifier: "message",  metadata: [message])
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(isOn)
            Logger.shared.info("Sending \(data.count) bytes to camera")
            
            connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        } catch {
            Logger.shared.error("request camera encoder error \(error)")
        }
    }
    
    func requestAuth() {
        guard let connection = connection else {
            return
        }
        
        let displayName = SettingsService.shared.settings.displayName.lengthOfBytes(using: .utf8) > 0 ?
        SettingsService.shared.settings.displayName : SettingsService.shared.settings.serverUUID
      
        
        let message = NWProtocolFramer.Message(commandMessageType: .authentication)
        let context = NWConnection.ContentContext(identifier: "message",  metadata: [message])
        Task {
            let agreementKey = SessionKeyEncryptor.shared.getAgreementPublicKey()
            let content = await AuthRequest(uuid: NetworkHandler.shared.serverUUID,
                                            title:displayName,
                                            model: Device.current.safeDescription,
                                            publicKey:SettingsService.shared.settings.serverPublicKey,
                                            sessionPublicKey:agreementKey.rawRepresentation,
                                            userMessage:NetworkHandler.shared.getSignupMessage(uuid: self.uuid),
                                            pairingCode: NetworkHandler.shared.getPairCode(uuid: self.uuid)
                                            )

            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(content)
                Logger.shared.info("Sending \(data.count) bytes to camera")
                
                connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
            } catch {
                Logger.shared.error("request auth encoder error \(error)")
            }
        }
    
    }

    func receiveNextMessage() {
        guard let connection = connection else {
            return
        }

        connection.receiveMessage { (content, context, isComplete, error) in
            if let commandMessage = context?.protocolMetadata(definition: CommandProtocol.definition) as? NWProtocolFramer.Message {
                Task(priority: .userInitiated, operation: { [weak self, content, commandMessage]  in
                    guard let self else { return }
                    await receivedMessage(content: content, message: commandMessage)
                    if error == nil {
                        await receiveNextMessage()
                    }
                })
            }
        }
    }
    
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message) {
        //Logger.shared.info("Received \(content!.count) bytes from camera")
        
        switch(message.commandMessageType) {
        case .authentication:
            AuthRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self, forCamera: self.uuid)
        case .camera:
            CameraRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self, forCamera: self.uuid)
        case .screenshot:
            Logger.shared.info("screenshot received. \(content?.bytes.count ?? 0)")
            if let content {
                let localUUID = uuid
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.screenshotReceived, object: nil, userInfo: ["uuid" : localUUID, "data" : content]) }
            }
        case .project:
            ProjectRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self, forCamera: self.uuid)
        case .status:
            StatusRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self, forCamera: self.uuid)
        case .standbyMode:
            if let content {
                let localUUID = uuid
                if let answer = try? JSONDecoder().decode(Bool.self, from: content) {
                    if answer {
                        DispatchQueue.main.async { [weak self]  in
                            guard let self else { return }
                            if !CameraManager.shared.standbyUUIDs.contains(localUUID) {
                                CameraManager.shared.standbyUUIDs.append(localUUID)
                                NotificationCenter.default.post(name: NSNotification.Name.Camera.standbyUpdated, object: nil)
                            }
                        }
                    } else {
                        DispatchQueue.main.async { 
                            CameraManager.shared.standbyUUIDs.removeAll { u in u == localUUID }
                            NotificationCenter.default.post(name: NSNotification.Name.Camera.standbyUpdated, object: nil)
                        }
                    }
                }
            }
        case .standbyModeOps:
            if let content {
                let localUUID = uuid
                if let answer = try? JSONDecoder().decode(Bool.self, from: content) {
                    if answer {
                        DispatchQueue.main.async {
                            if !CameraManager.shared.standbyOpsUUIDS.contains(localUUID) {
                                CameraManager.shared.standbyOpsUUIDS.append(localUUID)
                                NotificationCenter.default.post(name: NSNotification.Name.Camera.standbyUpdated, object: nil)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            CameraManager.shared.standbyOpsUUIDS.removeAll { u in u == localUUID }
                            NotificationCenter.default.post(name: NSNotification.Name.Camera.standbyUpdated, object: nil)
                        }
                    }
                }
            }
        default:
            Logger.shared.error("receivedMessage fallthrough")
        }
    }
    
    func connectionFailed() {
        
    }
    
}

