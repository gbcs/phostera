//
//  FootageManagerView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/13/23.
//

import SwiftUI
import PhosteraShared
import _PhotosUI_SwiftUI

struct FootageManagerView: View {
    @State private var showDetail: Bool = false
    @State var footageList:[FootageModel] = []
    @State var selection: [PhotosPickerItem] = []
    @State var editedFootage:FootageModel = FootageModel(url: URL(fileURLWithPath: ""), type: .video, name: "")
    @State var showEdit:Bool = false
    @State var showCameraManagerView:Bool = false
    @State var updateView:Bool = false
    @State var projectList:[StreamProjectModel] = []
    @State var currentProject:StreamProjectModel?
    @State var isCompatible:[URL] = []
    
    func checkVideos() {
        Task {
            isCompatible.removeAll()
            for footage in footageList {
                var foundProblem:Bool = false
                if footage.url.pathExtension == "png" { continue }
                if footage.name.starts(with: "Default ") { isCompatible.append(footage.url); continue }
                let u = URL.documentsDirectory.appending(path: "footage").appendingPathComponent(footage.url.lastPathComponent)
                //Logger.shared.info("eval: \(u.path)")
                if let metadata = await FootageService.videoMetadata(from: u) {
                    if metadata.resolution.width != 1920 { foundProblem = true }
                    if metadata.resolution.height != 1080 { foundProblem = true }
                    let frameRate = Int(metadata.frameRate.rounded())
                    switch currentProject?.streamFrameRate {
                    case .fr24:
                        if frameRate != 24 { foundProblem = true }
                    case .fr25:
                        if frameRate != 25 { foundProblem = true }
                    case .fr30:
                        if frameRate != 30 { foundProblem = true }
                    case .none:
                        foundProblem = true
                    }
                } else {
                    foundProblem = true
                }
                if !foundProblem {
                    isCompatible.append(footage.url)
                }
            }
            DispatchQueue.main.async {
                updateView.toggle()
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                if updateView || !updateView {
                    List {
//                        Section("Filter", content: {
//                            ScrollView(.horizontal, showsIndicators: false, content: {
//                                HStack {
//                                    ForEach(projectList, id: \.id) { project in
//                                        TagView(tagName: project.title)
//                                    }
//                                    TagView(tagName: "Unsaved")
//                                    TagView(tagName: "Compatible")
//                                }
//                            })
//                        })
                        
                        Section("Video Footage", content: {
                            ForEach(footageList) { p in
                                if p.type == .video {
                                    HStack {
                                        if WatchEntryManager.shared.mediaQueue.contains(p.url.path) {
                                            if let x = WatchEntryManager.shared.mediaQueue.firstIndex(of: p.url.path) {
                                                Image(systemName: "\(x + 1).square").resizable().frame(width: 30, height: 30).onTapGesture(perform:  {
                                                    WatchEntryManager.shared.mediaQueue.removeAll { v in
                                                        let answer = v == p.url.path
                                                        if answer {
                                                            DispatchQueue.main.async {
                                                                NotificationCenter.default.post(name: Notification.Name.mediaRemoved, object: nil, userInfo:["url" : v])
                                                            }
                                                        }
                                                        return answer
                                                    }
                                                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.mediaPicked, object: nil) }
                                                    updateView.toggle()
                                                })
                                            }
                                        } else {
                                            let check = isCompatible.contains(p.url)
                                            Image(systemName: "play.square").resizable().frame(width: 30, height: 30).onTapGesture(perform: {
                                                WatchEntryManager.shared.mediaQueue.append(p.url.path)
                                                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.mediaPicked, object: nil) }
                                                updateView.toggle()
                                            }).disabled(!check).foregroundStyle( check ? .primary : Color(red: 1, green: 1, blue: 1, opacity: 0.2))
                                        }
                                        
                                        Text(p.name == "" ? p.url.lastPathComponent : p.name).tag(p.url).onTapGesture(perform: {
                                            editedFootage = p
                                            showEdit.toggle()
                                        })
                                    }
                                }
                            }.onDelete(perform: deleteFootage)
                        })
                        
                        Section("Background Images", content: {
                            ForEach(footageList) { p in
                                if p.type == .photo {
                                    Text(p.name == "" ? p.url.lastPathComponent : p.name).tag(p.url).onTapGesture(perform: {
                                        editedFootage = p
                                        showEdit.toggle()
                                    })
                                }
                            }.onDelete(perform: deleteFootage)
                        })
                        
                        Section("Recorded Streams", content: {
                            ForEach(projectList) { p in
                                NavigationLink(p.title, destination: {
                                    RecordingsView(project:p)
                                })
                            }
                        })
                    }
                }
            }.navigationTitle("Media")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showCameraManagerView, onDismiss: {
                    
                }, content: {
                    NavigationStack {
                        CameraManagerView()
                    }
                })
                .sheet(isPresented: $showEdit, onDismiss: {
                    updateFootageList()
                }, content: {
                    NavigationStack {
                        FootageEditView(footage:$editedFootage)
                    }
                }).sheet(isPresented: $showDetail, onDismiss: {
                    updateFootageList()
                }, content: {
                    NavigationStack {
                        FootagePickerView()
                    }
                })
                .navigationBarItems(
                    trailing:
                        Button(action: {
                            showDetail = true
                        }, label: {
                            Image(systemName: "plus")
                        })
                )
        }.onAppear(perform: {
            updateProjectList()
            updateFootageList()
            Task {
                currentProject = await ProjectService.shared.currentProject()
                checkVideos()
                await FootageService.shared.pruneFootage()
                //await FootageService.shared.filesInFootageReport()
            }
        }).onReceive(PubCentral.shared.projectListChanged, perform: { _ in
            updateProjectList()
            Task {
                currentProject = await ProjectService.shared.currentProject()
                DispatchQueue.main.async {
                    checkVideos()
                }
            }
        }).onReceive(PubCentral.shared.pubReloadFootage, perform: { _ in
            updateFootageList()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                checkVideos()
            })
        })
    }
    
    func updateFootageList() {
        Task {
            let f = await FootageService.shared.footageList()
            DispatchQueue.main.async {
                footageList = f
            }
        }
    }
    
    func updateProjectList() {
        Task {
            let p = await ProjectService.shared.projectList()
            DispatchQueue.main.async {
                projectList = p
            }
        }
    }
    
    func deleteFootage(at offsets: IndexSet) {
        var list = footageList
        list.remove(atOffsets: offsets)
        let deleted:[FootageModel] = footageList.filter { !list.contains($0) }
        if deleted.count > 0 {
            if let item = deleted.first {
                Task {
                    var found:Bool = false
                    
                    let projects = await ProjectService.shared.projectList()
                    
                    for p in projects {
                        if p.mediaPreroll?.url.path == item.url.path {
                            found = true; break
                        }
                        if p.mediaIntro?.url.path == item.url.path {
                            found = true; break
                        }
                        if p.mediaInterstitial?.url.path == item.url.path {
                            found = true; break
                        }
                        if p.mediaOutro?.url.path == item.url.path {
                            found = true; break
                        }
                        if p.mediaBackgroundImage?.url.path == item.url.path {
                            found = true; break
                        }
                    }
                    
                    if !found {
                        DispatchQueue.main.async {
                            FootageService.removeFromDisk(footage: item)
                            footageList.removeAll { v in
                                v.url.path == item.url.path
                            }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            updateFootageList()
                        })
                        
                        
                    }
                }
                
            }
        }
    }
}

