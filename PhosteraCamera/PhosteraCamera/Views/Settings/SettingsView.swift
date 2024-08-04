//
//  WelcomeView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/7/23.
//

import SwiftUI
import AVFoundation
import PhosteraShared

enum CameraDirection: String, CaseIterable, Identifiable, CustomStringConvertible {
    case back
    case front
    
    var id: Self { self }
    var description: String {
        switch self {
        case .back:
            return "back"
        case .front:
            return "front"
        }
    }
}

enum CameraRecordingMethod: String, CaseIterable, Identifiable, CustomStringConvertible {
    case photo
    case video
    
    var id: Self { self }
    var description: String {
        switch self {
        case .photo:
            return "photo"
        case .video:
            return "video"
        }
    }
}

enum CameraModeSource: String, CaseIterable, Identifiable, CustomStringConvertible {
    case builtin
    case director
    
    var id: Self { self }
    var description: String {
        switch self {
        case .builtin:
            return "builtin"
        case .director:
            return "director"
        }
    }
}

struct SettingsPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentation
    @State var pathSettings: [SettingsRoute] = [SettingsRoute]()
    @State var cardModel:[SettingsCardModel] = [
        SettingsCardModel(title: "Camera", footer: "  Back to the camera", imageName: "camera"),
        SettingsCardModel(title: "Options", footer: "  Tools and Permissions", imageName: "gear"),
        SettingsCardModel(title: "Help", footer: "User Guide and Forum", imageName: "questionmark.circle"),
        SettingsCardModel(title: "Server", footer: "   Control your camera", imageName: "rectangle.righthalf.inset.filled.arrow.right")
     
    ]
    @State var whichCamera: CameraDirection = .back
    @State var whichCapture = CameraRecordingMethod.video
    @State var whichSource = CameraModeSource.builtin
    
    @State private var defaultModes:DefaultModes = ModeHandler.shared.defaultModes
    @State private var directorModes:DirectorModes = ModeHandler.shared.directorModes
    @State private var shouldDismiss:Bool = false
    @State private var onboardRouteForPermissions:[OnboardingRoute] = [OnboardingRoute]()
    @State private var selectedDirector:DirectorModel?
    
    let indexOfCardModelthatIsbackButton = 0
    
    var body: some View {
        NavigationStack() {
            ZStack {
                //backgroundGradient.ignoresSafeArea()
                VStack() {
                    HStack {
                        SettingsCardView(pathSettings: $pathSettings, cardModel: $cardModel[indexOfCardModelthatIsbackButton]).onTapGesture { dismiss() }
                        ForEach(1..<4) { x in
                            NavigationLink(value: SettingsRoute(rawValue: x - 1)) {
                                SettingsCardView(pathSettings: $pathSettings, cardModel: $cardModel[x])
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    HStack {
                     //   Text("Modes").bold()
                        Picker("Mode Source", selection: $whichSource) {
                            Text("Director").tag(CameraModeSource.director)
                            Text("Personal").tag(CameraModeSource.builtin)
                        }.pickerStyle(.segmented)
                        Picker("Camera", selection: $whichCamera) {
                            ForEach(CameraDirection.allCases, id: \.id) { value in
                                switch(value) {
                                case .front:
                                    Text("Front").font(.system(size: 8)).tag(CameraDirection.front)
                                case .back:
                                    Text("Back").font(.system(size: 8)).tag(CameraDirection.back)
                                }
                                
                            }
                        }.pickerStyle(.segmented)
                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//                    HStack {
//                        
//                        Spacer()
//                        Picker("Type", selection: $whichCapture) {
//                            Text("Video").tag(CameraRecordingMethod.video)
//                            Text("Photo").tag(CameraRecordingMethod.photo)
//
//                        }.pickerStyle(.segmented)
//                       
//                    }.padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    
                    List {
                        if whichSource == CameraModeSource.builtin {
                            switch(whichCamera) {
                            case CameraDirection.back:
                                switch(whichCapture) {
                                case .video:
                                    ForEach($defaultModes.modeListBackVideo) { card in
                                        NavigationLink {
                                            ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                        } label: {
                                            HStack {
                                                Spacer()
                                                ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                                Spacer()
                                            }.padding()
                                        }
                                    }
                                case .photo:
                                    ForEach($defaultModes.modeListBackPhoto) { mode in
                                        NavigationLink {
                                            ModeDetailPageView(pathSettings: $pathSettings, mode: mode )
                                        } label: {
                                            HStack {
                                                Spacer()
                                                ModeCardView(pathSettings: $pathSettings, modeModel: mode)
                                                Spacer()
                                            }.padding()
                                        }
                                    }
                                }
                            case .front:
                                switch(whichCapture) {
                                case .video:
                                    ForEach($defaultModes.modeListFrontVideo) { card in
                                        NavigationLink {
                                            ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                        } label: {
                                            HStack {
                                                Spacer()
                                                ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                                Spacer()
                                            }.padding()
                                        }
                                    }
                                case .photo:
                                    ForEach($defaultModes.modeListFrontPhoto) { card in
                                        NavigationLink {
                                            ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                        } label: {
                                            HStack {
                                                Spacer()
                                                ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                                Spacer()
                                            }.padding()
                                        }
                                    }
                                }
                            }
                        }
                        else if whichSource == CameraModeSource.director {
                            switch(whichCamera) {
                            case CameraDirection.back:
                                switch(whichCapture) {
                                case .video:
                                    if directorModes.modeListBackVideo.isEmpty {
                                        ContentUnavailableView("Back Camera Video", systemImage: "video", description: Text("Use Phostera Director to create and install modes."))
                                    } else {
                                        ForEach($directorModes.modeListBackVideo) { card in
                                            NavigationLink {
                                                ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                            } label: {
                                               ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                            }
                                        }
                                    }
                                case .photo:
                                    if directorModes.modeListBackPhoto.isEmpty {
                                        ContentUnavailableView("Back Camera Photo", systemImage: "photo", description: Text("Use Phostera Director to create and install modes."))
                                    } else {
                                        ForEach($defaultModes.modeListBackPhoto) { card in
                                            NavigationLink {
                                                ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                            } label: {
                                                HStack {
                                                    Spacer()
                                                    ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                                    Spacer()
                                                }.padding()
                                            }
                                        }
                                    }
                                }
                            case .front:
                                switch(whichCapture) {
                                case .video:
                                    if directorModes.modeListFrontVideo.isEmpty {
                                        ContentUnavailableView("Front Camera Video", systemImage: "video", description: Text("Use Phostera Director to create and install modes."))
                                    } else {
                                        ForEach($defaultModes.modeListFrontVideo) { card in
                                            NavigationLink {
                                                ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                            } label: {
                                                HStack {
                                                    Spacer()
                                                    ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                                    Spacer()
                                                }.padding()
                                            }
                                        }
                                    }
                                case .photo:
                                    if directorModes.modeListFrontPhoto.isEmpty {
                                        ContentUnavailableView("Front Camera Photo", systemImage: "photo", description: Text("Use Phostera Director to create and install modes."))
                                    } else {
                                        ForEach($defaultModes.modeListFrontPhoto) { card in
                                            NavigationLink {
                                                ModeDetailPageView(pathSettings: $pathSettings, mode: card )
                                            } label: {
                                                HStack {
                                                    Spacer()
                                                    ModeCardView(pathSettings: $pathSettings, modeModel: card)
                                                    Spacer()
                                                }.padding()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }.frame( maxWidth: .infinity)
                    .listStyle(PlainListStyle())
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                }
            }
            .onChange(of: shouldDismiss, { oldValue, newValue in
                dismiss()
            })
            .navigationBarHidden(true)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch(route) {
                case .options:
                    OptionsPageView(pathSettings: $pathSettings)
                case .help:
                    HelpPageView()
                case .server:
                    ServerPageView(pathSettings: $pathSettings)
                case .permissions:
                    PermissionsPageView(path: $onboardRouteForPermissions)
                }
            }
        }
    }
}
