//
//  CameraRoute.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/26/23.
//

import Foundation
import PhosteraShared

public class CameraRoute {
    static var shared = CameraRoute()
    
    func handleRouting(content:Data?, command:CommandMessageType, connection:CameraCommandConnector, forCamera:String) {
        //Pull out the requested auth response
        var cameraResponse:CameraResponse
        
        if (content == nil) || content!.isEmpty {
            Logger.shared.error("no data in handleRouting.\(command)")
            return
        }
        
        let decoder = JSONDecoder()
        do {
            cameraResponse = try decoder.decode(CameraResponse.self, from: content!)
        } catch {
            Logger.shared.error("decoder error:\(error)")
            return
        }
        
        Logger.shared.info("Camera response: \(cameraResponse.status == .success ? "success" : "failure") - \(cameraResponse.command) - data:\(String(describing: content?.bytes.count))")
       
        if content != nil {
            if (cameraResponse.command == .startTake) || (cameraResponse.command == .endTake) {
                let decoder = JSONDecoder()
                do {
                    let take = try decoder.decode(CameraTakeModel.self, from: cameraResponse.data)
                    Logger.shared.info("got take: \(take.uuid)")
                    DispatchQueue.main.async {
                        if DirectorProjectService.currentProject() != nil {
                            if let currentTake = TakeService.shared.currentTake {
                                if !currentTake.cameraUUIDs.contains(take.cameraUUID) {
                                    currentTake.cameraUUIDs.append(take.cameraUUID)
                                }
                                
                                currentTake.cameraTakeUUIDs[take.cameraUUID] = take.uuid
                                TakeService.save(take: currentTake)
                            } else {
                                if cameraResponse.command == .startTake {
                                    if let t = TakeService.shared.startTake(cameras: [take.cameraUUID]) {
                                        t.cameraTakeUUIDs[take.cameraUUID] = take.uuid
                                        TakeService.save(take: t)
                                        TakeService.shared.currentTake = nil
                                    }
                                }
                            }
                        }
                    }
                } catch {
                   // Logger.shared.info("error decoding take: \(error.localizedDescription)")
                }
            }
        }
    
        //Handle response code, any data
        //DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.updated, object: nil) }

    }
}


