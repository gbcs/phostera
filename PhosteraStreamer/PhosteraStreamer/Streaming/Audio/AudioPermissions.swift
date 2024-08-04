//
//  AudioPermissions.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/8/23.
//

import Foundation
import AVFoundation

class AudioPermissions {
    static func hasPermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }
    
    static func hasPermissionDenied() -> Bool {
        return AVAudioApplication.shared.recordPermission == .denied
    }
    
    static func requestPermission() {
        if (!AudioPermissions.hasPermission()) && (!AudioPermissions.hasPermissionDenied()) {
            AVAudioApplication.requestRecordPermission() {_ in
                DispatchQueue.main.async { NotificationCenter.default.post(name: .audioAccessChanged, object: nil) }
            }
        }
    }
}
