//
//  ModeDetailview.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/20/23.
//

import Foundation
import SwiftUI
import PhosteraShared
import AVFoundation

struct ModeDetailPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathSettings: [SettingsRoute]
    @Binding var mode:DirectorProjectCameraMode

    @State var resolution:DirectorProjectResolution = .v1920x1080
    @State var colorspace:DirectorProjectColorspace = .rec709
    @State var codec:DirectorProjectProresCodec = .proRes422HQ
    @State var framerate:DirectorProjectFrameRate = .fr24
    @State var recordToDisk:Bool = false
    @State var fileNamingScheme:DirectorProjectFileNamingScheme = .scheme1
    @State var update:Bool = false
    @State var useProresLogIfAvailable:Bool = false
    @State var locationInformation:Bool = false
    
    var externalStorageSupported:Bool = true

    var body: some View {
        ZStack {
            //backgroundGradient.ignoresSafeArea()
            VStack() {
                List() {
                    Section("Options") {
                        Picker("Resolution", selection: $resolution) {
                            ForEach(DirectorProjectResolution.allCases, id: \.self) { res in
                                switch(res) {
                                case .v3840x2160:
                                    Text("3840x2160").tag(res.rawValue)
                                case .v1920x1080:
                                    Text("1920x1080").tag(res.rawValue)
//                                case .v1280x720:
//                                    Text("1280x720").tag(res.rawValue)
                                }
                            }
                        }.onChange(of: resolution, { _, newValue in
                            mode.settings.resolution = newValue
                        }).disabled((mode.projectUUID != "") || mode.frontCamera)
                        
                        Picker("Framerate", selection: $framerate) {
                            ForEach(DirectorProjectFrameRate.allCases, id: \.self) { rate in
                                switch(rate) {
                                case .fr24:
                                    Text("24 fps").tag(rate.rawValue)
                                case .fr25:
                                    Text("25 fps").tag(rate.rawValue)
                                case .fr30:
                                    Text("30 fps").tag(rate.rawValue)
                                    //                                case .fr48:
                                    //                                    Text("48 fps").tag(rate.rawValue)
                                    //                                case .fr50:
                                    //                                    Text("50 fps").tag(rate.rawValue)
                                    //                                case .fr60:
                                    //                                    Text("60 fps").tag(rate.rawValue)
                                }
                            }
                        }.onChange(of: framerate, { _, newValue in
                            mode.settings.frameRate =  newValue
                        }).disabled(mode.projectUUID != "")
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
         
//                        Toggle(isOn: $locationInformation ) {
//                            Text("Include location information")
//                        }
                    }
                    
                    Section(header: Text("Footage")) {
                        Toggle(isOn: $recordToDisk) {
                            Text("Record directly to external storage")
                        }
                    }
                }
            }
        }.navigationTitle("Mode Detail").navigationBarHidden(false)
            .onAppear() {
                resolution = mode.settings.resolution
                colorspace = mode.settings.colorspace
                useProresLogIfAvailable = mode.settings.colorspace == .appleLog
                codec = mode.settings.codec
                framerate = mode.settings.frameRate
                recordToDisk = mode.settings.recordToDisk
                fileNamingScheme = mode.settings.fileNamingScheme
                Logger.shared.info("In: \(mode.uuid) \(resolution) \(colorspace) \(codec) \(framerate) \(recordToDisk) \(fileNamingScheme)")
                update.toggle()
                
            }
            .navigationBarItems(
                trailing:
                    Button("Use") {
                        SettingsService.shared.settings.currentModeId = mode.uuid
                        SettingsService.shared.save()
                        mode.settings.resolution = resolution
                        mode.settings.colorspace = useProresLogIfAvailable ? .appleLog : .rec709
                        mode.settings.codec = codec
                        mode.settings.frameRate = framerate
                        mode.settings.recordToDisk = recordToDisk
                        mode.settings.fileNamingScheme = fileNamingScheme
                        ModeHandler.shared.updateDefaultMode(mode: mode)
       
                   //     Logger.shared.info("Out:\(mode.uuid) \(mode.settings.resolution) \(mode.settings.colorspace) \(mode.settings.codec) \(mode.settings.frameRate) \(mode.settings.fileStorageLocation) \(fileNamingScheme)")
                        
                        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.handleNewMode, object: nil) }
                    })
    }
}

