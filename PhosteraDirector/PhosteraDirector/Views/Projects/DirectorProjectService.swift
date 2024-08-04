//
//  ProjectService.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/17/23.
//

import UIKit
import PhosteraShared
import AVFoundation

struct DirectorProjectService {
    static func projectDirectory() -> URL {
        let appSupport = URL.applicationSupportDirectory
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            do {
                try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create app support directory.\(error)")
            }
        }
        let projectURL = appSupport.appendingPathComponent("projects")
        if !FileManager.default.fileExists(atPath: projectURL.path) {
            do {
                try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create projects support directory.\(error)")
            }
        }
        return projectURL
    }
    
    static func getURLForNewProject() -> (URL, String) {
        let uuid = UUID().uuidString.lowercased()
        return (DirectorProjectService.projectDirectory().appendingPathComponent(uuid).appendingPathExtension("project"), uuid)
    }
    
    static func getURLforExistingProject(project:DirectorProjectModel) -> URL {
        return DirectorProjectService.projectDirectory().appendingPathComponent(project.uuid).appendingPathExtension("project")
    }
    
    static func getURLforExistingProject(uuid:String) -> URL {
        return DirectorProjectService.projectDirectory().appendingPathComponent(uuid).appendingPathExtension("project")
    }
    
    static func save(project: DirectorProjectModel) {
        let fm = FileManager.default
        let projectFile = DirectorProjectService.getURLforExistingProject(project: project)
        if fm.fileExists(atPath: projectFile.path) {
            try? fm.removeItem(atPath: projectFile.path)
        }
        
        if let data = try? JSONEncoder().encode(project) {
            do {
                //Logger.shared.info("a: \(String(describing: String(data: data, encoding: .utf8)))")
                
                try data.write(to: projectFile)
                Logger.shared.info("Wrote project to: \(projectFile.path) - name=\(project.title)")
//                
//                
//                if let p = DirectorProjectService.loadProject(uuid: project.uuid) {
//                    Logger.shared.info("read back: \(p.uuid)")
//                } else {
//                    Logger.shared.error("no read back. \(p.uuid)")
//                }
            } catch {
                Logger.shared.error("Unable to write project to: \(projectFile.path) - name=\(project.title) - error=\(error.localizedDescription)" )
            }
        }
    }
    
    static func loadProject(uuid:String) -> DirectorProjectModel? {
        let projectFile = DirectorProjectService.getURLforExistingProject(uuid: uuid)
        let fm = FileManager.default
        if !fm.fileExists(atPath: projectFile.path) {
            return nil
        }
        
        let data:Data? = fm.contents(atPath: projectFile.path)
        
        guard let data else { 
            return nil
        }
        
        if let project = try? JSONDecoder().decode(DirectorProjectModel.self, from: data) {
            return project
        }
        
        return nil
    }
    
    
    static func projectList() -> [DirectorProjectModel] {
        var projects:[DirectorProjectModel] = []
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:DirectorProjectService.projectDirectory(), includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return []
        }
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if !item.pathExtension.contains("project") {
                continue
            }
            
            if let data = fm.contents(atPath: item.path) {
                if let f = try? JSONDecoder().decode(DirectorProjectModel.self, from: data) {
                    projects.append(f)
                    Logger.shared.info("project load: \(f.id) - name=\(f.title)")
                }
            }
        }
        Logger.shared.info("Project list: found \(projects.count) project(s).")
        return projects
    }
    
    public static func makeBaseProjectModel() -> DirectorProjectModel {
        let project = DirectorProjectModel(title: "Default", directorUUID: SettingsService.shared.settings.serverUUID)
        let settings = CurrentModeMetadata(resolution: .v1920x1080, 
                                           frameRate: .fr24,
                                           codec: .proRes422HQ,
                                           colorspace: .rec709,
                                           fileNamingScheme: .scheme1,
                                           fileStorageLocation: .appStorage,
                                           recordToDisk: false)
        
        let mode = DirectorProjectCameraMode(type: .wide,
                                             title: "Wide Lens",
                                             desc: "Compatible",
                                             settings: settings,
                                             aspectRatio: CGSizeMake(16, 9),
                                             version: 1, 
                                             provider: SettingsService.shared.settings.serverUUID,
                                             frontCamera: false,
                                             photoMode: false,
                                             techType: .cifilter,
                                             projectUUID: project.uuid)
        project.modeList.append(mode)
        
        return project
    }
    
    static func makeInitialProject() -> DirectorProjectModel {
        let project = DirectorProjectService.makeBaseProjectModel()
        DirectorProjectService.save(project: project)
        
        if let project2:DirectorProjectModel = DirectorProjectService.loadProject(uuid: project.uuid) {
            if project2.uuid != project.uuid {
                Logger.shared.info("project oddness=\(project.uuid)")
            }
        }

        Logger.shared.info("created Default project with id=\(project.uuid)")
        
        return project
    }
    
    static func checkOnStartup() {
        if SettingsService.shared.settings.currentProjectId.lengthOfBytes(using: .utf8) < 1 {
            let project = DirectorProjectService.makeInitialProject()
            DispatchQueue.main.async {
                SettingsService.shared.settings.currentProjectId = project.uuid
                SettingsService.shared.save()
            }
        }
    }
    
    static func currentProject() -> DirectorProjectModel? {
        if SettingsService.shared.settings.currentProjectId.lengthOfBytes(using: .utf8) > 0 {
           return  DirectorProjectService.loadProject(uuid: SettingsService.shared.settings.currentProjectId)
        }
        return nil
    }
    
    static func removeAllTakesAndMediaFor(project:DirectorProjectModel) {
        let takes = TakeService.shared.getTakes(project: project)

        for take in takes {
            let takeDirectory = TakeService.getURLforExistingTake(take: take)
            
            
            let takeStorageURL = URL.documentsDirectory
                .appending(path: take.projectUUID, directoryHint: .isDirectory)
                .appending(path: take.uuid, directoryHint: .isDirectory)
            
            try? FileManager.default.removeItem(at: takeStorageURL)
            
            //Remove take file
            try? FileManager.default.removeItem(at: takeDirectory)
        }
    }
}
