//
//  PermissionsView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/6/23.
//

import SwiftUI
import Network
import Combine

struct PermissionsItemView: View {
    var imageName:String
    var imageTitle:String
    var statusImage:String
    var statusColor:Color
    var detailText:String
    var body: some View {
        HStack {
            Image(systemName: imageName).resizable().aspectRatio(contentMode: .fit).frame(width: 45, height: 45, alignment: .leading)
            if imageName.compare("gear") != .orderedSame { //Skip the info button on the system settings without adding another property
                NavigationLink {
                    ZStack {
                        VStack {
                            Spacer()
                            Text("\(detailText)")
                                .font(.system(size: 24))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.75)
                              
                            Spacer()
                        }
                    }
                } label: {
                    Image(systemName:"info.circle").resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30, alignment: .trailing)
                }
            }
            
            Text(imageTitle).frame(width: 180, height: 45, alignment: .leading).padding(.horizontal)
            
            Image(systemName: statusImage).resizable().aspectRatio(contentMode: .fit).frame(width: 45, height: 45, alignment: .trailing).foregroundColor(statusColor)
        }
    }
}

extension NSNotification.Name {
    static let cameraAccessChanged = Notification.Name("cameraAccessChanged")
    static let audioAccessChanged = Notification.Name("audioAccessChanged")
    static let networkAccessChanged = Notification.Name("networkAccessChanged")
}

struct PermissionsPageView: View {
    @State var audioPermission:Bool = false
    @State var cameraPermission:Bool = false
    @State var locationPermission:Bool = false
    @State var audioDenied:Bool = false
    @State var cameraDenied:Bool = false
    @State var networkingAllowed:Bool = false
    @State private var progress: Double = 0
    @Binding var path: [OnboardingRoute]
    @Environment(\.dismiss) private var dismiss
    
    @State var animateNetwork:Bool = false
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    let cameraDetailText =
"""
The camera is used to show light levels.
"""
    
    let microphoneDetailText =
"""
Audio from the microphone is used to show audio levels.
"""
    let networkDetailText =
"""
The local network is used to communicate with Phostera Cameras.
"""
    
    let sysSettingskDetailText =
"""
The main system settings up, opened up to the page for this app (Phostera Director.)
"""
        
    var body: some View {
        ZStack {
            //backgroundGradient.ignoresSafeArea()
            VStack() {
                Spacer()
                Text("Operating Permisisons").font(.title)
                ScrollView([.vertical], showsIndicators: true) {
                    Section {
                        if networkingAllowed {
                            PermissionsItemView(imageName: "network", imageTitle: "Local Networking", statusImage: "gear", statusColor: .green, detailText: networkDetailText)
                        } else {
                            if animateNetwork {
                                ProgressView("Starting...", value: progress, total: 2).progressViewStyle(.circular)
                            }
                            let color:Color = SettingsService.shared.settings.needsOnboarding ? .blue : .primary
                            PermissionsItemView(imageName: "network", imageTitle: "Local Networking", statusImage: "questionmark.app", statusColor: color, detailText: networkDetailText).onTapGesture {
                                animateNetwork = true
                                progress = 0
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                                    animateNetwork = false
                                })
                                Task {
                                    await NetworkHandler.shared.finder(beUp: true)
                                }
                            }
                        }
                      
                    } header: {
                        Text("Required").bold()
                    }
                 
//                    Section {
//                        
//                        if cameraDenied {
//                            PermissionsItemView(imageName: "camera", imageTitle: "Camera", statusImage: "xmark.square.fill", statusColor: .red, detailText: cameraDetailText)
//                        } else if (cameraPermission) {
//                            PermissionsItemView(imageName: "camera", imageTitle: "Camera", statusImage: "checkmark.square", statusColor: .green, detailText: cameraDetailText)
//                        } else {
//                            PermissionsItemView(imageName: "camera", imageTitle: "Camera", statusImage: "questionmark.app", statusColor: .blue, detailText: cameraDetailText).onTapGesture {
//                                CameraController.requestPermission()
//                            }
//                        }
//                        
//                        if audioDenied {
//                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "xmark.square.fill", statusColor: .red, detailText: microphoneDetailText)
//                        } else if (audioPermission) {
//                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "checkmark.square", statusColor: .green, detailText: microphoneDetailText)
//                        } else {
//                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "questionmark.app", statusColor: .blue, detailText: microphoneDetailText).onTapGesture {
//                                AudioController.requestPermission()
//                            }
//                        }
//                    } header: {
//                        Text("Optional").bold()
//                    }
                    
                    Section {
                        Text("Tap a line to grant or deny access. The System Settings App can be used to restore denied permissions.").padding(.bottom).padding(.top)
                    } header: {
                        Text("Note").bold()
                    }
                    
                    Section {
                        PermissionsItemView(imageName: "gear", imageTitle: "Open Settings App", statusImage: "", statusColor: .primary, detailText: sysSettingskDetailText).onTapGesture {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } header: {
                        Text("System Settings").bold()
                    }
                   
                }.onReceive(timer) { _ in
                    if progress < 1 {
                        progress += 0.1
                    } else {
                        timer.upstream.connect().cancel()
                    }
                }.onReceive(NotificationCenter.default.publisher(for: .cameraAccessChanged), perform: { _ in
                    cameraPermission = CameraController.hasPermission()
                    cameraDenied = CameraController.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .audioAccessChanged), perform: { _ in
                    audioPermission = AudioController.hasPermission()
                    audioDenied = AudioController.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .networkAccessChanged), perform: { _ in
                    SettingsService.shared.settings.allowNetworking = true
                    SettingsService.shared.save()
                    networkingAllowed = SettingsService.shared.settings.allowNetworking
                }).onAppear() {
                    cameraPermission = CameraController.hasPermission()
                    audioPermission = AudioController.hasPermission()
                    cameraDenied = CameraController.hasPermissionDenied()
                    audioDenied = AudioController.hasPermissionDenied()
                    networkingAllowed = SettingsService.shared.settings.allowNetworking
                }
                Spacer()
                
                if !SettingsService.shared.settings.allowNetworking {
                    Section {
                        Text("Grant network access").bold().padding()
                    } header: {
                        Text("To Continue").bold()
                    }
                } else {
                    Button {
                        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.Camera.onboardingComplete, object: nil) }
                    } label: {
                        Text("Continue")
                    }.buttonStyle(.borderedProminent)
                }
    
                Spacer()
            }
        }.navigationBarHidden(!$path.isEmpty) //Empty path comes from options. Non-empty from onboarding
    }
}
