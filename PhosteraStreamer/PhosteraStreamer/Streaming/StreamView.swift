//
//  StreamView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/13/23.
//

import SwiftUI
import MetalKit
import AVFoundation
import PhosteraShared
import UIKit
import HaishinKit
import Combine

class ScrubberViewModel: ObservableObject {
    @Published var currentTime: CMTime = .zero
    @Published var thumbnail: UIImage = UIImage()
    
    var cancellables:[AnyCancellable] = []
    
    init() {
        $currentTime
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { time in
                if let image = MetalTool.shared.mediaPlayer.generateThumbnail(time:time) {
                    self.thumbnail = image
                }
            }
            .store(in: &cancellables)
    }
}

struct StreamManagerView: View {
    let columns = [  GridItem(.adaptive(minimum: 140)) ]
    @State var showMetal:Bool = false
    @State var viewUpdateTime: Bool = false
    @State var goLiveStatus:StreamGoLiveStatus = .disabled
    @State var userCameraSelection:StreamUserCameraSelection = .off
    @State var subjectCameraSelection:StreamSubjectCameraSelection = .off
    @State var currentProject:StreamProjectModel?
    @State var streamPaused:Bool = true
    @State private var mediaFailed = false
    @State var firstConnectionMediaPlayed:Bool = false
    @StateObject var scrubber:ScrubberViewModel = ScrubberViewModel()
    @State var thumbnail:UIImage? = nil
    @State var isUserUpdatingSlider: Bool = false
    @State var selectedMicrophone:StreamMicrophoneSelection = .none
    @State var showCompositionView:Bool = false
    @State var landscapeMode:Bool = false
    @State private var volumeSlider: Double = 1.0
    @State private var showVolumeSlider:Bool = false
    @State private var bitrateSliderValue:Double = 64000
    @State private var maxBitrate:Double = 1024000
    
    @State var volumeList:[String:Float] =  ["media" : 1.0,
                                             "remote" : 1.0,
                                             "host" : 1.0,
                                             "subject" : 1.0,
                                             "interview" : 1.0]
    
    @State var streamStateControlsDisabled:Bool = false
    @State var streamGaugeSliderEnabled:Bool = false
    @State var allowedAlert:Bool = false
    
    func updateMaxBitrate() {
        if let currentProject {
            maxBitrate = currentProject.maxBandwidth
        }
    }
    
