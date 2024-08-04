//
//  StandbyModeService.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/26/23.
//

import Foundation
import UIKit
import AVFoundation
import PhosteraShared
import Combine

class StandbyModeService {
    static var shared = StandbyModeService()
    
    private var takeCopyList:[String] = []
    private var directorList:[DirectorModel] = []
    private var mediaURL:URL?
    private var videoSaver:VideoSaver = VideoSaver()
    private var keepGoing:Bool = true
    var takeCount:Int = 0
    var copyCompleted:Int = 0
    var projdirtakeList:[(DirectorModel, DirectorProjectModel, CameraTakeModel)] = []
    var runningProxy:Bool = false
    
    @Published var isRunning:Bool = false
    @Published var standbyMessage:String = ""
    
    func resetForNextProxy() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            updateStandbyMessage()
            makeNextProxy()
        }
    }
    
    func makeProxy(project:DirectorProjectModel, take:CameraTakeModel) {
        Task {
            let inputURL:URL = URL.documentsDirectory
                .appending(path: project.uuid, directoryHint: .isDirectory)
                .appending(path: take.uuid, directoryHint: .isDirectory)
                .appending(path: take.uuid, directoryHint: .notDirectory)
                .appendingPathExtension(for: .quickTimeMovie)
        
            let outputURL:URL = URL.documentsDirectory
                .appending(path: project.uuid, directoryHint: .isDirectory)
                .appending(path: take.uuid, directoryHint: .isDirectory)
                .appending(path: project.directorUUID, directoryHint: .isDirectory)
                .appendingPathExtension(for: .quickTimeMovie)
            
            var frameRate = 30
            
            switch project.frameRate {
            case .fr24:
                frameRate = 24
            case .fr25:
                frameRate = 25
            case .fr30:
                frameRate = 30
            }
            
            if !FileManager.default.fileExists(atPath: outputURL.path()) {
                await ProxyService.shared.convert(externalStorage: false,
                                                  inputURL: inputURL,
                                                  targetFrameRate: frameRate,
                                                  outputURL: outputURL) { status, url in
                    if project.backupProxiesOnCameraStorage {
                        for storage in ExternalStorageService.storageList() {
                            if let mediaURL = ExternalStorageManager.loadExernalStorage(media: storage) {
                                if mediaURL.startAccessingSecurityScopedResource() {
                                    let backupURL = mediaURL
                                        .appending(path: project.uuid, directoryHint: .isDirectory)
                                        .appending(path: take.uuid, directoryHint: .isDirectory)
                                        .appending(path: project.directorUUID, directoryHint: .isDirectory)
                                        .appendingPathExtension(for: .quickTimeMovie)
                                    
                                    try? FileManager.default.copyItem(at: outputURL, to: backupURL)
                                    mediaURL.stopAccessingSecurityScopedResource()
                                    break
                                }
                            }
                        }
                    }
                }
            } else {
                let logURLStr =  "\(project.uuid)/\(take.uuid)/\(project.directorUUID).mov"
                Logger.shared.info("Proxy exists: \(logURLStr)")
            }
 
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                updateStandbyMessage()
                makeNextProxy()
            }
        }
    }
    
    func countTakes(completion: @escaping (Int) -> Void) {
        Task {
            var count = 0
            for director in directorList {
                for project in DirectorProjectService.shared.projectListByDirector(director: director) {
                    for _ in CameraTakeService.getTakeList(forProject: project.uuid) {
                        count += 1
                    }
                }
            }
            completion(count)
        }
    }
    
    func debugRemoveAllProxies() {
//        directorList = DirectorService.shared.directorList()
//        for director in directorList {
//            for project in DirectorProjectService.shared.projectListByDirector(director: director) {
//                for take in CameraTakeService.getTakeList(forProject: project.uuid) {
//                    
//                    var takeURL:URL = URL.documentsDirectory
//                        .appending(path: project.uuid, directoryHint: .isDirectory)
//                        .appending(path: take.uuid, directoryHint: .isDirectory)
//                    
//                    var movieURL = takeURL
//                        .appending(path: take.uuid, directoryHint: .notDirectory)
//                        .appendingPathExtension(for: .quickTimeMovie)
//                    
//                    if let list = try? FileManager.default.contentsOfDirectory(atPath: takeURL.path()) {
//                        for item in list {
//                            let url = takeURL.appending(component: item)
//                            if url.lastPathComponent.suffix(13) == "thumbnail.png" { continue }
//                            if url.lastPathComponent != movieURL.lastPathComponent {
//                                try? FileManager.default.removeItem(at: url)
//                            }
//                        }
//                    }
//                }
//            }
//        }
    }
    
    
    func start() {
        if isRunning { return }
        //debugRemoveAllProxies()
        keepGoing = true
        directorList = DirectorService.shared.directorList()
   
        countTakes { [weak self] count in
            guard let self else { return }
            takeCount = count
            isRunning = true
            
            Task { [weak self] in
                guard let self else { return }
                for director in directorList {
                    for project in DirectorProjectService.shared.projectListByDirector(director: director) {
                        if project.backupFootageOnCameraStorage {
                            for take in CameraTakeService.getTakeList(forProject: project.uuid) {
                                _ = LibraryController.copyItemToExternalStorage(projectUUID: project.uuid, takeUUID: take.uuid)
                                copyCompleted += 1
                                DispatchQueue.main.async { [weak self] in
                                    guard let self else { return }
                                    updateStandbyMessage()
                                }
                                do {
                                    sleep(1)
                                }
                            }
                            if !keepGoing { break }
                        }
                    }
                    if !keepGoing { break }
                }
                
                projdirtakeList.removeAll()
                for director in directorList {
                    for project in DirectorProjectService.shared.projectListByDirector(director: director) {
                        Task {
                            await CommandServer.shared.sendTakeList(project: project)
                        }
                        if project.backupProxiesOnCameraStorage || project.collectProxies {
                            for take in CameraTakeService.getTakeList(forProject: project.uuid) {
                                projdirtakeList.append((director, project, take))
                            }
                        }
                    }
                }
                makeNextProxy()
            }
        }
    }
    
    func makeNextProxy() {
        if !keepGoing { stop(); return }
        
        if let (_, project, take) = projdirtakeList.first {
            projdirtakeList.removeFirst()
            makeProxy(project: project, take: take)
        } else {
            isRunning = false
            stop()
        }
    }

    func stop() {
        keepGoing = false
        isRunning = false
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.CameraOperations.standbyOpsComplete, object: nil)
        }
    }
    
    func checkDirectory(url:URL) -> Bool { //See if there is a directory in here, this means it's a project not personal
        if let directories = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            for d in directories {
                if d.hasDirectoryPath { return true }
            }
        }
        return false
    }
    
    func updateStandbyMessage() {
        var msg = "\(takeCount) total takes. "
        
        if (copyCompleted > 0) && (copyCompleted < takeCount){
            msg += "Backup take \(copyCompleted + 1). "
        } else if projdirtakeList.count > 0 {
            msg += " Making proxies: \(projdirtakeList.count)"
        }
        
        standbyMessage = msg
        Logger.shared.info("usm:\(msg)")
    
    }

}
