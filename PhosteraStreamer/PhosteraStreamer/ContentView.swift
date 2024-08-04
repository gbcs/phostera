//
//  ContentView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/4/23.
//

import SwiftUI
import Combine
import AVFAudio

struct ContentView: View {
    @State var updateViewToggle:Bool = false
    @State var currentProjectTitle:String = ""
    
    var body: some View {
        ZStack {
            if updateViewToggle || !updateViewToggle {
                if SettingsService.shared.settings.needsOnboarding {
                    NavigationStack {
                        WelcomePageView()
                    }
                } else {
                    TabView {
                        NavigationStack {
                            StreamManagerView()
                        }
                        .tabItem {
                            Label("Stream", systemImage: "waveform.path")
                        }
                        
                        NavigationStack {
                            FootageManagerView()
                        }
                        .tabItem {
                            Label("Media", systemImage: "photo")
                        }
                        
                        NavigationStack {
                            CameraManagerView()
                        }
                        .tabItem {
                            Label("Cameras", systemImage: "camera")
                        }

                        NavigationStack {
                            ProjectManagerView()
                        }
                        .tabItem {
                            Label("Projects", systemImage: "briefcase")
                        }
                    }
                }
                
            }
        }.onReceive(PubCentral.shared.projectListChanged, perform: { _ in
            updateProjectInfo()
        }).onReceive(PubCentral.shared.onboardingComplete, perform: { _ in
            updateViewToggle.toggle()
            setupAudio()
            WatchEntryManager.shared.startWatching()
        }).onReceive(PubCentral.shared.pubEnterBackground, perform: { _ in
            shutdownServices()
        }).onReceive(PubCentral.shared.pubWillEnterForeground, perform: { _ in
            startupServices()
            DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.restarted, object: nil) }
        })
        .onAppear() {
            startupServices()
        }
    }
    
    func setupAudio() {
        do {
            try AudioSession.shared.start()
            AudioTool.shared.startEngine()
        } catch {
            Logger.shared.error("Audio setup error \(error.localizedDescription)")
        }
    }
    
    func updateProjectInfo() {
        Task {
            let project = await ProjectService.shared.currentProject()
            DispatchQueue.main.async {
                currentProjectTitle = project.title
                updateViewToggle = !updateViewToggle
            }
        }
    }
   
    func startupServices() {
        _ = try? ServerKeys.keysForServer()
        FootageService.loadInitialDefaultContent()

        if !SettingsService.shared.settings.needsOnboarding {
            Task {
                let project = await ProjectService.shared.currentProject()
                DispatchQueue.main.async {
                    currentProjectTitle = project.title
                    updateViewToggle = !updateViewToggle
                    
                    setupAudio()
                    AudioDiscovery.shared.discoverAudio()

                    WatchEntryManager.shared.startWatching()
          
                    Task {
                        await NetworkHandler.shared.finder(beUp: true)
                        DispatchQueue.main.async {
                            updateViewToggle.toggle()
                        }
                    }
                }
            }
        }
    }
    
    func shutdownServices() {
        if !SettingsService.shared.settings.needsOnboarding {
            Task {
                await NetworkHandler.shared.finder(beUp: false)
                DispatchQueue.main.async {
                    WatchEntryManager.shared.stopWatching()
                    AudioTool.shared.stopEngine()
                }
            }
        }
    }
}
