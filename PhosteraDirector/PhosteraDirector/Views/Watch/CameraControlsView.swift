//
//  CameraControlsView.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/3/23.
//

import UIKit
import SwiftUI
import AVFoundation
import Combine
import PhosteraShared

struct CameraControlsCard: View {
    @Binding var value:String
    var title:String
    @Binding var locked:Bool
    @Binding var changing:Bool
    
    var body: some View {
        ZStack {
            if locked {
                Color(red: 1, green: 0, blue: 0, opacity: 0.2).padding(.horizontal, 10)
            } else if changing {
                Color(red: 0, green: 1, blue: 0, opacity: 0.2).padding(.horizontal, 10)
            }
            VStack {
                HStack {
                    if locked {
                        Image(systemName: "lock.circle").frame(alignment: .leading)
                    }
                    Text(title).frame(alignment: .center).foregroundColor(.white)
                }
                
                Text(value).foregroundColor(.white)
            }
        }
    }
}

struct CameraControlsView: View {
    @State var displayValues:Bool = false
    @State var whiteBalanceModeLocked:Bool = false
    @State var adjustingWhiteBalance:Bool = false
    @State var whiteBalanceTemperature:String = ""
    @State var whiteBalanceTint:String = ""
    @State var adjustingExposure:Bool = false
    @State var exposureModeLocked:Bool = false
    @State var exposurePOI:CGPoint = .zero
    @State var exposureISO:String = ""
    @State var exposureShutter:String = ""
    @State var focusPOI:CGPoint = .zero
    @State var focusModeLocked:Bool = false
    @State var adjustingFocus:Bool = false
    @State var lensPosition:String = ""
    @State var recordingState:Bool = false
    @State var horizonPreviewAngle:CGFloat = .zero
    @State var sessionResolution:String = ""
    @State var sessionFrameRate:String = ""
    @State var batteryLevel:String = ""
    @State var batteryCharging:Bool = false
    @State var diskFree:String = ""
    @State var pressureInfo:String = ""
    @State var cancellables:[AnyCancellable] = []
    @State var alwaysFalse:Bool = false
    @State var uuid:String = ""
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 100))
                    ], spacing: 8) {
                        HStack {  Text("Controls") }
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        CameraControlsCard(value: $exposureISO, title: "ISO", locked: $exposureModeLocked, changing: $adjustingExposure).onTapGesture {
                            Task(priority: .userInitiated, operation: {
                                if let camera = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                    await camera.requestFromCamera(content: CameraRequest(command: .toggleExposureLock, uuid: uuid, sesionKey: camera.sessionKey,
                                                                                          dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                }
                            })
                        }
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        CameraControlsCard(value: $exposureShutter, title: "Shutter", locked: $exposureModeLocked, changing: $adjustingExposure).onTapGesture {
                            Task(priority: .userInitiated, operation: {
                                if let camera = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                    await camera.requestFromCamera(content: CameraRequest(command: .toggleExposureLock, uuid: uuid, sesionKey: camera.sessionKey,
                                                                                          dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                }
                            })
                        }
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        CameraControlsCard(value: $whiteBalanceTemperature, title: "WB-Temp", locked: $whiteBalanceModeLocked, changing: $adjustingWhiteBalance).onTapGesture {
                            Task(priority: .userInitiated, operation: {
                                if let camera = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                    await camera.requestFromCamera(content: CameraRequest(command: .toggleWhiteBalanceLock, uuid: uuid, sesionKey: camera.sessionKey,
                                                                                          dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                }
                            })
                        }
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        CameraControlsCard(value: $whiteBalanceTint, title: "WB-Tint", locked: $whiteBalanceModeLocked, changing: $adjustingWhiteBalance).onTapGesture {
                            Task(priority: .userInitiated, operation: {
                                if let camera = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                    await camera.requestFromCamera(content: CameraRequest(command: .toggleWhiteBalanceLock, uuid: uuid, sesionKey: camera.sessionKey,
                                                                                          dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                }
                            })
                        }
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        CameraControlsCard(value: $lensPosition, title: "Focus", locked: $focusModeLocked, changing: $adjustingFocus).onTapGesture {
                            Task(priority: .userInitiated, operation: {
                                if let camera = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                    await camera.requestFromCamera(content: CameraRequest(command: .toggleFocusLock, uuid: uuid, sesionKey: camera.sessionKey,
                                                                                          dataUUID: DirectorProjectService.currentProject()?.uuid ?? ""))
                                }
                            })
                        }
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        CameraControlsCard(value: $sessionResolution, title: "Resolution", locked: $alwaysFalse, changing: $alwaysFalse)
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        
                        CameraControlsCard(value: $sessionFrameRate, title: "Framerate", locked:  $alwaysFalse, changing: $alwaysFalse)
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        
                        CameraControlsCard(value: $batteryLevel, title: "Battery", locked:  $alwaysFalse, changing: $batteryCharging)
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        
                        CameraControlsCard(value: $diskFree, title: "Disk", locked:  $alwaysFalse, changing: $alwaysFalse)
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                        
                        CameraControlsCard(value: $pressureInfo, title: "Pressure", locked:  $alwaysFalse, changing: $alwaysFalse)
                        Rectangle().fill(Color.gray).frame(height: 1).padding(.horizontal, 10)
                        
                    }
                    
                }
                .frame(width: 100)
                .foregroundColor(.primary)
                .font(.caption)
            }
        }
        .onAppear() {
            handleEvent()
        }
        .onReceive(PubCentral.shared.selectedChanged, perform: { _ in
            handleEvent()
        })
    }
    
    func handleEvent() {
        if let _ = WatchEntryManager.shared.selectedUUID {
            displayValues = true
            setupSubscribers()
        } else {
            displayValues = false
        }
    }
    
    func setupSubscribers() {
        cancellables.removeAll()
        uuid = WatchEntryManager.shared.selectedUUID ?? ""
        if WatchEntryManager.shared.selectedUUID == nil { return }
        if let u = WatchEntryManager.shared.selectedUUID {
            Logger.shared.info("Setup subscribers for \(u)")
            Task(priority: .userInitiated, operation: {
                if let c = await NetworkHandler.shared.cameraCommandConnections[u] {
                    await cancellables.append(c.status.$adjustingExposure.receive(on: DispatchQueue.main).sink() { value in
                        adjustingExposure = value
                        
                    })
                    await cancellables.append(c.status.$exposureISO.receive(on: DispatchQueue.main).sink() { value in
                        exposureISO = String(Int(value))
                    })
                    
                    await cancellables.append(c.status.$exposureMode.receive(on: DispatchQueue.main).sink() { value in
                        switch(value) {
                        case .autoExpose:
                            fallthrough
                        case .continuousAutoExposure:
                            exposureModeLocked = false
                        case .locked:
                            fallthrough
                        case .custom:
                            exposureModeLocked = true
                        @unknown default:
                            Logger.shared.error("Unknown case in exposureMode")
                        }
                        
                    })
                    
                    await cancellables.append(c.status.$exposureShutter.receive(on: DispatchQueue.main).sink() { value in
                        let frameRate = Double(value.timescale) / Double(value.value)
                        exposureShutter = String(format: "1/%.0f", frameRate)
                    })
                    
                    await cancellables.append(c.status.$adjustingWhiteBalance.receive(on: DispatchQueue.main).sink() { value in
                        adjustingWhiteBalance = value
                    })
                    
                    await cancellables.append(c.status.$whiteBalanceMode.receive(on: DispatchQueue.main).sink() { value in
                        switch(value) {
                        case .autoWhiteBalance:
                            whiteBalanceModeLocked = true
                        case.continuousAutoWhiteBalance:
                            whiteBalanceModeLocked = false
                        case .locked:
                            whiteBalanceModeLocked = true
                        @unknown default:
                            Logger.shared.error("Unknown case in whiteBalanceMode")
                        }
                        
                    })
                    
                    await cancellables.append(c.status.$whiteBalanceTemperature.receive(on: DispatchQueue.main).sink() { value in
                        whiteBalanceTemperature = String(Int(value)) + "K"
                    })
                    
                    await cancellables.append(c.status.$whiteBalanceTint.receive(on: DispatchQueue.main).sink() { value in
                        whiteBalanceTint = String(Int(value))
                    })
                    
                    await cancellables.append(c.status.$focusMode.receive(on: DispatchQueue.main).sink() { value in
                        switch(value) {
                        case .autoFocus:
                            focusModeLocked = true
                        case .continuousAutoFocus:
                            focusModeLocked = false
                        case .locked:
                            focusModeLocked = true
                        @unknown default:
                            Logger.shared.error("Unknown case in focusMode")
                        }
                    })
                    
                    await cancellables.append(c.status.$adjustingFocus.receive(on: DispatchQueue.main).sink() { value in
                        adjustingFocus = value
                    })
                    
                    await cancellables.append(c.status.$lensPosition.receive(on: DispatchQueue.main).sink() { value in
                        lensPosition = String(Int(value * 100))
                    })
                    
                    await cancellables.append(c.status.$sessionResolution.receive(on: DispatchQueue.main).sink() { value in
                        sessionResolution = String(format: "%.0fx%.0f", value.width, value.height)
                    })
                    
                    await cancellables.append(c.status.$sessionFrameRate.receive(on: DispatchQueue.main).sink() { value in
                        let frameRate = Double(value.timescale) / Double(value.value)
                        sessionFrameRate = String(format: "%.0f fps", frameRate)
                    })
                    
                    await cancellables.append(c.status.$pressureState.receive(on: DispatchQueue.main).sink() { value in
                        switch(value) {
                        case .critical:
                            pressureInfo = "Critical"
                        case .fair:
                            pressureInfo = "Fair"
                        case .nominal:
                            pressureInfo = "Nominal"
                        case .serious:
                            pressureInfo = "Serious"
                        case .shutdown:
                            pressureInfo = "Shutdown"
                        default:
                            pressureInfo = "Unknown"
                        }
                    })
                    
                    await cancellables.append(c.status.$batteryLevel.receive(on: DispatchQueue.main).sink() { value in
                        batteryLevel = String(Int(value * 100.0))
                    })
                    
                    await cancellables.append(c.status.$batteryState.receive(on: DispatchQueue.main).sink() { value in
                        batteryCharging = value == .charging
                    })
                    
                    await cancellables.append(c.status.$diskFree.receive(on: DispatchQueue.main).sink() { value in
                        let disk = Int(value / 1000000000)
                        diskFree = "\(disk)G"
                    })
                    
                    
                   
                }
                
            })
        }
    }
}
