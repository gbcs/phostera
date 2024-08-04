//
//  MediaPlayer.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/29/23.
//

import SwiftUI
import PhosteraShared
import AVKit

struct MediaPlayer: View {
    @Environment(\.dismiss) private var dismiss
    var media:URL
    @State var player:AVPlayer?
    var project:DirectorProjectModel
    var cameraUUID:String
    @State var externalStorage:Bool = false
    @State var mediaURL:URL?
    
    var body: some View {
        VStack {
            if let player {
                VideoPlayer(player:player)
            }
        }.onAppear() {
            if project.proxyStorageLocation == .externalStorage {
                for m in ExternalStorageService.storageList() {
                    mediaURL = ExternalStorageManager.loadExernalStorage(media: m)
                    if let mediaURL {
                        if mediaURL.startAccessingSecurityScopedResource() {
                            let answer = FileManager.default.fileExists(atPath: media.path())
                            if answer {
                                externalStorage = true
                            } else {
                                mediaURL.stopAccessingSecurityScopedResource()
                            }
                        }
                    }
                }
            }
            
            player = AVPlayer(url: media)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                if let player {
                    if player.status == .readyToPlay {
                        player.play()
                    }
                }
            })
        }.navigationTitle("Play Camera Take")
            .onDisappear() {
                if externalStorage, let mediaURL {
                    mediaURL.stopAccessingSecurityScopedResource()
                }
            }
    }
   
}


