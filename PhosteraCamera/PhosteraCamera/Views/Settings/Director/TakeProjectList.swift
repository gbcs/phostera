//
//  TakeViewer.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/20/23.
//

import SwiftUI
import PhosteraShared

struct TakeProjectList: View {
    @Binding var director: DirectorModel
    @State var projectList:[DirectorProjectModel] = []
    @State var projectTakeCount:[String:Int] = [:]
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                List {
                    ForEach($projectList, id: \.self) { $p in
                        NavigationLink {
                            TakeListView(director:director, projectUUID: p.uuid, projectTitle: p.title)
                        } label: {
                            if takeCount(project: p) > 0 {
                                Text(projectTitle(project: p))
                            } else {
                                Text(p.title)
                            }
                        }
                    }
                }
            }
        }.onAppear() {
            getTakeProjectsForDirector()
        }.navigationTitle("Projects for \(director.title)").navigationBarTitleDisplayMode(.inline)
    }
    
    func takeCount(project:DirectorProjectModel) -> Int {
        return projectTakeCount[project.uuid] ?? 0
    }
    
    func projectTitle(project:DirectorProjectModel) -> String {
        var answer = project.title
        
        let takeCount = takeCount(project: project)
        
        if takeCount > 0 {
            answer += " - \(takeCount) take(s)"
        }
        
        return answer
    }
    
    func getTakeProjectsForDirector() {
        projectList = DirectorProjectService.shared.projectListByDirector(director: director)
        
        for project in projectList {
            let takeURL = URL.applicationSupportDirectory
                .appending(path: "takes", directoryHint: .isDirectory)
                .appending(path: project.uuid, directoryHint: .isDirectory)
            
            var x:Int = 0
            if let y = try? FileManager.default.contentsOfDirectory(at: takeURL, includingPropertiesForKeys: [], options: .skipsSubdirectoryDescendants) {
                x = y.count
            }
            projectTakeCount[project.uuid] = x
        }
    }
    
}
