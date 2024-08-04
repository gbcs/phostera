//
//  TakeListView.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/20/23.
//

import SwiftUI
import PhosteraShared

struct TakeListView: View {
    var director:DirectorModel
    var projectUUID:String
    var projectTitle:String
    @State var userWantsToDelete:Bool = false
    @State var takeList:[CameraTakeModel] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                List {
                    ForEach(takeList) { t in
                        NavigationLink {
                            TakeDetailView(take: t)
                        } label: {
                            Text("\(dateTimeStamp(take: t)) - \(durationString(take: t))").foregroundStyle(.primary)
                        }
                    }
                }
            }
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing, content: {
                Button(action: {
                    userWantsToDelete.toggle()
                }) {
                    Image(systemName: "trash")
                }
            })
        }.alert(isPresented: $userWantsToDelete) {
            Alert(title: Text("Delete"),
                  message: Text("This will delete the ALL of the takes in this project. Are you sure?"),
                  primaryButton: .destructive(Text("Yes")) {
                Logger.shared.info("User chose to delete project: \(projectUUID) \(projectTitle) for director: \(director.uuid) \(director.title)")
                Task {
                    let footageURL = URL.documentsDirectory
                        .appending(path: director.uuid, directoryHint: .isDirectory)
                        .appending(path: projectUUID, directoryHint: .isDirectory)
                    
                    let takesURL = URL.applicationSupportDirectory
                        .appending(path: "takes", directoryHint: .isDirectory)
                        .appending(path: projectUUID, directoryHint: .isDirectory)
                    
                    try? FileManager.default.removeItem(at: takesURL)
                    try? FileManager.default.removeItem(at: footageURL)
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
            },
                  secondaryButton: .cancel(Text("No")) {
            })
        }.onAppear() {
            getTakeList()
        }.navigationTitle("Take List for \(projectTitle)").navigationBarTitleDisplayMode(.inline)
    }

    func getTakeList() {
        
        let takeDirectory = URL.applicationSupportDirectory
            .appending(component: "takes", directoryHint: .isDirectory)
            .appending(component: projectUUID, directoryHint: .isDirectory)
        
        var tempList:[CameraTakeModel] = []
        takeList.removeAll()
        let decoder = JSONDecoder()
        if let list = try? FileManager.default.contentsOfDirectory(at: takeDirectory, includingPropertiesForKeys: [.isRegularFileKey]) {
            for takeFile in list {
                if let data = try? Data(contentsOf: takeFile) {
                    if let take = try? decoder.decode(CameraTakeModel.self, from: data) {
                        tempList.append(take)
                    }
                }
            }
        }
        takeList = tempList.sorted(by: { c1, c2 in
            c1.startTime > c2.startTime
        })
    }
    
    func durationString(take:CameraTakeModel) -> String {
        let duration = take.endTime.timeIntervalSince(take.startTime)
        return DateService.shared.componentStringFrom(duration: duration)
    }
    
    func dateTimeStamp(take:CameraTakeModel) -> String {
        return DateService.shared.dateTimeStamp(date: take.startTime)
    }
    
    
}
