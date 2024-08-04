//
//  ProjectService.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/11/23.
//

import Foundation
import PhosteraShared

//MetalTool.shared.streamer.setup(url: "rtmp://192.168.42.1:1935", name: "live")
//MetalTool.shared.streamer.setup(url: "rtmp://192.168.1.24:1935/live", name: "live")
//MetalTool.shared.streamer.setup(url: "rtmp://a.rtmp.youtube.com/live2/djhc-87xr-5r2j-jra9-duca", name: "djhc-87xr-5r2j-jra9-duca")


enum ProjectServiceError: Error {
    case projectLoadFailed
}

actor ProjectService {
    static var shared = ProjectService()
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
    
    static func frameRate(project:StreamProjectModel) -> Double {
        switch project.streamFrameRate {
        case .fr24:
            return 1000 / 24
        case .fr25:
            return 1000 / 25
        case .fr30:
            return 1000 / 29.97
        }
    }
    
    
    
    func fillDefaultProject() {
        let project = currentProject()
        
        if (project.id == "default") && (project.mediaBackgroundImage == nil) {
            //Fill in the project details for the default project. (post footage service loading them up)
            Task {
                let list = await FootageService.shared.footageList()
                
                for item in list {
                    if item.name == FootageService.defaultFootageList[0].2 {
                        project.mediaBackgroundImage = item
                    } else if item.name == FootageService.defaultFootageList[2].2 {
                        project.mediaPreroll = item
                    } else if item.name == FootageService.defaultFootageList[3].2 {
                        project.mediaIntro = item
                    } else if item.name == FootageService.defaultFootageList[4].2 {
                        project.mediaInterstitial = item
                    } else if item.name == FootageService.defaultFootageList[5].2 {
                        project.mediaOutro = item
                    }
                }
                await _ = ProjectService.shared.save(project: project)
                DispatchQueue.main.async {
                    SettingsService.shared.settings.defaultContentLoaded = true
                    SettingsService.shared.save()
                }
            }
        }
    }
    
    
    func currentProject() -> StreamProjectModel {
        let projectId = SettingsService.shared.settings.currentProjectId
        //Logger.shared.info("Loading current projectId: \(projectId)")
        let url = ProjectService.projectDirectory().appendingPathComponent(projectId, conformingTo: .propertyList)
        guard let project = try? loadProject(url: url) else {
            if projectId == "default" { return makeInitialProjectEntry() }
            let p = StreamProjectModel(id: projectId, title: projectId == "default" ? "Default" : "Rebuilt", streamResolution: .v1920x1080, streamFrameRate: .fr30)
            _ = save(project: p)
            Logger.shared.info("Unable to load current project \(projectId). Making a new one.")
            return p
        }
        return project
    }
    
    init() {
        if !FileManager.default.fileExists(atPath: ProjectService.projectDirectory().path) {
            do { try FileManager.default.createDirectory(at: ProjectService.projectDirectory(), withIntermediateDirectories: false) } catch {
                Logger.shared.error("Unable to create projects directory.")
            }
        }
    }
    
    func makeInitialProjectEntry() -> StreamProjectModel {
        let p = StreamProjectModel(id: "default", title: "Default", streamResolution: .v1920x1080, streamFrameRate: .fr30)
        p.defaultUserMessage = "Stream the world around us to my viewers."
        _ = save(project: p)
        return p
    }
    
    func findProjectWith(id:String) -> StreamProjectModel? {
        for project in projectList() {
            if project.id == id {
                return project
            }
        }
        return nil
    }
    
    func projectList() -> [StreamProjectModel] {
        var projects:[StreamProjectModel] = []
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:ProjectService.projectDirectory(), includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return []
        }
        
        let plistExt:String = "plist"
        
        if files.count == 0 {
            let project = makeInitialProjectEntry()
            let url = ProjectService.projectDirectory().appendingPathComponent(project.id, conformingTo: .propertyList)
            files.append(url)
        }
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if item.pathExtension.caseInsensitiveCompare(plistExt) != .orderedSame {
                continue
            }
            
            do {
                let project = try self.loadProject(url: item)
                projects.append(project)
            } catch {
                Logger.shared.error("Invalid file reading project list: \(item.path)")
            }
        }
        
        return projects
    }
    
    func save(project:StreamProjectModel) -> Bool {
        let p = ProjectService.projectDirectory().appendingPathComponent(project.id, conformingTo: .propertyList)
        let answer = self.save(url: p, project: project)
        return answer
    }
    
    func delete(project:StreamProjectModel) {
        let p = ProjectService.projectDirectory().appendingPathComponent(project.id, conformingTo: .propertyList)
        do { try FileManager.default.removeItem(at: p) } catch {
            Logger.shared.error("Unable to delete project: \(project.debugDescription) at: \(p.path)")
        }
    }
    
    private func save(url:URL, project:StreamProjectModel) -> Bool {
        var answer = false
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(project) {
            do {
                try data.write(to:url)
                answer = true
            } catch {
                Logger.shared.error("Unable to save project: \(url.path) - \(project.debugDescription)")
            }
        } else {
            Logger.shared.error("Unable to encode project: \(url.path) - \(project.debugDescription)")
        }
        
        return answer
    }
    
    func loadProject(url:URL) throws -> StreamProjectModel {
        if let data = try? Data(contentsOf: url) {
            let decoder = PropertyListDecoder()
            if let s = try? decoder.decode(StreamProjectModel.self, from: data) {
                return s
            }
        }
        throw ProjectServiceError.projectLoadFailed
    }
}

