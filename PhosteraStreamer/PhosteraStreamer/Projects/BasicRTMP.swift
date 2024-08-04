//
//  BasicRTMP.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/23/23.
//

import SwiftUI
import PhosteraShared

struct BasicRTMPView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var streamName:String
    @Binding var streamURL:String
    @Binding var streamType:Int
    @State var localStreamURL:String = ""
    @State var localStreamName:String = ""
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Form {
                    Section(header: Text("Stream URL")) {
                        TextField("URL", text: $localStreamURL)
                    }
                    Section(header: Text("Stream Name")) {
                        TextField("URL", text: $localStreamName)
                    }
                    
                    Section(header: Text("Example RTMP URLs")) {
                        Button("RTMP") {
                            localStreamURL = "rtmp://192.168.1.100:1935/live"
                            localStreamName = "live"
                        }
//                        
//                        Button("RTMPS") {
//                            localStreamURL = "rtmps://192.168.1.100:1935/live"
//                            localStreamName = "live"
//                        }
                    }
                }
            }
        }.onAppear() {
       
        }.navigationBarTitleDisplayMode(.inline).navigationTitle("Basic RTMP")
            .navigationBarItems(trailing: Button("Accept") {
                streamURL = localStreamURL
                streamName = localStreamName
                streamType  = StreamServiceType.rtmp.rawValue
                dismiss()
            })
    }
    
    func populateDefault() {
        localStreamURL = "rtmp://192.168.1.100:1935/live/live/"
        streamName = "live"
    }
}
