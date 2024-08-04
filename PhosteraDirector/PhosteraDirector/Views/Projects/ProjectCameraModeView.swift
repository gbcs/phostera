//
//  ProjectCameraModeView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/16/23.
//

import SwiftUI
import PhosteraShared
import Combine
import AVFoundation

struct ProjectCameraModeView: View {
    @State var update:Bool = false
    @State var cameraType:Int = 1
    @State var techType:Int = 0
    @State var includeDepthData: Bool = false
    @State var allowLowSpecCapture: Bool = true
    @State var title:String = ""
    @State var desc:String = ""
    @State var aspectRatio:CGSize = .zero
    @State var frontCamera:Bool = false
    @State var photoMode:Bool = false
    var newMode:Bool
    
    @Binding var mode:DirectorProjectCameraMode
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("Mode Information")) {
                TextField("Title", text: $title)
                TextField("Description", text: $desc)
            }
            
            Section(header: Text("Cameras")) {
                Toggle(isOn: $frontCamera) {
                    Text("Front Camera")
                }
                if !frontCamera {
                    Picker("Lens", selection: $cameraType) {
                        ForEach(DirectorProjectCameraType.allCases, id: \.self.rawValue) { lens in
                            switch(lens) {
                                //                        case .external:
                                //                            Text("iPad External")
                            case .wide:
                                Text("Wide")
                            case .telephoto:
                                Text("Telephoto")
                            case .ultrawide:
                                Text("Ultrawide")
                            case .dual:
                                Text("Dual")
                            case .dualWide:
                                Text("Dual Wide")
                            case .triple:
                                Text("Triple")
                                //                        case .trueDepth:
                                //                            Text("trueDepth")
                                //                        case .lidarDepth:
                                //                            Text("lidarDepth")
                            }
                        }
                    }
                }
                
//                Picker("Type", selection: $techType) {
//                    ForEach(DirectorProjectCameraTechType.allCases, id: \.self.rawValue) { lens in
//                        switch(lens) {
//                        case .cifilter:
//                            Text("Video")
//                        case .photo:
//                            Text("Photo")
//                        case .movie:
//                            Text("Video-Movie")
//                        }
//                    }
//                }
                
//                Toggle(isOn: $allowLowSpecCapture) {
//                    Text("Allow below-spec capture")
//                }
                
//                Toggle(isOn: $includeDepthData) {
//                    Text("Include depth data")
//                }
            }
        }.onAppear() {
            cameraType = mode.cameraType.rawValue
            techType = mode.techType.rawValue
            includeDepthData = mode.includeDepthData
            allowLowSpecCapture = mode.allowLowSpecCapture
            title = mode.title
            desc = mode.desc
            aspectRatio = mode.aspectRatio
            frontCamera = mode.frontCamera
            photoMode = mode.photoMode
        }.navigationBarItems(
            trailing:
                Button("Save") {
                    mode.cameraType = DirectorProjectCameraType(rawValue: cameraType) ?? .wide
                    mode.techType = DirectorProjectCameraTechType(rawValue: techType) ?? .cifilter
                    mode.includeDepthData = includeDepthData
                    mode.allowLowSpecCapture = allowLowSpecCapture
                    mode.title = title
                    mode.desc = desc
                    mode.aspectRatio = aspectRatio
                    mode.frontCamera = frontCamera
                    mode.photoMode = photoMode
                    mode.allowLowSpecCapture = true
                    dismiss()
                }
        ).navigationTitle(newMode ? "Add Camera Mode" : "Edit Camera Mode").navigationBarTitleDisplayMode(.inline)
    }
}
