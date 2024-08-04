//
//  TakeProjectList.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/21/23.
//

import SwiftUI
import PhosteraShared
import Combine

struct TakeProjectList: View {
    @State var projectList:[DirectorProjectModel] = []
    @State var camera:CameraModel
    @State var waiting:Bool = true
    
    @State var cancellables:[AnyCancellable] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                if waiting {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView("Reading projects")
                            Spacer()
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach($projectList, id: \.self) { $p in
                            NavigationLink {
                                if p.allowStreamers {
                                    TakeListView(projectUUID: p.uuid, projectTitle: p.title, camera: camera)
                                }
                            } label: {
                                if let director = DirectorService.shared.findDirectorWithUUID(uuid: p.directorUUID) {
                                    Text("\(director.title) - \(p.title)").foregroundStyle(.primary)
                                } else {
                                    Text("\( p.title)").foregroundStyle(.primary)
                                }
                            }.disabled(!p.allowStreamers)
                        }
                    }
                }
            }
        }.onReceive(PubCentral.shared.onlineUpdated) { (output) in
            if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                dismiss()
            }
        }.onAppear() {
            if !CameraManager.shared.isUUIDOnline(uuid: camera.uuid) {
                dismiss()
            } else {
                subscribeToLists()
                getProjectsAndDirectors()
            }
        }.navigationTitle("Projects for \(camera.name != camera.uuid ? camera.name : camera.uuid)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        
                    }) {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                })
            }
    }
    
    func loadProjectsAndDirectors() {
        projectList.removeAll()
        for director in DirectorService.shared.directorList() {
            for project in DirectorProjectService.shared.projectListByDirector(director: director) {
                projectList.append(project)
            }
        }
    }
    
    func getProjectsAndDirectors() {
        Task {
            if let connection = await NetworkHandler.shared.cameraCommandConnections[camera.uuid] {
                let key = await connection.sessionKey
                let request = CameraRequest(command: .directorAndProjectList, uuid: camera.uuid, sesionKey: key, dataUUID: "")
                await connection.requestFromCamera(content: request)
            }
        }
    }
    
    func subscribeToLists() {
        cancellables.removeAll()
        cancellables.append(PubCentral.shared.pubDirectorsUpdated.receive(on: DispatchQueue.main).sink { notification in
            loadProjectsAndDirectors()
        })
        
        cancellables.append(PubCentral.shared.pubProjectsUpdated.receive(on: DispatchQueue.main).sink { notification in
            loadProjectsAndDirectors()
            waiting = false
        })
    }
    
}
