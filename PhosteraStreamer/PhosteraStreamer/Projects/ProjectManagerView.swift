//
//  Projects.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/13/23.
//

import SwiftUI
import PhosteraShared

struct ProjectManagerView: View {
    var columns:[GridItem] = [ GridItem(.fixed(100)), GridItem(.flexible(minimum: 200, maximum: 2000)) ]
    @State private var showDetail: Bool = false
    @State var project:StreamProjectModel?
    @State var addProjectModel:StreamProjectModel?
    @State var projectList:[StreamProjectModel] = []
    @State var viewUpdate:Bool = true
    @State private var showHelp: Bool = false
    @State private var showBuy: Bool = false
    @State private var title:String = ""
    @State private var isStreaming:Bool = false
    
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                Form {
                    Section("Your Identity", content: {
                        TextField("Name to Show to Camera Operators", text: $title)
                    }).onChange(of: title) { oldValue, newValue in
                        SettingsService.shared.settings.displayName = newValue
                        SettingsService.shared.save()
                    }
                    Section("Projects", content: {
                        List {
                            ForEach(projectList, id: \.id) { project in
                                ZStack {
                                    if project.id == SettingsService.shared.settings.currentProjectId {
                                        Text(project.title).bold().foregroundColor(.accentColor).opacity(isStreaming ? 0.5 : 1.0)
                                    } else {
                                        Text(project.title).opacity(isStreaming ? 0.5 : 1.0)
                                    }
                                    NavigationLink(destination: ProjectDetailView(project: project, newProject: false)) {
                                        EmptyView()
                                    }.disabled(isStreaming)
                                }
                            }
                            .onDelete(perform: deleteProject)
                        }.sheet(isPresented: $showDetail, onDismiss: {
                            updateList()
                        }, content: {
                            let p = StreamProjectModel(id: UUID().uuidString.lowercased(), title: "New Project", streamResolution: .v1920x1080, streamFrameRate: .fr30)
                            NavigationStack {
                                ProjectDetailView(project:p, newProject: true)
                            }
                        })
                    }).onReceive(PubCentral.shared.pubRemoteStreamChanged, perform: { _ in
                        isStreaming = MetalTool.shared.streamer.isConnected()
                        viewUpdate.toggle()
                    })
                    
                }
            }
        }
        .onAppear(perform: {
            updateList()
            title = SettingsService.shared.settings.displayName
            isStreaming = MetalTool.shared.streamer.isConnected()
        })
        .navigationTitle("Project Manager")
        .navigationBarTitleDisplayMode(.inline)
       
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                NavigationLink(destination: HelpView()) {
                    Image(systemName: "questionmark.circle")
                }
//                NavigationLink(destination: BuyView()) {
//                    Image(systemName: "dollarsign")
//                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    showDetail.toggle()
                }, label: {
                    Image(systemName: "plus")
                })
            }
        }
    }
    
    func updateList() {
        Task {
            let list = await ProjectService.shared.projectList()
            DispatchQueue.main.async {
                projectList = list
                viewUpdate = !viewUpdate
            }
        }
    }
    
    func deleteProject(at offsets: IndexSet) {
        var doDelete:Bool = true
        offsets.forEach { index in
            let project = projectList[index]
            if project.id != "default" {
                Task {
                    await ProjectService.shared.delete(project: project)
                }
            } else {
                doDelete = false
            }
        }
        if doDelete {
            projectList.remove(atOffsets: offsets)
        }
        updateList()
    }
}

