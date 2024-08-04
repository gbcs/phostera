
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

class DeviceZoom: NSObject {
    private var device:AVCaptureDevice?
  
    
    func updateSupportedModes() {
        
        //videoZoomFactorUpscaleThreshold
        
        if (device != nil) {
        }
    }

    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
        self.updateSupportedModes()
    }
}
