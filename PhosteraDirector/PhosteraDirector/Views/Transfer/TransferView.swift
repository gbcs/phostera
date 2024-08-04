//
//  Transfer.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/21/23.
//

import Foundation
import SwiftUI
import PhosteraShared


struct TransferView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPickerPresented: Bool = false
    @State var storageMedia:[StorageMediaModel] = []
    @State var updateView:Bool = false
    @State var projectList:[DirectorProjectModel] = []
    
    func updateProjectList() {
        projectList = DirectorProjectService.projectList()
        updateView.toggle()
    }
    
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
        GeometryReader { reader in
            if updateView || !updateView {
                VStack {
                    Section(header: HStack { Spacer(); Text("Projects"); Spacer() } ) {
                        List {
                            ForEach(projectList, id: \.id) { project in
                                HStack {
                                    NavigationLink {
                                        TakeListView(project: project)
                                    } label: {
                                        Text("\(project.title)").frame(alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("External Storage", content: {
                        if storageMedia.count == 0 {
                            ContentUnavailableView("No Storage Devices Enrolled",
                                                   image: "externaldrive.badge.plus",
                                                   description: Text("Insert an external storage device, then tap the add button."))
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
                    })
               
                    Spacer()
                }
            }
        }.onAppear() {
            updateStorage()
            updateProjectList()
        }.onReceive(PubCentral.shared.documentPicked, perform: { notification in
            if let userInfo = notification.userInfo {
                if let url = userInfo["url"] as? URL {
                    let (answer, reason) = ExternalStorageManager.evaluateExternalURL(url: url)
                    if !answer {
                        Logger.shared.info("evaluate external url pick returned: \(reason)")
                    } else {
                        if let storageDevice = ExternalStorageManager.addExternalStorage(url: url) {
                            Logger.shared.info("We got some storage. \(storageDevice)")
                            ExternalStorageService.save(storage: storageDevice)
                            updateStorage()
                            updateView.toggle()
                        }
                    }
                }
            }
        })
        .navigationTitle("Media")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    updateView.toggle()
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                }
                
            })
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    isPickerPresented = true
                }) {
                    Image(systemName: "externaldrive.badge.plus")
                }.documentPicker(isPresented: $isPickerPresented)
            })
        }
    }
}

extension View {
    func documentPicker(isPresented: Binding<Bool>) -> some View {
        return sheet(isPresented: isPresented) {
            DocumentPicker()
        }
    }
}
