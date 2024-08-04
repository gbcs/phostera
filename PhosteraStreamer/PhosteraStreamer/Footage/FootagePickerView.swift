//
//  FootagePickerView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/12/23.
//

import Foundation
import SwiftUI
import PhosteraShared
import _PhotosUI_SwiftUI
import Combine

struct StreamerMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy: URL = FootageService.getURLForNewVideo()
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

enum TransferError: Error {
    case importFailed
}

struct StreamerImage: Transferable {
#if canImport(AppKit)
    var image: NSImage
#elseif canImport(UIKit)
    var image: UIImage
#endif
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
#if canImport(AppKit)
            guard let nsImage = NSImage(data: data) else {
                throw TransferError.importFailed
            }
            return StreamerImage(image: nsImage)
#elseif canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return StreamerImage(image: uiImage)
#else
            throw TransferError.importFailed
#endif
        }
    }
}

struct FootagePickerView: View {
    @State private var showDetail: Bool = false
    @State var pickedImage: PhotosPickerItem?
    @State var pickedVideo: PhotosPickerItem?
    @State var selectedImage: StreamerImage?
    @State var selectedVideo:StreamerMovie?
    @State var complaintMessage:String = ""
    @Environment(\.dismiss) private var dismiss
    @State var selectedVideoMetadata:VideoMetadata?
    @State var selectedVideoThumb:UIImage?
    @State var showProgressUI:Bool = false
    
    @State private var isPickerPresented: Bool = false
    @State var storageMedia:[StorageMediaModel] = []
    @State var updateView:Bool = false
    @State var fileItem:DiskFileItem?
    @State var importCompletedSucessfully:Bool = false
    @State var picked:Bool = true
    

    func updateStorage() {
        storageMedia = ExternalStorageService.storageList()
    }
    
