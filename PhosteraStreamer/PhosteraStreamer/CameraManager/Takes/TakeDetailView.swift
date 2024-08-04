//
//  TakeDetailView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation
import SwiftUI
import Combine
import PhosteraShared

struct TakeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var take:CameraTakeModel
    var camera:CameraModel
    @State var thumbnail:UIImage?
    @State var takeMediaInfo:TakeMediaInfo?
    @State var cancellables:[AnyCancellable] = []
    @State var allowCopy:Bool = false
    @State var requireConversion:Bool = false
    @State var currentProject:StreamProjectModel?
    @State var proxyCreationStatus:ProxyCreationStatus?
    @State var proxyTransferManager:ProxyTransferManager?
    @State var proxyTransferring:Bool = false
    @State var proxyTransferProgress:Float = 0.0
    @State var chunk:Int = 0
    @State var working:Bool = false
    @State var copyStarted:Bool = false
    
    @State var proxyCreated:Bool = false
    
    func subscribeToList() {
        cancellables.removeAll()
        cancellables.append(PubCentral.shared.pubTakeMediaInfoUpdated.receive(on: DispatchQueue.main).sink { notification in
            if let userInfo = notification.userInfo {
                if let item = userInfo["info"] as? TakeMediaInfo {
                    takeMediaInfo = item
                    if item.thumbnail.bytes.count > 0 {
                        thumbnail = UIImage(data: item.thumbnail)
                    } 
                }
            }
        })
        
        cancellables.append(PubCentral.shared.pubProxyCreationStatus.receive(on: DispatchQueue.main).sink { notification in
            if let userInfo = notification.userInfo {
                if let item = userInfo["status"] as? ProxyCreationStatus {
                    proxyCreationStatus = item
                    if item.status {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                            requestProxyCreationStatusUpdate()
                        })
                    } else {
                        if item.progress == 1.0 {
                            if !proxyCreated {
                                proxyCreated = true
                                requestFileTransfer()
                            }
                        }
                    }
                }
            }
        })
        
        cancellables.append(PubCentral.shared.pubProxyMediaChunk.receive(on: DispatchQueue.main).sink { notification in
            if let userInfo = notification.userInfo {
                if let item = userInfo["chunk"] as? Data {
                    if let proxyTransferManager {
                        proxyTransferManager.receiveChunk(data: item)
                    }
                }
            }
        })
    }

    var body: some View {
        VStack {
            Form {
                Section("Actions", content: {
                    Button("Copy to Local Media", action: {
                        working = true
                        copyStarted = true
                        proxyCreated = false
                        requestProxyCreation()
                    }).disabled(copyStarted || working)
                })
   
                if proxyTransferring {
                    Section("Transfer Proxy", content: {
                        Text("\(chunk * mediaTransferChunkModelSegmentSize) bytes transferred.")
                    })
                } else if working {
                    Section("Make Proxy", content: {
                        ProgressView("Working")
                    })
                }
       
                Section("Preview", content: {
                    if takeMediaInfo == nil {
                        HStack {
                            Spacer()
                            ProgressView("Loading")
                            Spacer()
                        }
                    } else if let thumbnail {
                        Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
                    } else  {
                        ContentUnavailableView("Thumbnail not available", systemImage: "film")
                    }
                }).frame(maxHeight: 200)
                
                if let takeMediaInfo {
                    Section("Media", content: {
                        HStack {
                            Text("Resolution")
                            Spacer()
                            Text("\(Int(takeMediaInfo.mediaResolution.width))x\(Int(takeMediaInfo.mediaResolution.height))")
                        }
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text("\(durationString(take:take))")
                        }
                        HStack {
                            Text("Framerate")
                            Spacer()
                            switch takeMediaInfo.mediaFramerate {
                            case .fr24:
                                Text("24fps")
                            case .fr25:
                                Text("25fps")
                            case .fr30:
                                Text("30fps")
                            }
                        }
                        
                        ForEach(takeMediaInfo.mediaSegments, id:\.self) { value in
                            Text("\(value)")
                        }
                    })
                }
            }
        }.padding()
        .onReceive(PubCentral.shared.onlineUpdated) { (output) in
            if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                dismiss()
            }
        }
        .onAppear() {
            Task {
                let project = await ProjectService.shared.currentProject()
                DispatchQueue.main.async {
                    currentProject = project
                }
            }
            if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                dismiss()
            } else {
                subscribeToList()
                getTakeInfo()
            }
        }.frame(minWidth: 200, idealWidth: 200, maxWidth: .infinity, minHeight: 200, idealHeight: 400, maxHeight: .infinity, alignment: .center)
            .navigationTitle(takeTitle(take: take)).navigationBarTitleDisplayMode(.inline)
    }
    
    @State var requestSub:AnyCancellable?

    func requestFileTransfer() {
        Logger.shared.info("Starting file transfer.")
        Task {
            if let connection = await NetworkHandler.shared.cameraCommandConnections[camera.uuid] {
                let key = await connection.sessionKey
                proxyTransferring = true
                proxyTransferProgress = 0.0
                proxyTransferManager = ProxyTransferManager(key: key, connection: connection, camera: camera, projectUUID: take.projectUUID, takeUUID: take.uuid, title: takeTitle(take: take))
                
                if let proxyTransferManager {
                    requestSub = proxyTransferManager.$chunk.receive(on: DispatchQueue.main).sink { value in
                        chunk = value
                    }
                    proxyTransferManager.start(completion: { status in
                        proxyCreationStatus = nil
                        proxyTransferring = false
                        working = false
                        self.proxyTransferManager = nil
                    })
                } else {
                    Logger.shared.error("Unable to create proxyTransferManager")
                }
            }
        }
    }
    
    func requestProxyCreation() {
        Task {
            if let connection = await NetworkHandler.shared.cameraCommandConnections[camera.uuid] {
                let key = await connection.sessionKey
                if let takeMediaInfo {
                    var frameRate = 30
                    if takeMediaInfo.mediaFramerate == .fr24 { frameRate = 24}
                    if takeMediaInfo.mediaFramerate == .fr25 { frameRate = 25}
                    if let mediaFile = takeMediaInfo.mediaSegments.first {
                        let rString = "\(take.projectUUID)/\(take.uuid)/\(mediaFile)/\(frameRate)"
                        let request = CameraRequest(command: .makeProxy,
                                                    uuid: camera.uuid,
                                                    sesionKey: key,
                                                    dataUUID: rString)
                        await connection.requestFromCamera(content: request)
                    }
                }
            }
        }
    }
    
    func requestProxyCreationStatusUpdate() {
        Task {
            if let connection = await NetworkHandler.shared.cameraCommandConnections[camera.uuid] {
                let key = await connection.sessionKey
                if takeMediaInfo != nil {
                    let request = CameraRequest(command: .makeProxyStatus,
                                                uuid: camera.uuid,
                                                sesionKey: key,
                                                dataUUID: "")
                    await connection.requestFromCamera(content: request)
                }
            }
        }
    }
    
    func getTakeInfo() {
        Task {
            if let connection = await NetworkHandler.shared.cameraCommandConnections[camera.uuid] {
                let key = await connection.sessionKey
                let request = CameraRequest(command: .takeMediaInfo, uuid: camera.uuid, sesionKey: key, dataUUID: take.projectUUID + "/" + take.uuid)
                await connection.requestFromCamera(content: request)
            }
        }
    }

    func durationString(take:CameraTakeModel) -> String {
        let duration = take.endTime.timeIntervalSince(take.startTime)
        return DateService.shared.componentStringFrom(duration: duration)
    }
    
    func takeTitle(take:CameraTakeModel) -> String {
        return "Take:" + DateService.shared.dateTimeStamp(date: take.startTime)
    }
    
}


