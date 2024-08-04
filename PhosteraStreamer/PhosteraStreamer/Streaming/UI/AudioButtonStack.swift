//
//  AudioButtonStack.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/7/23.
//

import SwiftUI
import Combine
import PhosteraShared
import UIKit

struct AudioButtonStack : View {
    @State var selectedMicrophone:StreamMicrophoneSelection = .none
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
    
    func select(microphone:StreamMicrophoneSelection) {
        switch(microphone) {
        case .none:
           break
        case .host:
            break
        case .subject:
            break
        case .interview:
            break
        }
        selectedMicrophone = microphone
    }

    var body: some View {
        if viewUpdateTime || !viewUpdateTime {
            Button(action: {
                select(microphone: selectedMicrophone == .host ? .none : .host)
            }) {
                if selectedMicrophone == .host {
                    Image(systemName: "mic.circle.fill").foregroundStyle(.green)
                } else {
                    Image(systemName: "mic.circle")
                }
            }
           // .disabled(currentProject?.audioConfiguration.hostMicrophone == "")
                .frame(width: 44, height: 44, alignment: .leading)
            
            Button(action: {
                select(microphone: selectedMicrophone == .subject ? .none : .subject)
            }) {
                if selectedMicrophone == .subject {
                    Image(systemName: "mic.square.fill").foregroundStyle(.green)
                } else {
                    Image(systemName: "mic.square")
                }
            }.disabled(currentProject?.audioConfiguration.subjectMicrophone == "")
                .frame(width: 44, height: 44, alignment: .leading)
            
            Button(action: {
                select(microphone: selectedMicrophone == .interview ? .none : .interview)
            }) {
                if selectedMicrophone == .interview {
                    Image(systemName: "music.mic.circle.fill").foregroundStyle(.green)
                } else {
                    Image(systemName: "music.mic.circle")
                }
            }.disabled(currentProject?.audioConfiguration.interviewMicrophone == "")
                .frame(width: 44, height: 44, alignment: .leading)
                
                .onAppear() {
                startup()
                viewUpdateTime.toggle()
            }.onReceive(PubCentral.shared.projectListChanged, perform: { _ in
                DispatchQueue.main.async {
                    startup()
                    viewUpdateTime.toggle()
                }
            })
        }
    }
}
