//
//  PermissionsView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/6/23.
//

import SwiftUI
import Network
import Combine

extension NSNotification.Name {
    static let cameraAccessChanged = Notification.Name("cameraAccessChanged")
    static let audioAccessChanged = Notification.Name("audioAccessChanged")
    static let libraryAccessChanged = Notification.Name("libraryAccessChanged")
    static let locationAccessChanged = Notification.Name("locationAccessChanged")
    static let networkAccessChanged = Notification.Name("networkAccessChanged")
}

struct PermissionsPageView: View {
    @State var audioPermission:Bool = false
    @State var cameraPermission:Bool = false
    @State var locationPermission:Bool = false
    @State var libraryPermission:Bool = false
    @State var audioDenied:Bool = false
    @State var cameraDenied:Bool = false
    @State var locationDenied:Bool = false
    @State var libraryDenied:Bool = false
    @State var networkingAllowed:Bool = false
    @State private var progress: Double = 0
    @Binding var path: [OnboardingRoute]
    @Environment(\.dismiss) private var dismiss
    
    @State var animateNetwork:Bool = false
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    let cameraDetailText =
"""
The camera is used to record video and can be sent to remote Phostera Director and Phostera Streamers that you allow to connect.
"""
    
    let microphoneDetailText =
"""
The microphone is used to record audio and can be sent to remote Phostera Director and Phostera Streamers that you allow to connect.
"""
    let networkDetailText =
"""
The local network is used to communicate with Phostera Director and Phostera Streamer.
"""
    
    let sysSettingskDetailText =
"""
The main system settings up, opened up to the page for this app (Phostera Camera.)
"""
    
    let locationDetailText =
"""
Location data, if enabled, will be recorded in video.
"""
// and photographs
    
    var body: some View {
        ZStack {
            //backgroundGradient.ignoresSafeArea()
            VStack() {
                Spacer()
                Text("Operating Permisisons").font(.title)
                ScrollView([.vertical], showsIndicators: true) {
                    Section {
                        if cameraDenied {
                            PermissionsItemView(imageName: "camera", imageTitle: "Camera", statusImage: "xmark.square.fill", statusColor: .red, detailText: cameraDetailText)
                        } else if (cameraPermission) {
                            PermissionsItemView(imageName: "camera", imageTitle: "Camera", statusImage: "checkmark.square", statusColor: .green, detailText: cameraDetailText)
                        } else {
                            PermissionsItemView(imageName: "camera", imageTitle: "Camera", statusImage: "questionmark.app", statusColor: .blue, detailText: cameraDetailText).onTapGesture {
                                CamTool.shared.requestPermission()
                            }
                        }
                        if audioDenied {
                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "xmark.square.fill", statusColor: .red, detailText: microphoneDetailText)
                        } else if (audioPermission) {
                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "checkmark.square", statusColor: .green, detailText: microphoneDetailText)
                        } else {
                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "questionmark.app", statusColor: .blue, detailText: microphoneDetailText).onTapGesture {
                                AudioController.requestPermission()
                            }
                        }
                    } header: {
                        Text("Required").bold()
                    }
                    
                    Section {
                        if networkingAllowed {
                            PermissionsItemView(imageName: "network", imageTitle: "Local Networking", statusImage: "gear", statusColor: .primary, detailText: networkDetailText)
                        } else {
                            if animateNetwork {
                                ProgressView("Starting...", value: progress, total: 2).progressViewStyle(.circular)
                            }
                            let color:Color = SettingsService.shared.settings.needsOnboarding ? .blue : .primary
                            PermissionsItemView(imageName: "network", imageTitle: "Local Networking", statusImage: "questionmark.app", statusColor: color, detailText: networkDetailText).onTapGesture {
                                animateNetwork = true
                                progress = 0
                                ServerKeys.startServer()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                                    animateNetwork = false
                                })
                            }
                        }
                        
                        if locationDenied {
                            PermissionsItemView(imageName: "location", imageTitle: "Location", statusImage: "xmark.square.fill", statusColor: .red, detailText: locationDetailText)
                        } else if (locationPermission) {
                            PermissionsItemView(imageName: "location", imageTitle: "Location", statusImage: "checkmark.square", statusColor: .green, detailText: locationDetailText)
                        } else {
                            PermissionsItemView(imageName: "location", imageTitle: "Location", statusImage: "questionmark.app", statusColor: .blue, detailText: locationDetailText).onTapGesture {
                                LocationController.shared.requestPermission()
                            }
                        }
                    } header: {
                        Text("Optional").bold()
                    }
                    
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
                    cameraPermission = CamTool.shared.hasPermission()
                    cameraDenied = CamTool.shared.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .locationAccessChanged), perform: { _ in
                    locationPermission = LocationController.shared.hasPermission()
                    locationDenied = LocationController.shared.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .audioAccessChanged), perform: { _ in
                    audioPermission = AudioController.hasPermission()
                    audioDenied = AudioController.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .libraryAccessChanged), perform: { _ in
                    libraryPermission = LibraryController.hasPermission()
                    libraryDenied = LibraryController.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .networkAccessChanged), perform: { _ in
                    networkingAllowed = SettingsService.shared.settings.allowNetworking
                }).onAppear() {
                    cameraPermission = CamTool.shared.hasPermission()
                    locationPermission = LocationController.shared.hasPermission()
                    audioPermission = AudioController.hasPermission()
                    libraryPermission = LibraryController.hasPermission()
                    libraryDenied = LibraryController.hasPermissionDenied()
                    cameraDenied = CamTool.shared.hasPermissionDenied()
                    locationDenied = LocationController.shared.hasPermissionDenied()
                    audioDenied = AudioController.hasPermissionDenied()
                    networkingAllowed = SettingsService.shared.settings.allowNetworking
                }
                Spacer()
                if !CamTool.shared.hasPermission() {
                    Section {
                        Text("Grant camera access").bold().padding()
                    } header: {
                        Text("To Continue").bold()
                    }
                } else {
                    if SettingsService.shared.settings.needsOnboarding {
                        NavigationLink("Continue", value: OnboardingRoute.about).padding()
                            .background(.blue)
                            .foregroundColor(.primary)
                            .font(.headline)
                            .cornerRadius(10)
                    } else {
                        if !$path.isEmpty { //Empty path comes from options. Non-empty from onboarding
                            Button {
                                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.Onboarding.complete, object: nil) }
                            } label: {
                                Text("Continue")
                            }
                        }
                    }
                }
                Spacer()
            }
        }.navigationBarHidden(!$path.isEmpty) //Empty path comes from options. Non-empty from onboarding
    }
}
