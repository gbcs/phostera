//
//  ProjectDetailView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/11/23.
//

import SwiftUI
import PhosteraShared
import Combine
import AVFoundation

struct ProjectDetailView: View {
    @ObservedObject var project: DirectorProjectModel
    @State var externalStorageSupported:Bool = AVExternalStorageDeviceDiscoverySession.isSupported
    @State var update:Bool = false
    @State var resolution: Int = DirectorProjectResolution.v1920x1080.rawValue
    @State var framerate: Int = DirectorProjectFrameRate.fr24.rawValue
    @State var codec: Int = DirectorProjectProresCodec.proRes422HQ.rawValue
    @State var colorspace: Int = DirectorProjectProresCodec.proRes422HQ.rawValue
    @State var backupFootageOnCameraStorage:Bool = false
    @State var recordFootageToExternalStorage:Bool = false
    @State var backupProxiesonCameraStorage:Bool = false
    @State var collectProxies:Bool = false
    @State var proxyResolution: Int = DirectorProjectResolution.v1920x1080.rawValue
    @State var fileNamingScheme: Int = DirectorProjectFileNamingScheme.scheme1.rawValue
    @State var proxyNamingScheme: Int = DirectorProjectFileNamingScheme.scheme1.rawValue
    @State var fileStorageLocation: Int = DirectorProjectStorageLocation.appStorage.rawValue
    @State var proxyStorageLocation: Int = DirectorProjectStorageLocation.appStorage.rawValue
    @State var modeStandby:Bool = true
    @State var locationInformation:Bool = true
    @State var allowStreamers:Bool = true
    @State var modeList:[DirectorProjectCameraMode] = []
    @State var useProresLogIfAvailable:Bool = true
    
    @State var newMode:DirectorProjectCameraMode = DirectorProjectCameraMode(type: .wide, title: "New", desc: "", settings: CurrentModeMetadata(resolution: .v1920x1080, frameRate: .fr24, codec: .proRes422HQ, colorspace: .rec709, fileNamingScheme: .scheme1, fileStorageLocation: .appStorage, recordToDisk: false), aspectRatio: CGSizeMake(16, 9), version: 1, provider: SettingsService.shared.settings.serverUUID, frontCamera: false, photoMode: false, techType: .cifilter, projectUUID: "")
    
    @Environment(\.dismiss) private var dismiss
    
    var newProject:Bool
    
    func setupNewMode(){
        let setttings = CurrentModeMetadata(resolution: .v1920x1080, frameRate: .fr24, codec: .proRes422HQ, colorspace: .rec709, fileNamingScheme: .scheme1, fileStorageLocation: .appStorage, recordToDisk: false)
        let mode = DirectorProjectCameraMode(type: .wide, title: "New", desc: "", settings: setttings, aspectRatio: CGSizeMake(16, 9), version: 1, provider: SettingsService.shared.settings.serverUUID, frontCamera: false, photoMode: false, techType: .cifilter, projectUUID: "")
        project.modeList.append(mode)
        modeList.append(mode)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Project Settings")) {
                TextField("Title", text: $project.title)
                

                Picker("Resolution", selection: $resolution) {
                    ForEach(DirectorProjectResolution.allCases, id: \.self.rawValue) { res in
                        switch(res) {
                        case .v3840x2160:
                            Text("3840x2160").tag(res.rawValue)
                        case .v1920x1080:
                            Text("1920x1080").tag(res.rawValue)
                            //                        case .v1280x720:
                            //                            Text("1280x720 (N/A)").tag(res.rawValue)
                        }
                    }
                }
//                .onChange(of: resolution, { _, newValue in
//                    //                    if newValue == DirectorProjectResolution.v1280x720.rawValue {
//                    //                        resolution = project.resolution.rawValue
//                    //                    } else {
//                    //
//                    //                    }
//                    project.resolution = DirectorProjectResolution(rawValue: newValue) ?? .v1920x1080
//                })
//                
                Picker("Framerate", selection: $framerate) {
                    ForEach(DirectorProjectFrameRate.allCases, id: \.self.rawValue) { rate in
                        switch(rate) {
                        case .fr24:
                            Text("24 fps").tag(rate.rawValue)
                        case .fr25:
                            Text("25 fps").tag(rate.rawValue)
                        case .fr30:
                            Text("30 fps").tag(rate.rawValue)
                            //                        case .fr48:
                            //                            Text("48 fps").tag(rate.rawValue)
                            //                        case .fr50:
                            //                            Text("50 fps").tag(rate.rawValue)
                            //                        case .fr60:
                            //                            Text("60 fps").tag(rate.rawValue)
                        }
                    }
                }
//                onChange(of: framerate, { _, newValue in
//                    project.frameRate = DirectorProjectFrameRate(rawValue: newValue) ?? .fr24
//                })
            }
            