    func disableStreamStateControlsForATime() {
        streamStateControlsDisabled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            streamStateControlsDisabled = false
        })
    }
   
    private var displayView:PreviewMetalView?
    
    func updateDisplayForLandscapePortrait() {
        if let displayView = MetalTool.shared.getDisplayView() {
            displayView.alpha = landscapeMode ? 1.0 : 0.0
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if viewUpdateTime || !viewUpdateTime {
                    if showMetal {
                        HStack {
                            Spacer(minLength: landscapeMode ? 60 : 0)
                            if let _ = MetalTool.shared.getDisplayView() {
                                PreviewViewRep()
                            }
                            Spacer(minLength: landscapeMode ? 60 : 0)
                        }
                    }
                }
            }
        }.onReceive(PubCentral.shared.orientationChanged) { (output) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                landscapeMode = MetalTool.shared.currentInterfaceOrientation.isLandscape
                updateDisplayForLandscapePortrait()
                viewUpdateTime.toggle()
            })
            
        }
        .overlay(content: {
            if viewUpdateTime || !viewUpdateTime {
                if showCompositionView {
                    ZStack {
                        Color.blue.opacity(0.2)
                        StreamCompositionView()
                    }
                } else if !landscapeMode {
                    ZStack {
                        ContentUnavailableView("", systemImage: "rectangle.portrait.rotate")
                    }
                } else if showMetal && landscapeMode {
                    ZStack {
                        Color.white.opacity(0.0001).onTapGesture(perform: {
                            _ = MetalTool.shared.mediaPlayer.togglePaused()
                            thumbnail = nil
                        })
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            if windowScene.interfaceOrientation.isLandscape {
                                HStack {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Image(systemName: "plusminus.circle")
                                                .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                                ).foregroundStyle(Color.accentColor).onTapGesture(perform: {
                                                    if !showVolumeSlider {
                                                        switch selectedMicrophone {
                                                        case .none:
                                                            volumeSlider = Double(volumeList["media"] ?? 1.0)
                                                        case .host:
                                                            volumeSlider = Double(volumeList["host"] ?? 1.0)
                                                        case .subject:
                                                            volumeSlider = Double(volumeList["subject"] ?? 1.0)
                                                        case .interview:
                                                            volumeSlider = Double(volumeList["interview"] ?? 1.0)
                                                        }
                                                    }
                                                   showVolumeSlider.toggle()
                                                })
                                            if showVolumeSlider {
                                                Slider(value: $volumeSlider, in: 0...1).frame(width: 200)
                                                Spacer()
                                            }
                                        }
                                        Spacer(minLength: 20)
                                        HStack {
                                            Image(systemName: selectedMicrophone == .host ? "mic.circle.fill" : "mic.circle")
                                                .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                                ).foregroundStyle(Color.accentColor).onTapGesture(perform: {
                                                    select(microphone: selectedMicrophone == .host ? .none : .host)
                                                    if selectedMicrophone == .host {
                                                        AudioTool.shared.adjustInputVolume(level: volumeList["host"] ?? 1.0)
                                                    } else if selectedMicrophone == .none {
                                                        AudioTool.shared.adjustInputVolume(level: 0.0)
                                                    }
                                                })
                                            if showVolumeSlider { Spacer(minLength: 200) }
                                        }
                                        Spacer(minLength: 20)
                                        
                                        HStack {
                                            Image(systemName: selectedMicrophone == .subject ? "mic.square.fill" : "mic.square")
                                                .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                                ).disabled(currentProject?.audioConfiguration.subjectMicrophone == "").foregroundStyle( currentProject?.audioConfiguration.subjectMicrophone != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                    select(microphone: selectedMicrophone == .subject ? .none : .subject)
                                                    if selectedMicrophone == .subject {
                                                        AudioTool.shared.adjustInputVolume(level: volumeList["host"] ?? 1.0)
                                                    } else if selectedMicrophone == .none {
                                                        AudioTool.shared.adjustInputVolume(level: 0.0)
                                                    }
                                                })
                                            if showVolumeSlider { Spacer(minLength: 200) }
                                        }
                                        Spacer(minLength: 20)
                                        
                                        HStack {
                                            Image(systemName: selectedMicrophone == .interview ? "music.mic.circle.fill" : "music.mic.circle")
                                                .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                                ).disabled(currentProject?.audioConfiguration.interviewMicrophone == "").foregroundStyle( currentProject?.audioConfiguration.interviewMicrophone != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                    select(microphone: selectedMicrophone == .interview ? .none : .interview)
                                                    if selectedMicrophone == .interview {
                                                        AudioTool.shared.adjustInputVolume(level: volumeList["host"] ?? 1.0)
                                                    } else if selectedMicrophone == .none {
                                                        AudioTool.shared.adjustInputVolume(level: 0.0)
                                                    }
                                                })
                                            if showVolumeSlider { Spacer(minLength: 200) }
                                        }
                                    }
                                    Spacer()
                                }.padding(EdgeInsets(top: 0, leading: 10, bottom: UIDevice.current.userInterfaceIdiom == .pad ? 80 : 0, trailing: 0))
                         
                            } else {
                                VStack {
                                    Text("")
                                    HStack(alignment: .top, spacing: 20, content: {
                                        Spacer()
                                        Image(systemName: selectedMicrophone == .host ? "mic.circle.fill" : "mic.circle")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(currentProject?.audioConfiguration.hostMicrophone == "").foregroundStyle( currentProject?.audioConfiguration.hostMicrophone != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                select(microphone: selectedMicrophone == .host ? .none : .host)
                                            })
                                        Spacer(minLength: 20)
                                        
                                        Image(systemName: selectedMicrophone == .subject ? "mic.square.fill" : "mic.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(currentProject?.audioConfiguration.subjectMicrophone == "").foregroundStyle( currentProject?.audioConfiguration.subjectMicrophone != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                select(microphone: selectedMicrophone == .subject ? .none : .subject)
                                            })
                                        Spacer(minLength: 20)
                                        
                                        Image(systemName: selectedMicrophone == .interview ? "music.mic.circle.fill" : "music.mic.circle")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(currentProject?.audioConfiguration.interviewMicrophone == "").foregroundStyle( currentProject?.audioConfiguration.interviewMicrophone != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                select(microphone: selectedMicrophone == .interview ? .none : .interview)
                                            })
                                        Spacer()
                                    })
                                    Spacer()
                                }
                            }
                            
                            let mediaCount = WatchEntryManager.shared.mediaQueue.count
                            let mediaQueued = mediaCount > 0
                            let cam1 = WatchEntryManager.shared.remoteCameras[0]
                            let cam2 = WatchEntryManager.shared.remoteCameras[1]
                            let cam3 = WatchEntryManager.shared.remoteCameras[2]
                            let cam4 = WatchEntryManager.shared.remoteCameras[3]
                            let cam1On = WatchEntryManager.shared.remoteCamerasEnabled[0]
                            let cam2On = WatchEntryManager.shared.remoteCamerasEnabled[1]
                            let cam3On = WatchEntryManager.shared.remoteCamerasEnabled[2]
                            let cam4On = WatchEntryManager.shared.remoteCamerasEnabled[3]
                            let mediaShown = MetalTool.shared.mediaShown
                            
                            if (MetalTool.shared.currentInterfaceOrientation == UIInterfaceOrientation.landscapeLeft) ||
                                (MetalTool.shared.currentInterfaceOrientation == UIInterfaceOrientation.landscapeRight) {
                                HStack {
                                    Spacer()
                                    VStack(alignment: .center, spacing: 20, content: {
                                        Image(systemName: mediaShown ? "play.square.stack.fill" : "play.square.stack")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(mediaQueued).foregroundStyle( mediaQueued ? Color.red : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                MetalTool.shared.mediaShown.toggle()
                                                viewUpdateTime.toggle()
                                            })
                                        //                                            .onLongPressGesture(perform: {
                                        //                                                if (WatchEntryManager.shared.mediaQueue.count) > 0 {
                                        //                                                    MetalTool.shared.mediaPlayer.complete()
                                        //                                                }
                                        //                                            })
                                        
                                        Image(systemName: cam1On ? "1.square.fill" : "1.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam1 != "").foregroundStyle(cam1 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 0)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[0] = false
                                                WatchEntryManager.shared.remoteCameras[0] = ""
                                                viewUpdateTime.toggle()
                                            })
                                        
                                        Image(systemName: cam2On ? "2.square.fill" : "2.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam2 != "").foregroundStyle(cam2 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 1)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[1] = false
                                                WatchEntryManager.shared.remoteCameras[1] = ""
                                                viewUpdateTime.toggle()
                                            })
                                        
                                        Image(systemName: cam3On ? "3.square.fill" : "3.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam3 != "").foregroundStyle(cam3 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 2)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[2] = false
                                                WatchEntryManager.shared.remoteCameras[2] = ""
                                                viewUpdateTime.toggle()
                                            })
                                        
                                        Image(systemName: cam4On ? "4.square.fill" : "4.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam4 != "").foregroundStyle(cam4 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 3)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[3] = false
                                                WatchEntryManager.shared.remoteCameras[3] = ""
                                                viewUpdateTime.toggle()
                                            })
                                    })
                                }.padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 10))
                            } else {
                                VStack {
                                    Spacer()
                                    HStack(alignment: .top, spacing: 20, content: {
                                        
                                        Image(systemName: mediaShown ? "play.square.stack.fill" : "play.square.stack")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(mediaQueued).foregroundStyle( mediaQueued ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                MetalTool.shared.mediaShown.toggle()
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                if (WatchEntryManager.shared.mediaQueue.count) > 0 {
                                                    MetalTool.shared.mediaPlayer.complete()
                                                }
                                            })
                                        
                                        Image(systemName: cam1On ? "1.square.fill" : "1.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam1 != "").foregroundStyle(cam1 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 0)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[0] = false
                                                WatchEntryManager.shared.remoteCameras[0] = ""
                                                viewUpdateTime.toggle()
                                            })
                                        
                                        Image(systemName: cam2On ? "2.square.fill" : "2.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam2 != "").foregroundStyle(cam2 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 1)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[1] = false
                                                WatchEntryManager.shared.remoteCameras[1] = ""
                                                viewUpdateTime.toggle()
                                            })
                                        
                                        Image(systemName: cam3On ? "3.square.fill" : "3.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam3 != "").foregroundStyle(cam3 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 2)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[2] = false
                                                WatchEntryManager.shared.remoteCameras[2] = ""
                                                viewUpdateTime.toggle()
                                            })
                                        
                                        Image(systemName: cam4On ? "4.square.fill" : "4.square")
                                            .resizable().aspectRatio(contentMode: .fit).frame(width: 40, height: 40, alignment: .leading
                                            ).disabled(cam4 != "").foregroundStyle(cam4 != "" ? Color.accentColor : Color(red: 1, green: 0, blue: 0, opacity:0.2)).onTapGesture(perform: {
                                                WatchEntryManager.shared.remoteCameraToggle(index: 3)
                                                viewUpdateTime.toggle()
                                            }).onLongPressGesture(perform: {
                                                WatchEntryManager.shared.remoteCamerasEnabled[3] = false
                                                WatchEntryManager.shared.remoteCameras[3] = ""
                                                viewUpdateTime.toggle()
                                            })
                                    })
                                    Text("")
                                }
                            }
                            
                            VStack {
                                if let thumbnail {
                                    if thumbnail.size.width > 0 {
                                        Image(uiImage: thumbnail)
                                    }
                                }
                                Spacer()
                                let duration = MetalTool.shared.mediaPlayer.mediaDuration()
                                if duration.seconds > 0 {
                                    HStack {
                                        Spacer(minLength: 80)
                                        Slider(
                                            value: Binding(
                                                get: {
                                                    scrubber.currentTime.seconds
                                                },
                                                set: { newValue in
                                                    Logger.shared.info("newValue:\(newValue)")
                                                    if isUserUpdatingSlider {
                                                        if newValue < 1 {
                                                            scrubber.currentTime.value = 1
                                                        } else if Int(newValue) + 2 > duration.value {
                                                            scrubber.currentTime.value = duration.value - 60
                                                        } else {
                                                            scrubber.currentTime = CMTime(seconds: newValue, preferredTimescale: 600)
                                                        }
                                                    }
                                                }
                                            ),
                                            in: 1...duration.seconds-1,
                                            step: 1,
                                            onEditingChanged: { editing in
                                                if !editing {
                                                    isUserUpdatingSlider = editing
                                                    Task(priority: .userInitiated) {
                                                        if scrubber.currentTime.seconds >= 1 {
                                                            MetalTool.shared.mediaPlayer.seek(to: scrubber.currentTime)
                                                            DispatchQueue.main.async {
                                                                thumbnail = nil
                                                            }
                                                        }
                                                    }
                                                }
                                                isUserUpdatingSlider = editing
                                            }
                                        )
                                        Spacer(minLength: 80)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    let allowedOnline = allowOnline()
                    if (!streamStateControlsDisabled) && allowedOnline {
                        goLiveStatus = goLiveButtonStatus()
                        if goLiveStatus != .disabled {
                            disableStreamStateControlsForATime()
                            if MetalTool.shared.mediaShown {
                                MetalTool.shared.mediaShown = false
                            }
                            MediaAudioPlayer.shared.stop()
                            MetalTool.shared.mediaPlayer.stop()
                            
                            WatchEntryManager.shared.mediaQueue.removeAll()
                            MetalTool.shared.stopMediaBuffer()
                            
                            if MetalTool.shared.streamer.streamState == .connection {
                                MetalTool.shared.streamer.publish(beUp: false)
                            } else if MetalTool.shared.streamer.streamState == .offline {
                                firstConnectionMediaPlayed = false
                                MetalTool.shared.mediaShown = true
                                StreamBuffer.shared.clearAll()
                                MetalTool.shared.streamer.publish(beUp: true)
                            } else {
                                guard let currentProject else { return }
                                MetalTool.shared.streamer.handleStateChangeFromEvent(project: currentProject, newState: .outro)
                            }
                        }
                        viewUpdateTime.toggle()
                    }
                }) {
                    
                    if (MetalTool.shared.streamer.streamState == .failed) || (MetalTool.shared.streamer.streamState == .offline) {
                        Image(systemName: "network").tint(.gray).disabled(goLiveStatus == .disabled)
                    } else if MetalTool.shared.streamer.streamState == .connection {
                        Image(systemName: "network").tint(.yellow)
                    } else if (MetalTool.shared.streamer.streamState == .live) ||
                                (MetalTool.shared.streamer.streamState == .preroll) ||
                                (MetalTool.shared.streamer.streamState == .intro) ||
                                (MetalTool.shared.streamer.streamState == .paused) ||
                                (MetalTool.shared.streamer.streamState == .outro) {
                        Image(systemName: "network").tint(.green)
                    }
                }.disabled(MetalTool.shared.currentInterfaceOrientation.isPortrait)
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    if !streamStateControlsDisabled {
                        guard let currentProject else { return }
                        disableStreamStateControlsForATime()
                        MetalTool.shared.streamer.handleStateButtonPush(project: currentProject)
                    }
                }) {
                    switch(MetalTool.shared.streamer.streamState) {
                    case .offline:
                        Text("Offline").foregroundColor(.gray)
                    case .connection:
                        Text("Connecting").foregroundColor(.yellow)
                    case .preroll:
                        Text("Preroll").foregroundColor(.green)
                    case .intro:
                        Text("Intro").foregroundColor(.green)
                    case .live:
                        Text("Live").foregroundColor(.green)
                    case .paused:
                        Text("Paused")
                    case .outro:
                        Text("Outro").foregroundColor(.green)
                    case .failed:
                        Text("Failed").foregroundColor(.red)
                    }
                }.disabled(MetalTool.shared.currentInterfaceOrientation.isPortrait || streamStateControlsDisabled)
            }

            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    streamGaugeSliderEnabled.toggle()
                }) {
                    if viewUpdateTime || !viewUpdateTime {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.0percent")
                            if streamGaugeSliderEnabled {
                                let speedText = displayableSpeed(rate:MetalTool.shared.streamer.getBitrate())
                                Text("\(speedText)").foregroundColor(.primary)
                                Slider( value: $bitrateSliderValue,
                                        in: 640000...maxBitrate,
                                        step: 640000) { editing in
                                    if let currentProject {
                                        Logger.shared.info("stream rate: \(speedText)")
                                        if bitrateSliderValue > currentProject.maxBandwidth {
                                            bitrateSliderValue = currentProject.maxBandwidth
                                        }
                                    }
                                    MetalTool.shared.streamer.update(bitrate: Int(bitrateSliderValue))
                                    viewUpdateTime.toggle()
                                }.frame(minWidth: 300)
                                    .simultaneousGesture(DragGesture().onChanged {_ in }, including: .all)
                            }
                        }
                    }
                }.disabled(MetalTool.shared.currentInterfaceOrientation.isPortrait || streamStateControlsDisabled)
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    NavigationStack {
                        StreamCompositionView()
                    }
                } label: {
                    Image(systemName: "square.grid.3x3.square")
                }.disabled(MetalTool.shared.currentInterfaceOrientation.isPortrait)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    StreamBuffer.shared.clear(uuid: "front")
                    switch(userCameraSelection) {
                    case .off:
                        handleUserCamera(cameraType: .frontOn)
                    case .frontOn:
                        handleUserCamera(cameraType: .off)
                    }
                }) {
                    switch(userCameraSelection) {
                    case .off:
                        Image(systemName: "person.slash")
                    case .frontOn:
                        Image(systemName: "person")
                    }
                }.disabled(MetalTool.shared.currentInterfaceOrientation.isPortrait)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    StreamBuffer.shared.clear(uuid: "rear")
                    StreamBuffer.shared.clear(uuid: "external")
                    
                    switch(subjectCameraSelection) {
                    case .off:
                        handleSubjectCamera(cameraType: .rearOn)
                        WatchEntryManager.shared.disableAllRemoteCameras()
                    case .rearOn:
                        handleSubjectCamera(cameraType: .off)
                    }
                }) {
                    switch(subjectCameraSelection) {
                    case .off:
                        Image(systemName: "video.slash")
                    case .rearOn:
                        Image(systemName: "video")
                    }
                }.disabled(MetalTool.shared.currentInterfaceOrientation.isPortrait)
            }
        }.onChange(of: volumeSlider, { s1, s2 in
            switch selectedMicrophone {
            case .none:
                volumeList["media"] = Float(s2)
                AudioTool.shared.adjustMediaVolume(level: Float(s2))
            case .host:
                volumeList["host"] = Float(s2)
                AudioTool.shared.adjustInputVolume(level: Float(s2))
            case .subject:
                volumeList["subject"] = Float(s2)
                AudioTool.shared.adjustInputVolume(level: Float(s2))
            case .interview:
                volumeList["interview"] = Float(s2)
                AudioTool.shared.adjustInputVolume(level: Float(s2))
            }
        }).onReceive(MetalTool.shared.streamer.$streamState, perform: { _ in
            DispatchQueue.main.async {
                viewUpdateTime.toggle()
                if MetalTool.shared.streamer.streamState == .offline {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }).onReceive(scrubber.$thumbnail, perform: { value in
            DispatchQueue.main.async {
                if isUserUpdatingSlider {
                    thumbnail = value
                    viewUpdateTime.toggle()
                }
            }
        }).onReceive(PubCentral.shared.pubRemoteStreamChanged, perform: { _ in
            if MetalTool.shared.streamer.isConnected() {
                if !firstConnectionMediaPlayed {
                    firstConnectionMediaPlayed = true
                    guard let currentProject else { return }
                    MetalTool.shared.streamer.handleStateChangeFromEvent(project: currentProject, newState: .preroll)
                }
            }
            viewUpdateTime.toggle()
        })
        .onReceive(MetalTool.shared.mediaPlayer.$mediaPosition, perform: { value in
            if !isUserUpdatingSlider {
                scrubber.currentTime = value
            }
        })
        .alert(isPresented: $mediaFailed) {
            Alert(
                title: Text("Media Failed"),
                message: Text("The selected media failed to play. Please try again."),
                dismissButton: .default(Text("Dismiss"))
            )
        }
        .onReceive(PubCentral.shared.mediaFailed, perform: { _ in
            DispatchQueue.main.async {
                if WatchEntryManager.shared.mediaQueue.count > 0 {
                    WatchEntryManager.shared.mediaQueue.removeFirst()
                }
                thumbnail = nil
                MetalTool.shared.useMediaPlayerBuffer(video: nil)
                mediaFailed = true
                handleNextVideo()
            }
        })
        .onReceive(PubCentral.shared.mediaCompleted, perform: { _ in
            DispatchQueue.main.async {
                if WatchEntryManager.shared.mediaQueue.count < 2 {
                    MetalTool.shared.mediaShown = false
                }
                
                if WatchEntryManager.shared.mediaQueue.count > 0 {
                    WatchEntryManager.shared.mediaQueue.removeFirst()
                }
                
                thumbnail = nil
                MetalTool.shared.useMediaPlayerBuffer(video: nil)
                viewUpdateTime.toggle()
                handleNextVideo()
            }
        }).onReceive(PubCentral.shared.pubMediaRemoved, perform: { notification in
            let currentMediaURL:String = MetalTool.shared.mediaPlayer.getPlayingURL()?.lastPathComponent ?? ""
            if let userInfo = notification.userInfo {
                if let removedURL = userInfo["url"] as? String {
                    if let fname = URL(string: removedURL)?.lastPathComponent {
                        if currentMediaURL == fname {
                            MetalTool.shared.mediaPlayer.stop()
                            scrubber.currentTime = .zero
                            MetalTool.shared.mediaShown = false
                            MetalTool.shared.useMediaPlayerBuffer(video: nil)
                        }
                    }
                }
            }
            viewUpdateTime.toggle()
        })
        .onReceive(PubCentral.shared.mediaStarted, perform: { _ in
            DispatchQueue.main.async {
                thumbnail = nil
                viewUpdateTime.toggle()
            }
        })
        .onReceive(PubCentral.shared.projectListChanged, perform: { _ in
            DispatchQueue.main.async {
                startup(changed: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    landscapeMode = MetalTool.shared.currentInterfaceOrientation.isLandscape
                    updateDisplayForLandscapePortrait()
                    updateMaxBitrate()
                    showMetal = true
                    viewUpdateTime.toggle()
                })
            }
        })
        .onReceive(PubCentral.shared.localCameraChanged, perform: { _ in
            DispatchQueue.main.async {
                userCameraSelection = MetalTool.shared.camera.hostCamera
                subjectCameraSelection = MetalTool.shared.camera.subjectCamera
                viewUpdateTime.toggle()
            }
        }).onReceive(PubCentral.shared.pubEnterBackground, perform: { _ in
            shutdown()
        }).onReceive(PubCentral.shared.pubResetMedia, perform: { _ in
            scrubber.currentTime = .zero
            viewUpdateTime.toggle()
        })
        .onReceive(PubCentral.shared.pubRestarted, perform: { _ in
            landscapeMode = MetalTool.shared.currentInterfaceOrientation.isLandscape
            startup(changed: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                landscapeMode = MetalTool.shared.currentInterfaceOrientation.isLandscape
                updateDisplayForLandscapePortrait()
                updateMaxBitrate()
                showMetal = true
                viewUpdateTime.toggle()
            })
        })
        .onAppear() {
            if !startupComplete {
                landscapeMode = MetalTool.shared.currentInterfaceOrientation.isLandscape
                startup(changed: false)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                    volumeList["media"] = AudioTool.shared.mediaNode.volume
                   // volumeList["remote"] = AudioTool.shared.cameraNode.volume
                    volumeList["host"] = AudioTool.shared.inputNode?.volume ?? 1.0
                    volumeList["subject"] = AudioTool.shared.inputNode?.volume ?? 1.0
                    volumeList["interview"] = AudioTool.shared.inputNode?.volume ?? 1.0
                    
                    landscapeMode = MetalTool.shared.currentInterfaceOrientation.isLandscape
                    updateDisplayForLandscapePortrait()
                    showMetal = true
                    updateMaxBitrate()
                    bitrateSliderValue = Double(MetalTool.shared.streamer.getBitrate())
                    viewUpdateTime.toggle()
                })
            } else {
                MetalTool.shared.update(rendering: true)
                bitrateSliderValue = Double(MetalTool.shared.streamer.getBitrate())
                updateMaxBitrate()
                viewUpdateTime.toggle()
            }
        }.onReceive(PubCentral.shared.cameraListChanged) { (output) in
            WatchEntryManager.shared.updateList()
        }.onReceive(PubCentral.shared.pubBandwidthReport) { (notification) in
            bitrateSliderValue = Double(MetalTool.shared.streamer.getBitrate())
            viewUpdateTime.toggle()
        }
    }
    
    func displayableSpeed(rate:Int) -> String {
        let r = Double(rate) / 10000.0
        return String(format: "%.2f", r) + " KB/s"
    }
    
    func handleNextVideo() {
        switch(MetalTool.shared.streamer.streamState) {
        case .preroll:
            guard let currentProject else { return }
            MetalTool.shared.streamer.handleStateChangeFromEvent(project: currentProject, newState: .intro)
        case .intro:
            guard let currentProject else { return }
            MetalTool.shared.streamer.handleStateChangeFromEvent(project: currentProject, newState: .live)
        case .outro:
            guard let currentProject else { return }
            MetalTool.shared.streamer.handleStateChangeFromEvent(project: currentProject, newState: .offline)
        case .paused:
            guard let currentProject else { return }
            MetalTool.shared.streamer.handleStateChangeFromEvent(project: currentProject, newState: .paused)
        default:
            break
        }
        thumbnail = nil
    }
    
    func allowOnline() -> Bool {
        if let currentProject {
            if currentProject.audioConfiguration.hostMicrophone == "" { return false }
            if currentProject.config.service != .rtmp { return false }
        }
        
        return true
    }
    
    func shutdown() {
        MetalTool.shared.streamer.streamState = .offline
        MetalTool.shared.endRecording()
        showMetal = false
        MetalTool.shared.stopFillingStreamPixelBuffers()
        MetalTool.shared.stopRendering()
        MetalTool.shared.mediaPlayer.stop()
        MetalTool.shared.stopMediaBuffer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
            MetalTool.shared.streamer.shutdown()
        })
    }
    
    @State var startupComplete:Bool = false
    
    func startup(changed:Bool) {
        Task {
            let project = await ProjectService.shared.currentProject()
            DispatchQueue.main.async {
                if (currentProject == nil) || (project.id != currentProject?.id) || changed {
                    currentProject = project
                    if let currentProject {
                        MetalTool.shared.streamer.setup(project: currentProject)
                        MetalTool.shared.updateBaseImage()
                        
                        if MetalTool.shared.getDisplayView() == nil {
                            MetalTool.shared.startDisplayView()
                        }
                        
                        if let p = MetalTool.shared.getDisplayView() {
                            p.frame.size = UIScreen.main.bounds.size
                            MetalTool.shared.startRendering(withProject: currentProject)
                            showMetal = false
                        }
                        
                        goLiveStatus = goLiveButtonStatus()
                        self.startupComplete = true
            
                        MetalTool.shared.camera.start(withHost: userCameraSelection,
                                                      withSubject: subjectCameraSelection,
                                                      rearExternal: currentProject.ipadExternal == .replacesRear,
                                                      rearLens: currentProject.rearCameraLens)
                        
                        AudioTool.shared.adjustInputVolume(level: 0.0)
                        MetalTool.shared.update(rendering: true)
                    }
                }
            }
        }
    }
    
    func goLiveButtonStatus() -> StreamGoLiveStatus {
        guard let currentProject else { return .disabled }
        let url = currentProject.config.url
        let name = currentProject.config.name
        
        if name.lengthOfBytes(using: .utf8) < 1 { return .disabled }
        
        if url.lengthOfBytes(using: .utf8) < 10 { return .disabled }
        
        if currentProject.audioConfiguration.hostMicrophone == "" { return .disabled }
        
        if MetalTool.shared.streamer.isConnected() { return .connected }
        
        return .off
    }
    
    func handleUserCamera(cameraType:StreamUserCameraSelection) {
        guard let currentProject else { return }
        userCameraSelection = cameraType
        MetalTool.shared.camera.start(withHost: userCameraSelection,
                                      withSubject: subjectCameraSelection,
                                      rearExternal: currentProject.ipadExternal == .replacesRear,
                                      rearLens: currentProject.rearCameraLens)
    }
    
    func handleSubjectCamera(cameraType:StreamSubjectCameraSelection) { 
        guard let currentProject else { return }
        subjectCameraSelection = cameraType
        MetalTool.shared.camera.start(withHost: userCameraSelection, 
                                      withSubject: subjectCameraSelection,
                                      rearExternal: currentProject.ipadExternal == .replacesRear,
                                      rearLens: currentProject.rearCameraLens)
    }
    
    func select(microphone:StreamMicrophoneSelection) {
        guard let currentProject else { return }
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else { return }
        switch(microphone) {
        case .none:
            break
        case .host:
            for (_, input) in inputs.enumerated() {
                Logger.shared.info("Comparing host: \(currentProject.audioConfiguration.hostMicrophone) - \(input.uid)")
                if currentProject.audioConfiguration.hostMicrophone.contains(input.uid) {
                    do  {
                        Logger.shared.info("Setting host: \(input.uid)")
                        try session.setPreferredInput(input)
                        break
                    } catch {
                        Logger.shared.error("Unable to set to existing input: \(String(describing: currentProject.audioConfiguration.hostMicrophone))")
                    }
                }
            }
        case .subject:
            for (_, input) in inputs.enumerated() {
                Logger.shared.info("Comparing subject: \(currentProject.audioConfiguration.subjectMicrophone) - \(input.uid)")
                if currentProject.audioConfiguration.subjectMicrophone.contains(input.uid) {
                    do  {
                        Logger.shared.info("Setting subject: \(input.uid)")
                        try session.setPreferredInput(input)
                        break
                    } catch {
                        Logger.shared.error("Unable to set to existing input: \(String(describing: currentProject.audioConfiguration.subjectMicrophone))")
                    }
                }
            }
        case .interview:
            for (_, input) in inputs.enumerated() {
                Logger.shared.info("Comparing interview: \(currentProject.audioConfiguration.interviewMicrophone) - \(input.uid)")
                if currentProject.audioConfiguration.interviewMicrophone.contains(input.uid) {
                    do  {
                        Logger.shared.info("Setting interview: \(input.uid)")
                        try session.setPreferredInput(input)
                        break
                    } catch {
                        Logger.shared.error("Unable to set to existing input: \(String(describing: currentProject.audioConfiguration.interviewMicrophone))")
                    }
                }
            }
        }
        selectedMicrophone = microphone
    }
}
