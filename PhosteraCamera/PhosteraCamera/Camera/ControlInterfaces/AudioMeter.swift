//
//  AudioMeter.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/7/23.
//

import Foundation
import AVFoundation
import UIKit

import Combine

class DeviceAudioMeter: NSObject {
    private var device:AVCaptureDevice?
  
    func updateSupportedModes() {
        if (device != nil) {
            
        }
    }

    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
        self.updateSupportedModes()
    }
}
