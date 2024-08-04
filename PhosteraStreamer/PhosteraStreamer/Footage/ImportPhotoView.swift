//
//  ImportPhotoView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/5/23.
//

import SwiftUI
import PhosteraShared
import Combine

struct ImportPhotoView: View {
    @Binding var fileItem:DiskFileItem?
    @Environment(\.dismiss) private var dismiss
    @State var viewUpdate:Bool = false
    @State var image:UIImage?
    @State var metadata:PhotoMetadata?
    
    func loadPhoto() {
        if let f = fileItem, let url = URL(string: f.fullPath) {
            Task {
                if let storageMedia = SettingsService.shared.currentStorageMedia {
                    if let storageURL = ExternalStorageManager.loadExernalStorage(media: storageMedia) {
                        if storageURL.startAccessingSecurityScopedResource() {
                            Logger.shared.info("scr2 worked:\(storageURL)")
                            let f = URL(filePath: url.path)
                            metadata = await PhotoMetadata.photoMetadata(from: f)
                            if let i = UIImage(contentsOfFile: f.path) {
                                let thumb = ImageResizer.resizeImage(image: i)
                                DispatchQueue.main.async {
                                    image = thumb
                                    viewUpdate.toggle()
                                }
                            }
                            storageURL.stopAccessingSecurityScopedResource()
                        }
                    }
                }
            }
        }
    }
    
    func importPhoto() {
        let outURL = FootageService.getURLForNewPhoto()
        let footage = FootageService.makeFootage(url: outURL, type: .photo)
        footage.name = footage.url.lastPathComponent
        Task {
            if let data = image?.pngData() {
                try? data.write(to: footage.url)
                await FootageService.shared.add(footage: footage)
                DispatchQueue.main.async {
                    dismiss()
                }
            } else {
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack() {
                    Form {
                        if viewUpdate || !viewUpdate {
                            Section("\(fileItem?.name ?? "")", content: {
                                if let metadata {
                                    HStack {
                                        Text("Resolution")
                                        Spacer()
                                        Text("\(metadata.resolution.width)x\(metadata.resolution.height)")
                                    }
                                    
                                }
                            })
                        }
                        
                        if let image {
                            Section("1920x1080", content: {
                                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                            })
                        }
                    }
                }
            }
            .navigationTitle("Import Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading, content: {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                    }
                })
                
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        importPhoto()
                    }) {
                        Text("Import")
                    }
                })
            }
        }.onAppear() {
            loadPhoto()
        }
       
    }
}

