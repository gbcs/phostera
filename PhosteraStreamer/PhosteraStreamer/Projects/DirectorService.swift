//
//  DirectorService.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/22/23.
//

import Foundation
import PhosteraShared

enum DirectorServiceError: Error {
    case directorLoadFailed
}

class DirectorService {
    static var shared = DirectorService()
    private let directorDirectory:URL = URL.applicationSupportDirectory.appending(path: "directors")
    
    init() {
        if !FileManager.default.fileExists(atPath: directorDirectory.path) {
            do { try FileManager.default.createDirectory(at: directorDirectory, withIntermediateDirectories: true) } catch {
                Logger.shared.error("Unable to create directors directory.")
            }
        }
    }
    
    func findDirectorWithPublicKey(key:Data) -> DirectorModel? {
        for director in self.directorList() {
            if director.publicKey == key {
                return director
            }
        }
        return nil
    }
    
    func findDirectorWithUUID(uuid:String) -> DirectorModel? {
        for director in self.directorList() {
            if director.uuid == uuid {
                return director
            }
        }
        return nil
    }
    
    func directorList() -> [DirectorModel] {
        var directors:[DirectorModel] = []
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:directorDirectory, includingPropertiesForKeys: [.isRegularFileKey])
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
                let director = try self.loadDirector(url: item)
                directors.append(director)
            } catch {
                Logger.shared.error("Invalid file reading director list: \(item.path)")
            }
        }
        
        return directors
    }
    
    func saveDirector(director:DirectorModel) {
        let p = self.directorDirectory.appendingPathComponent(director.uuid, conformingTo: .propertyList)
        _ = self.save(url: p, director: director)
    }
    
    func deleteDirector(director:DirectorModel) {
        let p = self.directorDirectory.appendingPathComponent(director.uuid, conformingTo: .propertyList)
        do { try FileManager.default.removeItem(at: p) } catch {
            Logger.shared.error("Unable to delete director: \(director.debugDescription) at: \(p.path)")
        }
    }
    
    private func save(url:URL, director:DirectorModel) -> Bool {
        var answer = false
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(director) {
            do {
                try data.write(to:url)
                answer = true
            } catch {
                Logger.shared.error("Unable to save director: \(url.path) - \(director.debugDescription)")
            }
        } else {
            Logger.shared.error("Unable to encode director: \(url.path) - \(director.debugDescription)")
        }
        
        return answer
    }
    
    func loadDirector(url:URL) throws -> DirectorModel {
        if let data = try? Data(contentsOf: url) {
            let decoder = PropertyListDecoder()
            if let s = try? decoder.decode(DirectorModel.self, from: data) {
                return s
            }
        }
        throw DirectorServiceError.directorLoadFailed
    }
    
}
