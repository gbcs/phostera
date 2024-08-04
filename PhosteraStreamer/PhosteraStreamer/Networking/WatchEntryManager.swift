//
//  WatchEntryManager.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/22/23.
//

import UIKit
import Combine
import AVFoundation
import PhosteraShared

//Maintain a list of known cameras
class WatchEntryManager {
    static var shared = WatchEntryManager()
    private var cancellables = Set<AnyCancellable>()
    var selectedUUIDs: [String] = []
    let cameraInfoBarHeight = 10.0
    lazy var initialCameraSize = CGSizeMake(360, 360/(16/9) + cameraInfoBarHeight)
    var known:[WatchEntryModel] = []
    var collectionViewWidth:CGFloat = 200
    var cameraControlsViewWidth:CGFloat = 100
    var cameraControlsViewEnabled:Bool = false
    var mediaQueue:[String] = []
    var remoteCameras:[String] = ["", "", "", ""]
    var remoteCamerasEnabled:[Bool] = [false, false, false, false]

    func disableAllRemoteCameras() {
        for  x in 0...3 {
            remoteCamerasEnabled[x] = false
        }
    }
    
    func remoteCameraToggle(index: Int) {
        var value:Bool = remoteCamerasEnabled[index]
        value.toggle()
        for x in 0...3 {
            remoteCamerasEnabled[x] = index == x ? value : false
        }
        if value {
            MetalTool.shared.camera.stopRear()
        }
    }
    
    func remoteCameraIndex(uuid:String) -> Int {
        for (index, c) in remoteCameras.enumerated() {
            if c == uuid {
                return index
            }
        }
        return -1
    }
    
    func freeRemoteCameraIndex() -> Int {
        for (index, c) in remoteCameras.enumerated() {
            if c == "" {
                return index
            }
        }
        return -1
    }
    
    func getAvailableCameras() -> [WatchEntryModel] {
        var available:[WatchEntryModel] = []
        
        
        
        
        for item in known {
            if CameraManager.shared.availableUUIDs.contains(item.uuid) {
                for x in available {
                    if x.uuid == item.uuid {
                        Logger.shared.error("skipping dupe in getAvailableCameras for uuid \(item.uuid)")
                        continue
                    }
                }
                available.append(item)
            }
        }
        return available
    }
    
    var timer:Timer?
    
    var watchQueue = DispatchQueue(label: "watchManager")
    
    var opQueue = OperationQueue()
    
    func startWatching() {
        if timer != nil {
            Logger.shared.info("Already watching in startWatching")
        }
        opQueue.maxConcurrentOperationCount = 1
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true, block: { _ in
            Task { [weak self] in
                guard let self else { return }
                for uuid in await NetworkHandler.shared.cameraCommandConnections.keys {
                    
                    var removeList:[String] = []
                    if !CameraManager.shared.onlineUUIDs.contains(uuid) {
                        removeList.append(uuid)
                    } else {
                        if let command = await NetworkHandler.shared.cameraCommandConnections[uuid], let connection = await command.connection {
                            switch connection.state {
                            case .failed(_):
                                fallthrough
                            case .cancelled:
                                Logger.shared.info("Dropping command connection for \(uuid)")
                                removeList.append(uuid)
                            default:
                                break
                            }
                        }
                    }
                    
                    for uuid in removeList {
                        await NetworkHandler.shared.remove(command: uuid)
                    }
                    
                }
                
                var removeList:[String] = []
                for uuid in await NetworkHandler.shared.cameraVideoStreamConnections.keys {
                    if !CameraManager.shared.onlineUUIDs.contains(uuid) {
                        removeList.append(uuid)
                        continue
                    }
                    
                    let index = remoteCameraIndex(uuid: uuid)
                    if index < 0 {
                        removeList.append(uuid)
                        continue
                    } else if !remoteCamerasEnabled[index] {
                        removeList.append(uuid)
                        continue
                    }
                    
                    if let stream = await NetworkHandler.shared.cameraVideoStreamConnections[uuid], let connection = stream.connection {
                        if (connection.state != .ready)  {
                            Logger.shared.info("Dropping video stream connection for \(uuid)")
                            removeList.append(uuid)
                        }
                    }
                    if let stream = await NetworkHandler.shared.cameraAudioStreamConnections[uuid], let connection = stream.connection {
                        if (connection.state != .ready)  {
                            Logger.shared.info("Dropping audio stream connection for \(uuid)")
                            removeList.append(uuid)
                        }
                    }
                }
                
                let keyList = await NetworkHandler.shared.cameraAudioStreamConnections.keys
                for uuid in keyList {
                    if !CameraManager.shared.wantsAudio(uuid: uuid) {
                        await NetworkHandler.shared.remove(audio: uuid)
                    }
                }
                
                for uuid in removeList {
                    await NetworkHandler.shared.remove(video: uuid)
                    await NetworkHandler.shared.remove(audio: uuid)
                }
                
                for item in known {
                    if let camera = CameraManager.shared.getCamera(uuid: item.uuid) {
                        if camera.blocked { continue }
                    }
                    
                    if !CameraManager.shared.onlineUUIDs.contains(item.uuid) {
                        continue
                    }
                    
                    if !CameraManager.shared.availableUUIDs.contains(item.uuid) {
                        continue
                    }
                     
                    if let command = await NetworkHandler.shared.cameraCommandConnections[item.uuid] {
                        let index = remoteCameraIndex(uuid: item.uuid)
                        if index > -1 {
                            if remoteCamerasEnabled[index] {
                                if await NetworkHandler.shared.cameraVideoStreamConnections[item.uuid] == nil {
                                    await command.requestScreenshot()
                                    Logger.shared.info("Making video stream connection for \(item.uuid)")
                                    _ = await NetworkHandler.shared.connectCameraVideoStreamChannel(uuid: item.uuid)
                                } else if CameraManager.shared.wantsAudio(uuid: item.uuid) {
                                    if await NetworkHandler.shared.cameraAudioStreamConnections[item.uuid] == nil {
                                        Logger.shared.info("Making audio stream connection for \(item.uuid)")
                                        _ = await NetworkHandler.shared.connectCameraAudioStreamChannel(uuid: item.uuid)
                                    }
                                }
                            }
                        }
                    } else {
                        Logger.shared.info("Making command connection for \(item.uuid)")
                        let _ = await NetworkHandler.shared.connectCameraCommandChannel(uuid: item.uuid)
                    }
                }
                
                //            var a = ""
                //            for uuid in NetworkHandler.shared.cameraCommandConnections.keys {
                //                if let command = NetworkHandler.shared.cameraCommandConnections[uuid] {
                //                    a += "\(command.uuid) - state:\(String(describing: command.connection?.state))"
                //                }
                //            }
                //
                //            var b = ""
                //            for uuid in NetworkHandler.shared.cameraStreamConnections.keys {
                //                if let command = NetworkHandler.shared.cameraStreamConnections[uuid] {
                //                    b += "\(command.uuid) - state:\(String(describing: command.connection?.state))"
                //                }
                //            }
                //            Logger.shared.error(
                //"""
                //State Report
                //
                //
                //\(NetworkHandler.shared.cameraCommandConnections.debugDescription)
                //
                //
                //\(NetworkHandler.shared.cameraStreamConnections.debugDescription)
                //
                //
                //\(a)
                //
                //
                //\(b)
                //"""
                //            )
                
                
            }
            
            
            
        })
        
