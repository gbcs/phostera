//
//  StreamDetailView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/23/23.
//

import SwiftUI
import PhosteraShared
import Combine

struct ProjectStreamDetailView: View {
    @ObservedObject var project: StreamProjectModel
    @State var update:Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State var streamName:String = ""
    @State var streamURL:String = ""
    @State var streamType: Int = StreamServiceType.unknown.rawValue
    
    @State var appearing:Bool = true
    @State var firstAppear:Bool = true
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Form {
                    Section(header: Text("Stream Type")) {
                        Picker("Stream Type", selection: $streamType) {
                            ForEach(StreamServiceType.allCases, id: \.self.rawValue) { res in
                                switch(res) {
//                                case .srt:
//                                    Text("SRT").tag(res.rawValue)
                                case .rtmp:
                                    Text("RTMP").tag(res.rawValue)
                                case .unknown:
                                    Text("None").tag(res.rawValue)
                                }
                            }
                        }
                    }
                    Section(header: Text("Configuration")) {
                        switch(streamType) {
//                        case StreamServiceType.srt.rawValue:
//                            VStack {
//                                TextField("srt uri", text: $streamURL)
//                                    .autocapitalization(.none)
//                                    .disableAutocorrection(true)
//                                    .keyboardType(.URL)
//                                TextField("Stream name", text: $streamName)
//                            }
                        case StreamServiceType.rtmp.rawValue:
                            VStack {
                                TextField("rtmp server", text: $streamURL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .keyboardType(.URL)
                                TextField("Stream name", text: $streamName)
                            }
                        case StreamServiceType.unknown.rawValue:
                            Text("")
                        default:
                            Text("")
                        }
                    }
                    
                    Section(header: Text("Configuration")) {
                        NavigationLink("Standard RTMP") {
                            BasicRTMPView(streamName: $streamName, streamURL: $streamURL, streamType: $streamType)
                        }
                        
                        NavigationLink("Youtube") {
                            YoutubeRTMPView(streamName: $streamName, streamURL: $streamURL, streamType: $streamType)
                        }
                    }
                }.onAppear() {
                    if firstAppear {
                        firstAppear = false
                        
                        streamType = project.config.service.rawValue
                        
                        switch(project.config.service) {
                        case .unknown:
                            break
                        case .rtmp:
                            streamName = project.config.name
                            streamURL = project.config.url
//                        case .srt:
//                            streamName = project.config.name
//                            streamURL = project.config.url
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            appearing = false
                        })
                    }
                }.navigationBarItems(trailing: Button("Accept") {
                    project.config.service = StreamServiceType(rawValue: streamType) ?? .unknown
                    project.config.name = streamName
                    project.config.url = streamURL
                    dismiss() })
            }
        }.navigationTitle("Streaming Service").navigationBarTitleDisplayMode(.inline)
    }
}
