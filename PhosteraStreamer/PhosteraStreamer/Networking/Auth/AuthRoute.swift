//
//  AuthRoute.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/22/23.
//

import Foundation
import PhosteraShared

public class AuthRoute {
    static var shared = AuthRoute()
    
    func handleRouting(content:Data?, command:CommandMessageType, connection:CameraCommandConnector, forCamera:String) {
        //Pull out the requested auth response
        Task(priority: .userInitiated, operation: {
            var authResponse:AuthResponse
            
            if (content == nil) || content!.isEmpty {
                Logger.shared.error("no data in handleRouting.\(command)")
                return
            }
            
            let decoder = JSONDecoder()
            do {
                authResponse = try decoder.decode(AuthResponse.self, from: content!)
            } catch {
                Logger.shared.error("decoder error:\(error)")
                return
            }
            
            let camera = CameraManager.shared.getCamera(uuid: forCamera)
            camera?.name = authResponse.name
            camera?.model = authResponse.model
            camera?.authorized = authResponse.status == .success
            camera?.blocked = authResponse.blocked
            
            if authResponse.status == .success {
                await connection.updateSessionKey(key: authResponse.sessionKey,
                                                  signature: authResponse.sessionKey,
                                                  serverSessionPublicKey: authResponse.serverSessionPublicKey,
                                                  serverAgreementPublicKey: authResponse.serverSessionAgreementKey)
                
                await connection.updatePorts(streamTCPIn: authResponse.streamTCP,
                                             streamQUICIn: authResponse.streamQUIC,
                                             audioStreamTCPIn: authResponse.audioStreamTCP,
                                             audioStreamQUICIn: authResponse.audioStreamQUIC)
                Logger.shared.info("setting cameramodel streamtcp to \(authResponse.streamTCP)")
            }
        
            _ = CameraManager.shared.updateCamera(camera: camera!)
            
            if authResponse.status == .success {
               // await connection.requestFromCamera(content: CameraRequest(command: .requestStatusSubscription, uuid: connection.uuid, sesionKey: connection.sessionKey))
                await connection.requestScreenshot()
            } else {
                await connection.stop()
                
            }
            
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.updated, object: nil) }
        })
    }
}