            Section(header:HStack { Text("Camera Modes"); Spacer(); Button { setupNewMode() } label: { Image(systemName: "plus") } } ) {
                ForEach($modeList, id: \.uuid) { $m in
                    NavigationLink {
                        ProjectCameraModeView(newMode: false, mode: $m)
                    } label: {
                        Text(m.title)
                    }
                }.onDelete(perform: deleteMode)
            }
            
            Section(header: Text("Media")) {
                Toggle(isOn: $useProresLogIfAvailable) {
                    Text("Use Apple Log if supported")
                    Text("Media default: HEVC/sRGB").font(.subheadline.lowercaseSmallCaps())
                }

                Picker("Prores Codec", selection: $codec) {
                    Text("Apple ProRes 422 HQ").tag(DirectorProjectProresCodec.proRes422HQ.rawValue)
                    Text("Apple ProRes 422").tag(DirectorProjectProresCodec.proRes422.rawValue)
                    Text("Apple ProRes 422 LT").tag(DirectorProjectProresCodec.proRes422LT.rawValue)
                    Text("Apple ProRes 422 Proxy").tag(DirectorProjectProresCodec.proRes422Proxy.rawValue)
                }
                
              
                
                Toggle(isOn: $locationInformation ) {
                    Text("Include location information")
                }
            }
            
            Section(header: Text("Footage")) {
                Toggle(isOn: $recordFootageToExternalStorage) {
                    Text("Record directly to external storage")
                }
                
                Toggle(isOn: $backupFootageOnCameraStorage) {
                    Text("Copy to camera external storage")
                }
            }
            
            Section(header: Text("Phostera Streamer")) {
                Toggle(isOn: $allowStreamers) {
                    Text("Allow access to proxies")
                }
            }
            
            //
            //
            //                Picker("Storage Location", selection: $fileStorageLocation) {
            //                    ForEach(DirectorProjectStorageLocation.allCases, id: \.self.rawValue) { c in
            //                        switch(c) {
            //                        case .appStorage:
            //                            Text("App (transfer to mac/pc)").tag(c.rawValue)
            //                        case .photoLibrary:
            //                            Text("Photo Library (edit on this device)").tag(c.rawValue)
            //                        case .externalStorage:
            //                            Text("External Storage").tag(c.rawValue)
            //                        }
            //                    }
            //                }.onChange(of: fileStorageLocation, { _, newValue in
            //                    project.fileStorageLocation = DirectorProjectStorageLocation(rawValue: newValue) ?? .appStorage
            //                })
            //
            //                Picker("File Naming Scheme", selection: $fileNamingScheme) {
            //                    ForEach(DirectorProjectFileNamingScheme.allCases, id: \.self.rawValue) { c in
            //                        switch(c) {
            //                        case .scheme1:
            //                            Text("director_project_mode_cameraid_mm_dd_yy_hh_mm_ss_duration.mov").tag(c.rawValue).disabled(true)
            //                        case .scheme2:
            //                            Text("Some other scheme").tag(c.rawValue).disabled(true)
            //                        }
            //                    }
            //                }.onChange(of: fileNamingScheme, { _, newValue in
            //                    project.fileNamingScheme = DirectorProjectFileNamingScheme(rawValue: newValue) ?? .scheme1
            //                })
            //            }
            
