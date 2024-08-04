//
//  ProjectRoute.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/29/23.
//

import Foundation
import PhosteraShared

public class ProjectRoute {
    static var shared = ProjectRoute()
    
    func handleRouting(content:Data?, command:CommandMessageType, connection:CameraCommandConnector, forCamera:String) {
        //Pull out the requested auth response
        Task(priority: .userInitiated, operation: {
            var projectResponse:ProjectResponse
            
            if (content == nil) || content!.isEmpty {
                Logger.shared.error("no data in handleRouting.\(command)")
                return
            }
            
            let decoder = JSONDecoder()
            do {
                projectResponse = try decoder.decode(ProjectResponse.self, from: content!)
            } catch {
                Logger.shared.error("decoder error:\(error)")
                return
            }
            
            if projectResponse.status == .success {
                if projectResponse.command == .takeMediaChunk {
                    let chunkData = projectResponse.data
                    DispatchQueue.main.async { [chunkData] in
                        NotificationCenter.default.post(name: NSNotification.Name.Project.proxyMediaChunk,
                                                        object: nil,
                                                        userInfo: ["chunk" : chunkData])
                    }
                }  else if projectResponse.command == .takeList {
                    if let list = try? decoder.decode(Array<CameraTakeModel>.self, from: projectResponse.data) {
                        if let project = DirectorProjectService.loadProject(uuid: projectResponse.projectUUID) {
                            let dirTakeList = TakeService.shared.getTakes(project: project)
                            for take in list {
                                var found:Bool = false
                                for dTake in dirTakeList  {
                                    if dTake.cameraTakeUUIDs[forCamera] == take.uuid {
                                        found = true
                                        break
                                    }
                                }
                                if !found {
                                    let newTake = DirectorTakeModel(projectUUID:projectResponse.projectUUID,
                                                                    cameraUUIDs: [forCamera],
                                                                    startTime: take.startTime)
                                    newTake.endTime = take.endTime
                                    newTake.cameraTakeUUIDs[forCamera] = take.uuid
                                    TakeService.save(take: newTake)
                                }
                            }
                        }
                        NotificationCenter.default.post(name: NSNotification.Name.Project.takeListUpdated, object: nil)
                    }
                } else {
                    Logger.shared.info("invalid project response \(projectResponse.command)")
                }
            }
        })
    }
}

