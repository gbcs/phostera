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
            Image(systemName: imageName).resizable().aspectRatio(contentMode: .fit).frame(width: 45, height: 45, alignment: .leading).foregroundColor(.primary)
            if imageName.compare("gear") != .orderedSame { //Skip the info button on the system settings without adding another property
                NavigationLink {
                    ZStack {
                        VStack {
                            Spacer()
                            Text("\(detailText)")
                                .font(.system(size: 24))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.75)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                } label: {
                    Image(systemName:"info.circle").resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30, alignment: .trailing)
                }
            }
            
            Text(imageTitle).frame(width: 180, height: 45, alignment: .leading).padding(.horizontal).foregroundColor(.primary)
            
            Image(systemName: statusImage).resizable().aspectRatio(contentMode: .fit).frame(width: 45, height: 45, alignment: .trailing).foregroundColor(statusColor)
        }
    }
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
Images and video from the camera may be displayed locally, streamed to a remote server, saved locally and to external storage.
"""
    
    let microphoneDetailText =
"""
Live and recorded audio may be displayed locally, streamed to a remote server, saved locally and to external storage.
"""
    let networkDetailText =
"""
The local network is used to communicate with Phostera Cameras.
"""
    
    let sysSettingskDetailText =
"""
The main system settings up, opened up to the page for this app (Phostera Streamer.)
"""
    var body: some View {
        ZStack {
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
                                Camera.requestPermission()
                            }
                        }
                        if audioDenied {
                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "xmark.square.fill", statusColor: .red, detailText: microphoneDetailText)
                        } else if (audioPermission) {
                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "checkmark.square", statusColor: .green, detailText: microphoneDetailText)
                        } else {
                            PermissionsItemView(imageName: "mic", imageTitle: "Microphone", statusImage: "questionmark.app", statusColor: .blue, detailText: microphoneDetailText).onTapGesture {
                                AudioPermissions.requestPermission()
                            }
                        }
                    } header: {
                        Text("Required").bold().foregroundStyle(.primary)
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                                    animateNetwork = false
                                })
                                Task {
                                    await NetworkHandler.shared.finder(beUp: true)
                                }
                            }
                        }
                    } header: {
                        Text("Recommended").bold().foregroundStyle(.primary)
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
                    
                }
                .onReceive(timer) { _ in
                    if progress < 1 {
                        progress += 0.1
                    } else {
                        timer.upstream.connect().cancel()
                    }
                }.onReceive(NotificationCenter.default.publisher(for: .cameraAccessChanged), perform: { _ in
                    cameraPermission = Camera.hasPermission()
                    cameraDenied = Camera.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .audioAccessChanged), perform: { _ in
                    audioPermission = AudioPermissions.hasPermission()
                    audioDenied = AudioPermissions.hasPermissionDenied()
                }).onReceive(NotificationCenter.default.publisher(for: .networkAccessChanged), perform: { _ in
                    SettingsService.shared.settings.allowNetworking = true
                    SettingsService.shared.save()
                    networkingAllowed = SettingsService.shared.settings.allowNetworking
                }).onAppear() {
                    cameraPermission = Camera.hasPermission()
                    audioPermission = AudioPermissions.hasPermission()
                    cameraDenied = Camera.hasPermissionDenied()
                    audioDenied = AudioPermissions.hasPermissionDenied()
                    networkingAllowed = SettingsService.shared.settings.allowNetworking
                }
                Spacer()
                
                if (!Camera.hasPermission()) || (!AudioPermissions.hasPermission()) {
                    Section {
                        Text("Grant access").bold().padding().foregroundColor(.primary)
                    } header: {
                        Text("To Continue").bold().foregroundColor(.primary)
                    }
                } else {
                    
                    Button {
                        DispatchQueue.main.async {
                            SettingsService.shared.settings.needsOnboarding = false
                            SettingsService.shared.save()
                            NotificationCenter.default.post(name: Notification.Name.Onboarding.complete, object: nil)
                        }
                    } label: {
                        Text("Continue")
                    }.buttonStyle(.borderedProminent).foregroundColor(.white).tint(.blue)
                    Spacer(minLength: 40)
                }
                
                Spacer()
            }
        }.navigationBarHidden(!$path.isEmpty) //Empty path comes from options. Non-empty from onboarding
    }
}
