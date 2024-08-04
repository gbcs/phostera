//
//  PubCentral.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/9/23.
//

import UIKit

import Combine
import AVFoundation

extension NSNotification.Name {
    class OrientationLock {
        static let toMask = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.lock")
        static let toCurrent = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.lock.current")
    }
    class Onboarding {
        static let complete = NSNotification.Name(rawValue: "com.gb-cs.phostera.onboarding.complete")
    }
    class CameraOperations {
        static let start = NSNotification.Name(rawValue: "com.gb-cs.phostera.camops.start")
        static let stop = NSNotification.Name(rawValue: "com.gb-cs.phostera.camops.stop")
        static let beginRecording = NSNotification.Name(rawValue: "com.gb-cs.phostera.camops.beginrecording")
        static let endRecording = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.endrecording")
        static let togglePreviewSize = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.togglepreview")
        static let handleNewMode = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.handlenewmode")
        static let showtorchUI = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.showtorchUI")
        static let showviztoolsui = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.showviztoolsui")
        static let flashScreen = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.flashscreen") 
        static let modeSwitch = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.switchmode")
        static let standby = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.standby")
        static let standbyOpsComplete = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.stamdbyOpsComplete")
        static let droppedFrame = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.droppedFrame")
        static let cameraPosition = NSNotification.Name(rawValue: "com.gb-cs.phostera.orientation.camops.cameraPosition")
    }
    
    class UtilityPages {
        static let settings = NSNotification.Name(rawValue: "com.gb-cs.phostera.utility.settings")
        static let library = NSNotification.Name(rawValue: "com.gb-cs.phostera.utility.library")
    }
    static let documentPicked = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.documentPicked")
    static let externalScreenChanged = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.externalScreenChanged")
}

class PubCentral: NSObject {
    static var shared = PubCentral()
    var pubIsAdjustingWhitebalance:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, Bool>, DispatchQueue>?
    var pubWhiteBalanceMode:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, AVCaptureDevice.WhiteBalanceMode>, DispatchQueue>?
    
    var pubDeviceWhiteBalanceGains:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, AVCaptureDevice.WhiteBalanceGains>, DispatchQueue>?
    
    var pubIsAdjustingExposure:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, Bool>, DispatchQueue>?
    var pubExposureMode:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, AVCaptureDevice.ExposureMode>, DispatchQueue>?
    var pubExposurePOI:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, CGPoint>, DispatchQueue>?
    var pubExposureISO:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, Float>, DispatchQueue>?
    var pubExposureShutter:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, CMTime>, DispatchQueue>?
    
    var pubFocusPointOfInterest:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, CGPoint>, DispatchQueue>?
    var pubFocusMode:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, AVCaptureDevice.FocusMode>, DispatchQueue>?
    var pubisAdjustingFocus:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, Bool>, DispatchQueue>?
    var publensPosition:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, Float>, DispatchQueue>?
    
    var pubRecordingState:Publishers.Throttle<NSObject.KeyValueObservingPublisher<CamTool, Bool>, DispatchQueue>?
    var pubvideoRotationAngleForHorizonLevelPreview:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureConnection, CGFloat>, DispatchQueue>?
    
    var pubSessionResolution:Publishers.Throttle<NSObject.KeyValueObservingPublisher<CamTool, CGSize>, DispatchQueue>?
    var pubSessionFrameRate:Publishers.Throttle<NSObject.KeyValueObservingPublisher<CamTool, CMTime>, DispatchQueue>?
    var pubModeName:Publishers.Throttle<NSObject.KeyValueObservingPublisher<CamTool, String>, DispatchQueue>?
    var pubModeOutputName:Publishers.Throttle<NSObject.KeyValueObservingPublisher<CamTool, String>, DispatchQueue>?
    
    var pubPressureState:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, AVCaptureDevice.SystemPressureState>, DispatchQueue>?
    var pubCameraPosition:Publishers.Throttle<NSObject.KeyValueObservingPublisher<CamTool, Bool>, DispatchQueue>?
    
