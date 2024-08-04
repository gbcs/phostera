//
//  ProjectAudioConfigView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/30/23.
//

import SwiftUI
import PhosteraShared
import Combine
import AVFoundation


struct ProjectAudioConfigView: View {
    @ObservedObject var project: StreamProjectModel
    @State var update:Bool = false
    @Environment(\.dismiss) private var dismiss
    @State var outputPortList:[AVAudioSessionPortDescription] = []
    @State var inputPortList:[AVAudioSessionPortDescription] = []
    @State var appearing:Bool = true
    
    @State var hostMicrophone:String = ""
    @State var subjectMicrophone:String = ""
    @State var interviewMicrophone:String = ""
    
    func audioOutputText(port:AVAudioSessionPortDescription) -> some View {
        let portName = port.portName
        
        if portName == "Speaker" {
            return AnyView (Group {
                HStack {
                    Text("Speaker")
                    Text("This is not recommended. Use a headset or equivalent.").font(.caption.lowercaseSmallCaps())
                }
            })
        }
        
        return AnyView(Text("\(portName)"))
    }
    
    func audioInputText(port:AVAudioSessionPortDescription) -> some View {
        let portName = port.portName
        
        return AnyView(Text("\(portName)"))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Form {
                    Section(header: Text("Audio Output")) {
                        ForEach($outputPortList, id: \.self.uid) { $port in
                            audioOutputText(port: port)
                        }
                    }
                    
                    if !appearing {
                        Section(header: Text("Microphones")) {
                            Picker("Host Microphone", selection: $hostMicrophone) {
                                ForEach(inputPortList, id: \.uid) { port in
                                    Text(port.portName).tag(port.uid)
                                }
                            }
                            Text("Select the microphone the host will speak into. (Front microphone or external input)").font(.caption.lowercaseSmallCaps())
                            
                            Picker("Subject Microphone", selection: $subjectMicrophone) {
                                ForEach(inputPortList, id: \.uid) { port in
                                    Text(port.portName).tag(port.uid)
                                }
                            }
                            Text("Select the microphone that will cover the subject of the stream (rear microphone or external input)").font(.caption.lowercaseSmallCaps())
                            
                            Picker("Interview Microphone", selection: $interviewMicrophone) {
                                ForEach(inputPortList, id: \.uid) { port in
                                    Text(port.portName).tag(port.uid)
                                }
                            }
                            Text("Select an alternate microphone used for interviewing.").font(.caption.lowercaseSmallCaps())
                        }
                    }
                }.onAppear() {
                    if appearing {
                        outputPortList = AVAudioSession.sharedInstance().currentRoute.outputs
                        inputPortList = AVAudioSession.sharedInstance().availableInputs ?? []
                        
                        if project.audioConfiguration.hostMicrophone == "" {
                            project.audioConfiguration.hostMicrophone = inputPortList.first?.uid ?? ""
                        }
                        
                        if project.audioConfiguration.subjectMicrophone == "" {
                            project.audioConfiguration.subjectMicrophone = inputPortList.first?.uid ?? ""
                        }
                        
                        if project.audioConfiguration.interviewMicrophone == "" {
                            project.audioConfiguration.interviewMicrophone = inputPortList.first?.uid ?? ""
                        }
                        
                        hostMicrophone = project.audioConfiguration.hostMicrophone
                        subjectMicrophone = project.audioConfiguration.subjectMicrophone
                        interviewMicrophone = project.audioConfiguration.interviewMicrophone
                        
                    }
                   
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        appearing = false
                    })
                }.navigationBarItems(trailing: Button("Accept") {
                    project.audioConfiguration.hostMicrophone = hostMicrophone
                    project.audioConfiguration.subjectMicrophone = subjectMicrophone
                    project.audioConfiguration.interviewMicrophone = interviewMicrophone
                    
                    dismiss() })
            }
        }.navigationTitle("Audio Configuration").navigationBarTitleDisplayMode(.inline)
    }
}
