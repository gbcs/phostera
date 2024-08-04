//
//  Help.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import SwiftUI
import PhosteraShared

struct HelpPageView: View {
    var body: some View {
        GeometryReader { geo in
            List {
                Section("Phostera Community Forum") {
                    Text("Get help, give feedback, tell stories")
                    Text("https://community.phostera.com/")
                }
                
                Section("How to Use") {
                    NavigationLink {
                        List { 
                            NavigationLink("Selecting a mode", destination: {
                                Text(
"""
Modes are divided into personal and director.

Personal modes store footage that can be reviewed in the library page.

Director modes store footage in takes and can be reviewed in the server page of settings.

""")
                            })
                            
                            NavigationLink("Capturing Footage", destination: {
                                Text(
"""
The record button will start and end a recording. Footage can be reviewed on the library page.
""")
                            })
                            
                            NavigationLink("Editing", destination: {
                                Text(
"""
To edit footage, either use the library page to copy the footage to the Photo Album, a PC or Mac to copy the footage for editing or copy to external storage for later editing.
""")
                            })
                            
                            NavigationLink("Security", destination: {
                                Text(
"""
To restrict previously connected directors or streamers, use the Block feature in the Server page of Settings.

To manage footage filmed for a director, use the View Takes feature, on a given director, in the Server page of Settings.

To disable sharing from your device, switch the 'Run Server' feature in the Server page of Settings, to off.

Note that if the camera is not running, the server is not running. It only runs when the app is showing on screen.
""")
                            })
                        }
                    } label: {
                        Text("Features")
                    }
          
                    NavigationLink {
                        VStack {
                            Text(
"""
Phostera Director will install a project, which will contain a number of camera modes.

When using one of these modes, footage will be stored by take and is available to the Director when it is in range.

Generally it is recommended to install external storage on the cameras and configure the director to backup footage to storage and to collect proxy versions of the footage for review/streaming over the network.

""")
                        }
                    } label: {
                        Text("Working with Phostera Director")
                    }
                    
                    NavigationLink {
                        VStack {
                            Text(
"""
A connected Phostera streamer can stream what your camera is currently seeing to the world.

It can also download (to then stream) any footage stored on your camera that has been taken via one of the Director modes.

Footage taken with a Personal mode is not shared to Streamers and Directors.
""")
                        }
                    } label: {
                        Text("Working with Phostera Streamer")
                    }
                }
                
                Section("Phostera Legal") {
                    NavigationLink {
                        ScrollView {
                            Text(ProductInfo.privacyPolicy)
                   
                        }
                    } label: {
                        Text("Privacy Policy")
                    }
                    
                    NavigationLink {
                        ScrollView {
                            Text(ProductInfo.termsOfUseCamera)
                   
                        }
                    } label: {
                        Text("Terms of Use")
                    }
                }
                
                Section("Program Information") {
                    HStack {
                        Text("Product")
                        Spacer()
                        Text("Phostera Camera")
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