    //Commands
    var pubOrientationLockToMask:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubOrientationLockToCurrent:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubOnboardingComplete:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubCameraOperationsStart:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubCameraOperationsStop:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubCameraOperationsBeginRecording:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubCameraOperationsEndRecording:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubCameraOperationsTogglePreview:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubUtilityPagesSettings:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubUtilityPagesLibrary:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubOrientationDidChangeNotification:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubDidActivateNotification:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubHandleNewMode:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubShowtorchUI:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubShowVizToolsUI:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    
    var pubEnterBackground:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubWillEnterForeground:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubThermalStateChanged:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubSessionRuntimeError:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubSessionWasInterrupted:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubSessionInterruptionEnded:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    
    var pubFlashScreen:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubExternalDisplayChanged:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubModeSwitch:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubStandby:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubStandbyOpsComplete:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>
    var pubDroppedFrame:Publishers.Throttle<NotificationCenter.Publisher, DispatchQueue>

    
    @Published var userMessageIndex:Int = 0
    @Published var releaseUserMessageView:Bool = false
    @Published var screenShot:Data = Data()
    
    let documentPicked = NotificationCenter.default.publisher(for: NSNotification.Name.documentPicked)
    
    override init() {
        let center = Foundation.NotificationCenter.default
        pubOrientationLockToMask = center.publisher(for: Notification.Name.OrientationLock.toMask).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubOrientationLockToCurrent = center.publisher(for: Notification.Name.OrientationLock.toCurrent).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubOnboardingComplete = center.publisher(for: Notification.Name.Onboarding.complete).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubCameraOperationsStart = center.publisher(for: Notification.Name.CameraOperations.start).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubCameraOperationsStop = center.publisher(for: Notification.Name.CameraOperations.stop).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubCameraOperationsBeginRecording = center.publisher(for: Notification.Name.CameraOperations.beginRecording).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubCameraOperationsEndRecording = center.publisher(for: Notification.Name.CameraOperations.endRecording).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubCameraOperationsTogglePreview = center.publisher(for: Notification.Name.CameraOperations.togglePreviewSize).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubUtilityPagesSettings = center.publisher(for: Notification.Name.UtilityPages.settings).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubUtilityPagesLibrary = center.publisher(for: Notification.Name.UtilityPages.library).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubOrientationDidChangeNotification = center.publisher(for: UIDevice.orientationDidChangeNotification).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubDidActivateNotification = center.publisher(for: UIScene.didActivateNotification).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubHandleNewMode = center.publisher(for: Notification.Name.CameraOperations.handleNewMode).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubShowtorchUI = center.publisher(for: Notification.Name.CameraOperations.showtorchUI).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubShowVizToolsUI = center.publisher(for: Notification.Name.CameraOperations.showviztoolsui).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        
        pubEnterBackground = center.publisher(for: UIApplication.didEnterBackgroundNotification).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubWillEnterForeground = center.publisher(for: UIApplication.willEnterForegroundNotification).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubThermalStateChanged = center.publisher(for: ProcessInfo.thermalStateDidChangeNotification).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubSessionRuntimeError = center.publisher(for: .AVCaptureSessionRuntimeError).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubSessionWasInterrupted = center.publisher(for: .AVCaptureSessionWasInterrupted).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubSessionInterruptionEnded = center.publisher(for: NSNotification.Name.AVCaptureSessionInterruptionEnded).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
    
        pubFlashScreen = center.publisher(for: Notification.Name.CameraOperations.flashScreen).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubExternalDisplayChanged = center.publisher(for: Notification.Name.externalScreenChanged).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubModeSwitch = center.publisher(for: Notification.Name.CameraOperations.modeSwitch).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubStandby = center.publisher(for: Notification.Name.CameraOperations.standby).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubStandbyOpsComplete = center.publisher(for: Notification.Name.CameraOperations.standbyOpsComplete).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        pubDroppedFrame = center.publisher(for: Notification.Name.CameraOperations.droppedFrame).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
        
        super.init()
    }
    
    func setupDevicePublishers() {
        guard let cameraDevice = CamTool.shared.getCameraDevice() else {
            Logger.shared.error("No cameraDevice in setupDevicePublishers")
            return
        }
        pubPressureState = cameraDevice.publisher(for: \.systemPressureState).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        pubRecordingState = CamTool.shared.publisher(for: \.isCurrentlyRecording).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        pubSessionResolution = CamTool.shared.publisher(for: \.outputSize).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        pubSessionFrameRate = CamTool.shared.publisher(for: \.outputFrameRate).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        pubModeName = CamTool.shared.publisher(for: \.modeName).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        pubModeOutputName = CamTool.shared.publisher(for: \.outputEncoderName).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        pubCameraPosition = CamTool.shared.publisher(for: \.cameraPositionIsFront).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    }
}

