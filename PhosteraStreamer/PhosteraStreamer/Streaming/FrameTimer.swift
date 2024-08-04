//
//  FrameTimer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/19/23.
//

import Foundation
import AVFoundation

//Vend out timestamps to keep the Youtube happy
//Allow resetting timestamp so Youtube can get 0 begins

class FrameTimer {
    static var shared = FrameTimer()
    private var oneSecond:Int32 = 48000
    private var oneSecondDouble:Double = 48000.0
    
    private var currentVideo:Int64 = 0
    
    private var currentAudio:Int64 = 0
    
    private var frameRate:Int64 = 30
    
    private lazy var videoFrameEach:Int64 = Int64(oneSecond) / frameRate
    
    func nextVideoTimestamp() -> CMTime {
        let t = CMTime(value: currentVideo * videoFrameEach, timescale: oneSecond)
        currentVideo += 1
        return t
    }
    
    func nextAudioTimestamp(samples:Int64) -> AVAudioTime {
        let t = AVAudioTime(sampleTime: currentAudio, atRate: oneSecondDouble)
        currentAudio += samples
        return t
    }
    
    func setRate(sampleRate:Int32, fr:Int32) {
        oneSecond = sampleRate
        oneSecondDouble = Double(sampleRate)
        frameRate = Int64(fr)
        videoFrameEach = Int64(oneSecond) / frameRate
    }
    
    func reset() {
        currentVideo = 0
        currentAudio = 0
    }
}
