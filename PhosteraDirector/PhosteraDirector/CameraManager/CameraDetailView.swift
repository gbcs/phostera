//
//  CameraDetail.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/22/23.
//

import SwiftUI
import AVFoundation
import PhosteraShared

#if os(macOS)
struct NSRepresentedPreviewView: NSViewRepresentable {
    typealias NSViewType = PreviewView
    @Binding var camera:CameraModel
    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView(camera: camera)
        return view
    }
    func updateNSView(_ nsView: PreviewView, context: Context) {
        
    }
}

#else
struct RepresentedPreviewView: UIViewRepresentable {
    typealias UIViewType = PreviewView
    @Binding var camera:CameraModel
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView(camera: camera)
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        
    }
}
#endif

struct CameraDetailView: View {
    @State var camera:CameraModel
    @State var viewUpdateTime: Bool = false
    
    var body: some View {
        ZStack {
            VStack {
                Text("This is the detail page. (project membership, any details about user, maybe free space, etc")
            }
        }.navigationTitle("Camera View")
    }
}