            Section(header: Text("Proxies")) {
                Toggle(isOn: $backupProxiesonCameraStorage) {
                    Text("Copy to camera external storage")
                }
                
                Toggle(isOn: $collectProxies) {
                    Text("Collect on this director")
                }
                
//                Picker("Resolution", selection: $proxyResolution) {
//                    ForEach(DirectorProjectResolution.allCases, id: \.self.rawValue) { c in
//                        switch(c) {
//                        case .v3840x2160:
//                            Text("3840x2160").tag(c.rawValue)
//                        case .v1920x1080:
//                            Text("1920x1080").tag(c.rawValue)
//                            //                        case .v1280x720:
//                            //                            Text("1280x720").tag(c.rawValue)
//                        }
//                    }
//                }.onChange(of: proxyResolution, { _, newValue in
//                    //                    if project.proxyResolution.rawValue >= newValue {
//                    //                        project.proxyResolution = DirectorProjectResolution(rawValue: newValue) ?? .v1280x720
//                    //                    } else {
//                    //
//                    //                    }
//                    proxyResolution = project.proxyResolution.rawValue
//                })
                
                Picker("Storage Location", selection: $proxyStorageLocation) {
                    Text("App").tag(DirectorProjectStorageLocation.appStorage.rawValue)
                    Text("External").tag(DirectorProjectStorageLocation.externalStorage.rawValue)
//                    ForEach(DirectorProjectStorageLocation.allCases, id: \.self.rawValue) { c in
//                        switch(c) {
//                        case .appStorage:
//                            
//                        case .photoLibrary:
//                            Text("Photo Library").tag(c.rawValue)
//                        case .externalStorage:
//                           
//                        }
//                    }
                }.onChange(of: proxyStorageLocation, { _, newValue in
                    project.proxyStorageLocation = DirectorProjectStorageLocation(rawValue: newValue) ?? .appStorage
                })
                
                
                //                Picker("File Naming Scheme", selection: $proxyNamingScheme) {
                //                    ForEach(DirectorProjectFileNamingScheme.allCases, id: \.self.rawValue) { c in
                //                        switch(c) {
                //                        case .scheme1:
                //                            Text("director_project_mode_cameraid_mm_dd_yy_hh_mm_ss_duration.mov").tag(c.rawValue).disabled(true)
                //                        case .scheme2:
                //                            Text("Some other scheme").tag(c.rawValue)
                //                        }
                //                    }
                //                }.onChange(of: proxyResolution, { _, newValue in
                //                    project.proxyNamingScheme = DirectorProjectFileNamingScheme(rawValue: newValue) ?? .scheme1
                //                })
            }
            
            
            
            //            Section(header: Text("Mode - Standby")) {
            //                Toggle(isOn: $modeStandby) {
            //                    Text("Enabled")
            //                }.onChange(of: modeStandby, { _, newValue in
            //
            //                })
            //            }
            //        }.sheet(isPresented: $showNewMode, content: {
            //            NavigationStack {
            //                ProjectCameraModeView(newMode: true, mode: $newMode)
            //            }
            //        })
        } .onAppear() {
            externalStorageSupported = AVExternalStorageDeviceDiscoverySession.isSupported
            resolution = project.resolution.rawValue
            framerate = project.frameRate.rawValue
            codec = project.codec.rawValue
            useProresLogIfAvailable = (project.colorspace == .appleLog)
            backupFootageOnCameraStorage = project.backupFootageOnCameraStorage
            backupProxiesonCameraStorage = project.backupProxiesOnCameraStorage
            collectProxies = project.collectProxies
            proxyResolution = project.proxyResolution.rawValue
            fileNamingScheme = project.fileNamingScheme.rawValue
            proxyNamingScheme = project.proxyNamingScheme.rawValue
            fileStorageLocation = project.fileStorageLocation.rawValue
            proxyStorageLocation = project.proxyStorageLocation.rawValue
            locationInformation = project.locationInformation
            recordFootageToExternalStorage = project.recordFootageToCameraStorage
            modeList = project.modeList
            allowStreamers = project.allowStreamers
            //modeStandby = project.modeStandby
            //Standby always on in 1.0
            modeStandby = true
        }.navigationBarItems(leading: newProject ? Button("Cancel") {
            dismiss()
        } : nil,
                             trailing:
                                HStack {
            Button("Use") {
                saveProperties()
                updateModeProjectLinks()
                DirectorProjectService.save(project: project)
                SettingsService.shared.settings.currentProjectId = project.uuid
                SettingsService.shared.save()
                NotificationCenter.default.post(name: NSNotification.Name.projectListChanged, object: nil)
                dismiss()
            }
        }
        ).navigationTitle(newProject ? "Add Project" : "Edit Project").navigationBarTitleDisplayMode(.inline)
    }
    
    func deleteMode(at offsets: IndexSet) {
        project.modeList.remove(atOffsets: offsets)
        DirectorProjectService.save(project: project)
        modeList = project.modeList
    }
    
    func saveProperties() {
        project.backupFootageOnCameraStorage = backupFootageOnCameraStorage
        project.backupProxiesOnCameraStorage = backupProxiesonCameraStorage
        project.recordFootageToCameraStorage = recordFootageToExternalStorage
        project.modeStandby = modeStandby
        project.locationInformation = locationInformation
        project.collectProxies = collectProxies
        project.modeList = modeList
        project.colorspace = useProresLogIfAvailable ? .appleLog : .rec709
        project.codec = DirectorProjectProresCodec(rawValue: codec) ?? .proRes422HQ
        project.frameRate = DirectorProjectFrameRate(rawValue: framerate) ?? .fr24
    }
    
    func updateModeProjectLinks() {
        for mode in project.modeList {
            mode.projectUUID = project.uuid
            mode.provider = SettingsService.shared.settings.serverUUID
        }
    }
}
