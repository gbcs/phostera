//
//  CameraManager.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/21/23.
//

import Foundation
import Combine
import PhosteraShared

public class CameraManager: NSObject {
    static var shared = CameraManager()
    @Published var onlineUUIDs:[String] = []
    @Published var onlineSeqIDs:[String:String] = [:]
    @Published var cameraList:[CameraModel] = []
    @Published var availableUUIDs:Set<String> = []
    @Published var standbyUUIDs:[String] = []
    @Published var standbyOpsUUIDS:[String] = []
    
    override init() {
        super.init()
        populateCameraList()
        loadAvailableCameras()
    }
    
    func isUUIDOnline(uuid:String) -> Bool {
        return self.onlineUUIDs.contains(uuid)
    }
    
    func setAvailableStatus(uuid:String, online:Bool) {
        if online {
            if !self.availableUUIDs.contains(uuid) {
                self.availableUUIDs.insert(uuid)
            }
        } else {
            if self.availableUUIDs.contains(uuid) {
                self.availableUUIDs.remove(uuid)
            }
        }
    }
    
    func setUUIDStatus(uuid:String, online:Bool) {
        if online {
            if !self.isUUIDOnline(uuid: uuid) {
                self.onlineUUIDs.append(uuid)
            }
        } else {
            if self.isUUIDOnline(uuid: uuid) {
                self.onlineUUIDs.removeAll { $0 == uuid }
            }
        }
        DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.online, object: nil) }
    }
    
    static func cameraListStorageURL() -> URL {
        let appSupport = URL.applicationSupportDirectory
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            do {
                try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create app support directory.\(error)")
            }
        }
        let cameraURL = appSupport.appendingPathComponent("cameras")
        if !FileManager.default.fileExists(atPath: cameraURL.path) {
            do {
                try FileManager.default.createDirectory(at: cameraURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create cameras support directory.\(error)")
            }
        }
        return cameraURL
    }
    
    static func availableCamerasStorageURL() -> URL {
        let appSupport = URL.applicationSupportDirectory
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            do {
                try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: false, attributes: nil)
            } catch {
                Logger.shared.error("Unable to create app support directory.\(error)")
            }
        }
        
        return appSupport.appendingPathComponent("availableCameras.plist")
    }
    
    func saveAvailableCameras() {
        let url = CameraManager.availableCamerasStorageURL()
        
        do {
            let itemJson = try JSONEncoder().encode(availableUUIDs)
            do { try FileManager.default.removeItem(atPath: url.path)
            } catch { } //Might not exist, so no worries.
            
            FileManager.default.createFile(atPath: url.path, contents: itemJson)
        } catch {
            Logger.shared.info("Unable to encode availableUUIDs for:\(url.path)")
        }
    }
    
    func loadAvailableCameras() {
        let url = CameraManager.availableCamerasStorageURL()
        
        let itemContents = FileManager.default.contents(atPath: url.path)
        if itemContents != nil {
            if let result = try? JSONDecoder().decode(Set<String>.self, from: itemContents!) {
                availableUUIDs = result
                Logger.shared.info("loadAvailableCameras: \(result)")
            }
        } else {
            Logger.shared.error("loadAvailableCameras error")
        }
    }
    
    func populateCameraList(){
        let cameraURL = CameraManager.cameraListStorageURL()
        
        do {
            let fileList = try FileManager.default.contentsOfDirectory(atPath: cameraURL.path)
            for item in fileList {
                let itemContents = FileManager.default.contents(atPath: cameraURL.appendingPathComponent(item).path)
                if itemContents != nil {
                    let camera = try! JSONDecoder().decode(CameraModel.self, from: itemContents!)
                    cameraList.append(camera)
                    Logger.shared.info("populateCameraList: \(camera.uuid)")
                }
            }
        } catch {
            Logger.shared.error("populateCameraList error: \(error)")
        }
    }
    
    func getCamera(uuid:String) -> CameraModel? {
        for camera in cameraList {
            if camera.uuid == uuid { return camera }
        }
        
        return nil
    }
    
    func removeCamera(camera:CameraModel) -> Bool {
        let cameraURL = CameraManager.cameraListStorageURL()

        do {
            let itemURL = cameraURL.appendingPathComponent(camera.uuid)
            Logger.shared.info("Removing camera  \(itemURL.path)")
            try FileManager.default.removeItem(at: itemURL)
        } catch {
            Logger.shared.error("file deletion error: \(error)")
        }
        
        cameraList.removeAll { entry in
            entry.uuid == camera.uuid
        }
        
        return false
    }
    
   func addCamera(camera:CameraModel) -> Bool {
        for entry in cameraList {
            if entry.uuid == camera.uuid {
                Logger.shared.error("Attempt to addCamera when it already exists. uuid=\(camera.uuid)")
                return false
            }
        }
        cameraList.append(camera)
       Logger.shared.info("addCamera: \(camera.uuid)")
        return saveCamera(camera: camera)
    }
    
    func saveCamera(camera:CameraModel) -> Bool {
        let cameraURL = CameraManager.cameraListStorageURL()
        let itemURL = cameraURL.appendingPathComponent(camera.uuid)
        
        var itemJson:Data?
        
        do {
           itemJson = try JSONEncoder().encode(camera)
        } catch {
            //Logger.shared.info("Unable to encode camera for:\(itemURL.path)")
            return false
        }

        do {
            try FileManager.default.removeItem(atPath: itemURL.path)
        } catch { } //Might not exist, so no worries.
        
        Logger.shared.info("Writing camera to \(itemURL.path)")
        return FileManager.default.createFile(atPath: itemURL.path, contents: itemJson)
    }
    
    func updateCamera(camera:CameraModel) -> Bool {
        return saveCamera(camera: camera)
    }
}
