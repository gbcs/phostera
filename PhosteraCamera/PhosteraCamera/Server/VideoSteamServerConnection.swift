//
//  VideoStreamServerConnection.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 9/8/23.
//

import Foundation
import Network
import PhosteraShared

class VideoStreamServerConnection: NSObject {
    var connection: NWConnection?
    var sessionKey:String = ""
    var transformUpdateIndex:Int = -1
    
    func stop() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.Server.removeStreamConnection, object: nil, userInfo: ["sessionKey":self.sessionKey])
        }
        if let connection {
            connection.cancel()
            self.connection = nil
        }
    }
    private func authorizeConnection() {
        Task {
            await VideoStreamServer.shared.moveStartupToConnections(connection:self)
        }
    }
   
    private func denyConnection() {
        Logger.shared.info("Video Stream connection received invalid session key from remote client. \(sessionKey)")
        connection?.cancel()
    }
   
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message) {
        guard let content else { return }
        Logger.shared.info("Received \(content.bytes.count) bytes from director")
        
        switch(message.StreamMessageType) {
        case .auth:
            var authRequest:StreamAuthRequest
            let decoder = JSONDecoder()
            do {
                authRequest = try decoder.decode(StreamAuthRequest.self, from: content)
                sessionKey = authRequest.sessionKey
                Task {
                    await CommandServer.shared.connectionWithSessionKey(sessionkey: sessionKey, completion: { [weak self] connection in
                        guard let self else { return }
                        if connection != nil {
                            authorizeConnection()
                        } else {
                            denyConnection()
                        }
                    })
                }
            } catch {
                Logger.shared.error("decoder error:\(error.localizedDescription)")
                return
            }
            break
        default:
            Logger.shared.error("Unknown message in VideoStreamServerConnection")
        }
    }
    
    func connectionFailed() {
        Logger.shared.info("connection failed")
    }
    
    func connectionReady() {
        Logger.shared.info("connection ready")
    }
 
    init(connection: NWConnection, server:VideoStreamServer) {
        self.connection = connection
        super.init()
        startConnection()
    }
    
    private func startConnection() {
        guard let connection = connection else {
            return
        }

        connection.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                Logger.shared.info("\(connection.debugDescription) established")
                connectionReady()
                receiveNextMessage()
            case .cancelled:
                stop()
            case .failed(let error):
                Logger.shared.info("\(connection.debugDescription) failed with \(error.localizedDescription)")
                stop()
            default:
                break
            }
        }

        connection.start(queue: .main)
    }
    
    func sendPreviewFrame(_ content: Data, transform: Data?, transformIndex: Int, messsageType:StreamMessageType) {
        guard let connection = connection else {
            return
        }
    
        if transformIndex > transformUpdateIndex {
            transformUpdateIndex = transformIndex
            let transformMsg = NWProtocolFramer.Message(StreamMessageType: .metadata)
            let transformContext = NWConnection.ContentContext(identifier: "message", metadata: [transformMsg])
            
            connection.send(content: transform, contentContext: transformContext, isComplete: true, completion: .contentProcessed({ error in
                if error != nil {
                    Logger.shared.info("Error Sending \(content.bytes.count) bytes to director: \(String(describing: error?.localizedDescription))")
                } else {
                    Logger.shared.info("Sent \(String(describing: transform?.bytes.count)) metadata bytes to director:")
                }
            }))
        }
        
        let message = NWProtocolFramer.Message(StreamMessageType: messsageType)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [message])
        
        connection.send(content: content, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
            if error != nil {
                Logger.shared.info("Error Sending \(content.bytes.count) bytes to director: \(String(describing: error?.localizedDescription))")
            } else {
               //Logger.shared.info("Sent \(content.bytes.count) bytes to director: \(messsageType)")
            }
        }))
    }
    

    func sendToDirector(_ content: Data, messsageType:StreamMessageType) {
        guard let connection = connection else {
            return
        }
        
        let message = NWProtocolFramer.Message(StreamMessageType: messsageType)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [message])
        
        //Logger.shared.info("Sending \(content.bytes.count) bytes to director")
        
        connection.send(content: content, contentContext: context, isComplete: true, completion: .idempotent)
    }

    func receiveNextMessage() {
        guard let connection = connection else {
            return
        }

        connection.receiveMessage { [weak self] (content, context, isComplete, error) in
            guard let self else { return }
            if let StreamMessage = context?.protocolMetadata(definition: StreamProtocol.definition) as? NWProtocolFramer.Message {
                receivedMessage(content: content, message: StreamMessage)
            }
            if error == nil {
                receiveNextMessage()
            }
        }
    }
}
