//
//  FootageService.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/12/23.
//

import UIKit
import PhosteraShared
import AVFoundation
import PhosteraShared

actor FootageService {
    static var shared = FootageService()
    
    static let footageDirectory:URL = URL.documentsDirectory.appending(path: "footage")
    
    static func getURLForNewVideo() -> URL {
        let uuid = UUID().uuidString.lowercased()
        return FootageService.footageDirectory.appendingPathComponent(uuid).appendingPathExtension("mov")
    }
    
    static func getURLForNewPhoto() -> URL {
        let uuid = UUID().uuidString.lowercased()
        return FootageService.footageDirectory.appendingPathComponent(uuid).appendingPathExtension("png")
    }
    
    static func getURLForMetadata(footage:FootageModel) -> URL {
        let file = footage.url.lastPathComponent
        let url = FootageService.footageDirectory.appendingPathComponent(file).appendingPathExtension(for: .propertyList)
        return url
    }
    
    static func getURL(footageURL:URL) -> URL {
        let file = footageURL.lastPathComponent
        let url = FootageService.footageDirectory.appendingPathComponent(file)
        return url
    }
    
    static func makeFootageDirectory() {
        if !FileManager.default.fileExists(atPath: FootageService.footageDirectory.path) {
            do { try FileManager.default.createDirectory(at: FootageService.footageDirectory, withIntermediateDirectories: false) } catch {
                Logger.shared.error("Unable to create footage directory.")
            }
        }
    }
    
    init() {
        FootageService.makeFootageDirectory()
    }
    
    static let defaultFootageList = [("Background", "png", "Default Background", FootageType.photo),
                       ("Background2", "png", "Alternate Default Background", FootageType.photo),
                       ("Preroll", "mov", "Default Preroll Video", FootageType.video),
                       ("Intro", "mov", "Default Intro Video", FootageType.video),
                       ("Interstitial", "mov", "Default Interstitial Video", FootageType.video),
                       ("Outro", "mov", "Default Outro Video", FootageType.video)
           ]
    
    static func loadInitialDefaultContent() {
        if !SettingsService.shared.settings.defaultContentLoaded {
            FootageService.makeFootageDirectory()
            
            for (itemFile, itemFileType, itemName, itemType) in FootageService.defaultFootageList {
                var url:URL?
                
                switch(itemType) {
                case .photo:
                    url = FootageService.getURLForNewPhoto()
                case .video:
                    url = FootageService.getURLForNewVideo()
                case .other:
                    fatalError("Default footage list contains unknown media type")
                }
                
                guard let url else { continue }
                let fileManager = FileManager.default
                
                if let bundlePath = Bundle.main.path(forResource: itemFile, ofType: itemFileType) {
                    do {
                        if fileManager.fileExists(atPath: bundlePath) {
                            
                            try fileManager.copyItem(at: URL(fileURLWithPath: bundlePath), to: url)
                            let footage = FootageService.makeFootage(url: url, type: itemType)
                            footage.name = itemName
                            Task {
                                await FootageService.shared.add(footage: footage)
                            }
                        } else {
                            Logger.shared.error("Bundle file not found: \(bundlePath)")
                        }
                    } catch {
                        Logger.shared.error("File copy failed: \(error)")
                    }
                }
            }
            
            Task {
                await ProjectService.shared.fillDefaultProject()
            }
        }
    }

    
    var lastCreatedModel:FootageModel?
    
    static func removeFromDisk(footage: FootageModel) {
        let fm = FileManager.default
        let meta = FootageService.getURLForMetadata(footage: footage)
        
        if fm.fileExists(atPath: meta.path) {
            try? fm.removeItem(atPath: meta.path)
        }
        
        let file = footage.url.lastPathComponent
        let url = FootageService.footageDirectory.appendingPathComponent(file)

        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(atPath: url.path)
        }
    }
    
    func add(footage: FootageModel) {
        let fm = FileManager.default
        let meta = FootageService.getURLForMetadata(footage: footage)
        if fm.fileExists(atPath: meta.path) {
            try? fm.removeItem(atPath: meta.path)
        }
        
        if let data = try? JSONEncoder().encode(footage) {
            do {
                try data.write(to: meta)
                lastCreatedModel = footage
                Logger.shared.info("Wrote footage to: \(meta.path) - name=\(footage.name)")
            } catch {
                Logger.shared.error("Unable to write footage to: \(meta.path) - name=\(footage.name) - error=\(error.localizedDescription)" )
            }
         
        }
    }
    
    func getPhotos() -> [FootageModel] {
        let list = footageList()
        var photos:[FootageModel] = []
        for photo in list {
            if photo.type == .photo {
                photos.append(photo)
            }
        }
        return photos
    }
    
    func getVideos() -> [FootageModel] {
        let list = footageList()
        var videos:[FootageModel] = []
        for video in list {
            if video.type == .video {
                videos.append(video)
            }
        }
        return videos
    }

    func footageList() -> [FootageModel] {
        var footage:[FootageModel] = []
        let fm = FileManager.default
        var files:[URL] = []
        
        do {
            files = try fm.contentsOfDirectory(at:FootageService.footageDirectory, includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return []
        }
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if !item.pathExtension.contains("plist") {
                continue
            }
            
            if let data = fm.contents(atPath: item.path) {
                if let f = try? JSONDecoder().decode(FootageModel.self, from: data) {
                    footage.append(f)
                    //Logger.shared.info("footage load: \(f.url.path) - name=\(f.name)")
                }
            }
        }
        
        return footage
    }

    static func makeFootage(url:URL, type:FootageType) -> FootageModel {
        return FootageModel(url: url, type: type, name: "")
    }
    
    static func videoMetadata(from url: URL) async -> VideoMetadata? {
        let exists = FileManager.default.fileExists(atPath: url.path)
        
        //Logger.shared.info("url:\(url) - \(exists)")
        let asset = AVAsset(url: url)
        do {
            
            let length = CMTimeGetSeconds(try await asset.load(.duration))
            
            for format in try await asset.load(.availableMetadataFormats) {
                _ = try await asset.loadMetadata(for: format)
                //Logger.shared.info("meta:\(metadata.debugDescription)")
            }
            
            guard let videoTrack = try await asset.loadTracks(withMediaType:.video).first else {
                return nil
            }
            
            let resolution = try await videoTrack.load(.naturalSize)
            let frameRate = try await videoTrack.load(.nominalFrameRate)
            
            
            let descriptions = try await videoTrack.load(.formatDescriptions)
            
            guard let encoding = descriptions.first.flatMap({
                CMFormatDescriptionGetExtension($0 , extensionKey: kCMFormatDescriptionExtension_FormatName) as? String
            }) else {
                return nil
            }
            
            let metadata = VideoMetadata(duration: length, resolution: resolution, frameRate: frameRate, encoding: encoding)
            
            //Logger.shared.info("videoMetadata:\(length) - \(resolution) - \(frameRate) - \(encoding)")
            
            return metadata
        } catch {
            return nil
        }
    }
    
    static func makeThumbnailFor(url:URL) -> UIImage? {
        let asset: AVAsset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        var thumbnailImage:CGImage?
        
        do {
            thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
        } catch let error {
            Logger.shared.error("make thumbnail error:\(error.localizedDescription)")
            return nil
        }
        
        if let thumbnailImage {
            return UIImage(cgImage: thumbnailImage)
        }
        
        return nil
    }
    
    func pruneFootage() {
        let fm = FileManager.default
        var files:[URL] = []

        let footage = footageList()
        
        do {
            files = try fm.contentsOfDirectory(at:FootageService.footageDirectory, includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return
        }

        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if item.pathExtension == "plist" {
                continue
            }
            
            if item.pathExtension == "caf" {
                continue
            }
            
            let itemFile = item.lastPathComponent
            
            var found:Bool = false
            
            for f in footage {
                if f.url.lastPathComponent == itemFile {
                    found = true
                    break
                }
            }
            
            if !found {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }

    func filesInFootageReport() {
        let fm = FileManager.default
        var files:[URL] = []
        
        var report:String = ""
        
        let footage = footageList()
        
        do {
            files = try fm.contentsOfDirectory(at:FootageService.footageDirectory, includingPropertiesForKeys: [.isRegularFileKey])
        } catch {
            return
        }
        
        for item in files {
            if !item.isFileURL {
                continue
            }
            
            if item.pathExtension == "plist" {
                continue
            }
            
            if item.pathExtension == "caf" {
                continue
            }
            
            let itemFile = item.lastPathComponent
            
            var found:Bool = false
            
            for f in footage {
                if f.url.lastPathComponent == itemFile {
                    found = true
                    break
                }
            }
            
            report += "\(item.lastPathComponent) - \(found ? "found" : "not found")\n"
        }
        
        print("\(report)")
    }
    
}

