//
//  CommandServerConnection.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/20/23.
//

import UIKit
import Network
import Combine
import CoreMedia
import PhosteraShared

actor CommandServerConnection: NSObject {
    private var connection: NWConnection?
    
    var sessionKey = UUID().uuidString.lowercased()
    
    private var cancellables:[AnyCancellable] = []
    
    private let timerQueue = DispatchQueue(label: "timerQueue", qos: .background, attributes: [], autoreleaseFrequency: .workItem)
    private var dataTimer:DispatchSourceTimer?
    
    private var screenShotSub:AnyCancellable?
    private var directorUUID:String = ""
    
    func update(directorUUID:String) {
        self.directorUUID = directorUUID
    }
    
    func getDirectorUUID() -> String {
        return directorUUID
    }
    
    func screenshotSubSetup() {
        if screenShotSub == nil {
            screenShotSub = PubCentral.shared.$screenShot.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await sendToDirector(value, messsageType: .screenshot)
                })
            }
            CamTool.shared.sendScreenshotNow()
        }
    }
    
    func standbyMode(isOn:Bool) {
        Task {
            if let data = try? JSONEncoder().encode(isOn) {
                sendToDirector(data, messsageType: .standbyMode)
            }
        }
    }
    
    func standbyModeOps(isRunning:Bool) {
        Task {
            if let data = try? JSONEncoder().encode(isRunning) {
                sendToDirector(data, messsageType: .standbyModeOps)
            }
        }
    }
    
    func sendTaskList(data:Data) {
        Task {
            let response:ProjectResponse = ProjectResponse(status: .success,
                                                           command: .takeList, data: data, projectUUID: "")
            do {
                let encoder = JSONEncoder()
                let modelData:Data = try encoder.encode(response)
                sendToDirector(modelData, messsageType: .project)
            } catch {
                Logger.shared.error("sendTaskList: encoder error: \(error.localizedDescription)")
            }
        }
    }

    private func receivedMessage(content: Data?, message: NWProtocolFramer.Message) {
        Logger.shared.info("Received \(content!.bytes.count) bytes from director")
        
        switch(message.commandMessageType) {
        case .authentication:
            AuthRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self)
        case .camera:
            CameraRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self)
        case .project:
            ProjectRoute.shared.handleRouting(content: content, command: message.commandMessageType, connection: self)
        case .standbyMode:
            if let content, let _ = try? JSONDecoder().decode(Bool.self, from: content) {
                DispatchQueue.main.async {
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.standby, object: nil) }
                }
               
            }
        case .standbyModeOps:
           break
        default:
            break
        }
    }
    
    func getSessionKey() -> String {
        return sessionKey
    }
    
    private func connectionFailed() {
        Logger.shared.error("connection failed")
    }
    
    private func connectionReady() {
        Logger.shared.info("connection ready")
    }
    
    var publicKey:Data?

    init(connection: NWConnection, server:CommandServer) {
        self.connection = connection
        super.init()
        Task(priority: .userInitiated, operation: { [weak self] in
            guard let self else { return }
            await startConnection()
        })
    }
    
    func cancel() {
        let s = sessionKey
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.Server.removeCommandConnection, object: nil, userInfo: ["sessionKey":s])
        }
    
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }
    

    
    private func startConnection() {
        guard let connection = connection else {
            return
        }
        
        connection.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                Logger.shared.info("\(connection.debugDescription) established")
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await connectionReady()
                    await receiveNextMessage()
                    await screenshotSubSetup()
                })
            case .cancelled:
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await cancel()
                })
            case .failed(let error):
                Logger.shared.info("\(connection.debugDescription) failed with \(error.localizedDescription)")
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await cancel()
                })
            default:
                break
            }
        }
        Task {
            connection.start(queue: .global(qos: .userInitiated))
        }
    }
    
    func getPublicKey() -> Data? {
       return publicKey
    }
    
    func update(publicKey:Data?) {
        self.publicKey = publicKey
    }
    
    func sendToDirector(_ content: Data, messsageType:CommandMessageType) {
        guard let connection = connection else {
            return
        }
        
        let message = NWProtocolFramer.Message(commandMessageType: messsageType)
        let context = NWConnection.ContentContext(identifier: "message", metadata: [message])
        
        //Logger.shared.info("Sending \(content.bytes.count) bytes to director")
        
        connection.send(content: content, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    func receiveNextMessage() {
        guard let connection = connection else {
            return
        }
        
        connection.receiveMessage { (content, context, isComplete, error) in
            if let commandMessage = context?.protocolMetadata(definition: CommandProtocol.definition) as? NWProtocolFramer.Message {
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await receivedMessage(content: content, message: commandMessage)
                })
            }
            
            if error == nil {
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await receiveNextMessage()
                })
            }
        }
    }
    
    var cameraTransferList:[CameraUpdateElement:CameraStatusElement] = [:]
    
    func ingestElementForDirector(value:Any, element:CameraUpdateElement) {
        let e = CameraStatusElement(element: element, value: value)
        cameraTransferList[element] = e
        startDataTimer()
    }
    
    var isProcessingFrame = false
    let encoder = JSONEncoder()
    
    private func startDataTimer() {
        if isProcessingFrame { return }
        
        let nextExecution = DispatchTime.now().advanced(by: DispatchTimeInterval.milliseconds(100))
        
        dataTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        
        guard let dataTimer else { return }
        
        dataTimer.schedule(deadline: nextExecution, repeating: .never)
        
        dataTimer.setEventHandler {
            Task { [weak self] in
                guard let self else { return }
                
                var list:[CameraStatusElement] = []
                for item in await cameraTransferList.values {
                    list.append(item)
                }
                
                //Logger.shared.info("sending \(list.count) items")
                do {
                    let data = try encoder.encode(list)
                    await sendToDirector(data, messsageType: .status)
                } catch {
                    
                }
                
                await cleanTransferList()
                await updateProcessingFrame(isOn: false)
            }
        }
        
        isProcessingFrame = true
        dataTimer.resume()
    }
    
    func cleanTransferList() {
        cameraTransferList.removeAll()
    }
    
    func updateProcessingFrame(isOn:Bool) {
        isProcessingFrame = isOn
    }

    func setupForSubscriptionForwarding() {
        cancellables.removeAll()
        
        Task(priority: .userInitiated, operation: {
            await ingestElementForDirector(value: UIDevice.current.batteryLevel, element: .batteryLevel)
            await ingestElementForDirector(value: UIDevice.current.batteryState, element: .batteryState)
            ingestElementForDirector(value: StatusService.shared.diskSpaceMonitor.freeSpace, element: .diskFree)
        })
        
        if let p = PubCentral.shared.pubIsAdjustingWhitebalance {
            cancellables.append(p.removeDuplicates().sink { value in
                let answer:Bool = value ? true : false
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await ingestElementForDirector(value: answer, element: .adjustingWhiteBalance)
                })
            })
        }
        
        if let p = PubCentral.shared.pubWhiteBalanceMode {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return }
                    await ingestElementForDirector(value: value, element: .whiteBalanceMode)
                })
            })
        }
        
        if let p = PubCentral.shared.pubDeviceWhiteBalanceGains {
            cancellables.append(p.sink { value in
                if (value.blueGain < 1.0) || (value.redGain < 1.0) || (value.greenGain < 1.0) { return }
                if let c = CamTool.shared.getCameraDevice() {
                    let m = c.maxWhiteBalanceGain
                    if (value.blueGain > m) || (value.redGain > m) || (value.greenGain > m) { return }
                    let v = c.temperatureAndTintValues(for: value)
                    Task(priority: .userInitiated, operation: { [weak self] in
                        guard let self else { return };
                        await ingestElementForDirector(value: v.temperature, element: .whiteBalanceTemperature)
                        await ingestElementForDirector(value: v.tint, element: .whiteBalanceTint)
                    })
                }
            })
        }
        
        if let p = PubCentral.shared.pubIsAdjustingExposure {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .adjustingExposure)
                })
            })
        }
        
        if let p = PubCentral.shared.pubExposureMode {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .exposureMode)
                })
            })
        }
        
        if let p = PubCentral.shared.pubExposurePOI {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .exposurePOI)
                })
            })
        }
        
        if let p = PubCentral.shared.pubExposureISO {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .exposureISO)
                })
            })
        }
        
        if let p = PubCentral.shared.pubExposureShutter {
            cancellables.append(p.removeDuplicates().sink {value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .exposureShutter)
                })
            })
        }
        
        if let p = PubCentral.shared.pubFocusPointOfInterest {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .focusPOI)
                })
            })
        }
        
        if let p = PubCentral.shared.pubFocusMode {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .focusMode)
                })
            })
        }
        
        if let p = PubCentral.shared.pubisAdjustingFocus {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .adjustingFocus)
                })
            })
        }
        
        if let p = PubCentral.shared.publensPosition {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .lensPosition)
                })
            })
        }
        
        if let p = PubCentral.shared.pubRecordingState {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .recordingState)
                })
            })
        }
        
        if let p = PubCentral.shared.pubvideoRotationAngleForHorizonLevelPreview {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .horizonPreviewAngle)
                })
            })
        }
        
        if let p = PubCentral.shared.pubSessionResolution {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .sessionResolution)
                })
            })
        }
        
        if let p = PubCentral.shared.pubSessionFrameRate {
            cancellables.append(p.removeDuplicates().sink { [weak self] value in guard let self else { return };
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .sessionFrameRate)
                })
            })
        }
        
        if let p = PubCentral.shared.pubModeName {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .modeName)
                })
            })
        }
        
        if let p = PubCentral.shared.pubModeOutputName {
            cancellables.append(p.removeDuplicates().sink {value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .modeOutputName)
                })
            })
        }
        
        if let p = PubCentral.shared.pubPressureState {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value.level, element: .pressureState)
                })
            })
            //Todo: Factors not sent over the wire; only the level at present
        }
        
        if let p = StatusService.shared.pubBatteryLevelChange {
            cancellables.append(p.sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: UIDevice.current.batteryLevel, element: .batteryLevel)
                })
            })
        }
        
        if let p = StatusService.shared.pubBatteryStateChange {
            cancellables.append(p.sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: UIDevice.current.batteryState, element: .batteryState)
                })
            })
        }
        
        let p = StatusService.shared.diskSpaceMonitor.$freeSpace
        cancellables.append(p.removeDuplicates().sink {value in
            Task(priority: .userInitiated, operation: { [weak self] in
                guard let self else { return };
                await ingestElementForDirector(value: value, element: .diskFree)
            })
        })
        
        if let p = PubCentral.shared.pubCameraPosition {
            cancellables.append(p.removeDuplicates().sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: value, element: .frontPosition)
                })
            })
        }
    
        for element in [
            (PubCentral.shared.pubCameraOperationsStart, CameraUpdateElement.cameraStart),
            (PubCentral.shared.pubCameraOperationsStop, CameraUpdateElement.cameraStop),
            (PubCentral.shared.pubCameraOperationsBeginRecording, CameraUpdateElement.beginRecording),
            (PubCentral.shared.pubCameraOperationsEndRecording, CameraUpdateElement.endRecording),
            (PubCentral.shared.pubCameraOperationsTogglePreview, CameraUpdateElement.togglePreview),
            (PubCentral.shared.pubUtilityPagesSettings, CameraUpdateElement.gotoSettings),
            (PubCentral.shared.pubUtilityPagesLibrary, CameraUpdateElement.gotoLibrary),
            (PubCentral.shared.pubOrientationDidChangeNotification, CameraUpdateElement.orientationChange),
            (PubCentral.shared.pubDidActivateNotification, CameraUpdateElement.appActive),
            (PubCentral.shared.pubHandleNewMode, CameraUpdateElement.newMode),
            (PubCentral.shared.pubShowtorchUI, CameraUpdateElement.showTorchUI),
            (PubCentral.shared.pubShowVizToolsUI, CameraUpdateElement.showVizToolsUI),
            (PubCentral.shared.pubEnterBackground, CameraUpdateElement.appBackground),
            (PubCentral.shared.pubWillEnterForeground, CameraUpdateElement.appForeground),
            (PubCentral.shared.pubThermalStateChanged, CameraUpdateElement.thermalStateChange),
            (PubCentral.shared.pubSessionRuntimeError, CameraUpdateElement.sessionRuntimeError),
            (PubCentral.shared.pubSessionWasInterrupted, CameraUpdateElement.sessionWasInterrupted),
            (PubCentral.shared.pubSessionInterruptionEnded, CameraUpdateElement.sessionInterruptionEnded),
            (PubCentral.shared.pubFlashScreen, CameraUpdateElement.flashScreen)
        ] {
            let pub = element.0
            let which = element.1
            cancellables.append(pub.sink { value in
                Task(priority: .userInitiated, operation: { [weak self] in
                    guard let self else { return };
                    await ingestElementForDirector(value: "event", element: which)
                })
            })
        }
    }
}
    
