//
//  RecordingBeep.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 11/6/23.
//

import Foundation
import AVFoundation
import AudioToolbox

public class BeepTool {
    var bombSoundEffect: AVAudioPlayer?

    func playBeepSound() {
        if let fileURL = Bundle.main.url(forResource: "beep-7", withExtension: "wav") {
            do {
                bombSoundEffect = try AVAudioPlayer(contentsOf: fileURL)
                bombSoundEffect?.play()
            } catch {
                Logger.shared.error("Could not play beep-7.wav")
            }
        } else {
            Logger.shared.error("Could not find beep-7.wav in the main bundle")
        }
    }
}
