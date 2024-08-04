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
    @State var project:DirectorProjectModel?
    @State var addProjectModel:DirectorProjectModel?
    @State var projectList:[DirectorProjectModel] = []
    @State var viewUpdate:Bool = true
    @State var showHelpView:Bool = false
    @State var showBuyView:Bool = false
    @State var directorTitle:String = ""
    
    var body: some View {
        Form {
            Section("Your Identity") {
                TextField("Name for Camera Users", text: $directorTitle).onChange(of: directorTitle) {
                    SettingsService.shared.settings.displayName = directorTitle
                    SettingsService.shared.save()
                }
            }
                        
            Section("Projects") {
                List {
                    ForEach(projectList) { p in
                        NavigationLink(destination: ProjectDetailView(project: p, newProject: false)) {
                            if p.uuid == SettingsService.shared.settings.currentProjectId {
                                Text(p.title).tag(p.uuid).bold()
                            } else {
                                Text(p.title).tag(p.uuid)
                            }
                        }
                    }
                    .onDelete(perform: deleteProject)
                }.sheet(isPresented: $showDetail, onDismiss: {
                    updateList()
                }) {
                    let p = DirectorProjectService.makeBaseProjectModel()
                    NavigationView {
                        ProjectDetailView(project: p,
                                          resolution: p.resolution.rawValue,
                                          framerate: p.frameRate.rawValue,
                                          codec: p.codec.rawValue,
                                          colorspace: p.colorspace.rawValue,
                                          collectProxies: p.collectProxies,
                                          proxyResolution: p.proxyResolution.rawValue,
                                          fileNamingScheme: p.fileNamingScheme.rawValue,
                                          proxyNamingScheme: p.proxyNamingScheme.rawValue,
                                          fileStorageLocation: p.fileStorageLocation.rawValue,
                                          proxyStorageLocation: p.proxyStorageLocation.rawValue,
                                          
                                          modeStandby: p.modeStandby,
                                          locationInformation: p.locationInformation,
                                          newProject: true)
                    }
                }
            }
            }
        .onAppear(perform: {
            directorTitle = SettingsService.shared.settings.displayName
            updateList()
        })
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                NavigationLink {
                    HelpView()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
//                NavigationLink {
//                    BuyView()
//                } label: {
//                    Image(systemName: "dollarsign")
//                }
                
                Button(action: {
                    showDetail.toggle()
                }, label: {
                    Image(systemName: "plus.rectangle.on.folder.fill")
                })
            }
        }
    }
    
    func updateList() {
        let list = DirectorProjectService.projectList()
        projectList = list
        viewUpdate = !viewUpdate
    }
    
    func deleteProject(at offsets: IndexSet) {
        projectList.remove(atOffsets: offsets)
    }
}

