//
//  VideoItemDetailView.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import SwiftUI
import AVFoundation
import AVKit
import PhosteraShared

struct VideoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathLibrary: [LibraryRoute]
    @Binding var selectedItem:FootageFileItem
    @State var reload:Bool = false
    @State var player:AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player).onAppear() {
            let path = selectedItem.url
            let url = URL(fileURLWithPath: path)
            player = AVPlayer(url: url)
            if let player { player.play() }
        }
    }
}
