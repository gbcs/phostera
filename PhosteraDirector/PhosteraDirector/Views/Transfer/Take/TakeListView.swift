//
//  TakeListView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/17/23.
//

import Foundation
import SwiftUI
import Combine
import PhosteraShared

struct TakeListView: View {
    @Environment(\.dismiss) private var dismiss
    @State var update:Bool = false
    @State var takeList:[DirectorTakeModel] = []
    @State var workOnTransferQueue:Bool = false
    @State var project:DirectorProjectModel?
    @State var transferMessage:String = ""
    @State var showingDeleteMessage:Bool = false
    
    func durationString(take:DirectorTakeModel) -> String {
        let duration = take.endTime.timeIntervalSince(take.startTime)
        return DateService.shared.componentStringFrom(duration: duration)
    }
    
    func dateTimeStamp(take:DirectorTakeModel) -> String {
        return DateService.shared.dateTimeStamp(date: take.startTime)
    }

    var body: some View {
        Form {
            Section("Copy Proxies", content: {
                Button(workOnTransferQueue ? "Stop Sync" : "Start Sync", action: {
                    //TakeTransferQueue.debugDeleteAllProxies()
                    workOnTransferQueue.toggle()
                    if workOnTransferQueue {
                        var media:URL?
                        if let project {
                            for m in ExternalStorageService.storageList() {
                                if let mediaURL = ExternalStorageManager.loadExernalStorage(media: m) {
                                    if mediaURL.startAccessingSecurityScopedResource() {
                                        media = mediaURL
                                    }
                                }
                            }
                            TakeTransferQueue.shared.start(project: project, media: media)
                        }
                    } else {
                        TakeTransferQueue.shared.stop()
                    }
                })
                if transferMessage != "" {
                    Text(transferMessage)
                } else {
                    Text("Proxies are created when camera is in standby mode.").font(.caption.lowercaseSmallCaps())
                }
            })
            
            Section("Take List", content: {
                List {
                    ForEach(takeList) { t in
                        NavigationLink {
                            TakeDetailView(take: t)
                        } label: {
                            Text("\(dateTimeStamp(take: t)) - \(durationString(take: t))").foregroundStyle(.primary)
                        }
                    }
                }
            }) .actionSheet(isPresented: $showingDeleteMessage) {
                ActionSheet(
                    title: Text("Delete ALL takes"),
                    message: Text("Delete the takes in this project, including ALL videos from this project that are stored on this device?"),
                    buttons: [
                        .destructive(Text("Delete")) {
                            Task {
                                if let project {
                                    DirectorProjectService.removeAllTakesAndMediaFor(project: project)
                                }
                                DispatchQueue.main.async {
                                    self.showingDeleteMessage = false
                                    updateTakeList()
                                }
                            }
                        },
                        .cancel() {
                            self.showingDeleteMessage = false
                        }
                    ]
                )
                
                
            }
        } .onReceive(TakeTransferQueue.shared.$bytesTransferred, perform: { msg in
            DispatchQueue.main.async {
                transferMessage = "\(msg) bytes transferred."
            }
        }).onReceive(TakeTransferQueue.shared.$updateMessage, perform: { msg in
            DispatchQueue.main.async {
                if msg == "stopped" {
                    workOnTransferQueue = false
                    transferMessage = "Complete"
                } else {
                    transferMessage = msg
                }
            }
        })
            .toolbar {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    showingDeleteMessage.toggle()
                }) {
                    Image(systemName: "trash")
                }
            })
        }.onAppear() {
           updateTakeList()
        }.frame(minWidth: 200, idealWidth: 200, maxWidth: .infinity, minHeight: 200, idealHeight: 400, maxHeight: .infinity, alignment: .center)
            .navigationTitle("Media").navigationBarTitleDisplayMode(.inline)
    }
    
    func updateTakeList() {
        if let project = DirectorProjectService.currentProject() {
            takeList = TakeService.shared.getTakes(project:project).sorted(by: { t, t2 in
                t.startTime > t2.startTime
            })
      
            update.toggle()
        }
    }
}


