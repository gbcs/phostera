//
//  ContentView.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/15/23.
//

#if os(macOS)
import AppKit
#endif

import SwiftUI
import Network
import PhosteraShared
import AVFAudio

enum SheetToView: Identifiable {
    case transfer, help, settings
    
    var id: Int {
        switch self {
        case .transfer: return 0
        case .help: return 1
        case .settings: return 2
        }
    }
}

struct ContentView: View {
    @State private var sheetSelectedView: SheetToView? = nil
    @State private var disableRecordButton:Bool = true
    @State private var disableModeButton:Bool = true
    @State private var showModeView = false
    @State private var path:[OnboardingRoute] = []
    @State private var updateViewToggle:Bool = false
    private var toneGenerator = AudioController()
    
#if os(macOS)
    func showNewWindow<Content: View>(with content: Content) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("New Window")
        window.contentView = NSHostingView(rootView: content)
        window.makeKeyAndOrderFront(nil)
    }
#endif
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if updateViewToggle || !updateViewToggle {
                    if SettingsService.shared.settings.needsOnboarding {
                        NavigationStack(path: $path) {
                            WelcomePageView(path: $path).onReceive(PubCentral.shared.onboardingComplete, perform: { _ in
                                SettingsService.shared.settings.needsOnboarding = false
                                SettingsService.shared.save()
                                path = []
                                updateViewToggle.toggle()
                                startupServices()
                            })
                        }
                    } else {
                        NavigationStack(path: $path, root: {
                                HStack {
                                    WatchViewControllerView().frame(minWidth: geometry.size.width - WatchEntryManager.shared.cameraControlsViewWidth).id("Watcher")
                                    if let selectedUUID = WatchEntryManager.shared.selectedUUID {
                                        CameraControlsView(uuid:selectedUUID).frame(maxWidth: WatchEntryManager.shared.cameraControlsViewWidth)
                                    } else {
                                        CameraControlsView(uuid:"").frame(maxWidth: WatchEntryManager.shared.cameraControlsViewWidth)
                                    }
                                }
                            .background(.black)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .toolbar {
                                    ToolbarItem(placement: .topBarLeading) {
                                        HStack {
#if os(macOS)
                                            Button("folder.badge.gear") { showNewWindow(with: ProjectsView()) }
#else
                                            NavigationLink(destination: ProjectManagerView(), label: { Image(systemName: "filemenu.and.selection") })
#endif
#if os(macOS)
                                            Button("Cameras") { showNewWindow(with: CameraManagerView()) }
#else
                                            NavigationLink(destination: CameraManagerView(), label: { Image(systemName: "camera") }).frame(alignment:.leading)
#endif
                                            NavigationLink(destination: TransferView(), label: { Image(systemName: "plus.rectangle.on.folder") })
                                        }
                                    }
                                }.onReceive(PubCentral.shared.selectedChanged, perform: { _ in
                                    let count = WatchEntryManager.shared.getAvailableCameras().count
                                    disableRecordButton = count < 1
                                    disableModeButton = count < 1
                                    updateViewToggle.toggle()
                                })
                                .toolbar {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        HStack {
                                            Button {
                                                let cameraList = CameraManager.shared.availableUUIDs
                                                _ = TakeService.shared.startTake(cameras: [])
                                        
                                                for uuid in cameraList {
                                                    Task(priority: .userInitiated, operation: {
                                                        if let c = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                                            await c.requestFromCamera(content: CameraRequest(command: .startTake, uuid: uuid, sesionKey: c.sessionKey,dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                                            addTakeCamera(uuid: uuid)
                                                        }
                                                    })
                                                }
                                                
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                                                    if let currentTake = TakeService.shared.currentTake {
                                                        TakeService.save(take: currentTake)
                                                    }
                                                })
                                            } label: {
                                                Image(systemName: "record.circle")
                                            }.frame(alignment:.trailing).disabled(disableRecordButton)
                                            
                                            Button {
                                                if let currentTake = TakeService.shared.currentTake {
                                                    TakeService.shared.stop(take: currentTake)
                                                }
                                                
                                                let cameraList = CameraManager.shared.availableUUIDs
                                                for uuid in cameraList {
                                                    Task(priority: .userInitiated, operation: {
                                                        if let c = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                                            await c.requestFromCamera(content: CameraRequest(command: .endTake, uuid: uuid, sesionKey: c.sessionKey,dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                                        }
                                                    })
                                                }
                                            } label: {
                                                Image(systemName: "stop.fill")
                                            }.frame(alignment:.trailing).disabled(disableRecordButton)
                                            
                                            Button {
                                                showModeView.toggle()
                                            } label: {
                                                Image(systemName: "timeline.selection")
                                            }.frame(alignment:.trailing).disabled(disableModeButton)
                                                .popover(isPresented: $showModeView) {
                                                    if UIDevice.current.userInterfaceIdiom == .pad {
                                                        ModeView()
                                                    } else {
                                                        NavigationStack {
                                                            ModeView()
                                                        }
                                                    }
                                                }
                                        }
                                    }
                                }.sheet(item: $sheetSelectedView) { item in
                                    switch item {
                                    case .transfer:
                                        TransferView()
                                    case .help:
                                        HelpView()
                                    case .settings:
                                        SettingsView()
                                    }
                                }.onAppear() {
                                    let count = WatchEntryManager.shared.getAvailableCameras().count
                                    disableRecordButton = count < 1
                                    disableModeButton = count < 1
                                    DirectorProjectService.checkOnStartup()
                                    WatchEntryManager.shared.collectionViewWidth = geometry.size.width - WatchEntryManager.shared.cameraControlsViewWidth
                                    if !SettingsService.shared.settings.needsOnboarding {
                                        startupServices()
                                    }
                                }
                        })
                    }
                }
            }
        }
    }
    
    func addTakeCamera(uuid:String) {
        if let currentTake = TakeService.shared.currentTake {
            currentTake.cameraUUIDs.append(uuid)
        }
    }
    
    func startupServices() {
//        let session = AVAudioSession.sharedInstance()
//        do {  try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth]) } catch { Logger.shared.info("setupAudioSession fail1"); return }
//        do {  try session.setPreferredSampleRate(48000) } catch { Logger.shared.info("setupAudioSession fail2b"); return }
//        do {  try session.setPreferredInputNumberOfChannels(session.maximumInputNumberOfChannels) } catch { Logger.shared.info("setupAudioSession fail2"); return }
//        do {  try session.setPreferredOutputNumberOfChannels(session.maximumOutputNumberOfChannels) } catch { Logger.shared.info("setupAudioSession fail3"); return }
//        do {  try session.setActive(true) } catch { Logger.shared.info("setupAudioSession fail4"); return }
        
        WatchEntryManager.shared.startWatching()
        Task {
            await NetworkHandler.shared.finder(beUp: true)
        }
    }
}

#if os(macOS)
struct WatchViewControllerView: NSViewRepresentable {
    // Your data here
    
    func makeNSView(context: Context) -> WatchViewController {
        let collectionView = WatchViewController()
        // Configure collectionView here
        return collectionView
    }
    
    func updateNSView(_ nsView: WatchViewController, context: Context) {
        // Update code here
    }
}
#else
struct WatchViewControllerView: UIViewControllerRepresentable {
    // Your data here
    
    func makeUIViewController(context: Context) -> WatchViewController {
        let vc = WatchViewController()
        return vc
    }
    
    func updateUIViewController(_ uiViewController: WatchViewController, context: Context) {
        uiViewController.view.frame.size.width = WatchEntryManager.shared.collectionViewWidth
        uiViewController.collectionView.reloadData()
    }
}
#endif
