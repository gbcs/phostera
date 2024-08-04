//
//  DirectorProxyTransferManager.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/28/23.
//

import Foundation
import PhosteraShared
import Combine

class DirectorProxyTransferManager {
    var key:String
    var connection:CameraCommandConnector
    @Published var chunk:Int = 0
    var camera:CameraModel
    var take:DirectorTakeModel
    let encoder = JSONEncoder()
    var outputURL:URL?
    var outputFile:FileHandle?
    var finished:Bool = false
    var completionHandler: ((Bool) -> Void)?
    var title:String
    var media:URL?
    var project:DirectorProjectModel
    var sub:AnyCancellable?
    var gotAtLeastOneChunk:Bool = false
    
    init(key: String, connection: CameraCommandConnector, camera: CameraModel, take:DirectorTakeModel, project:DirectorProjectModel, storageMedia:URL?, title:String) {
        self.key = key
        self.connection = connection
        self.camera = camera
        self.take = take
        self.title = title
        self.project = project
        self.media = storageMedia
    }
       
    func start(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        gotAtLeastOneChunk = false
        sub = PubCentral.shared.pubProxyMediaChunk.receive(on: DispatchQueue.main).sink { [weak self] notification in
            guard let self else { return }
            if let userInfo = notification.userInfo {
                if let item = userInfo["chunk"] as? Data {
                    receiveChunk(data: item)
                }
            }
        }
        
        if project.proxyStorageLocation == .externalStorage {
            guard let media else { completion(false); Logger.shared.error("exernalstoragenomediaatstart"); return }
            outputURL = TakeTransferQueue.urlForExternalStorageProxyIn(media: media, take: take, cameraUUID: camera.uuid)
            guard let _ = outputURL else { completion(false); Logger.shared.error("exernalstoragenooutputurl"); return }
        } else {
            outputURL = TakeTransferQueue.urlForAppStorageProxyIn(take: take, cameraUUID: camera.uuid)
        }
        
        if let outputURL {
            FileManager.default.createFile(atPath: outputURL.path(), contents: nil)
            outputFile = FileHandle(forWritingAtPath: outputURL.path())
        }
        
        if outputFile != nil {
            getChunk()
        } else {
            completion(false)
        }
    }
    
    func getChunk() {
        if finished {  return }
        Task {
            if let cameraTakeUUID = take.cameraTakeUUIDs[camera.uuid] {
                let chunkRequest = MediaTransferChunkModel(projectUUID: take.projectUUID, takeUUID: cameraTakeUUID, file: SettingsService.shared.settings.serverUUID + ".mov", index: chunk)
                if let chunkRData = try? encoder.encode(chunkRequest).base64EncodedString() {
                    let request = CameraRequest(command: .takeMediaChunk,
                                                uuid: camera.uuid,
                                                sesionKey: key,
                                                dataUUID: chunkRData)
                    await connection.requestFromCamera(content: request)
                }
            } else {
                Logger.shared.error("cameraTakeUUID not present in take. Unable to sync this file.")
                complete()
            }
        }
    }
    
    func complete() {
        if finished { return }
        finished = true
        if let outputFile {
            outputFile.closeFile()
        }
        if !gotAtLeastOneChunk {
            if let outputURL {
                try? FileManager.default.removeItem(at: outputURL)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let completionHandler {
                    completionHandler(false)
                }
            }
            return
        }
        
        if let _ = outputURL {
//            let footage = FootageService.makeFootage(url: outputURL, type: .video)
//            footage.name = "\(camera.name) - \(title)"
//            
            Task {
               // await FootageService.shared.add(footage: footage)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if let completionHandler {
                        completionHandler(true)
                    }
                }
            }
        }
    }
    
    func receiveChunk(data:Data) {
        if finished { return }
      
        let icount = data.bytes.count
        
        if icount > 0 {
            gotAtLeastOneChunk = true
        }
        
        Logger.shared.info("r:\(icount) - \(chunk)")
        TakeTransferQueue.shared.bytesTransferred += UInt64(icount)
        if icount > 0 {
            try? outputFile?.write(contentsOf: data)
        }
        
        if icount < mediaTransferChunkModelSegmentSize {
            complete()
        } else {
            chunk += 1
            getChunk()
        }
    }
}