        cancellables.insert(CameraManager.shared.$onlineUUIDs.sink { [weak self] uuidList in
            guard let self else { return }
            //Logger.shared.error("Online UUIDs updated: \(uuidList)")
            var found:Bool = false
            for uuid in uuidList {
                let status = CameraManager.shared.isUUIDOnline(uuid: uuid)
                for camera in known {
                    if camera.uuid == uuid {
                        camera.online = status;
                        found = true
                        if status {
                            
                        }
                    }
                }
                
                if !found {
                    if let camera = CameraManager.shared.getCamera(uuid: uuid) {
                        let model = WatchEntryModel(uuid: camera.uuid, online: status, name: camera.name, size: initialCameraSize)
                        if camera.isKnown() {
                            known.removeAll(where: { value in camera.uuid == value.uuid })
                            known.append(model)
                            Task {
                                let _ = await NetworkHandler.shared.connectCameraCommandChannel(uuid: model.uuid)
                            }
                        }
                    }
                }
            }
        })
        
        cancellables.insert(PubCentral.shared.cameraUpdated.sink() { [weak self] value in
            guard let self else { return }
            //Logger.shared.error("Camera List updated: \(value)")
            for camera in CameraManager.shared.cameraList {
                if !camera.isKnown() { continue }
                var found = false
                
                for k in known {
                    if k.uuid == camera.uuid {
                        found = true
                        break
                    }
                }
                
                if !found {
                    let w = WatchEntryModel(uuid: camera.uuid, online: CameraManager.shared.isUUIDOnline(uuid: camera.uuid), name: camera.name, size: initialCameraSize)
                    known.append(w)
                    Task {
                        let _ = await NetworkHandler.shared.connectCameraCommandChannel(uuid: w.uuid)
                    }
               
                }
            }
        })
        
    }
    
    func stopWatching() {
        if timer == nil {
            Logger.shared.info("Wasn't watching in stopWatching")
        }
        
        timer?.invalidate()
        timer = nil
        for item in known {
                Task(priority: .userInitiated, operation: {
                    if let connection = await NetworkHandler.shared.cameraCommandConnections[item.uuid] {
                        await connection.stop()
                    }
                    if let stream = await NetworkHandler.shared.cameraVideoStreamConnections[item.uuid] {
                        stream.stop()
                    }
                    
                    if let stream = await NetworkHandler.shared.cameraAudioStreamConnections[item.uuid] {
                        stream.stop()
                    }
                })
           
        }
        
        Task {
            await NetworkHandler.shared.removeAllCommandConnections()
            await NetworkHandler.shared.removeAllVideoConnections()
            await NetworkHandler.shared.removeAllAudioConnections()
        }
    }
    
    func updateList() {
        for camera in CameraManager.shared.cameraList {
            if camera.isKnown() {
                let watch = WatchEntryModel(uuid: camera.uuid, online: CameraManager.shared.isUUIDOnline(uuid: camera.uuid), name: camera.name, size: initialCameraSize)
                known.removeAll(where: { value in camera.uuid == value.uuid })
                known.append(watch)
            }
        }
    }
    
    func loadInitialList() {
        for camera in CameraManager.shared.cameraList {
            if camera.isKnown() {
                var found:Bool = false
                for x in known {
                    if x.uuid == camera.uuid {
                        found = true
                        break
                    }
                }
                if !found {
                    let watch = WatchEntryModel(uuid: camera.uuid, online: CameraManager.shared.isUUIDOnline(uuid: camera.uuid), name: camera.name, size: initialCameraSize)
                    known.append(watch)
                }
            }
        }
    }
}

