//
//  Exposure.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//

import Foundation
import AVFoundation
import UIKit

import Combine

//An interface to the AVCaptureDevice exposure properties. This is a complex set of interactions with user-selectable modes available on some devices.
//As user-supplied external cameras are now a thing, runtime determination is the only way

class DeviceExposure: NSObject {
    //Interrogate current capture device
    //Provide data to UI to display in topStrip
    //Coordinate an exposure area-of-interest reticle
    private var device:AVCaptureDevice?

    private var exposurePOI:CGPoint = .zero
    
    private var modeLocked:Bool = false
    private var modeAutoOnce:Bool = false
    private var modeContinuous:Bool = false
    private var modeCustom:Bool = false
    
    func updateSupportedModes() {
        modeLocked = false
        modeAutoOnce = false
        modeContinuous = false
        modeCustom = false
        
        if (device != nil) {
            if device!.isExposureModeSupported(.locked) { modeLocked = true }
            if device!.isExposureModeSupported(.autoExpose) { modeAutoOnce = true }
            if device!.isExposureModeSupported(.continuousAutoExposure) { modeContinuous = true }
            if device!.isExposureModeSupported(.custom) { modeCustom = true }
        }
    }
    
//    exposurePOI = (PubCentral.shared.pubExposurePOI?.receive(on: DispatchQueue.main).sink { value in
//      
//    })
    
    func userUpdatedPOI(poi:CGPoint) {
        if let d = device {
            if d.isExposurePointOfInterestSupported {
                do {
                    try d.lockForConfiguration()
                    if d.exposureMode != .continuousAutoExposure { d.exposureMode = .continuousAutoExposure }
                    d.exposurePointOfInterest = poi
                    d.unlockForConfiguration()
                  //  Logger.shared.info("Exposure POI set to: \(poi.debugDescription)")
                } catch {
                    Logger.shared.error("Unable to update exposure POI.")
                }
            }
        }
    }
    
    func userToggledExposure() {
        if let d = device {
            do {
                try d.lockForConfiguration()
                if d.exposureMode == .continuousAutoExposure {
                    if d.isExposureModeSupported(.locked) { d.exposureMode = .locked }
                } else {
                    d.exposureMode = .continuousAutoExposure
                }
                d.unlockForConfiguration()
            } catch {
                Logger.shared.error("Unable to lock cameraDevice for configuration.")
            }
        } else {
            Logger.shared.error("Unable to get camera device.")
        }
    }

    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
        self.updateSupportedModes()
        PubCentral.shared.pubIsAdjustingExposure = currentDevice.publisher(for: \.isAdjustingExposure).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubExposureMode = currentDevice.publisher(for: \.exposureMode).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubExposurePOI = currentDevice.publisher(for: \.exposurePointOfInterest).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubExposureISO = currentDevice.publisher(for: \.iso).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubExposureShutter = currentDevice.publisher(for: \.exposureDuration).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    }
}
