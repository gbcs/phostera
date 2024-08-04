//
//  TakeDetailView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/17/23.
//

import Foundation
import SwiftUI
import Combine
import PhosteraShared
import AVFoundation

struct TakeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State var update:Bool = false
    @State var take:DirectorTakeModel
    
    func durationString(take:DirectorTakeModel) -> String {
        let duration = take.endTime.timeIntervalSince(take.startTime)
        return DateService.shared.componentStringFrom(duration: duration)
    }
    
    func dateTimeStamp(take:DirectorTakeModel) -> String {
        return DateService.shared.dateTimeStamp(date: take.startTime)
    }
    
    func proxyExists(take:DirectorTakeModel, cameraUUID:String) -> URL? {
        if let project = DirectorProjectService.loadProject(uuid: take.projectUUID) {
            if project.proxyStorageLocation == .appStorage {
                let url = TakeTransferQueue.urlForAppStorageProxyIn(take: take, cameraUUID: cameraUUID)
                if FileManager.default.fileExists(atPath: url.path()) {
                    return url
                }
            } else if project.proxyStorageLocation == .externalStorage {
                for m in ExternalStorageService.storageList() {
                    if let mediaURL = ExternalStorageManager.loadExernalStorage(media: m) {
                        if mediaURL.startAccessingSecurityScopedResource() {
                            let url = TakeTransferQueue.urlForExternalStorageProxyIn(media: mediaURL, take: take, cameraUUID: cameraUUID)
                            let answer = FileManager.default.fileExists(atPath: url.path())
                            mediaURL.stopAccessingSecurityScopedResource()
                            if answer {
                                return url
                            } else {
                                return nil
                            }
                        }
                    }
                }
            } else {
                Logger.shared.error("unhandled proxyExists check")
            }
        }
        return nil
    }
    
    func thumbnailFor(take:DirectorTakeModel, cameraUUID:String) -> UIImage {
        if let project = DirectorProjectService.loadProject(uuid: take.projectUUID) {
            if project.proxyStorageLocation == .appStorage {
                let url = TakeTransferQueue.urlForAppStorageProxyIn(take: take, cameraUUID: cameraUUID)
                
                let asset: AVAsset = AVAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                var thumbnailImage:CGImage?
                
                do {
                    thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 1), actualTime: nil)
                } catch let error {
                    Logger.shared.error("makeThumbnail error:\(error.localizedDescription)")
                    return UIImage(systemName: "video.slash")!
                }
                
                if let thumbnailImage  {
                    let i:UIImage = UIImage(cgImage: thumbnailImage)
                    return i
                }
            } else if project.proxyStorageLocation == .externalStorage {
                    for m in ExternalStorageService.storageList() {
                        if let mediaURL = ExternalStorageManager.loadExernalStorage(media: m) {
                            if mediaURL.startAccessingSecurityScopedResource() {
                                let url = TakeTransferQueue.urlForExternalStorageProxyIn(media: mediaURL, take: take, cameraUUID: cameraUUID)
                                let asset: AVAsset = AVAsset(url: url)
                                let imageGenerator = AVAssetImageGenerator(asset: asset)
                                imageGenerator.appliesPreferredTrackTransform = true
                                
                                var thumbnailImage:CGImage?
                                
                                do {
                                    thumbnailImage = try imageGenerator.copyCGImage(at: CMTimeMake(value: 1, timescale: 1), actualTime: nil)
                                } catch let error {
                                    Logger.shared.error("makeThumbnail error:\(error.localizedDescription)")
                                    mediaURL.stopAccessingSecurityScopedResource()
                                    return UIImage(systemName: "video.slash")!
                                }
                                
                                if let thumbnailImage  {
                                    let i:UIImage = UIImage(cgImage: thumbnailImage)
                                    mediaURL.stopAccessingSecurityScopedResource()
                                    return i
                                }
                              
                                mediaURL.stopAccessingSecurityScopedResource()
                                return UIImage(systemName: "video.slash")!
                            }
                        }
                    }
            }
        }
        
         return UIImage(systemName: "video.slash")!
    }
    
    @State var marked:Bool = false
    @State var updateToggle:Bool = false
    
    var body: some View {
        VStack {
            GeometryReader { geo in
                Form {
                    Section("Take", content: {
                        Text("\(dateTimeStamp(take: take)) - \(durationString(take: take))").foregroundStyle(.primary)
                        
                    })
                    
                    Section("Phostera Cameras", content: {
                        List {
                            ForEach(take.cameraUUIDs, id: \.self) { uuid in
                                HStack {
                                    Text("\(uuid)").backgroundStyle(marked ? .green : .primary).frame(alignment: .leading)
                                    Spacer()
                                    Image(uiImage: thumbnailFor(take: take, cameraUUID: uuid)).resizable().aspectRatio(contentMode: .fit).frame(maxHeight:150).frame(alignment: .center)
                                    Spacer()
                                    if let project = DirectorProjectService.loadProject(uuid: take.projectUUID) {
                                        let url = proxyExists(take: take, cameraUUID: uuid)
                                        if let url  {
                                            NavigationLink {
                                                MediaPlayer(media: url, project: project, cameraUUID: uuid)
                                            } label: {
                                                Text("Play Proxy").frame(alignment: .trailing)
                                            }
                                        } else {
                                            Text("No Proxy").frame(alignment: .trailing)
                                        }
                                    }
                                }
                                
                            }
                        }
                    })
                }
            }
        }.onAppear() {
          
        }.frame(minWidth: 200, idealWidth: 200, maxWidth: .infinity, minHeight: 200, idealHeight: 400, maxHeight: .infinity, alignment: .center)
            .navigationTitle("View Take").navigationBarTitleDisplayMode(.inline)
    }
}



//                Section(header: Text( "Footage")) {
//                    List {
//                        ForEach(take.cameraUUIDs, id: \.self) { item in
//                            HStack {
//                                Text("\(item) - ")
//                                ForEach(take.directorFootageReference.keys.filter({ k in
//                                    k == item
//                                }), id: \.self) { f in
//                                    Text("dirhasfootage:\(f)")
//                                    //Tell if in app storage or which external storage or if copied to camera roll
//                                }
//                            }
//                        }
//                    }
//                }

//                Section(header: Text( "Proxies")) {
//                    List {
//                        ForEach(take.cameraUUIDs, id: \.self) { item in
//                            HStack {
//                                Text("\(item) - ")
//                                ForEach(take.directorProxyReference.keys.filter({ k in
//                                    k == item
//                                }), id: \.self) { f in
//                                    Text("dirhasfootage:\(f)")
//                                    //Tell if in app storage or which external storage or if copied to camera roll
//                                }
//                            }
//                        }
//                    }
//                }
