//
//  Help.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/21/23.
//

import SwiftUI
import PhosteraShared

struct HelpView: View {
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
                            NavigationLink("Working with a project", destination: {
                                Text(
"""

Projects provide common camera settings and modes that are used with all cameras in the project.

Director modes store footage in takes and can be reviewed on the media page.

""")
                            })
                            
                            NavigationLink("Capturing Takes", destination: {
                                Text(
"""
The general workflow is as follows:

1) Connect cameras
2) Pick a mode
3) Start takes with the record button
4) Stop takes with the stop button
5) Put the cameras into standby mode
6) Wait until the standby progress indicators finish. This will have created any proxies and backed up footage to camera external storage.
7) Goto transfer mode, select the project and tap "Start Sync"
8) Take information will be collated and proxies downloaded, if configured.

""")
                            })
                            
                            NavigationLink("Editing", destination: {
                                Text(
"""

If you configure external storage on the cameras and the director, transferring footage and proxies is easy. 

If external storage is not an option, connect the cameras to your mac/pc and use Finder/etc to transfer footage.

For proxies, the director can collect them locally or on director external storage.

""")
                            })
                            
                            NavigationLink("Security", destination: {
                                Text(
"""
Cameras operated by others should not be considered secure from disclosure of recorded footage. As the camera owner, they likely retain the right to publish. If you direct cameras owned by others, get your agreement worked out ahead of time to avoid problems.

If you wish Streamers to have access to footage filmed with one of your director modes, you can enable that on a per-project basis.

The connection between cameras and directors/streamers is reasonably secure.


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
Phostera Cameras visible on your local network can be controlled from this Director (with owner permission.)

Director modes control which lens and project settings control resolution, frame rate and media encoding.

Proxy footage can be transferred to the Director over the network.

External storage is supported throughout.

""")
                        }
                    } label: {
                        Text("Working with Phostera Cameras")
                    }
       
                    
                    NavigationLink {
                        VStack {
                            Text(
"""
Phostera Streamer can stream what any connected Phostera Camera is currently seeing to the world.

It can also download (to then stream) any footage stored that has been taken via one of the Director modes, if your project setting allows it.

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
                            Text(ProductInfo.termsOfUseDirector)
                   
                        }
                    } label: {
                        Text("Terms of Use")
                    }
                }
                
                Section("Program Information") {
                    HStack {
                        Text("Product")
                        Spacer()
                        Text("Phostera Director")
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
