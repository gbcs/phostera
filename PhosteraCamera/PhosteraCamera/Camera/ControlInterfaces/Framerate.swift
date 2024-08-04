//
//  Framerate.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/7/23.
//

import Foundation
import AVFoundation
import UIKit

import Combine

class DeviceFramerate: NSObject {
    private var device:AVCaptureDevice?

    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
    }

    func capFrameRate(rate:Float64) {
        guard let device else { return }
        
        let duration = CMTimeMake(value: 1, timescale: Int32(rate))
        
        for range in device.activeFormat.videoSupportedFrameRateRanges {
            let minRate:Float64 = range.minFrameRate
            let maxRate:Float64 = range.maxFrameRate
            
            if (minRate <= rate) && (maxRate >= rate) {
                do {
                    try device.lockForConfiguration()
                    device.activeVideoMaxFrameDuration = duration
                    device.activeVideoMinFrameDuration = duration
                    device.unlockForConfiguration()
                    Logger.shared.info("Set framerate to: \(duration)")
                    return
                } catch {
                    Logger.shared.error("Error setting framerate to: \(duration)")
                }
            }
        }
        Logger.shared.info("Unable to set framerate to: \(duration)")
    }
}
