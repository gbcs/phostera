//
//  Focus.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//

import Foundation
import AVFoundation
import UIKit

import Combine

//An interface to the AVCaptureDevice focus properties. This is a complex set of interactions with user-selectable modes available on some devices.
//As user-supplied external cameras are now a thing, runtime determination is the only way

class DeviceFocus: NSObject {
    //Interrogate current capture device
    //Provide data to UI to display in topStrip
    //Coordinate an exposure area-of-interest reticle
    private var device:AVCaptureDevice?

    private var focusPOI:CGPoint = .zero
    
    private var modeLockFocus:Bool = false
    private var modeAutoOnce:Bool = false
    private var modeContinuous:Bool = false
    private var modeLockLens:Bool = false
    private var focusPointOfInterest:AnyCancellable?
   
    //NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange),  name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange,  object: videoInput.device)
  
    func updateSupportedModes() {
        modeLockFocus = false
        modeAutoOnce = false
        modeContinuous = false
        modeLockLens = false
        
        if let device {
            if device.isFocusModeSupported(.locked) { modeLockFocus = true }
            if device.isFocusModeSupported(.autoFocus) { modeAutoOnce = true }
            if device.isFocusModeSupported(.continuousAutoFocus) { modeContinuous = true }
            if device.isLockingFocusWithCustomLensPositionSupported { modeLockLens = true }
        }
    }
    
    func userUpdatedPOI(poi:CGPoint) {
        if let d = device {
            if d.isFocusPointOfInterestSupported {
                do {
                    try d.lockForConfiguration()
                    if d.focusMode != .continuousAutoFocus { d.focusMode = .continuousAutoFocus }
                    d.focusPointOfInterest = poi
                    d.unlockForConfiguration()
                   // Logger.shared.info("Focus POI set to: \(poi.debugDescription)")
                } catch {
                    Logger.shared.error("Unable to update focus POI.")
                }
            }
        }
    }
    
    func userToggledFocus() {
        if let d = device {
            if d.isFocusModeSupported(.locked) {
                do {
                    try d.lockForConfiguration()
                    if d.focusMode == .continuousAutoFocus {
                        if d.isFocusModeSupported(.locked) { d.focusMode = .locked}
                    } else {
                        d.focusMode = .continuousAutoFocus
                    }
                    d.unlockForConfiguration()
                } catch {
                    Logger.shared.error("Unable to lock cameraDevice for configuration.")
                }
            }
        } else {
            Logger.shared.error("Unable to get camera device.")
        }
    }

    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
        self.updateSupportedModes()
        Logger.shared.info("Registering Focus publishers")
        PubCentral.shared.pubFocusMode = currentDevice.publisher(for: \.focusMode).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.publensPosition = currentDevice.publisher(for: \.lensPosition).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubFocusPointOfInterest = currentDevice.publisher(for: \.focusPointOfInterest).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubisAdjustingFocus = currentDevice.publisher(for: \.isAdjustingFocus).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        
    }
    
//    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
//        
//        sessionQueue.async {
//            let videoDevice = self.videoInput.device
//            
//            do {
//                try videoDevice.lockForConfiguration()
//                if videoDevice.isFocusPointOfInterestSupported && videoDevice.isFocusModeSupported(focusMode) {
//                    videoDevice.focusPointOfInterest = devicePoint
//                    videoDevice.focusMode = focusMode
//                }
//                
//                if videoDevice.isExposurePointOfInterestSupported && videoDevice.isExposureModeSupported(exposureMode) {
//                    videoDevice.exposurePointOfInterest = devicePoint
//                    videoDevice.exposureMode = exposureMode
//                }
//                
//                videoDevice.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
//                videoDevice.unlockForConfiguration()
//            } catch {
//                Logger.shared.error("Could not lock device for configuration: \(error)")
//            }
//        }
//    }
//    @IBAction private func focusAndExposeTap(_ gesture: UITapGestureRecognizer) {
//    }
//    
//    @objc
//    func subjectAreaDidChange(notification: NSNotification) {
//        let devicePoint = CGPoint(x: 0.5, y: 0.5)
//        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
//    }
}
