//
//  ModeView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import Foundation
import SwiftUI
import PhosteraShared

struct ModeCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathSettings: [SettingsRoute]
    @Binding var modeModel:DirectorProjectCameraMode

    func directorTitle() -> String {
        if modeModel.provider == "" { return "" }
        let director = DirectorService.shared.directorList().filter { d in  d.uuid == modeModel.provider }.first
        if let director {
            return director.title
        }
        return  ""
    }
    
    func projectTitle() -> String {
        if modeModel.projectUUID == "" { return "" }
        let director = DirectorService.shared.directorList().filter { d in  d.uuid == modeModel.provider }.first
        if let director {
            let project = DirectorProjectService.shared.projectListByDirector(director: director).filter { p in p.uuid == modeModel.projectUUID }.first
            if let project {
                return project.title + " - "
            }
        }
      
        return ""
    }
    
    
    var body: some View {
  
            VStack {
                Text("\(projectTitle())\(modeModel.title)")
                Text("\(modeModel.desc == "" ? "" : modeModel.desc + " - ")\(directorTitle())")
                
            }.frame(minHeight: 60)
        
    }
}
