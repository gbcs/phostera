//
//  TakeService.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/17/23.
//

import Foundation
import PhosteraShared

class TakeService {
    static var shared = TakeService()
    
    var currentTake:DirectorTakeModel?
    
    func startTake(cameras:[String]) -> DirectorTakeModel? {
        let startTime:Date = Date.now
        if let proj = DirectorProjectService.currentProject() {
            let take = DirectorTakeModel(projectUUID:proj.uuid,
                                 cameraUUIDs: cameras,
                                 startTime: startTime
            )
            TakeService.save(take: take)
            currentTake = take
            return take
        }
        
        currentTake = nil
        return nil
    }
    
    func stop(take:DirectorTakeModel) {
        let stopTime:Date = Date.now
        take.endTime = stopTime
        TakeService.save(take: take)
        currentTake = nil
    }
    
    func getTakes(project:DirectorProjectModel) -> [DirectorTakeModel] {
        let url = TakeService.takeDirectory()
        if let itemContents = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            var takes:[DirectorTakeModel] = []
            
            for item in itemContents {
                let elements = item.split(separator: ".")
                if let fname = elements.first {
                    if let take = TakeService.loadTake(uuid: String(fname)) {
                        takes.append(take)
                    }
                }
            }
            
            return takes
        }
        
        return []
    }
    
    static func loadTake(uuid:String) -> DirectorTakeModel? {
        let decoder = JSONDecoder()
        let url = DirectorProjectService.projectDirectory().appendingPathComponent("takes").appendingPathComponent(uuid).appendingPathExtension("take")
        do {
            if let data = FileManager.default.contents(atPath: url.path) {
                return try decoder.decode(DirectorTakeModel.self, from: data)
            }
        } catch {
            Logger.shared.info("Unable to load take \(uuid) - \(error.localizedDescription)")
        }
        return nil
    }
    
    static func save(take:DirectorTakeModel) {
        let url = TakeService.getURLforExistingTake(take: take)
        let encoder = JSONEncoder()
        
        do {
            let data = try encoder.encode(take)
            try data.write(to: url)
        } catch {
            Logger.shared.error("Unable to save take: \(take.uuid) - \(error.localizedDescription)")
        }
    }
    
    init() {
        _ = TakeService.takeDirectory()
    }
    
    static func takeDirectory() -> URL {
        let takeURL = DirectorProjectService.projectDirectory().appendingPathComponent("takes")
        if !FileManager.default.fileExists(atPath: takeURL.path) {
            do {
                try FileManager.default.createDirectory(at: takeURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create takes support directory.\(error)")
            }
        }
        return takeURL
    }
    
    static func getURLForNewTake() -> (URL, String) {
        let uuid = UUID().uuidString.lowercased()
        return (DirectorProjectService.projectDirectory().appendingPathComponent("takes").appendingPathComponent(uuid).appendingPathExtension("take"), uuid)
    }
    
    static func getURLforExistingTake(take:DirectorTakeModel) -> URL {
        return DirectorProjectService.projectDirectory().appendingPathComponent("takes").appendingPathComponent(take.uuid).appendingPathExtension("take")
    }

}
