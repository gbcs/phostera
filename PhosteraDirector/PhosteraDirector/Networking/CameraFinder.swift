//
//  CameraFinder.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/20/23.
//

import Network
import SwiftUI
import PhosteraShared

class CameraFinder {
    var browser: NWBrowser?
    var serviceList:[String:NWBrowser.Result] = [String:NWBrowser.Result]()
    
    func getEndpointForUUID(uuid:String) -> NWEndpoint? {
        let sequence = CameraManager.shared.onlineSeqIDs[uuid]
        
        if let service = serviceList[uuid + (sequence ?? "000")]  {
            return service.endpoint
        }
        return nil
    }
    
    func updateCameraAndDB(name:String, isOnline:Bool) {  //8 + 3
        let uuid = String(name.prefix(8))
        let sequence:Int = Int(String(name.suffix(3))) ?? 0
        
        CameraManager.shared.setUUIDStatus(uuid: uuid, online: isOnline)
        let currentSequence:Int = Int(CameraManager.shared.onlineSeqIDs[uuid] ?? "0") ?? 0
        if sequence > currentSequence {
            CameraManager.shared.onlineSeqIDs[uuid] = String(format: "%03d", sequence)
        }
        var camera = CameraManager.shared.getCamera(uuid: uuid)
        if (camera == nil) {
            camera = CameraModel(uuid: uuid, name: uuid, model: "Unknown", blocked: false)
            if (camera != nil) {
                _ =  CameraManager.shared.addCamera(camera: camera!)
            }
        }
    }
    
    func stopBrowsing() {
        browser?.cancel()
    }
    
    func isBrowsing() -> Bool {
        return browser?.state == .ready
    }
    
    func startBrowsing() {
        let parameters = CameraCommandConnector.createTLSParameters(allowInsecure: true, queue: .global(qos: .utility))
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: "_phostera._tcp", domain: "local."), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { newState in
            switch newState {
            case .failed(let error):
                // Restart the browser if it loses its connection.
                if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                    Logger.shared.error("Browser failed with \(error), restarting")
                    browser.cancel()
                    self.startBrowsing()
                } else {
                    Logger.shared.error("Browser failed with \(error), stopping")
                    browser.cancel()
                }
            case .ready:
                // Post initial results.
               Logger.shared.info("Browser ready")
                //notify app publish worked
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.networkAccessChanged, object: nil) }
            case .cancelled:
                Logger.shared.info("Browser cancelled")
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { results, changes in
            for change in changes {
                if case .added(let added) = change {
                    if case .service(let name, _, _, _) = added.endpoint {
                        let containsSpace = name.contains(where: { value in
                            return value == " "
                        })
                        if containsSpace {
                            Logger.shared.error("Browser name with a space. skipping: \(name)")
                            continue //Each run of the server has a unique sequence in server name, so dupes should not happen.
                        }
                        
                        if name.lengthOfBytes(using: .utf8) != 11 {
                            Logger.shared.error("Browser name does not match convention. Skipping: \(name)")
                            continue //8 + 3
                        }
          
                        self.updateCameraAndDB(name: name, isOnline: true)
                        self.serviceList[name] = added
                    }
                } else if case .removed(let removed) = change {
                    if case .service(let name, _, _, _) = removed.endpoint {
                        let containsSpace = name.contains(where: { value in
                            return value == " "
                        })
                        if containsSpace {
                            Logger.shared.error("Browser name with a space. skipping: \(name)")
                            continue //Each run of the server has a unique sequence in server name, so dupes should not happen.
                        }
                        
                        if name.lengthOfBytes(using: .utf8) != 11 {
                            Logger.shared.error("Browser name does not match convention. Skipping: \(name)")
                            continue //8 + 3
                        }
                        self.updateCameraAndDB(name: name, isOnline: false)
                        self.serviceList.removeValue(forKey: name)
                    }
                }
            }
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.updated, object: nil) }
        }
        
        browser.start(queue: .main)
    }
    
}

