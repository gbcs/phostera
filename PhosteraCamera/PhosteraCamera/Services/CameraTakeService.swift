//
//  CameraTakeService.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/26/23.
//

import Foundation
import PhosteraShared

class CameraTakeService {
    static var shared = CameraTakeService()
    
    private var currentTake:CameraTakeModel?
    
    func getCurrentTake() -> CameraTakeModel? {
        return currentTake
    }
    
    func hasTakes(director:DirectorModel) -> Bool {
        let list = DirectorProjectService.shared.projectListByDirector(director: director)
        for item in list {
             let takeDirectory = URL.applicationSupportDirectory
                .appending(component: "takes", directoryHint: .isDirectory)
                .appending(component: item.uuid, directoryHint: .isDirectory)
            
            if let count = try? FileManager.default.contentsOfDirectory(at: takeDirectory, includingPropertiesForKeys: nil).count {
                if count > 0 {
                    return true
                }
            }
        }
        
        return false
    }
    
    
    func delete(take:CameraTakeModel) {
        var takeFile:URL?
        
        if let currentProject = CamTool.shared.getCurrentProject() {
            let takeDirectory = URL.applicationSupportDirectory
                .appending(component: "takes", directoryHint: .isDirectory)
                .appending(component: currentProject.uuid, directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: takeDirectory, withIntermediateDirectories: true)
            takeFile = takeDirectory.appending(component: take.uuid, directoryHint: .notDirectory)
        } else {
            let takeDirectory = URL.applicationSupportDirectory
                .appending(component: "takes", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: takeDirectory, withIntermediateDirectories: true)
            takeFile = takeDirectory.appending(component: take.uuid, directoryHint: .notDirectory)
        }
        
        if let takeFile {
            do {
                try FileManager.default.removeItem(at: takeFile)
            } catch {
                Logger.shared.info("Unable to delete take file: \(String(describing: takeFile))")
            }
        }
    }
    
    func save(take:CameraTakeModel) {
        var takeFile:URL?
        
        if take.projectUUID != "" {
            let takeDirectory = URL.applicationSupportDirectory
                .appending(component: "takes", directoryHint: .isDirectory)
                .appending(component: take.projectUUID, directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: takeDirectory, withIntermediateDirectories: true)
            takeFile = takeDirectory.appending(component: take.uuid, directoryHint: .notDirectory)
        } else {
            let takeDirectory = URL.applicationSupportDirectory
                .appending(component: "takes", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: takeDirectory, withIntermediateDirectories: true)
            takeFile = takeDirectory.appending(component: take.uuid, directoryHint: .notDirectory)
        }
        
        if let takeFile {
            do {
                let enc = JSONEncoder()
                let data:Data = try enc.encode(take)
                try? FileManager.default.removeItem(at: takeFile)
                try data.write(to: takeFile)
            } catch {
                Logger.shared.info("Unable to write take file: \(String(describing: takeFile))")
            }
        }
    }
    
    func startTake() {
        
        Logger.shared.info("Starting take for project: \(CamTool.shared.getCurrentProject()?.uuid ?? "None")")
        
        var takeDirectory:URL?
        
        if let currentProject = CamTool.shared.getCurrentProject() {
            currentTake = CameraTakeModel( projectUUID: currentProject.uuid,
                                           cameraUUID: SettingsService.shared.settings.serverUUID,
                                           startTime: .now
            )
        } else {
            currentTake = CameraTakeModel( projectUUID: "",
                                           cameraUUID: SettingsService.shared.settings.serverUUID,
                                           startTime: .now
            )
        }
        
        if let currentProject = CamTool.shared.getCurrentProject(), let currentTake {
            takeDirectory = URL.documentsDirectory
                .appending(component: currentProject.uuid, directoryHint: .isDirectory)
                .appending(component: currentTake.uuid, directoryHint: .isDirectory)
            
            if let takeDirectory {
                currentTake.localTakeDirectory = takeDirectory.path
            }
            
        } else if let currentTake {
            takeDirectory = URL.documentsDirectory
                .appending(component: currentTake.uuid, directoryHint: .isDirectory)
            
            if let takeDirectory {
                currentTake.localTakeDirectory = takeDirectory.path
            }
        }
        
        if let takeDirectory {
            do {
                try FileManager.default.createDirectory(at: takeDirectory, withIntermediateDirectories: true)
            } catch {
                currentTake = nil
                Logger.shared.error("Unable to create take directory:\(String(describing: takeDirectory))")
                return
            }
        }
        
        if let _ = CamTool.shared.getCurrentProject() {
            if let currentTake {
                save(take: currentTake)
                ProjectRoute.shared.sendTakeMessage(take: currentTake, start: true)
            }
        }
    }
    
    func endTake() {
        guard let currentTake else { return }
        Logger.shared.info("Ending take for project: \(CamTool.shared.getCurrentProject()?.uuid ?? "None")")
        
        currentTake.endTime = .now
        
        if let _ = CamTool.shared.getCurrentProject() {
            save(take: currentTake)
            ProjectRoute.shared.sendTakeMessage(take: currentTake, start: false)
        }
        
        self.currentTake = nil
    }
    
    static func getTakeList(forProject:String) -> [CameraTakeModel] {
        let takeDirectory = URL.applicationSupportDirectory
            .appending(component: "takes", directoryHint: .isDirectory)
            .appending(component: forProject, directoryHint: .isDirectory)
        
        var tempList:[CameraTakeModel] = []
        
        let decoder = JSONDecoder()
        if let list = try? FileManager.default.contentsOfDirectory(at: takeDirectory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for takeFile in list {
                if let data = try? Data(contentsOf: takeFile) {
                    if let take = try? decoder.decode(CameraTakeModel.self, from: data) {
                        tempList.append(take)
                    }
                }
            }
        }
        return tempList.sorted(by: { c1, c2 in
            c1.startTime > c2.startTime
        })
    }
}
