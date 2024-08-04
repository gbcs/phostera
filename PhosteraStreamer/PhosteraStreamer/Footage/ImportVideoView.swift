//
//  ImportMediaView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/4/23.
//


import SwiftUI
import PhosteraShared
import Combine

@objc class ImportViewModel: NSObject {
    var videoImporter:VideoImporter = VideoImporter()
}

struct ImportVideoView: View {
    @Binding var fileItem:DiskFileItem?
    @Environment(\.dismiss) private var dismiss
    @State var importMode:Bool = false
    @State var importModel = ImportViewModel()
    @State var alertShown:Bool = false
    @State var timer:Timer?
    @State var status:Float = 0.0
    @State var metadata:VideoMetadata?
    @State var viewUpdate:Bool = false
    @State var thumbnail:UIImage?
    @State var storageURL:URL?
    @Binding var importCompletedSucessfully:Bool
    @Binding var picked:Bool
    
    func importVideo() {
        guard let fileItem else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
            Task {
                if let s = await importModel.videoImporter.exportSession?.progress {
                    DispatchQueue.main.async {
                        status = s
                    }
                }
            }
        })
        
        let outURL = FootageService.getURLForNewVideo() //Might not get created. If it does, then 
        if let inUrl = URL(string: fileItem.fullPath) {
            Task {
                let frameRate = await StreamFrameRate.toInt(streamRate: ProjectService.shared.currentProject().streamFrameRate)
           
                await importModel.videoImporter.convert(externalStorage: storageURL != nil, inputURL: inUrl,
                                                        targetFrameRate: frameRate,
                                                        outputURL: outURL,
                                                        completion: { status, url in
                    Logger.shared.info("import finish: \(status) - \(String(describing: url))")
                   
                    if status == .completed, let url {
                        let audioOutputURL = URL(filePath:url.appendingPathExtension("caf").path())
                        
                        AudioImporter.convertAACtoLPCM(inputURL: inUrl, outputURL: audioOutputURL, externalStorage: storageURL != nil) { result in
                            switch result {
                            case .success():
                                Logger.shared.info("Audio Conversion successful")
                            case .failure(let error):
                                Logger.shared.error("Audio conversion failed with error: \(error)")
                            }
                            
                            DispatchQueue.main.async {
                                timer?.invalidate()
                                timer = nil
                                if status == .completed {
                                    let footage = FootageService.makeFootage(url: url, type: .video)
                                    if fileItem.name != "" {
                                        footage.name = fileItem.name
                                    } else {
                                        footage.name = footage.url.lastPathComponent
                                    }
                                    Task {
                                        await FootageService.shared.add(footage: footage)
                                        let a = url.lastPathComponent
                                        let b = inUrl.lastPathComponent
                                        
                                        if picked && (a != b) {
                                            Logger.shared.info("Deleting \(inUrl) as it was picked and not the same as url returned from converter.")
                                            do {
                                                try FileManager.default.removeItem(at: URL(filePath: inUrl.path()))
                                            } catch {
                                                Logger.shared.error("Unable to delete temp import from photo library. \(inUrl)")
                                            }
                                        } else {
                                            Logger.shared.info("Keeping \(inUrl) as it wasn't picked and not the same as url returned from converter.")
                                        }
                                        importCompletedSucessfully = true
                                        DispatchQueue.main.async {
                                            dismiss()
                                            NotificationCenter.default.post(name: Notification.Name.reloadFootage, object: nil)
                                        }
                                    }
                                } else {
                                    alertShown = true
                                }
                                importMode = false
                            }
                        }
                    }
                })
            }
        }
    }
    
    func getMetadata() {
        if let f = fileItem, let url = URL(string: f.fullPath) {
            Task {
                if let storageMedia = SettingsService.shared.currentStorageMedia {
                    storageURL = ExternalStorageManager.loadExernalStorage(media: storageMedia)
                    if let storageURL {
                        if storageURL.startAccessingSecurityScopedResource() {
                            Logger.shared.info("scr2 worked:\(storageURL)")
                        }
                    }
                }
                
                let f = URL(filePath: url.path)
                let thumb = FootageService.makeThumbnailFor(url: f)
                
                if let metadataIn = await VideoMetadata.videoMetadata(from: f) {
                    DispatchQueue.main.async {
                        thumbnail = thumb
                        metadata = metadataIn
                        viewUpdate.toggle()
                    }
                }
                storageURL?.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack() {
                    Form {
                        if importMode {
                            Section(fileItem?.name ?? "", content: {
                                ProgressView("Converting", value:status, total: 1.0)
                            })
                        }
                        if viewUpdate || !viewUpdate {
                            Section("\(fileItem?.name ?? "")", content: {
                                if let metadata {
                                    HStack {
                                        Text("Duration")
                                        Spacer()
                                        Text("\(DateService.shared.componentStringFrom(duration: TimeInterval(floatLiteral: metadata.duration)))")
                                    }
                                    HStack {
                                        Text("Resolution")
                                        Spacer()
                                        Text("\(Int(metadata.resolution.width))x\(Int(metadata.resolution.height))")
                                    }
                                    HStack {
                                        Text("Framerate")
                                        Spacer()
                                        let t = String(format: "%.2f", metadata.frameRate)
                                        Text("\(t) fps")
                                    }
                                    HStack {
                                        Text("Encoding")
                                        Spacer()
                                        Text("\(metadata.encoding)")
                                    }
                                }
                            })
                            if let thumbnail {
                                Section("Thumbnail") {
                                    Image(uiImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
                                }
                            }
                            
                        }
                    }
                }
            }.onAppear() {
                getMetadata()
            }.alert(isPresented: $alertShown) {
                Alert(title: Text("Import Error"), message: Text("Problem with import. Check log and source video for compatibility."), dismissButton: .default(Text("Ok"), action: {
                    dismiss()
                }))
            }
            .navigationTitle("Import Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading, content: {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel").disabled(importMode)
                    }
                    
                })
                
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        importVideo()
                        importMode.toggle()
                    }) {
                        Text("Import").disabled(importMode)
                    }
                })
            }
        }
    }
}

