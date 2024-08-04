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

let lightMeterUUID = "LightMeter"

//Maintain a list of known cameras
class WatchEntryManager {
    static var shared = WatchEntryManager()
    private var cancellables = Set<AnyCancellable>()
    var selectedUUID: String?
    let cameraInfoBarHeight = 10.0
    lazy var initialCameraSize = CGSizeMake(295, 295/(16/9) + cameraInfoBarHeight)
    var known:[WatchEntryModel] = []
    var collectionViewWidth:CGFloat = 200
    var cameraControlsViewWidth:CGFloat = 95
    var cameraControlsViewEnabled:Bool = false
    
    func getAvailableCameras() -> [WatchEntryModel] {
        var available:[WatchEntryModel] = []
        for item in known {
            if CameraManager.shared.availableUUIDs.contains(item.uuid) {
                available.append(item)
            }
        }
        return available
    }
    
    var timer:Timer?
    
    var watchQueue = DispatchQueue(label: "watchManager")
    
    var opQueue = OperationQueue()
    
    func processItem(item:WatchEntryModel) {
        DispatchQueue.main.async {
            if let camera = CameraManager.shared.getCamera(uuid: item.uuid) {
                if camera.blocked { return }
            }
            
            if !CameraManager.shared.onlineUUIDs.contains(item.uuid) {
                return
            }
            
            if !CameraManager.shared.availableUUIDs.contains(item.uuid) {
                return
            }
            
            if item.uuid == lightMeterUUID {
                return
            }
            Task {
                if let command = await NetworkHandler.shared.cameraCommandConnections[item.uuid] {
                    if await NetworkHandler.shared.cameraVideoStreamConnections[item.uuid] == nil {
                        Logger.shared.info("Making video stream connection for \(item.uuid)")
                        let _ = await NetworkHandler.shared.connectCameraVideoStreamChannel(uuid: item.uuid)
                        await command.requestScreenshot()
                        //                      Audio works decently, at least one at a time. Needs lower bandwidth though for shipping state
                        //                      Use this for a push-to-listen feature in director.
                        //                    } else if NetworkHandler.shared.cameraAudioStreamConnections[item.uuid] == nil {
                        //                        Logger.shared.info("Making audio stream connection for \(item.uuid)")
                        //                        let _ = NetworkHandler.shared.connectCameraAudioStreamChannel(uuid: item.uuid)
                    }
                } else {
                    Logger.shared.info("Making command connection for \(item.uuid)")
                    let _ = await NetworkHandler.shared.connectCameraCommandChannel(uuid: item.uuid)
                }
            }
        }
    }
    
    func startWatching() {
        if timer != nil {
            Logger.shared.info("Already watching in startWatching")
        }
        opQueue.maxConcurrentOperationCount = 1
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true, block: { _ in
            let onlineUUIDS = CameraManager.shared.onlineUUIDs
            Task { [weak self] in
                guard let self else { return }
                for uuid in await NetworkHandler.shared.cameraCommandConnections.keys {
                    
                    var removeList:[String] = []
                    if !onlineUUIDS.contains(uuid) {
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
                        if uuid == lightMeterUUID { continue }
                        await NetworkHandler.shared.remove(command: uuid)
                    }
                    
                }
                
                var removeList:[String] = []
                for uuid in await NetworkHandler.shared.cameraVideoStreamConnections.keys {
                    if !onlineUUIDS.contains(uuid) {
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
                
                for uuid in removeList {
                    if uuid == lightMeterUUID { continue }
                    await NetworkHandler.shared.remove(video: uuid)
                    await NetworkHandler.shared.remove(audio: uuid)
                }
                
                for item in known {
                    processItem(item:item)
                }
            }
        })
        
        cancellables.insert(CameraManager.shared.$onlineUUIDs.sink { [weak self] uuidList in
            guard let self else { return }
            //Logger.shared.error("Online UUIDs updated: \(uuidList)")
            var found:Bool = false
            for uuid in uuidList {
                var status = CameraManager.shared.isUUIDOnline(uuid: uuid)
                if (uuid == lightMeterUUID) && CameraController.hasPermission() { status = true }
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
                        if (uuid == lightMeterUUID) && (!CameraController.hasPermission()) { continue }
                        if camera.isKnown() {
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
                
                if camera.uuid == lightMeterUUID {
                    found = true
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
        
        cancellables.insert(PubCentral.shared.projectListChanged.sink() { value in
            Logger.shared.info("Project List updated: \(value)")
            var list:[String] = []
            for camera in CameraManager.shared.cameraList {
                if CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                    list.append(camera.uuid)
                }
            }
            Task { [list] in
                for uuid in list {
                    if let connection = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                        await connection.sendProject()
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
                known.append(watch)
            }
        }
    }
    
    func loadInitialList() {
        for camera in CameraManager.shared.cameraList {
            if camera.isKnown() {
                let watch = WatchEntryModel(uuid: camera.uuid, online: CameraManager.shared.isUUIDOnline(uuid: camera.uuid), name: camera.name, size: initialCameraSize)
                known.append(watch)
            }
        }
        
        if CameraController.hasPermission() {
            if CameraManager.shared.getCamera(uuid: lightMeterUUID) == nil {
                let camera = CameraModel(uuid: lightMeterUUID, name: "Light Meter", model: "iPad", blocked: false)
                _ = CameraManager.shared.availableUUIDs.insert(camera.uuid)
                _ = CameraManager.shared.updateCamera(camera: camera)
            }
        }
    }
}

