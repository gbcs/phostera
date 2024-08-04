//
//  YoutubeRTMP.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/23/23.
//

import SwiftUI
import PhosteraShared

struct YoutubeRTMPView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var streamName:String
    @Binding var streamURL:String
    @Binding var streamType:Int
    @State var localStreamURL:String = ""
    @State var update:Bool = false
    @State var localStreamName:String = ""
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if update || !update {
                    Form {
                        Section(header: Text("Stream URL")) {
                            TextField("URL", text: $localStreamURL)
                        }
                        
                        Section(header: Text("Stream Key")) {
                            TextField("Key", text: $localStreamName, onEditingChanged: { _ in
                                localStreamURL = defaultStreamURL() + localStreamName
                                update.toggle()
                            }).autocorrectionDisabled().textInputAutocapitalization(.none)
                        }
                        
                        Section(header: Text("Default Youtube URLs")) {
                            Button("RTMP") {
                                localStreamURL = "rtmp://a.rtmp.youtube.com/live2/"
                            }
                            
                            //                        Button("RTMPS") {
                            //                            localStreamURL = "rtmps://a.rtmp.youtube.com/live2/"
                            //                        }
                        }
                    }
                }
            }
        }
        .onAppear() {
            if streamURL == "" {
                localStreamURL = defaultStreamURL()
               
            }
            localStreamName = streamName
        }.navigationBarTitleDisplayMode(.inline).navigationTitle("Youtube - RTMP")
            .navigationBarItems(trailing: Button("Accept") {
                streamURL = localStreamURL
                streamName = localStreamName
                streamType  = StreamServiceType.rtmp.rawValue
                dismiss()
            })
    }
    
    func defaultStreamURL() -> String {
        return "rtmp://a.rtmp.youtube.com/live2/"
    }
}
