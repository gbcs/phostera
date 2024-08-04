//
//  StreamListButtonStack.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/8/23.
//

import SwiftUI
import Combine
import PhosteraShared
import UIKit

struct StreamListButtonStack : View {
    @State var currentProject:StreamProjectModel?
    @State var viewUpdateTime:Bool = true
    
    func startup() {
        Task {
            let project = await ProjectService.shared.currentProject()
            DispatchQueue.main.async {
                currentProject = project
                viewUpdateTime.toggle()
            }
        }
    }
    
    func content() -> some View {
        Group {
            Button {
                
            } label: {
                Image(systemName: "mic.circle")
            }
            
            Button {
                
            } label: {
                Image(systemName: "mic.circle")
            }
            
            Button {
                
            } label: {
                Image(systemName: "mic.circle")
            }
        }
    }
    
    var body: some View {
        if viewUpdateTime || !viewUpdateTime {
            content()
                .onAppear() {
                    startup()
                }.onReceive(PubCentral.shared.projectListChanged, perform: { _ in
                    DispatchQueue.main.async {
                        startup()
                    }
                })
        }
    }
}
