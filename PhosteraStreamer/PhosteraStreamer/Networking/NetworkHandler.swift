//
//  NetworkHandler.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/21/23.
//

import Foundation
import Network
import Swift
import AVFoundation

actor NetworkHandler {
    static var shared = NetworkHandler()
    var cameraFinder:CameraFinder = CameraFinder()
    lazy var serverUUID:String = setupServerUUID()
    private var signupMessage:[String:String] = [:]
    private var pairCode:[String:String] = [:]
   
    func setupServerUUID() -> String {
        return SettingsService.shared.settings.serverUUID
    }

    func updateSignupMessage(uuid:String, message:String) {
        signupMessage[uuid] = message
    }
    
    func getSignupMessage(uuid:String) -> String {
        return signupMessage[uuid] ?? ""
    }
    
    func updatePairCode(uuid:String, code:String) {
        pairCode[uuid] = code
    }
    
    func getPairCode(uuid:String) -> String {
        return pairCode[uuid] ?? ""
    }
    
    var cameraCommandConnections:[String:CameraCommandConnector] = [String:CameraCommandConnector]()
    var cameraVideoStreamConnections:[String:CameraStreamConnector] = [String:CameraStreamConnector]()
    var cameraAudioStreamConnections:[String:CameraStreamConnector] = [String:CameraStreamConnector]()
    
    func finder(beUp:Bool) {
        if self.cameraFinder.isBrowsing() && (!beUp) {
            self.cameraFinder.stopBrowsing()
        } else if (!self.cameraFinder.isBrowsing()) && beUp {
            self.cameraFinder.startBrowsing()
        }
    }
    
    func removeAllCommandConnections () {
        cameraCommandConnections.removeAll()
    }
    
    func removeAllVideoConnections () {
        cameraVideoStreamConnections.removeAll()
    }
    
    func removeAllAudioConnections () {
        cameraAudioStreamConnections.removeAll()
    }
    
    func remove(command uuid:String) {
        cameraCommandConnections.removeValue(forKey: uuid)
    }
    
    func remove(video uuid:String) {
        if let c = cameraVideoStreamConnections[uuid] {
            cameraVideoStreamConnections.removeValue(forKey: uuid)
            c.cancel()
        }
    }
    
    func remove(audio uuid:String) {
        if let c = cameraAudioStreamConnections[uuid] {
            cameraAudioStreamConnections.removeValue(forKey: uuid)
            c.cancel()
        }
    }
    
    func getEndpoint(uuid:String) -> NWEndpoint? {
        return cameraFinder.getEndpointForUUID(uuid: uuid)
    }
    
    func updateCommandConnection(uuid:String, connector:CameraCommandConnector) {
        cameraCommandConnections[uuid] = connector
    }

    func connectCameraCommandChannel(uuid:String) -> CameraCommandConnector? {
        Logger.shared.info("Connecting command channel for \(uuid)")
        let connector = CameraCommandConnector()
        if let ep = getEndpoint(uuid: uuid) {
            Task(priority: .userInitiated, operation: { [weak self] in
                guard let self else { return }
                await connector.setEndpoint(ep: ep)
                await updateCommandConnection(uuid: uuid, connector: connector)
                await connector.startConnection(uuid: uuid)
            })
            return connector
        } else {
            Logger.shared.error("Endpoint problem connecting command channel to \(uuid)")
        }

        return nil
    }
    
    func updateVideoStreamConnection(uuid:String, connector:CameraStreamConnector) {
        cameraVideoStreamConnections[uuid] = connector
    }

    func connectCameraVideoStreamChannel(uuid:String) {
        let sequence = CameraManager.shared.onlineSeqIDs[uuid] ?? "000"

        //Logger.shared.info("will resolve, service: \(service)")
        DispatchQueue.main.async {
            let service = NetService(domain: "local.", type: "_phostera._tcp", name:uuid + sequence)
            BonjourResolver.resolve(service: service) { result in
                switch result {
                case .success((let hostName, _)):
                    //Logger.shared.error("did resolve, host: \(hostName)")
                    Task(priority: .userInitiated, operation: { [weak self] in
                        guard let self else { return }
                        let connector = CameraStreamConnector()
                        if let command = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                            let tcpPort = await command.streamTCP
                            if let epp = NWEndpoint.Port(rawValue: tcpPort) {
                                let eph = NWEndpoint.Host(stringLiteral: hostName)
                                let ep = NWEndpoint.hostPort(host: eph, port: epp)
                                Logger.shared.info("connecting video stream to \(hostName) on port: \(tcpPort)")
                                await updateVideoStreamConnection(uuid: uuid, connector: connector)
                                await connector.sessionKey = command.sessionKey
                                connector.setEndpoint(ep: ep, useQUIC: false)
                                connector.startConnection(uuid: uuid)
                            }  else {
                                Logger.shared.error("issue with endpoint")
                            }
                        }
                    })
                    
                    
                case .failure(let error):
                    Logger.shared.info("did not resolve: \(error)")
                }
            }
        }
    }
    
    func updateAudioStreamConnection(uuid:String, connector:CameraStreamConnector) {
        cameraAudioStreamConnections[uuid] = connector
    }
    
    func connectCameraAudioStreamChannel(uuid:String) {
        let sequence = CameraManager.shared.onlineSeqIDs[uuid] ?? "000"
        DispatchQueue.main.async {
            let service = NetService(domain: "local.", type: "_phostera._tcp", name:uuid + sequence)
            //Logger.shared.info("will resolve, service: \(service)")
            BonjourResolver.resolve(service: service) { result in
                switch result {
                case .success((let hostName, _)):
                    Task(priority: .userInitiated, operation: { [weak self] in
                        guard let self else { return }
                        let connector = CameraStreamConnector()
                        if let command = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                            let tcpPort = await command.audioStreamTCP
                            if let epp = NWEndpoint.Port(rawValue: tcpPort) {
                                let eph = NWEndpoint.Host(stringLiteral: hostName)
                                let ep = NWEndpoint.hostPort(host: eph, port: epp)
                                Logger.shared.info("connecting audio stream to \(hostName) on port: \(tcpPort)")
                                await updateAudioStreamConnection(uuid: uuid, connector: connector)
                                await connector.sessionKey = command.sessionKey
                                connector.setEndpoint(ep: ep, useQUIC: false)
                                connector.startConnection(uuid: uuid)
                            }  else {
                                Logger.shared.error("issue with endpoint")
                            }
                        }
                    })
                    
                    
                case .failure(let error):
                    Logger.shared.info("did not resolve: \(error)")
                }
            }
        }
    }
}