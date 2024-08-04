//
//  CameraManager.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/21/23.
//

import SwiftUI
import PhosteraShared
import DeviceKit

struct BorderedSection<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Section {
            content
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 2)
        )
    }
}

struct CameraManagerView: View {
    let columns = [  GridItem(.adaptive(minimum: 140)) ]
    let columnsSelected = [  GridItem(.adaptive(minimum: 200)) ]
    @State var viewUpdateTime: Bool = false
    @State private var showingDeleteMessage = false
    @State private var cameraToMaybeDelete:CameraModel?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewUpdateTime == false || viewUpdateTime == true {
                   
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(CameraManager.shared.cameraList.filter {
                                var found = false
                                for x in CameraManager.shared.availableUUIDs {
                                    if $0.uuid == x {
                                        found = true
                                        break
                                    }
                                }
                                return !found
                            }, id: \.self) { item in
                                if item.isKnown() {
                                    CameraCard(camera: item, isSelected: CameraManager.shared.availableUUIDs.contains(item.uuid)).onTapGesture {
                                        if CameraManager.shared.availableUUIDs.contains(item.uuid) {
                                            CameraManager.shared.availableUUIDs.remove(item.uuid)
                                        } else {
                                            CameraManager.shared.availableUUIDs.insert(item.uuid)
                                        }
                                        CameraManager.shared.saveAvailableCameras()
                                        viewUpdateTime.toggle()
                                    }.onLongPressGesture(perform: {
                                        self.cameraToMaybeDelete = item
                                        self.showingDeleteMessage = true
                                    }
                                    )
                                } else {
                                    if CameraManager.shared.onlineUUIDs.contains(item.uuid) {
                                        NavigationLink(destination:  CameraPairView(camera: item), label: {
                                            CameraCard(camera: item)
                                        })
                                    } else {
                                        CameraCard(camera: item)
                                    }
                                }
                            }.actionSheet(isPresented: $showingDeleteMessage) {
                                ActionSheet(
                                    title: Text("Delete Camera"),
                                    message: Text("Delete \(cameraToMaybeDelete?.name ?? "Unknown") (\(cameraToMaybeDelete?.uuid ?? "Unknown"))?"),
                                    buttons: [
                                        .destructive(Text("Delete")) {
                                            if let cameraToMaybeDelete {
                                                _ =  CameraManager.shared.removeCamera(camera: cameraToMaybeDelete)
                                            }
                                            self.cameraToMaybeDelete = nil
                                            self.showingDeleteMessage = false
                                        },
                                        .cancel() {
                                            self.cameraToMaybeDelete = nil
                                            self.showingDeleteMessage = false
                                        }
                                    ]
                                )
                            }
                        
                    }.padding(.horizontal)
                
                }
                Rectangle().fill(.gray).frame(height: 1)
            
                    LazyVGrid(columns: columnsSelected, spacing: 10) {
                        ForEach(CameraManager.shared.cameraList.filter {
                            var found = false
                            for x in CameraManager.shared.availableUUIDs {
                                if $0.uuid == x {
                                    found = true
                                    break
                                }
                            }
                            return found
                        }, id: \.self) { item in
                            CameraSelectedCard(camera: item, online: CameraManager.shared.onlineUUIDs.contains(item.uuid), updateView: true) .onTapGesture {
                                CameraManager.shared.availableUUIDs.remove(item.uuid)
                                let x = WatchEntryManager.shared.remoteCameraIndex(uuid: item.uuid)
                                if x > -1 {
                                    WatchEntryManager.shared.remoteCameras[x] = ""
                                    WatchEntryManager.shared.remoteCamerasEnabled[x] = false
                                }
                                viewUpdateTime.toggle()
                            }
                        }
                    }.padding(.horizontal)
                
            }.onReceive(PubCentral.shared.cameraListChanged) { (output) in
                self.viewUpdateTime.toggle()
            }.onReceive(PubCentral.shared.cameraUpdated) { (output) in
                self.viewUpdateTime.toggle()
            }.onDisappear() {
                CameraManager.shared.saveAvailableCameras()
            }
        }.navigationTitle("Phostera Cameras").navigationBarTitleDisplayMode(.inline)
//            .navigationBarItems(
//                trailing:
//                    NavigationLink(destination: {
//                        WifiView()
//                    }, label: { Image(systemName: "wifi") })
//            )
    }
}

