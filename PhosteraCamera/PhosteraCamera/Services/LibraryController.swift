//
//  LibraryController.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/5/23.
//

import Foundation
import Photos
import UIKit
import SwiftUI
import AVFoundation
import CoreGraphics
import PhosteraShared

enum LibraryError: Error {
    case fileAttributesProblem
    case findAllProblem
    case readDocumentsDirectory
}

extension Calendar {
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from)
        let toDate = startOfDay(for: to)
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate)
        
        return numberOfDays.day!
    }
}

public class LibraryController {
    static var shared = LibraryController()
    
    static func thumbnailUrlforFileUrl(fileUrl:URL) -> URL? {
        return URL(string:"\(fileUrl.path()).thumbnail.png")
    }
    
    static func getItemList(category:LibraryDateRange) async -> [FootageFileItem] {
        var itemList:[FootageFileItem] = []
        let fm = FileManager.default
        let path = URL.documentsDirectory
        var fileCount:Int = 0
        
        do {
            let dirList = try fm.contentsOfDirectory(at:path, includingPropertiesForKeys: [.isDirectoryKey])
            for d in dirList {
                let fileList = try fm.contentsOfDirectory(at:d, includingPropertiesForKeys: [.isRegularFileKey])
                for item in fileList {
                    if !item.isFileURL {
                        continue
                    }
                    
                    var skip:Bool = true
                    
                    if item.pathExtension.caseInsensitiveCompare("mov") == .orderedSame {
                        skip = false
                    } else if item.pathExtension.caseInsensitiveCompare("jpg") == .orderedSame {
                        skip = false
                    } else if item.pathExtension.caseInsensitiveCompare("raw") == .orderedSame {
                        skip = false
                    }
                    
                    if skip { continue }
                    
                    do {
                        let attrs = try FileManager.default.attributesOfItem(atPath: item.path)
                        let foundItem = FootageFileItem(url: item.path,
                                                        size: (attrs[FileAttributeKey.size] as? NSNumber)!.uint64Value,
                                                        creationDate: (attrs[FileAttributeKey.creationDate] as? Date)!,
                                                        thumbnailURL: LibraryController.makeThumbnailFor(url: item))
                        
                        
                        
                        switch(category) {
                        case .today:
                            if !Calendar.current.isDateInToday(foundItem.creationDate) { continue }
                        case .yesterday:
                            if !Calendar.current.isDateInYesterday(foundItem.creationDate) { continue }
                        case .earlier:
                            if Calendar.current.numberOfDaysBetween(foundItem.creationDate, and: Date(timeIntervalSinceNow: 0)) < 2 { continue }
                        }
                        
                        
                        fileCount += 1
                        if fileCount > 100 {
                            break //No more files
                        }
                        
                        itemList.append(foundItem)
                        if let url = URL(string:foundItem.url) {
                            if url.pathExtension.lowercased() == "mov" {
                                foundItem.videoMetadata = await VideoMetadata.videoMetadata(from: item)
                            } else {
                                foundItem.photoMetadata = await PhotoMetadata.photoMetadata(from: item)
                            }
                        }
                    } catch {
                        print ("\(item.path) - error:\(error.localizedDescription)")
                        continue;
                    }
                }
            }
            
        } catch {
            return []
        }
        
        
        return itemList.sorted {
            $0.creationDate > $1.creationDate
        }
    }
    
