//
//  ExternalStorageManager.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/29/23.
//

import Foundation
import PhosteraShared

public class ExternalStorageManager {
    
    public static func isLastPathComponentUUID(url: URL) -> Bool {
        let uuidPattern = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        let regex = try? NSRegularExpression(pattern: uuidPattern, options: [])
        let lastPathComponent = url.lastPathComponent
        let match = regex?.firstMatch(in: lastPathComponent, options: [], range: NSRange(location: 0, length: lastPathComponent.count))
        return match != nil
    }

    public  static func evaluateExternalURL(url:URL) -> (Bool, String) {
        if !isLastPathComponentUUID(url: url) {
            return (false, "Pick the root, not a subdirectory")
        }
        
        return (true, "Picked root directory")
    }
    
    public static func addExternalStorage(url:URL) -> StorageMediaModel? {
        //This gets us good URL. We can request final access via the bookmark once the user names it.
        //Do we have to unload this url yet? or after bookmark? research
        
        if !url.startAccessingSecurityScopedResource() {
            Logger.shared.error("Unable to access user selected directory")
            return nil
        }
        
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeIdentifierKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsReadOnlyKey]
        let volumeResources = try? url.resourceValues(forKeys: keys)
       
        guard let volumeResources else {
            Logger.shared.error("Unable to access volumeResources")
            url.stopAccessingSecurityScopedResource()
            return nil
        }
        
        let readOnly = volumeResources.volumeIsReadOnly ?? false
        let volumeName = volumeResources.volumeName ?? "Unknown"
        let totalCapacity = volumeResources.volumeTotalCapacity ?? -1
        let availableCapacity = volumeResources.volumeAvailableCapacity ?? -1
        var bookmarkData:Data?
        
        do {
           bookmarkData = try url.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            Logger.shared.error("Error creating bookmark for \(url) - \(error.localizedDescription)")
            url.stopAccessingSecurityScopedResource()
            return nil
        }
        
        guard let bookmarkData else { return nil } //Compiler happiness
        
        //Look for an existing storage file
        
        let storage_file_name = "Phostera.media.metadata"
        let metadataURL = url.appending(path: storage_file_name)
        
        var storage:StorageMediaModel?
        
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            do {
                if let data = FileManager.default.contents(atPath: metadataURL.path) {
                    let decoder = JSONDecoder()
                    storage = try decoder.decode(StorageMediaModel.self, from: data)
                }
            } catch {
                //Bad/old version maybe?
            }
        }
        
        if storage == nil {
            storage = StorageMediaModel(currentURL: url,
                                           owningUUID: SettingsService.shared.settings.serverUUID,
                                           readOnly: readOnly,
                                           volumeName: volumeName,
                                           totalCapacity: totalCapacity,
                                           availableCapacity: availableCapacity,
                                           bookmark: bookmarkData)
            
            var written:Bool = false
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(storage) {
                do {
                    try data.write(to: metadataURL)
                    written = true
                } catch {
                    Logger.shared.error("Unable to write storage metadata - \(metadataURL) - \(error.localizedDescription)")
                }
            }
            if !written {
                url.stopAccessingSecurityScopedResource()
                return nil
            }
        }
        
        url.stopAccessingSecurityScopedResource()
        return storage
    }

    
    public  static func loadExernalStorage(media:StorageMediaModel) -> URL? {
        var state:Bool = false
        if let bookmark = media.bookmark {
            do {
                let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &state)
                return url
            } catch {
                Logger.shared.error("Unable to loadExernalStorage - \(media.currentURL) - \(error.localizedDescription)")
            }
        }
        return nil
    }
}
