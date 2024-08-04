//
//  ProjectRoute.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/14/23.
//

import Foundation
import DeviceKit
import PhosteraShared

public class ProjectRoute {
    static var shared = ProjectRoute()
   
    func handleRouting(content:Data?, command:CommandMessageType, connection:CommandServerConnection) {
        if (content == nil) || content!.isEmpty {
            Logger.shared.error("no data in handleRouting.\(command.rawValue)")
            return
        }
        
        let decoder = JSONDecoder()
        var project:DirectorProjectModel?
       
        do {
            project = try decoder.decode(DirectorProjectModel.self, from: content!)
        } catch {
            Logger.shared.error("decoder error:\(error.localizedDescription)")
            return
        }
        
        Task { [project] in
            DispatchQueue.main.async {
                Logger.shared.info("Got project from director. \(String(describing: project))")
                if let project {
                    DirectorProjectService.shared.ingest(project: project)
                    Logger.shared.info("Project:\(project.title) - Codec:\(project.codec) - Colorspace:\(project.colorspace)")
                    CamTool.shared.update(project:project)
                }
            }
        }
    }
    
    
    func sendTakeMessage(take:CameraTakeModel, start:Bool) {
        Task {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(take)
                
                let response:CameraResponse = CameraResponse(status: .success, command: start ? .startTake : .endTake, data: data)
     
                let responseData:Data = try encoder.encode(response)
                
                if let project = CamTool.shared.getCurrentProject() {
                    await CommandServer.shared.connectionWithDirector(directorUUID: project.directorUUID, completion: { connection in
                        Task {
                            if let connection  {
                                await connection.sendToDirector(responseData, messsageType: .camera)
                            }
                        }
                    })
                }
            } catch {
                Logger.shared.error("sendProjectResponse: encoder error: \(error.localizedDescription)")
            }
        }
    }

}

