
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

class DeviceWhitebalance: NSObject {
    //Interrogate current capture device
    //Provide data to UI to display in topStrip
    //Coordinate an exposure area-of-interest reticle
    private var device:AVCaptureDevice?
  
    private var modeLocked:Bool = false
    private var modeAutoOnce:Bool = false
    private var modeContinuous:Bool = false
    
    func updateSupportedModes() {
        modeLocked = false
        modeAutoOnce = false
        modeContinuous = false
        
        if (device != nil) {
            if device!.isWhiteBalanceModeSupported(.locked) { modeLocked = true }
            if device!.isWhiteBalanceModeSupported(.autoWhiteBalance) { modeAutoOnce = true }
            if device!.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { modeContinuous = true }
        }
    }
    
    func userToggledWhitebalance() {
        if let d = device {
            do {
                try d.lockForConfiguration()
                if d.whiteBalanceMode == .continuousAutoWhiteBalance {
                    if d.isWhiteBalanceModeSupported(.locked) { d.whiteBalanceMode = .locked }
                } else {
                    d.whiteBalanceMode = .continuousAutoWhiteBalance
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
        PubCentral.shared.pubIsAdjustingWhitebalance = currentDevice.publisher(for: \.isAdjustingWhiteBalance).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubWhiteBalanceMode = currentDevice.publisher(for: \.whiteBalanceMode).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
        PubCentral.shared.pubDeviceWhiteBalanceGains = currentDevice.publisher(for: \.deviceWhiteBalanceGains).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    }
}
