//
//  ProjectRoute.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/21/23.
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
              
                if projectResponse.command == .directorList {
                    if let list = try? decoder.decode(Array<DirectorModel>.self, from: projectResponse.data) {
                        for item in list {
                            DirectorService.shared.saveDirector(director: item)
                        }
                    }
                    DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Project.directorsUpdated, object: nil) }
                } else if projectResponse.command == .projectList {
                    if let list = try? decoder.decode(Array<DirectorProjectModel>.self, from: projectResponse.data) {
                        for item in list {
                            DirectorProjectService.shared.ingest(project: item)
                        }
                    }
                    DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Project.projectsUpdated, object: nil) }
                } else if projectResponse.command == .takeList {
                    if let list = try? decoder.decode(Array<CameraTakeModel>.self, from: projectResponse.data) {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name.Project.takeListUpdated,
                                                            object: nil,
                                                            userInfo: ["list" : list])
                        }
                    }
                } else if projectResponse.command == .takeMediaInfo {
                    if let item = try? decoder.decode(TakeMediaInfo.self, from: projectResponse.data) {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name.Project.takeMediaInfoUpdated,
                                                            object: nil,
                                                            userInfo: ["info" : item])
                        }
                    }
                } else if projectResponse.command == .makeProxyStatus {
                    if let item = try? decoder.decode(ProxyCreationStatus.self, from: projectResponse.data) {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name.Project.proxyCreationStatus,
                                                            object: nil,
                                                            userInfo: ["status" : item])
                        }
                    }
                } else if projectResponse.command == .takeMediaChunk {
                    let chunkData = projectResponse.data
                    DispatchQueue.main.async { [chunkData] in
                        NotificationCenter.default.post(name: NSNotification.Name.Project.proxyMediaChunk,
                                                        object: nil,
                                                        userInfo: ["chunk" : chunkData])
                    }
                }  else {
                    Logger.shared.info("invalid project response \(projectResponse.command)")
                }
            }
        })
    }
}

