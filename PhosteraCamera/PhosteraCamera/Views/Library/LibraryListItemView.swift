//
//  LibraryListItemView.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/12/23.
//

import Foundation
import SwiftUI
import PhosteraShared

struct LibraryListItemView: View {
    @Binding var pathLibrary: [LibraryRoute]
    @Binding var items:[FootageFileItem]
    @Binding var selectedItem:FootageFileItem
    
    @State private var isDeletingSelectedItem = false
    @State private var isSharingSelectedItem = false
    @State private var isDetailViewingSelectedItem = false
    @State private var isExternalCopyingItem = false
    
    @State private var progressViewShowing = false
    @State private var copyToCameraRollFailed = false
    @State private var copyToCameraRollSucceeded = false
    
    @State private var copyToExternalStorageFailed = false
    @State private var copyToExternalStorageSucceeded = false
    @State private var copyingToExternalStorage:Bool = false
    
    @State private var showDetailView = false
    @State private var viewUpdate:Bool = false
    
    @State var externalSaver:ExternalStorageSaver = ExternalStorageSaver()
    @State var videoSaver:VideoSaver = VideoSaver()
    
    var image:UIImage
    
    func deleteSelectedItem() {
        LibraryController.removeSelectedItemFromDisk(item: selectedItem)
        items.removeAll { i in
            i == selectedItem
        }
    }
 
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack {
                    HStack {
                        if selectedItem.url.hasSuffix("mov") {
                            NavigationLink(destination: VideoDetailView(pathLibrary: $pathLibrary, selectedItem: $selectedItem)) {
                                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(minWidth: geo.size.width - 200)
                            }
                        } else {
                            NavigationLink(destination: PhotoDetailView(pathLibrary: $pathLibrary, selectedItem: $selectedItem)) {
                                Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(minWidth: geo.size.width - 200)
                            }
                        }
                        if viewUpdate || (!viewUpdate) {
                            VStack(alignment: .leading, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
                                if selectedItem.url.hasSuffix("mov") {
                                    if let d = selectedItem.videoMetadata?.duration {
                                        Text("\(DateService.shared.componentStringFrom(duration: TimeInterval(floatLiteral: d)))").font(.system(size: 16))
                                    } else {
                                        Text("--x--")
                                    }
                                    
                                    if let r = selectedItem.videoMetadata?.resolution {
                                        Text("\(Int(r.width))x\(Int(r.height))").font(.system(size: 16))
                                    } else {
                                        Text("--x--")
                                    }
                                    
                                    if let f = selectedItem.videoMetadata?.frameRate {
                                        let t = String(format: "%.2f", f)
                                        Text("\(t) fps").font(.system(size: 16))
                                    } else {
                                        Text("?? fps")
                                    }
                                    
                                    if let e = selectedItem.videoMetadata?.encoding {
                                        Text("\(e)").font(.system(size: 16))
                                    } else {
                                        Text("??")
                                    }
                                } else {
                                    Spacer()
                                    if let r = selectedItem.photoMetadata?.resolution {
                                        Text("\(Int(r.width))x\(Int(r.height))").font(.system(size: 16))
                                    } else {
                                        Text("--x--")
                                    }
                                    
                                    if let e = selectedItem.photoMetadata?.encoding {
                                        Text("\(e)").font(.system(size: 16))
                                    } else {
                                        Text("??")
                                    }
                                    Spacer()
                                }
                                Spacer()
                                HStack {
                                    Button {
                                        isDeletingSelectedItem.toggle()
                                    } label: {
                                        Image(systemName: "trash")
                                    }.frame(alignment: .leading)
                                        .alert("Delete Item", isPresented: $isDeletingSelectedItem) {
                                            Button("OK", role: .destructive ) {
                                                self.deleteSelectedItem()
                                                
                                            }
                                            Button("Cancel", role: .cancel) { }
                                        }
                                    Spacer()
                                    Button {
                                        let url = URL(filePath: selectedItem.url)
            
                                        if let takeDirectory = url.pathComponents.dropLast().last {
                                            progressViewShowing.toggle()
                                            self.copyingToExternalStorage = true
                                            self.externalSaver = ExternalStorageSaver()
                                            self.externalSaver.successHandler = {
                                                Logger.shared.info("Copy \(takeDirectory) to external storage succeeded.")
                                                self.progressViewShowing = false
                                                copyToExternalStorageSucceeded = true
                                            }
                                            self.externalSaver.failHandler = {
                                                Logger.shared.error("Copy \(takeDirectory) to external storage failed.")
                                                self.progressViewShowing = false
                                                self.copyToExternalStorageFailed = true
                                            }
                                            self.externalSaver.save(takeUUID: takeDirectory)
                                            
                                        }
                                    } label: {
                                        if copyingToExternalStorage && progressViewShowing  {
                                            ProgressView { }
                                        } else {
                                            Image(systemName: "externaldrive")
                                        }
                                    }.frame(alignment: .leading)
                                        .alert("An error occuurred while copying \(selectedItem.url) to external storage.", isPresented: $copyToExternalStorageFailed) {
                                            Button("OK", role: .cancel ) {
                                                copyToExternalStorageFailed = false
                                            }
                                        }.alert("The item was copied to external storage successfully.", isPresented: $copyToExternalStorageSucceeded) {
                                            Button("OK", role: .cancel ) {
                                                copyToExternalStorageSucceeded = false
                                            }
                                        }
                                    
                                    Spacer(minLength: 20)
                                    Button {
                                        progressViewShowing.toggle()
                                        self.videoSaver = VideoSaver()
                                        self.copyingToExternalStorage = false
                                        self.videoSaver.successHandler = {
                                            Logger.shared.info("success")
                                            self.progressViewShowing = false
                                            copyToCameraRollSucceeded = true
                                        }
                                        self.videoSaver.errorHandler = {
                                            Logger.shared.error("Video file copy to camera roll error: \($0.localizedDescription)")
                                            self.progressViewShowing = false
                                            copyToCameraRollFailed = true
                                        }
                                        self.videoSaver.writeToPhotoAlbum(video: selectedItem.url)
                                    } label: {
                                        if (!copyingToExternalStorage) && progressViewShowing  {
                                            ProgressView { }
                                        } else {
                                            Image(systemName: "square.and.arrow.up")
                                        }
                                    }.frame(alignment: .trailing)
                                        .alert("An error occuurred while copying \(selectedItem.url) to the camera roll.", isPresented: $copyToCameraRollFailed) {
                                            Button("OK", role: .cancel ) {
                                                copyToCameraRollFailed = false
                                            }
                                        }.alert("The item was copied to the camera roll successfully.", isPresented: $copyToCameraRollSucceeded) {
                                            Button("OK", role: .cancel ) {
                                                copyToCameraRollSucceeded = false
                                            }
                                        }
                                }
                            }).frame(width: 120, height: 190, alignment: .trailing)
                            Spacer(minLength: 5)
                        }
                    }
                }.frame(width: geo.size.width - 120, height: 200, alignment: .center)
            }.onAppear() {
                
            }
        }
    }
}


