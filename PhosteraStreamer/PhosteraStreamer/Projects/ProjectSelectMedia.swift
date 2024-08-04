//
//  ProjectSelectMedia.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/12/23.
//

import SwiftUI
import PhosteraShared
import Combine



struct ProjectSelectMediaView: View {
    @ObservedObject var project: StreamProjectModel
    var mediaType:StreamProjectMediaType
    @State var mediaList:[FootageModel] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Form {
                    Section(header: Text("Media")) {
                        List {
                            ForEach(mediaList) { p in
                                Text("\(p.name == "" ? p.url.lastPathComponent : p.name)").tag(p.id).onTapGesture {
                                    switch(mediaType) {
                                    case .backgroundImage:
                                        project.mediaBackgroundImage = p
                                    case .interstitial:
                                        project.mediaInterstitial = p
                                    case .intro:
                                        project.mediaIntro = p
                                    case .outro:
                                        project.mediaOutro = p
                                    case .preroll:
                                        project.mediaPreroll = p
                                    }
                                    Task {
                                        DispatchQueue.main.async {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }.onAppear() {
            Task {
                let list:[FootageModel]?
                if mediaType == .backgroundImage {
                    list = await FootageService.shared.getPhotos()
                } else {
                    list = await FootageService.shared.getVideos()
                }
                DispatchQueue.main.async {
                    if let list {
                        mediaList = list
                    }
                }
            }
        }
    }
}
