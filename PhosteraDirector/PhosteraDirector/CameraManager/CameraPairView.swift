//
//  CameraPairView.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/22/23.
//

import Foundation
import SwiftUI
import PhosteraShared

//Display the UUID and request info
//Display a pairing code the user can see to match

struct CameraPairView: View {
    var camera:CameraModel
    @State var commandConnector:CameraCommandConnector?
    @Environment(\.dismiss) private var dismiss
    @State var pairCode:String?
    @State var currentProject:StreamProjectModel?
    @State var userMessage:String = ""
    @State var updateToggle:Bool = false
    @State var requestingAccess:Bool = false
    @State var success:Bool = false
    
    var body: some View {
        
        Form {
            Section("Phostera Camera") {
                HStack {
                    Text("Identifier").frame(alignment: .leading)
                    Spacer()
                    Text("\(camera.uuid)").frame(alignment: .trailing)
                }
            }
            
            Section("Message") {
                TextEditor(text: $userMessage)
            }
            
            Section("Access") {
                HStack {
                    Text("Pair code").frame(alignment: .leading)
                    Spacer()
                    Text("\(pairCode ?? "")").frame(alignment: .trailing).font(.headline)
                }
                Button(action: {
                    requestingAccess = true
                    Task(priority: .userInitiated, operation: {
                        await NetworkHandler.shared.updatePairCode(uuid: camera.uuid, code: pairCode ?? "")
                        await NetworkHandler.shared.updateSignupMessage(uuid: camera.uuid, message: userMessage)
                        let _ = await NetworkHandler.shared.connectCameraCommandChannel(uuid: camera.uuid)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                            if requestingAccess {
                                checkStillConnected(uuid: camera.uuid)
                            }
                        })
                    })
                }, label: {
                    HStack {
                        Text("Request Access").font(.headline).frame(alignment: .leading)
                        Spacer()
                        if requestingAccess {
                            ProgressView("Working")
                        } else if success {
                            Text("Connected!").foregroundStyle(.green)
                        }
                    }
                    
                }).disabled(requestingAccess || success)
            }
        }
        .navigationTitle("Camera Pairing")
        .onReceive(PubCentral.shared.cameraUpdated) { (output) in
            if let updated:CameraModel = CameraManager.shared.getCamera(uuid: camera.uuid) {
                requestingAccess = false
                if camera.authorized {
                    requestingAccess = false
                    success = true
                    camera.name = updated.name
                    camera.model = updated.model
                    _ = CameraManager.shared.updateCamera(camera: camera)
                    Dispatch.DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.cameraListChanged, object: nil) }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                        dismiss()
                    })
                } else if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                    dismiss()
                } else {
                    checkStillConnected(uuid: camera.uuid)
                }
            }
        }
        .onAppear() {
            Task {
                pairCode = generatePairCode()
                if let project = DirectorProjectService.currentProject() {
                    DispatchQueue.main.async {
                        userMessage = project.signupMessage
                        updateToggle.toggle()
                    }
                }
            }
        }
    }
    
    func checkStillConnected(uuid:String) {
        Task {
            if await NetworkHandler.shared.cameraCommandConnections[uuid] == nil {
                DispatchQueue.main.async {
                    requestingAccess = false
                }
            }
        }
    }
    
    func generatePairCode() -> String {
        let uuid = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let startIndex = uuid.startIndex
        let endIndex = uuid.index(uuid.startIndex, offsetBy: 4)
        return String(uuid[startIndex..<endIndex])
    }
}
