//
//  AuthRoute.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/22/23.
//

import Foundation
import DeviceKit
import PhosteraShared
import Network
import CryptoKit

public class AuthRoute {
    static var shared = AuthRoute()

    func handleRouting(content:Data?, command:CommandMessageType, connection:CommandServerConnection) {
        //Pull out the requested auth, send a response
        var authRequest:AuthRequest
        
        if (content == nil) || content!.isEmpty {
            Logger.shared.error("no data in handleRouting.\(command.rawValue)")
            return
        }
        
        let decoder = JSONDecoder()
        do {
            authRequest = try decoder.decode(AuthRequest.self, from: content!)
        } catch {
            Logger.shared.error("decoder error:\(error.localizedDescription)")
            return
        }
        
        Task { [authRequest] in
            await connection.update(publicKey: authRequest.userPublicKey)
            DispatchQueue.main.async {
                if let director = DirectorService.shared.findDirectorWithPublicKey(key: authRequest.userPublicKey) {
                    Task(priority: .userInitiated, operation: { [weak self] in
                        guard let self else { return }
                        if director.blocked {
                            Logger.shared.info("Blocked connection from \(director.title) (\(director.uuid))")
                            sendAuthResponse(success: false, publicKey: authRequest.userPublicKey, connection: connection, remoteSessionPublicKeyData:authRequest.userSessionPublicKey)
                            await connection.cancel()
                        } else if director.authorized {
                            await director.sessionkey = connection.sessionKey
                            await connection.update(directorUUID: director.uuid)
                            DirectorService.shared.saveDirector(director: director)
                            sendAuthResponse(success: director.authorized, publicKey: authRequest.userPublicKey, connection: connection, remoteSessionPublicKeyData:authRequest.userSessionPublicKey)
                        } else {
                            await UserMessagingService.shared.add(message: UserMessageRequest(requestType: .newUserAuth, text: authRequest.userMessageForSignup, director: director))
                        }
                        
                    })
                } else {
                    Task { [authRequest] in
                        let director = await DirectorModel(title: authRequest.title,
                                                           uuid: authRequest.uuid,
                                                           publicKey: authRequest.userPublicKey,
                                                           authorized: false,
                                                           sessionKey: connection.sessionKey,
                                                           blocked: false,
                                                           sessionPublicKey: authRequest.userSessionPublicKey)
                        DirectorService.shared.saveDirector(director: director)
                        await UserMessagingService.shared.add(message: UserMessageRequest(requestType: .newUserAuth, text: authRequest.userMessageForSignup, director: director))
                    }
                }
            }
        }
        
    }
    
    private func generateFailureResponse(publicKey:Data, director:DirectorModel, connection:CommandServerConnection) {
        let displayname = SettingsService.shared.settings.displayName.isEmpty ?
        SettingsService.shared.settings.displayName : SettingsService.shared.settings.serverUUID
        
        let response = AuthResponse(status: .failure,
                                    uuid: SettingsService.shared.settings.serverUUID,
                                    sessionKey: Data(),
                                    name: displayname,
                                    model: Device.current.safeDescription,
                                    publicKey: SettingsService.shared.settings.serverPublicKey,
                                    streamTCP: 0,
                                    streamQUIC: 0,
                                    audioStreamTCP: 0,
                                    audioStreamQUIC: 0,
                                    blocked: director.blocked,
                                    serverSessionPublicKey: Data(),
                                    sessionSignature: Data(),
                                    serverAgreementPublicKey: Data(),
                                    version:1)
        
        send(response: response, director: director)
    }
    
    private func send(response:AuthResponse, director:DirectorModel) {
        Task {
            await CommandServer.shared.connectionWithSessionKey(sessionkey: director.sessionkey) { connection in
                guard let connection else { return }
                Task {
                    let encoder = JSONEncoder()
                    var data:Data?
                    do {
                        data = try encoder.encode(response)
                        guard let data else { return }
                        await connection.sendToDirector(data, messsageType: .authentication)
                    } catch {
                        Logger.shared.error("sendAuthResponse: encoder error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func sendAuthResponse(success:Bool, publicKey:Data, connection:CommandServerConnection, remoteSessionPublicKeyData:Data) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05, execute: { [weak self, success] in
            guard let self else { return }
            
            guard let director = DirectorService.shared.findDirectorWithPublicKey(key: publicKey) else {
                //Not going to touch this; let it die
                return
            }
            
            if !success {
                return generateFailureResponse(publicKey: publicKey, director: director, connection: connection)
            }
            
            Task { [weak self] in
                guard let self else { return }
                
                let sessionKeyData = await connection.sessionKey.data(using: .utf8) ?? Data()
                let sessionAgreement = SessionKeyEncryptor.shared.getAgreementPublicKey()
                let (sessionPublic, _) = SessionKeyEncryptor.shared.getKeys()
                
                if let remotePublicKey = try? P256.KeyAgreement.PublicKey(rawRepresentation:remoteSessionPublicKeyData) {
                    if let (cipherText, signature) = try? SessionKeyEncryptor.shared.encryptAndSign(remotePublicKey: remotePublicKey, message: sessionKeyData) {
                        let displayname = SettingsService.shared.settings.displayName.lengthOfBytes(using: .utf8) > 0 ?
                        SettingsService.shared.settings.displayName : SettingsService.shared.settings.serverUUID
                        
                        let response:AuthResponse = await AuthResponse(status: .success,
                                                                       uuid: SettingsService.shared.settings.serverUUID,
                                                                       sessionKey: cipherText,
                                                                       name: displayname,
                                                                       model: Device.current.safeDescription,
                                                                       publicKey: SettingsService.shared.settings.serverPublicKey,
                                                                       streamTCP: VideoStreamServer.shared.tcpPort(),
                                                                       streamQUIC: VideoStreamServer.shared.quicPort(),
                                                                       audioStreamTCP: AudioStreamServer.shared.tcpPort(),
                                                                       audioStreamQUIC: AudioStreamServer.shared.quicPort(),
                                                                       blocked: director.blocked,
                                                                       serverSessionPublicKey:sessionPublic.rawRepresentation,
                                                                       sessionSignature: signature,
                                                                       serverAgreementPublicKey: sessionAgreement.rawRepresentation,
                                                                       version:1)
                        send(response: response, director: director)
                    }
                }
            }
        })
    }
}