    func testDevice(media:StorageMediaModel) -> Bool {
        if let mediaURL = ExternalStorageManager.loadExernalStorage(media: media) {
            if mediaURL.startAccessingSecurityScopedResource() {
                mediaURL.stopAccessingSecurityScopedResource()
                return true
            }
        }
        return false
    }
    
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                VStack {
                    Form {
                        if showProgressUI {
                            HStack {
                                Text("Importing")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Section("Photo Library") {
                                PhotosPicker(selection: $pickedVideo, matching: .videos) {
                                    Text("Find a Video")
                                }
                                PhotosPicker(selection: $pickedImage, matching: .images) {
                                    Text("Find a Picture")
                                }
                            }
                        }
                        Section("Enrolled Storage Devices") {
                            Button(action: {
                                isPickerPresented = true
                            }) {
                                Text("Enroll Storage Device")
                            }.disabled(showProgressUI)
                            .documentPicker(isPresented: $isPickerPresented)
                            
                            if storageMedia.count == 0 {
                                ContentUnavailableView("No Storage Devices Enrolled",
                                                       systemImage: "externaldrive.badge.plus",
                                                       description: Text("Insert an external storage device, then tap Enroll"))
                            } else {
                                List {
                                    ForEach(storageMedia, id: \.owningUUID) { media in
                                        HStack {
                                            NavigationLink {
                                                ExternalStorageViewer(media: media)
                                            } label: {
                                                Text("\(media.volumeName)").frame(alignment: .leading)
                                                Text("\(media.availableCapacity) of \(media.totalCapacity)").frame(alignment: .trailing)
                                            }.disabled(!testDevice(media: media))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                   
                    
                    if complaintMessage.lengthOfBytes(using: .utf8) > 0 {
                        Text("\(complaintMessage)").foregroundStyle(.red)
                    }
                    
                    if let selectedImage {
                        GeometryReader { geometry in
                            ZStack {
                                Image(uiImage: selectedImage.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width)
                            }
                        }
                    }
                    
                    if let selectedVideoThumb, let selectedVideoMetadata {
                        GeometryReader { geometry in
                            VStack {
                                Image(uiImage: selectedVideoThumb)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width)
                                Text( "\(Int(selectedVideoMetadata.resolution.width))x\(Int(selectedVideoMetadata.resolution.height)), 1/\(Int(selectedVideoMetadata.frameRate))" )
                            }
                        }
                    }
                }
            }.onAppear() {
                if importCompletedSucessfully {
                    dismiss()
                }  else {
                    updateStorage()
                    
                }
            }.onReceive(PubCentral.shared.documentPicked, perform: { notification in
                if let userInfo = notification.userInfo {
                    if let url = userInfo["url"] as? URL {
                        let (answer, reason) = ExternalStorageManager.evaluateExternalURL(url: url)
                        if !answer {
                            Logger.shared.info("evaluate external url pick returned: \(reason)")
                        } else {
                            if let storageDevice = ExternalStorageManager.addExternalStorage(url: url, ownerUUID: SettingsService.shared.settings.serverUUID) {
                                Logger.shared.info("We got some storage. \(storageDevice)")
                                ExternalStorageService.save(storage: storageDevice)
                                updateStorage()
                                updateView.toggle()
                            }
                        }
                    }
                }
            })
            .task(id: pickedVideo) {
                if pickedVideo == nil { return }
                showProgressUI = true
                var good:Bool = false
                if let video = try? await pickedVideo?.loadTransferable(type: StreamerMovie.self) {
                    if let metadata = await FootageService.videoMetadata(from: video.url) {
                        if let thumbnail = FootageService.makeThumbnailFor(url: video.url) {
                            good = true
                            DispatchQueue.main.async {
                                clearSelection()
                                selectedVideoMetadata = metadata
                                selectedVideo = video
                                selectedVideoThumb = thumbnail
                                fileItem = DiskFileItem(id: 42, name:  video.url.lastPathComponent, fullPath: video.url.path())
                                fileItem?.footageType = .video
                                fileItem?.name = video.url.lastPathComponent
                                picked = true
                            }
                        }
                    }
                    if !good {
                        deleteVideo(url: video.url)
                    }
                }
                
                if !good {
                    DispatchQueue.main.async {
                        clearSelection()
                        complaintMessage = "Video not usable."
                    }
                }
            }.task(id: pickedImage) {
                if let i = try? await pickedImage?.loadTransferable(type: StreamerImage.self) {
                    if (i.image.size.width != 1920) || (i.image.size.height != 1080) {
                        let z = ImageResizer.resizeImage(image: i.image)
                        Logger.shared.info("Resized image: \(z.size.width)x\(z.size.height)")
                        DispatchQueue.main.async {
                            clearSelection()
                            selectedImage = StreamerImage(image: z)
                        }
                    } else {
                        DispatchQueue.main.async {
                            clearSelection()
                            selectedImage = i
                        }
                    }
                }
            }.navigationTitle("Add Asset").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: {
                            if let selectedVideo {
                                deleteVideo(url: selectedVideo.url)
                            }
                            dismiss()
                        }) {
                            Text("Cancel")
                        }.disabled(showProgressUI)
                    }
                    
                    if let selectedImage {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: {
                                if let photoURL = savePhoto(image: selectedImage.image) {
                                    let footage = FootageService.makeFootage(url: photoURL, type: .photo)
                                    Task {
                                        
                                        await FootageService.shared.add(footage: footage)
                                    }
                                }
                                dismiss()
                            }) {
                                Text("Save")
                            }.disabled(showProgressUI)
                        }
                    }
                    
                    if let _ = selectedVideo {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                ImportVideoView(fileItem: $fileItem, importCompletedSucessfully: $importCompletedSucessfully, picked: $picked)
                            } label: {
                                Text("Convert")
                            }
                        }
                    }
                }
        }
    }

    func savePhoto(image:UIImage) -> URL? {
        let url = FootageService.getURLForNewPhoto()
        
        guard let data = image.pngData() else {
            return nil
        }
        
        do {
            try data.write(to: url)
        } catch {
            return nil
        }
        
        return url
    }
    
    func deleteVideo(url:URL) {
        try? FileManager.default.removeItem(atPath: url.path)
    }
    
    func clearSelection() {
        complaintMessage = ""
        selectedVideo = nil
        selectedImage = nil
        selectedVideoMetadata = nil
        selectedVideoThumb = nil
        showProgressUI = false
    }
}

extension View {
    func documentPicker(isPresented: Binding<Bool>) -> some View {
        return sheet(isPresented: isPresented) {
            DocumentPicker()
        }
    }
}
