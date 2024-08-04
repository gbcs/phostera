//
//  TransferManager.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/23/23.
//

import Foundation
import PhosteraShared
import Combine

class ProxyTransferManager {
    var key:String
    var connection:CameraCommandConnector
    @Published var chunk:Int = 0
    var camera:CameraModel
    var projectUUID:String
    var takeUUID:String
    let encoder = JSONEncoder()
    var outputURL:URL?
    var outputFile:FileHandle?
    var finished:Bool = false
    var completionHandler: ((Bool) -> Void)?
    var title:String
    
    init(key: String, connection: CameraCommandConnector, camera: CameraModel, projectUUID:String, takeUUID:String, title:String) {
        self.key = key
        self.connection = connection
        self.camera = camera
        self.projectUUID = projectUUID
        self.takeUUID = takeUUID
        self.title = title
    }
    
    func start(completion: @escaping (Bool) -> Void) {
        completionHandler = completion
        outputURL = FootageService.getURLForNewVideo()
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
            let chunkRequest = MediaTransferChunkModel(projectUUID: projectUUID, takeUUID: takeUUID, file: camera.uuid + ".mov", index: chunk)
            if let chunkRData = try? encoder.encode(chunkRequest).base64EncodedString() {
                let request = CameraRequest(command: .takeMediaChunk,
                                            uuid: camera.uuid,
                                            sesionKey: key,
                                            dataUUID: chunkRData)
                await connection.requestFromCamera(content: request)
            }
        }
    }
    
    func complete() {
        if finished { return }
        finished = true
        if let outputFile {
            outputFile.closeFile()
        }
        if let outputURL {
            let footage = FootageService.makeFootage(url: outputURL, type: .video)
            footage.name = "\(camera.name) - \(title)"
            
            Task {
                await FootageService.shared.add(footage: footage)
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
        Logger.shared.info("r:\(data.bytes.count) - \(chunk)")
        let icount = data.bytes.count
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
