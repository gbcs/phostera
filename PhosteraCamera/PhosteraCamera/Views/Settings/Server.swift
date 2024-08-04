//
//  Server.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/16/23.
//

import SwiftUI
import PhosteraShared

struct ServerPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var pathSettings: [SettingsRoute]
    @State private var serverRunning = SettingsService.shared.settings.runServer
    @State private var allowNewDirector = SettingsService.shared.settings.allowNewDirectorToConnect
    @State private var displayName = SettingsService.shared.settings.displayName
    @FocusState private var focusedVal:Bool
    @State private var directorList:[DirectorModel] = DirectorService.shared.directorList()
    @State private var selectedDirector:DirectorModel?
    @State private var redrawList:Bool = false
 
    var body: some View {
        ZStack {
            //backgroundGradient.ignoresSafeArea()
            VStack() {
                List() {
                    Section("Your Identity") {
                        TextField("Name to show to Director",  text: $displayName
                        )
                        .focused($focusedVal)
                        .onSubmit {
                            if !displayName.isEmpty {
                                SettingsService.shared.settings.displayName = displayName
                                SettingsService.shared.save()
                            }
                        }
                        .textInputAutocapitalization(.words)
                    }

                    Section("Phostera Camera Server") {
                        if SettingsService.shared.settings.allowNetworking {
                            Toggle("Run Server (\(SettingsService.shared.settings.serverUUID))", isOn: $serverRunning).onChange(of: serverRunning) {
                                if serverRunning { ServerKeys.startServer() } else { ServerKeys.stopServer() }
                                SettingsService.shared.settings.runServer = serverRunning
                                SettingsService.shared.save()
                            }
                            
                            Toggle("Allow a new device to connect", isOn: $allowNewDirector).onChange(of: allowNewDirector) {
                                SettingsService.shared.settings.allowNewDirectorToConnect = allowNewDirector
                                SettingsService.shared.save()
                            }
                        } else {
                            ContentUnavailableView("Server Not Allowed", systemImage: "network", description: Text("Use the Settings app to enable local networking for PTCamera. You can find a link in Options, look for Permissions."))
                        }
                    }
                
                    Section("Phostera Directors and Streamers") {
                        if $directorList.count < 1 {
                            ContentUnavailableView("None Found", systemImage: "point.3.connected.trianglepath.dotted")
                        } else {
                           ForEach($directorList) { $director in
                               NavigationLink(destination: DirectorDetailPageView(pathSettings: $pathSettings, director: $director, redraw: false, directorList: $directorList), label: {
                                   Text("\(director.title) (\(director.uuid))")
                                       .foregroundStyle( CameraTakeService.shared.hasTakes(director: director) ? .accent : .primary )
                               })
                            }
                        }
                    }
                }
            }
        }
    }
}