    static func hasPermissionDenied() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        return (status == .denied)
    }
    
    static func hasPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let answer:Bool = ((status == .authorized) || (status == .limited) || (status == .restricted))
        return answer
    }
    
    static func requestPermission() {
        if (!(hasPermission()) && (!hasPermissionDenied())) {
            PHPhotoLibrary.requestAuthorization(for: PHAccessLevel.addOnly) { status in
                DispatchQueue.main.async { NotificationCenter.default.post(name: .libraryAccessChanged, object: nil) }
            }
        }
    }
    
    static func makeThumbnailFor(url:URL) -> Bool {
        let thumbUrl = URL(string:"\(url.path()).thumbnail.png")
        guard let thumbUrl else { return false }
        
        let ext = url.pathExtension
        if ext.caseInsensitiveCompare("mov") == .orderedSame {
            
            if FileManager.default.fileExists(atPath: thumbUrl.path) {
                return true
            }
            
            let asset: AVAsset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            var thumbnailImage:CGImage?
            
            do {
                thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            } catch let error {
                Logger.shared.error("makeThumbnail error:\(error.localizedDescription)")
                return false
            }
            
            let i:UIImage = UIImage(cgImage: thumbnailImage!)
            FileManager.default.createFile(atPath: thumbUrl.path,
                                           contents: i.pngData(),
                                           attributes: .none)
            
            
            if FileManager.default.fileExists(atPath: thumbUrl.path) {
                return true
            }
        } else if ext.caseInsensitiveCompare("jpg") == .orderedSame {
            guard let image = UIImage(contentsOfFile: url.path) else {
                Logger.shared.error("no image found at \(url)")
                return false
            }
            let size = CGSizeMake(200, 200.0/(16.0/9.0))
            
            let widthRatio  = size.width  / image.size.width
            let heightRatio = size.height / image.size.height
            
            let ratio = min(widthRatio, heightRatio)
            
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let newImage else {
                Logger.shared.error("Unable to create a thumbnail image from \(url)")
                return false
            }
            
            guard let data = newImage.pngData() else {
                Logger.shared.error("Unable to create a png from thumbnail image from \(url)")
                return false
            }
            do {
                try data.write(to: thumbUrl)
            } catch {
                Logger.shared.error("Unable to write png data for \(url) to \(thumbUrl)")
                return false
            }
            
            if FileManager.default.fileExists(atPath: thumbUrl.path) {
                return true
            }
            
        } else {
            Logger.shared.error("makeThumbnailFor: \(url.path) - not handled")
        }
        
        return false
    }
    
    static func getImageFromFile(path:String) -> UIImage? {
        if FileManager.default.fileExists(atPath: path){
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
    
    static func getThumbnailImage(path:String) -> UIImage? {
        let selURL = URL(string: path)
        guard let selURL else { return nil }
        
        let thumbURL = LibraryController.thumbnailUrlforFileUrl(fileUrl: selURL)
        guard let thumbURL else { return nil }
        
        if FileManager.default.fileExists(atPath: thumbURL.path){
            return UIImage(contentsOfFile: thumbURL.path)
        }
        
        return nil
    }
    
    static func removeSelectedItemFromDisk(item:FootageFileItem) {
        let folder = URL(filePath: item.url).deletingLastPathComponent()
        let folder2 = URL(fileURLWithPath: folder.path, isDirectory: true)
        
        do {
            try FileManager.default.removeItem(at: folder2)
        } catch {
            Logger.shared.error("removeSelectedItemFromDisk error:\(error.localizedDescription)")
        }
    }
    
    enum VideoMetadataError: Error {
        case trackNotFound
        case encodingNotFound
    }
    
    static func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        
        // Check if the source is a directory
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // Create the destination directory if it doesn't exist
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                
                // Get the contents of the source directory
                let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil, options: [])
                
                // Recursively copy each item in the source directory
                for item in contents {
                    let destinationItemURL = destinationURL.appendingPathComponent(item.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: destinationItemURL.path()) {
                        try LibraryController.copyItem(at: item, to: destinationItemURL)
                    }
                }
            } else {
                // Copy the file from source to destination
                if !FileManager.default.fileExists(atPath: destinationURL.path()) {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
            }
        }
    }
    
    
    static func copyItemToExternalStorage(takeUUID:String) -> Bool {
        var found:Bool = false
        for storage in ExternalStorageService.storageList() {
            if let mediaURL = ExternalStorageManager.loadExernalStorage(media: storage) {
                if mediaURL.startAccessingSecurityScopedResource() {
                    let source = URL.documentsDirectory.appending(path: takeUUID, directoryHint: .isDirectory)
                    let destination = mediaURL.appending(path: takeUUID, directoryHint: .isDirectory)
                    Logger.shared.info("Start copying \(source) to \(destination) on storage \(mediaURL)")
                     
                    do {
                        try LibraryController.copyItem(at: source, to: destination)
                    } catch {
                        Logger.shared.error("Error copying \(source) to \(destination) on storage \(mediaURL) - \(error.localizedDescription)")
                    }
                    mediaURL.stopAccessingSecurityScopedResource()
                    Logger.shared.info("Finished copying \(source) to \(destination) on storage \(mediaURL)")
                    found = true
                    break
                } else {
                    Logger.shared.error("Unable to access storage at \(mediaURL)")
                }
            }
        }
        if !found {
            Logger.shared.error("Unable to find storage to copy take:\(takeUUID) to")
        }
        return found
    }
    
    static func copyItemToExternalStorage(projectUUID:String, takeUUID:String) -> Bool {
        var found:Bool = false
        for storage in ExternalStorageService.storageList() {
            if let mediaURL = ExternalStorageManager.loadExernalStorage(media: storage) {
                if mediaURL.startAccessingSecurityScopedResource() {
                    let source = URL.documentsDirectory
                        .appending(path: projectUUID, directoryHint: .isDirectory)
                        .appending(path: takeUUID, directoryHint: .isDirectory)
                    
                    let destination = mediaURL.appending(path: takeUUID, directoryHint: .isDirectory)
                    Logger.shared.info("Start copying \(source) to \(destination) on storage \(mediaURL)")
                     
                    do {
                        try LibraryController.copyItem(at: source, to: destination)
                        
                        let takeFileSrc = URL.applicationSupportDirectory
                            .appending(component: "takes", directoryHint: .isDirectory)
                            .appending(component: projectUUID, directoryHint: .isDirectory)
                            .appending(component: takeUUID, directoryHint: .notDirectory)
                        
                        let  takeFileDst = mediaURL
                            .appending(component: projectUUID, directoryHint: .isDirectory)
                            .appending(component: takeUUID, directoryHint: .isDirectory)
                            .appending(component: takeUUID, directoryHint: .notDirectory)
                        
                        if FileManager.default.fileExists(atPath: takeFileDst.path()) {
                            Logger.shared.info("dst exists:\(takeFileDst)")
                        } else {
                            try? FileManager.default.copyItem(at: takeFileSrc, to: takeFileDst)
                        }
                    } catch {
                        Logger.shared.error("Error copying \(source) to \(destination) on storage \(mediaURL) - \(error.localizedDescription)")
                    }
    
                    mediaURL.stopAccessingSecurityScopedResource()
                    Logger.shared.info("Finished copying \(source) to \(destination) on storage \(mediaURL)")
                    found = true
                    break
                } else {
                    Logger.shared.error("Unable to access storage at \(mediaURL)")
                }
            }
        }
        if !found {
            Logger.shared.error("Unable to find storage to copy take:\(takeUUID) to")
        }
        return found
    }
    
    
    
}
