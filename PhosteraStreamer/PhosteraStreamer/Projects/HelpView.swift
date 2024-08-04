//
//  HelpView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/19/23.
//

import SwiftUI
import PhosteraShared

struct HelpView: View {
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                List {
                    Section("Phostera Community Forum") {
                        Text("Get help, give feedback, tell stories")
                        Text("https://community.phostera.com/")
                    }
                    
                    Section("Usage Information") {
                        NavigationLink {
                            ScrollView {
                                Text(
                                    """
Navigate to the Projects page, select the default project (or create one.)

Select your audio configuration and your streaming configuration.

Youtube and nginx via RTMP configurations were tested for this release.

Once you have selected a configuration, tap the Globe on the Stream page. It will connect and run your Preroll video, then introduction.

To pause the stream tap 'Live' and tap 'Paused' to return to 'Live'. Tap the Globe to end your stream.

To play media, tap one or more items to play on the Media page, then use the media button (right-hand, above the camera numbers, to enage the media player.
The bar on the bottom lets you move the play position and tapping the screen will play/pause video.

Microphones may be selected with the icons on the left of the stream. Volume control is the upper control. When no microphone is selected, this controls media volume.

Both front and rear cameras are supported at the same time. The Grid button on the top right allows for location of the front camera to your specifications.

Rear camera is presented full screen. For an iPad with an external camera attached, it will replace the rear camera. For an iPhone, wide, ultrawide and telephoto lens are supported.

Phostera cameras may be streamed through the Cameras page and the buttons on the right.


"""
)
                            }.padding()
                        } label: {
                            Text("How to stream")
                        }
                        
                        NavigationLink {
                            ScrollView {
                                Text(
"""
Consider the legal implications of streaming in your locality.

There is no edit step between what your camera sees and what you are publishing.

This creates potential liability. Be aware and manage this to avoid legal issues.
""")
                            }.padding()
                        } label: {
                            Text("Privacy and legal implications")
                        }
                        
                        NavigationLink {
                            ScrollView {
                                Text(
"""
You can stream the output of any Phostera Camera (owner willing.) on your stream by selecting a camera from the Cameras page, pairing it (if not already done) and then tapping on the play button. 

This will change to a number, which corresponds to the number on the stream page, right-hand side.

Tapping that number will engage and disengage the camera from the stream.

In this manner, you can have many cameras, and make any four of them available to easily switch between.

Note that for version 1.0, audio is not streamed and reliable video streaming is best accomplished by connecting an ethernet connection between the cameras.
"""
                                )
                            }.padding()
                        } label: {
                            Text("Connecting to Phostera Cameras")
                        }
                        
                        NavigationLink {
                            ScrollView {
                                Text("Phostera Director manages Phostera Cameras. If the director's project allows it, you may tap on the library icon of any camera, browse the recorded footage and download it. This footage can then be streamed.")
                            }.padding()
                        } label: {
                            Text("Working with Phostera Director")
                        }
                    }
                    
                    Section("Phostera Legal") {
                        NavigationLink {
                            ScrollView {
                                Text(ProductInfo.privacyPolicy)
                       
                            }.padding()
                        } label: {
                            Text("Privacy Policy")
                        }
                        
                        NavigationLink {
                            ScrollView {
                                Text(ProductInfo.termsOfUseStreamer)
                       
                            }.padding()
                        } label: {
                            Text("Terms of Use")
                        }
                    }
                    
                    Section("Program Information") {
                        HStack {
                            Text("Product")
                            Spacer()
                            Text("Phostera Streamer")
                        }
                        HStack { 
                            Text("Version")
                            Spacer()
                            Text("\(VersionInfo.productVersion).\(VersionInfo.buildNumber)")
                        }
                        HStack {
                            Text("Copyright © 2023 Phostera, LLC. All rights reserved.")
                        }
                    }
                }.listStyle(.grouped)
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
