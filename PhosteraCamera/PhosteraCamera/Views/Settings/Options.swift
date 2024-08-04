//
//  Options.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import SwiftUI
import PhosteraShared

struct OptionsPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathSettings: [SettingsRoute]
    @State var leftHand:Bool = SettingsService.shared.settings.leftHandOperation
    @State var showCamera:Bool = SettingsService.shared.settings.showCameraWhenConnectedToExternalDisplay
    @State var showCameraUI:Bool = SettingsService.shared.settings.showUIOnExternalDisplay
    
    @State private var isPickerPresented: Bool = false
    @State var storageMedia:[StorageMediaModel] = []
    @State var updateView:Bool = false
    
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
        List {
            if updateView || !updateView {
                Section("Privacy") {
                    NavigationLink(value: SettingsRoute.permissions) {
                        Text("Permissions")
                    }
                }
                
                Section("Enrolled Storage Devices") {
                    Button(action: {
                        isPickerPresented = true
                    }) {
                        Text("Enroll Storage Device")
                    }.documentPicker(isPresented: $isPickerPresented)
                    
                    ForEach(storageMedia, id: \.owningUUID) { media in
                        Text("\(media.volumeName) - \(media.availableCapacity) of \(media.totalCapacity)").foregroundColor(testDevice(media: media) ? .primary : .gray)
                    }
                }
            }
        }.onAppear() {
            updateStorage()
        }
        .onReceive(PubCentral.shared.documentPicked, perform: { notification in
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
        
        
        //                Section("Interface Choices") {
        //                    Toggle("Left hand operation", isOn: $leftHand).onChange(of: leftHand) {
        //                        SettingsService.shared.settings.leftHandOperation = leftHand
        //                        SettingsService.shared.save()
        //                    }
        //                }
        //                Section("Connected Display") {
        //                    Toggle("Show camera when connected", isOn: $showCamera).onChange(of: showCamera) {
        //                        SettingsService.shared.settings.showCameraWhenConnectedToExternalDisplay = showCamera
        //                        SettingsService.shared.save()
        //                    }
        //                    Toggle("Show UI", isOn: $showCameraUI).onChange(of: showCameraUI) {
        //                        SettingsService.shared.settings.showUIOnExternalDisplay = showCameraUI
        //                        SettingsService.shared.save()
        //                    }
        //                }
        .navigationTitle("Options")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    updateView.toggle()
                }) {
                    Image(systemName: "arrow.clockwise.circle")
                }
                
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
