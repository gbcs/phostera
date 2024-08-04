//
//  AudioDiscovery.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/30/23.
//

import Foundation
import AVFoundation

class AudioDiscovery {
    static var shared = AudioDiscovery()
    var discoverySession:AVCaptureDevice.DiscoverySession?
    
    func discoverAudio() {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .front)
        Logger.shared.info("Listing Audio Devices")
        for device in discoverySession.devices {
            if device.hasMediaType(.audio) {
                Logger.shared.info("Device Name: \(device.localizedName)")
                Logger.shared.info("Unique ID: \(device.uniqueID)")
                Logger.shared.info("Model ID: \(device.modelID)")
                Logger.shared.info("Connected: \(device.isConnected)")
                Logger.shared.info("Suspended: \(device.isSuspended)")
                
                let format = device.activeFormat
                let formatDescription = format.formatDescription
                
                let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
                
                if mediaType == kCMMediaType_Audio {
                    let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                    Logger.shared.info("Sample Rate: \(streamDescription?.pointee.mSampleRate ?? 0)")
                    Logger.shared.info("Channels Per Frame: \(streamDescription?.pointee.mChannelsPerFrame ?? 0)")
                    Logger.shared.info("Bits Per Channel: \(streamDescription?.pointee.mBitsPerChannel ?? 0)")
                    Logger.shared.info("Media Type: Not Audio")
                } else {
                    Logger.shared.info("Media Type: Audio")
                }
            }
        }
    }
}
