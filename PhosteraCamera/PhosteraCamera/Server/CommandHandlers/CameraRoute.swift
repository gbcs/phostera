//
//  CameraRoute.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/26/23.
//

import Foundation
import DeviceKit
import PhosteraShared

public class CameraRoute {
    static var shared = CameraRoute()
    
    func handleRouting(content:Data?, command:CommandMessageType, connection:CommandServerConnection) {
        if (content == nil) || content!.isEmpty {
            Logger.shared.error("no data in handleRouting.\(command.rawValue)")
            return
        }
        
        let decoder = JSONDecoder()
        var cameraRequest:CameraRequest
        
        do {
            cameraRequest = try decoder.decode(CameraRequest.self, from: content!)
        } catch {
            Logger.shared.error("decoder error:\(error.localizedDescription)")
            return
        }
        Task { [cameraRequest] in
            if await cameraRequest.sessionKey != connection.sessionKey {
                sendCameraResponse(success: false, connection:connection, command: cameraRequest.command, data: nil)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                switch(cameraRequest.command) {
                case .startTake:
                    NotificationCenter.default.post(name: Notification.Name.CameraOperations.beginRecording, object: nil)
                case .endTake:
                    NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil)
                case .zoomIn:
                    break
                case .zoomOut:
                    break
                case .requestStatusSubscription:
                    Task {
                        await connection.setupForSubscriptionForwarding()
                    }
                    sendCameraResponse(success: true, connection:connection, command: cameraRequest.command, data: Data())
                case .toggleExposureLock:
                    CamTool.shared.getCameraDeviceExposure().userToggledExposure()
                case .toggleWhiteBalanceLock:
                    CamTool.shared.getCameraDeviceWhitebalance().userToggledWhitebalance()
                case .toggleFocusLock:
                    CamTool.shared.getCameraDeviceFocus().userToggledFocus()
                case .directorMode:
                    break
                case .screenshot:
                    CamTool.shared.sendScreenshotNow()
                case .changeMode:
                    //dataUUID is the uuid of the camera mode. do a switcheroo
                    if cameraRequest.dataUUID == "standby" {
                        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.standby, object: nil) }
                    } else {
                        if let _ = ModeHandler.shared.findMode(withUUID: cameraRequest.dataUUID) {
                            SettingsService.shared.settings.currentModeId = cameraRequest.dataUUID
                            SettingsService.shared.save()
                            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.modeSwitch, object: nil) }
                        }
                    }
                case .directorAndProjectList:
                    let list = directorsAndProjects()
                    let encoder = JSONEncoder()
                    var data = try? encoder.encode(list.0)
                    sendProjectResponse(success: true, connection:connection, command: .directorList, data: data, projectUUID: "")
                    data = try? encoder.encode(list.1)
                    sendProjectResponse(success: true, connection:connection, command: .projectList, data: data, projectUUID: "")
                case .takeList:
                    let list = takes(projectUUID: cameraRequest.dataUUID)
                    let encoder = JSONEncoder()
                    let data = try? encoder.encode(list)
                    sendProjectResponse(success: true, connection:connection, command: .takeList, data: data, projectUUID: cameraRequest.dataUUID)
                case .takeMediaInfo:
                    let parts = cameraRequest.dataUUID.components(separatedBy: "/")
                    if parts.count == 2 {
                        takeMediaInfo(projectUUID: parts[0], takeUUID: parts[1]) { [weak self] mediaInfo in
                            
                            guard let self else { return }
                            let encoder = JSONEncoder()
                            let data = try? encoder.encode(mediaInfo)
                            sendProjectResponse(success: true, connection:connection, command: .takeMediaInfo, data: data, projectUUID: parts[0])
                            
                        }
                    }
                case .takeMediaChunk:
                    if let data = Data(base64Encoded: cameraRequest.dataUUID) {
                        if let chunkRequest = try? decoder.decode(MediaTransferChunkModel.self, from: data) {
                            if let chunk = takeMediaChunk(model:chunkRequest) {
                                sendProjectResponse(success: true, connection:connection, command: .takeMediaChunk, data: chunk, projectUUID: "")
                            }
                        }
                    }
                case .makeProxy:
                    let parts = cameraRequest.dataUUID.components(separatedBy: "/")
                    let projectUUID = parts[0]
                    let takeUUID = parts[1]
                    let mediaUUID = parts[2]
                    let frameRate = parts[3]
                    let requestorUUID = cameraRequest.uuid
                    
                    Task { [weak self] in
                        guard let self else { return }
                
                        let inputURL = URL.documentsDirectory
                            .appending(component: projectUUID, directoryHint: .isDirectory)
                            .appending(component: takeUUID, directoryHint: .isDirectory)
                            .appending(component: mediaUUID, directoryHint: .notDirectory)
                        
                        let outputURL = URL.documentsDirectory
                            .appending(component: projectUUID, directoryHint: .isDirectory)
                            .appending(component: takeUUID, directoryHint: .isDirectory)
                            .appending(component: requestorUUID + ".mov", directoryHint: .notDirectory)
                        
                        try? FileManager.default.removeItem(at: outputURL)
                        
                        await videoImporter.convert(inputURL: inputURL, targetFrameRate: Int(frameRate) ?? 30, outputURL: outputURL) { [weak self] status, url in
                            guard let self else { return }
                            reportProxyCreationStatus(connection: connection, complete: true)
                        }
                    }
                case .makeProxyStatus:
                    reportProxyCreationStatus(connection: connection, complete: false)
                case .aacCookie:
                    if let cookie = CamTool.shared.getAACCookie() {
                        sendCameraResponse(success: true, connection: connection, command: .aacCookie, data: cookie)
                    }
                }
            }
        }
    }
    
    var videoImporter:SharedVideoImporter = SharedVideoImporter()
    
    func reportProxyCreationStatus(connection:CommandServerConnection, complete:Bool) {
        let encoder = JSONEncoder()
        let progress = videoImporter.getProgress()

        let status = ProxyCreationStatus(status: !complete, progress:progress)
        
        if let data = try? encoder.encode(status) {
            sendProjectResponse(success: true, connection:connection, command: .makeProxyStatus, data: data, projectUUID: "")
        }
    }

    func takeMediaChunk(model:MediaTransferChunkModel) -> Data? {
        //Need to convert take from director to cameratake
        
        let takeMediaLocation = URL.documentsDirectory
            .appending(component: model.projectUUID, directoryHint: .isDirectory)
            .appending(component: model.takeUUID, directoryHint: .isDirectory)
            .appending(component: model.file, directoryHint: .notDirectory)
        
        let start = model.index * mediaTransferChunkModelSegmentSize
        
        do {
            let exists = FileManager.default.fileExists(atPath: takeMediaLocation.path())
            Logger.shared.info("takeMediaChunk:\(takeMediaLocation) - exists:\(exists)")
            let fileHandle = try FileHandle(forReadingFrom: takeMediaLocation)
            fileHandle.seek(toFileOffset: UInt64(start))
            let data = fileHandle.readData(ofLength: mediaTransferChunkModelSegmentSize)
            fileHandle.closeFile()
            return data
        } catch {
            Logger.shared.error("takeMediaChunk \(error.localizedDescription)")
        }
        
        return Data()
    }
    
    func sendCameraResponse(success:Bool, connection:CommandServerConnection, command:CameraRequestCommand, data:Data?) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05, execute: { [success] in
            let response:CameraResponse = CameraResponse(status: success ? .success : .failure, command: command, data: data ?? Data())
            
            do {
                let encoder = JSONEncoder()
                let data:Data = try encoder.encode(response)
                Task {
                    await connection.sendToDirector(data, messsageType: .camera)
                }
            } catch {
                Logger.shared.error("sendCameraResponse: encoder error: \(error.localizedDescription)")
            }
        })
    }
    
    func sendProjectResponse(success:Bool, connection:CommandServerConnection, command:ProjectRequestCommand, data:Data?, projectUUID:String) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05, execute: { [success] in
            let response:ProjectResponse = ProjectResponse(status: success ? .success : .failure, command: command, data: data ?? Data(), projectUUID: projectUUID)
            
            do {
                let encoder = JSONEncoder()
                let data:Data = try encoder.encode(response)
                Task {
                    await connection.sendToDirector(data, messsageType: .project)
                }
            } catch {
                Logger.shared.error("sendProjectResponse: encoder error: \(error.localizedDescription)")
            }
        })
    }
    
    func directorsAndProjects() -> ([DirectorModel], [DirectorProjectModel]) {
        let directorList = DirectorService.shared.directorList()
        var projectList:[DirectorProjectModel] = []
        for director in directorList {
            for projet in DirectorProjectService.shared.projectListByDirector(director: director) {
                projectList.append(projet)
            }
        }
        
        return (directorList, projectList)
    }
    
    func takes(projectUUID:String) -> [CameraTakeModel] {
        let takeDirectory = URL.applicationSupportDirectory
            .appending(component: "takes", directoryHint: .isDirectory)
            .appending(component: projectUUID, directoryHint: .isDirectory)
        
        let decoder = JSONDecoder()
        
        var tempList:[CameraTakeModel] = []
        
        if let list = try? FileManager.default.contentsOfDirectory(at: takeDirectory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for takeFile in list {
                if let data = try? Data(contentsOf: takeFile) {
                    if let take = try? decoder.decode(CameraTakeModel.self, from: data) {
                        tempList.append(take)
                    }
                }
            }
        }
        
        return tempList
    }
    
    func takeMediaInfo(projectUUID:String, takeUUID:String, completion: @escaping (TakeMediaInfo?) -> Void) {
        Task {
            let takeMediaLocation = URL.documentsDirectory
                .appending(component: projectUUID, directoryHint: .isDirectory)
                .appending(component: takeUUID, directoryHint: .isDirectory)
            
            var segments:[String] = []
            var segmentSizes:[UInt64] = []
            var thumbnailData:Data = Data()
            var mediaResolution:CGSize = .zero
            var mediaDuration:Float64 = 0
            var proxyExists:Bool = false
            var proxySize:UInt64 = 0
            var mediaFrameRate:Float = 0
            
            if let list = try? FileManager.default.contentsOfDirectory(at: takeMediaLocation, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]) {
                for item in list {
                    if item.path().contains("thumbnail.png") {
                        do {
                            thumbnailData = try Data(contentsOf: item)
                        } catch {
                            Logger.shared.error("Unable to read thumbnail for take: \(projectUUID) \(takeUUID)")
                        }
                        continue
                    }
                    
                    if item.path().contains("proxy.mov") {
                        if let attr = try? FileManager.default.attributesOfItem(atPath: item.path()) {
                            proxySize = attr[FileAttributeKey.size] as? UInt64 ?? 0
                        }
                        proxyExists = true
                        continue
                    }
                    
                    
                    if let meta = await VideoMetadata.videoMetadata(from: item) {
                        mediaResolution = meta.resolution
                        mediaDuration = meta.duration
                        mediaFrameRate = meta.frameRate
                    }
                    
                    if let attr = try? FileManager.default.attributesOfItem(atPath: item.path()) {
                        let fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
                        segmentSizes.append(fileSize)
                    } else {
                        segmentSizes.append(0)
                    }
                    segments.append(item.lastPathComponent)
                }
            }
            
            var fr:DirectorProjectFrameRate = .fr24
            
            if Int(mediaFrameRate) == 25 {
                fr = .fr25
            } else if Int(mediaFrameRate) >= 29 {
                fr = .fr30
            }
            
            let takeMediaInfo = TakeMediaInfo(thumbnail: thumbnailData,
                                              mediaSegments: segments,
                                              mediaSegmentSizes:segmentSizes,
                                              mediaResolution: mediaResolution,
                                              proxyExists: proxyExists,
                                              proxySize: proxySize,
                                              mediaDuration: mediaDuration,
                                              mediaFramerate: fr)
            
            completion(segments.count > 0 ? takeMediaInfo : nil)
        }
    }
}

