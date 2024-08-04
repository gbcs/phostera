//
//  TakeTransferQueue.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/17/23.
//

import Foundation
import PhosteraShared

class TransferRequestElement {
    var take:DirectorTakeModel
    var camera:CameraModel
    
    init(take: DirectorTakeModel, camera: CameraModel) {
        self.take = take
        self.camera = camera
    }
}

class TakeTransferQueue {
    static var shared = TakeTransferQueue()
    private var list:[TransferRequestElement] = []
    private var project:DirectorProjectModel?
    private var media:URL?
    @Published var bytesTransferred:UInt64 = 0
    
    //Manage the sync of takes with a nice ui report progress update
    
    //Proxies are stored in documents/project/take/cameraUUID.proxy.mov
    
    static func debugDeleteAllProxies() {
//        #warning("Disable when not using")
//        if let list = try? FileManager.default.contentsOfDirectory(at: URL.documentsDirectory, includingPropertiesForKeys: [.isDirectoryKey]) {
//            for d in list {
//                if d.lastPathComponent == "logs" { continue }
//                try? FileManager.default.removeItem(at: d)
//            }
//        }
    }
    
    static func urlForAppStorageProxyIn(take:DirectorTakeModel, cameraUUID:String) -> URL {
        var url = URL.documentsDirectory
            .appending(path: take.projectUUID, directoryHint: .isDirectory)
            .appending(path: take.uuid, directoryHint: .isDirectory)
        
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      
        url = url
            .appending(path: cameraUUID, directoryHint: .notDirectory)
            .appendingPathExtension(for: .quickTimeMovie)
        
        return url
    }
    
    //Assumes you have securityscoped permission before calling
    static func urlForExternalStorageProxyIn(media:URL, take:DirectorTakeModel, cameraUUID:String) -> URL {
        var url = media
            .appending(path: take.projectUUID, directoryHint: .isDirectory)
            .appending(path: take.uuid, directoryHint: .isDirectory)
        
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        url = url
            .appending(path: cameraUUID, directoryHint: .notDirectory)
            .appendingPathExtension(for: .quickTimeMovie)
   
        return url
    }
    
    //Would do parallel, but something for 2.0 and save bandwidth/not overload wifi, etc. excuses :)
    func start(project:DirectorProjectModel, media:URL?) {
        self.project = project
        self.media = media
        let cameraList = CameraManager.shared.cameraList
        Task {
            let tmpTakeList = TakeService.shared.getTakes(project: project)
            for take in tmpTakeList {
                for cameraUUID in take.cameraUUIDs {
                    for camera in cameraList {
                        if camera.uuid == cameraUUID {
                            let element = TransferRequestElement(take: take, camera: camera)
                            list.append(element)
                            break
                        }
                    }
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                getNextProxy()
            }
        }
    }
    
    func finishCurrentProxy() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
            guard let self else { return }
            //update(message: "finishCurrentProxy")
            //Update Ui
            if list.count > 0 {
                getNextProxy()
            } else {
                stop()
            }
        })
    }
    
    var transferManager:DirectorProxyTransferManager?
    
    func getNextProxy() {
        if let element = list.first {
            list.removeFirst()
            update(message: "Getting the next proxy: \(list.count + 1)")
            Task { [weak self] in
                guard let self else { return }
                //Fill in all the details.
                
                //if external storage is wanted, must have media security scoped before calling and release after
                
                //See if the file exists before transferring it
                
                guard let project else { return }
                
                if project.proxyStorageLocation == .externalStorage {
                    if let media {
                        let url = TakeTransferQueue.urlForExternalStorageProxyIn(media: media, take: element.take, cameraUUID: element.camera.uuid)
                        if FileManager.default.fileExists(atPath:url.path()) {
                            //update(message: "exists")
                            finishCurrentProxy()
                            return
                        }
                    } else {
                        finishCurrentProxy()
                        return
                    }
                } else {
                    let url = TakeTransferQueue.urlForAppStorageProxyIn(take: element.take, cameraUUID: element.camera.uuid)
                    if FileManager.default.fileExists(atPath:url.path()) {
                        //update(message: "exists")
                        finishCurrentProxy()
                        return
                    }
                }
            
                if let connection = await NetworkHandler.shared.cameraCommandConnections[element.camera.uuid] {
                    transferManager = DirectorProxyTransferManager(key: await connection.sessionKey,
                                                                   connection: connection,
                                                                   camera: element.camera,
                                                                   take: element.take,
                                                                   project: project,
                                                                   storageMedia: media,
                                                                   title: "")
                    
                    
                       transferManager?.start(completion: { [weak self] success in
                           guard let self else { return }
                           //update(message: "complete:\(success)")
                           finishCurrentProxy()
                       })
                } else {
                    finishCurrentProxy()
                }
            }
        } else {
            finishCurrentProxy()
        }
    }
    
    @Published var updateMessage:String = ""
    
    func update(message:String) {
        Logger.shared.info("ttq:\(message)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            updateMessage = message
        }
    }
    
    func stop() {
        if let media {
            media.stopAccessingSecurityScopedResource()
        }
        list.removeAll()
        update(message: "stopped")
    }
}
