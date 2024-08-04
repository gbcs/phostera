//
//  ExternalStorageService.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/29/23.
//

import UIKit
import AVFoundation

public struct ExternalStorageService {
    public static func storageDirectory() -> URL {
        let appSupport = URL.applicationSupportDirectory
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            do {
                try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Unable to create app support directory.\(error)")
            }
        }
        let storageURL = appSupport.appendingPathComponent("storage")
        if !FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                try FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Unable to create storage directory.\(error)")
            }
        }
        return storageURL
    }
    
    public static func getURLforExistingstorage(storage:StorageMediaModel) -> URL {
        return ExternalStorageService.storageDirectory().appendingPathComponent(storage.owningUUID).appendingPathExtension("storage")
    }
    
    public static func getURLforExistingStorage(owningUUID:String) -> URL {
        return ExternalStorageService.storageDirectory().appendingPathComponent(owningUUID).appendingPathExtension("storage")
    }
    
    public static func save(storage: StorageMediaModel) {
        let fm = FileManager.default
        let storageFile = ExternalStorageService.getURLforExistingstorage(storage: storage)
        if fm.fileExists(atPath: storageFile.path) {
            try? fm.removeItem(atPath: storageFile.path)
        }
        
        if let data = try? JSONEncoder().encode(storage) {
            do {
                try data.write(to: storageFile)
                print("Wrote storage to: \(storageFile.path) - name=\(storage.owningUUID)")
                
                
                if let p = ExternalStorageService.loadstorage(owningUUID: storage.owningUUID) {
                    print("read back: \(p.owningUUID)")
                } else {
                    print("no read")
                }
            } catch {
                print("Unable to write storage to: \(storageFile.path) - name=\(storage.owningUUID) - error=\(error.localizedDescription)" )
            }
        }
    }
    
    public static func loadstorage(owningUUID:String) -> StorageMediaModel? {
        let storageFile = ExternalStorageService.getURLforExistingStorage(owningUUID: owningUUID)
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageFile.path) {
            return nil
        }
        
        let data:Data? = fm.contents(atPath: storageFile.path)
        
        guard let data else {
            return nil
        }
        
        if let storage = try? JSONDecoder().decode(StorageMediaModel.self, from: data) {
            return storage
        }
        
        return nil
    }
    
    
    public static func storageList() -> [StorageMediaModel] {
        var storages:[StorageMediaModel] = []
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:ExternalStorageService.storageDirectory(), includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return []
        }
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if !item.pathExtension.contains("storage") {
                continue
            }
            
            if let data = fm.contents(atPath: item.path) {
                if let f = try? JSONDecoder().decode(StorageMediaModel.self, from: data) {
                    storages.append(f)
                    print("storage load: \(f.owningUUID) - name=\(f.volumeName)")
                }
            }
        }
        print("storage list: found \(storages.count) storage(s).")
        return storages
    }
}
