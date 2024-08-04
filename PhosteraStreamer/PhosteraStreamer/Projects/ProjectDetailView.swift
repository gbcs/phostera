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
    @ObservedObject var project: StreamProjectModel
    @State var selectedResolution: Int = StreamResolution.v1920x1080.rawValue
    @State var selectedFrameRate: Int = StreamFrameRate.fr30.rawValue
    @State var update:Bool = false
    @Environment(\.dismiss) private var dismiss
    @State var ipadExternal: Int = StreamExternalCamera.replacesRear.rawValue
    @State var rearCameraLens: Int = StreamRearCameraLens.ultrawide.rawValue
    var newProject:Bool
    
    @State var urlPath:String = ""
    @State var streamName:String = ""
    
    @State var recordStream:Bool = false
    @State var provideWifi:Bool = false
    
    @State var bandwidthLimit:Double = 0.0
    @State var updateSlider:Bool = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Form {
                    Section(header: Text("Project Title")) {
                        TextField("Title", text: $project.title)
                    }
                    
                    Section(header: Text("Stream")) {
                        NavigationLink {
                            ProjectStreamDetailView(project: project)
                        } label: {
                            HStack {
                                switch(project.config.service) {
                                    //                                case .srt:
                                    //                                    Text("SRT (\(project.config.name))")
                                case .rtmp:
                                    Text("RTMP")
                                case .unknown:
                                    Text("None")
                                }
                            }
                        }
                        
                        Picker("Resolution", selection: $selectedResolution) {
                            ForEach(StreamResolution.allCases, id: \.self.rawValue) { res in
                                switch(res) {
                                case .v1920x1080:
                                    Text("1920x1080").tag(res.rawValue)
                                case .v1280x720:
                                    Text("1280x720").tag(res.rawValue)
                                case .v720x480:
                                    Text("720x480").tag(res.rawValue)
                                case .v640x360:
                                    Text("640x360").tag(res.rawValue)
                                }
                            }
                        }.onChange(of: selectedResolution, { _, newValue in
                            project.streamResolution = StreamResolution(rawValue: newValue) ?? .v1920x1080
                        })
                        
                        Picker("Frame Rate", selection: $selectedFrameRate) {
                            ForEach(StreamFrameRate.allCases, id: \.self.rawValue) { rate in
                                switch(rate) {
                                case .fr24:
                                    Text("24 fps").tag(rate.rawValue)
                                case .fr25:
                                    Text("25 fps").tag(rate.rawValue)
                                case .fr30:
                                    Text("30 fps").tag(rate.rawValue)
                                }
                            }
                        }.onChange(of: selectedFrameRate, { _, newValue in
                            project.streamFrameRate = StreamFrameRate(rawValue: newValue) ?? .fr30
                        })
                        
                        if bandwidthLimit > 0 {
                            Slider(
                                value: $bandwidthLimit,
                                in: 640000...10240000,
                                step: 640000,
                                minimumValueLabel: Text("64 KB/s"),
                                maximumValueLabel: Text("1 MB/s")
                            ) {
                                
                            }
                            Text("Max bandwidth set to: \(bandwidthLimit / 10000, specifier: "%.2f") KB/s")
                        }
                    }
                    
                    Section(header: Text("Audio Configuration")) {
                        NavigationLink(destination: {
                            showAudioConfig(forProject: project)
                        }, label: {
                            showAudioConfigInfo(forProject: project)
                        })
                    }
                    
                    Section(header: Text("Local Cameras")) {
                        Picker("Rear Camera Lens", selection: $rearCameraLens) {
                            ForEach(StreamRearCameraLens.allCases, id: \.self.rawValue) { r in
                                switch(r) {
                                case .ultrawide:
                                    Text("Ultrawide").tag(StreamRearCameraLens.ultrawide.rawValue)
                                case .wide:
                                    Text("Wide").tag(StreamRearCameraLens.wide.rawValue)
                                case .telephoto:
                                    Text("Telephoto").tag(StreamRearCameraLens.telephoto.rawValue)
                                }
                            }
                        }.onChange(of: rearCameraLens, { _, newValue in
                            project.rearCameraLens = StreamRearCameraLens(rawValue: newValue) ?? .ultrawide
                        })
                        
//                        Picker("iPad External Camera", selection: $ipadExternal) {
//                            ForEach(StreamExternalCamera.allCases, id: \.self.rawValue) { rate in
//                                switch(rate) {
//                                case .replacesRear:
//                                    Text("Replace rear camera").tag(rate.rawValue)
//                                case .replacesFront:
//                                    Text("Replace front camera").tag(rate.rawValue)
//                                }
//                            }
//                        }.onChange(of: ipadExternal, { _, newValue in
//                            project.ipadExternal = StreamExternalCamera(rawValue: newValue) ?? .replacesRear
//                        })
                        
                    }
                    
                    Section(header: Text("Phostera Cameras")) {
                        Section(header: Text("Message To New User")) {
                            
                            TextEditor(text: $project.defaultUserMessage)
                                .frame(height: 100)
                                .border(Color.gray, width: 1)
                        }
                        
//                        Toggle(isOn: $provideWifi) {
//                            Text("Provide a wi-fi")
//                        }
//                        .onChange(of: provideWifi, { _, newValue in
//                            project.provideWifi = newValue
//                        })
//                        
//                        TextField("Wi-fi SSID", text: $project.wifiSSID).textFieldStyle(RoundedBorderTextFieldStyle()).autocapitalization(.none).disableAutocorrection(true).padding()
//   
//                        SecureField("Wi-fi Password", text: $project.wifiPassword).textFieldStyle(RoundedBorderTextFieldStyle()).autocapitalization(.none).disableAutocorrection(true).padding()
//
//                        Text("Note: You provide wi-fi seperately, this feature enables a QR Code page in camera manager to show to camera users.").font(.caption2)
                    }
                    
                    Section(header: Text("Background Image")) {
                        NavigationLink(destination: {
                            showDetail(forProject: project, type: .backgroundImage)
                        }, label: {
                            showInfo(forProject: project, type: .backgroundImage)
                        })
                    }
                    
                    Section(header: Text("Video - Preroll")) {
                        NavigationLink(destination: {
                            showDetail(forProject: project, type: .preroll)
                        }, label: {
                            showInfo(forProject: project, type: .preroll)
                        })
                    }
                    
                    Section(header: Text("Video - Introduction")) {
                        NavigationLink(destination: {
                            showDetail(forProject: project, type: .intro)
                        }, label: {
                            showInfo(forProject: project, type: .intro)
                        })
                    }
                    
                    Section(header: Text("Video - Stream Paused")) {
                        NavigationLink(destination: {
                            showDetail(forProject: project, type: .interstitial)
                        }, label: {
                            showInfo(forProject: project, type: .interstitial)
                        })
                        Text("This video will loop until the stream resumes.").font(.caption2)
                    }
                    
                    Section(header: Text("Video - Outro")) {
                        NavigationLink(destination: {
                            showDetail(forProject: project, type: .outro)
                        }, label: {
                            showInfo(forProject: project, type: .outro)
                        })
                    }
                }
            }
        }.onAppear() {
            streamName = project.config.name
            urlPath = project.config.url
            selectedResolution = project.streamResolution.rawValue
            selectedFrameRate = project.streamFrameRate.rawValue
            recordStream = project.recordStream
            provideWifi = project.provideWifi
            rearCameraLens = project.rearCameraLens.rawValue
            bandwidthLimit = project.maxBandwidth
       
        }.navigationBarItems(leading: newProject ? Button("Cancel") {
            dismiss()
        } : nil,
                             trailing:
                                HStack {
            Button("Use") {
                Task {
                    project.maxBandwidth = bandwidthLimit
                    project.rearCameraLens = StreamRearCameraLens(rawValue: rearCameraLens) ?? .wide
                    await _ = ProjectService.shared.save(project: project)
                    DispatchQueue.main.async {
                        SettingsService.shared.settings.currentProjectId = project.id
                        SettingsService.shared.save()
                        NotificationCenter.default.post(name: NSNotification.Name.projectListChanged, object: nil)
                        dismiss()
                    }
                }
            }
        }
        ).navigationTitle(newProject ? "Add Project" : "Edit Project").navigationBarTitleDisplayMode(.inline)
    }
    
    func showInfo(forProject: StreamProjectModel, type: StreamProjectMediaType) -> Text {
        switch(type) {
        case .backgroundImage:
            if let i = forProject.mediaBackgroundImage {
                return Text("\(i.name == "" ? i.url.lastPathComponent : i.name)")
            }
        case .interstitial:
            if let i = forProject.mediaInterstitial {
                return Text("\(i.name == "" ? i.url.lastPathComponent : i.name)")
            }
        case .intro:
            if let i = forProject.mediaIntro {
                return Text("\(i.name == "" ? i.url.lastPathComponent : i.name)")
            }
        case .outro:
            if let i = forProject.mediaOutro {
                return Text("\(i.name == "" ? i.url.lastPathComponent : i.name)")
            }
        case .preroll:
            if let i = forProject.mediaPreroll {
                return Text("\(i.name == "" ? i.url.lastPathComponent : i.name)")
            }
        }
        
        return Text("Tap to select media").foregroundStyle(.placeholder)
    }
    
    func showAudioConfigInfo(forProject: StreamProjectModel) -> Text {
        return Text("Configure")
    }
    
    func showAudioConfig(forProject:StreamProjectModel) -> ProjectAudioConfigView {
        return ProjectAudioConfigView(project: forProject)
    }
    
    func showDetail(forProject:StreamProjectModel, type:StreamProjectMediaType) -> ProjectSelectMediaView {
        return ProjectSelectMediaView(project: forProject, mediaType: type)
    }
}
