//
//  ModeView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/28/23.
//

import Foundation
import SwiftUI
import Combine
import PhosteraShared

struct ModeView: View {
    @State var modeList:[DirectorProjectCameraMode] = []
    @Environment(\.dismiss) private var dismiss
    @State var update:Bool = false
    
    var body: some View {
        Form {
            Section("Modes") {
                ForEach(modeList) { p in
                    HStack {
                        switch(p.techType) {
                        case .cifilter:
                            Image(systemName: "video")
                        case .movie:
                            Image(systemName: "video")
                        case .photo:
                            Image(systemName: "photo")
                        }
                        
                        Text("\(p.title)").foregroundStyle(.primary).font(.title).onTapGesture {
                            let cameraList = CameraManager.shared.availableUUIDs
                            
                            for uuid in cameraList {
                                Task(priority: .userInitiated, operation: {
                                    if let c = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                        await c.requestFromCamera(content: CameraRequest(command: .changeMode, uuid: uuid, sesionKey: c.sessionKey, dataUUID: p.uuid))
                                    }
                                })
                            }
                            dismiss()
                        }
                        Spacer()
                    }
                }
            }
            
            Section("Standby", content: {
                HStack {
                    Text("Standby/Transfer").onTapGesture {
                        let cameraList = CameraManager.shared.availableUUIDs
                        
                        for uuid in cameraList {
                            Task(priority: .userInitiated, operation: {
                                if let c = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                    await c.requestStandby(isOn: true)
                                }
                            })
                        }
                        dismiss()
                    }
                }
            })
        }.onAppear() {
            if let project = DirectorProjectService.currentProject() {
                modeList = project.modeList
                update.toggle()
            }
        }.frame(minWidth: 300, idealWidth: 300, maxWidth: .infinity, minHeight: 400, idealHeight: 400, maxHeight: .infinity, alignment: .trailing)
            .navigationTitle("Choose a Mode").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading, content: {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                    }
                })
            }
    }
}

//
//case .standby:
//    Task(priority: .userInitiated, operation: {
//        await connection.status.standby = !connection.status.standby
//    })
//case .standbyOpsComplete:
//    Task(priority: .userInitiated, operation: {
//        await connection.status.standbyOpsComplete = !connection.status.standbyOpsComplete
//    })
//    await subs.append(conn.status.$standby .receive(on: DispatchQueue.main).sink() { [weak self] value in
//        guard let self else { return }
//        Logger.shared.info("standby:\(value)")
//    })
//
//    await subs.append(conn.status.$standbyOpsComplete .receive(on: DispatchQueue.main).sink() { [weak self] value in
//        guard let self else { return }
//        Logger.shared.info("standbyOpsComplete:\(value)")
//    })
