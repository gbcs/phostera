//
//  DirectorProjectService.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 9/18/23.
//

import Foundation
import PhosteraShared

enum DirectorProjectServiceError: Error {
    case projectLoadFailed
}

class DirectorProjectService {
    static var shared = DirectorProjectService()
    private let directorProjectsDirectory:URL = URL.applicationSupportDirectory.appending(path: "dirproj")
    
    init() {
        if !FileManager.default.fileExists(atPath: directorProjectsDirectory.path) {
            do { try FileManager.default.createDirectory(at: directorProjectsDirectory, withIntermediateDirectories: true) } catch {
                Logger.shared.error("Unable to create directors directory.")
            }
        }
    }
    
    
    func loadProject(uuid:String) -> DirectorProjectModel? {
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:directorProjectsDirectory, includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return nil
        }
        
        let plistExt:String = "plist"
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if item.pathExtension.caseInsensitiveCompare(plistExt) != .orderedSame {
                continue
            }
            
            do {
                let project = try self.loadProject(url: item)
                if project.uuid == uuid {
                    return project
                }
            } catch {
                Logger.shared.error("Invalid file reading director list: \(item.path)")
            }
        }
        
        return nil
    }
    
    func projectListByDirector(director:DirectorModel) -> [DirectorProjectModel] {
        var projects:[DirectorProjectModel] = []
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:directorProjectsDirectory, includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return []
        }
        
        let plistExt:String = "plist"
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if item.pathExtension.caseInsensitiveCompare(plistExt) != .orderedSame {
                continue
            }
            
            do {
                let project = try self.loadProject(url: item)
                if project.directorUUID == director.uuid {
                    projects.append(project)
                }
            } catch {
                Logger.shared.error("Invalid file reading director list: \(item.path)")
            }
        }
        
        return projects
    }
    
    func ingest(project:DirectorProjectModel) {
        let url = self.directorProjectsDirectory.appendingPathComponent(project.uuid, conformingTo: .propertyList)
        
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(project) {
            do {
                try data.write(to:url)
                ModeHandler.shared.directorModes.cleanDirectorModes()
                ModeHandler.shared.directorModes.loadDirectorModes()
            } catch {
                Logger.shared.error("Unable to save project: \(url.path) - \(project.debugDescription)")
            }
        } else {
            Logger.shared.error("Unable to encode project: \(url.path) - \(project.debugDescription)")
        }
        
    }

    func loadProject(url:URL) throws -> DirectorProjectModel {
        if let data = try? Data(contentsOf: url) {
            let decoder = PropertyListDecoder()
            if let s = try? decoder.decode(DirectorProjectModel.self, from: data) {
                return s
            }
        }
        throw DirectorProjectServiceError.projectLoadFailed
    }
}
