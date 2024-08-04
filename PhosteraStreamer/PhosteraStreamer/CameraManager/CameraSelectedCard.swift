//
//  CameraSelectedCard.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/9/23.
//

import Foundation
import SwiftUI
import PhosteraShared
import Combine

//16x9 image preview
//button to add/remove from stream
//Online/offline X
//Name


struct CameraSelectedCard: View {
    var camera:CameraModel
    @State var online:Bool = false
    @State var updateView:Bool = false
    var frameSize:CGSize = CGSizeMake(220, 220 / (16/9))
    @State var screenshot:Data?
    @State var screenshotSub:AnyCancellable?
    
    @State var audioSelected:Bool = false
    
    func subscribeToScreenshots() {
        screenshotSub = PubCentral.shared.pubScreenshotReceived.receive(on: DispatchQueue.main).sink { notification in
            if let userInfo = notification.userInfo {
                if let uuid = userInfo["uuid"] as? String {
                    if uuid == camera.uuid {
                        screenshot = userInfo["data"] as? Data
                        updateView.toggle()
                    }
                }
            }
        }
    }
 
    var body: some View {
        if updateView || !updateView {
            VStack {
                if let screenshot, let i = UIImage(data: screenshot) {
                     Image(uiImage: i).resizable().aspectRatio(contentMode: .fit)
                } else {
                    ZStack {
                        Color.blue
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Offline").font(.system(size: 24))
                                Spacer()
                            }
                            Spacer()
                        }
                    }.frame(width: frameSize.width, height: frameSize.height)
                }
            }.frame(width: frameSize.width, height: frameSize.height)
                .onReceive(PubCentral.shared.onlineUpdated) { (output) in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                        online = CameraManager.shared.isUUIDOnline(uuid: camera.uuid)
                        if !online {
                            screenshot = nil
                        } else {
                            subscribeToScreenshots()
                        }
                        updateView.toggle()
                    })
                }.onAppear() {
                    online = CameraManager.shared.isUUIDOnline(uuid: camera.uuid)
                    subscribeToScreenshots()
                    updateView.toggle()
                    if online {
                        CameraManager.shared.requestScreenshot(uuid: camera.uuid)
                    }
                }.overlay {
                    VStack {
                        HStack {
                            Text(camera.name == "" ? camera.uuid : camera.name)
                            Spacer()
                            Text(camera.model)
                        }
                        Spacer()
                        HStack {
                            let x = WatchEntryManager.shared.remoteCameraIndex(uuid: camera.uuid)
                            Image(systemName: x == -1 ? "play.square" : "\(x + 1).square").resizable().frame(width: 30, height: 30).foregroundColor(.red).onTapGesture(perform: {
                                let x = WatchEntryManager.shared.remoteCameraIndex(uuid: camera.uuid)
                                if x > -1 {
                                    WatchEntryManager.shared.remoteCameras[x] = ""
                                    WatchEntryManager.shared.remoteCamerasEnabled[x] = false
                                } else {
                                    let y = WatchEntryManager.shared.freeRemoteCameraIndex()
                                    if y > -1 {
                                        WatchEntryManager.shared.remoteCameras[y] = camera.uuid
                                        WatchEntryManager.shared.remoteCamerasEnabled[y] = false
                                    }
                                }
                                updateView.toggle()
                            })
                            Spacer()
                            NavigationLink {
                                TakeProjectList(camera: camera)
                            } label: {
                                Image(systemName: "list.and.film").resizable().frame(width: 30, height: 30).foregroundColor(.red)
                            }

                            Spacer()
                            Image(systemName: audioSelected ? "waveform.circle.fill" : "waveform.circle")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.accent.opacity(0.2))
                                .onTapGesture(perform: {
                                    //audioSelected.toggle()
                                    CameraManager.shared.setWantsAudio(uuid: camera.uuid, audio: audioSelected)
                            }).disabled(true)
                        }.padding(EdgeInsets(top: 0, leading: 10, bottom: 5, trailing: 10))
                    }
                }
        }
    }
}
