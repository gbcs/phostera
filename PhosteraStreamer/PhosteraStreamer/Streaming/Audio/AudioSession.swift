//
//  AudioSession.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/9/23.
//

import Foundation
import AVFoundation


enum AudioSessionError: Error {
    case setCategory
    case setSampleRate
    case setInputNumberChannels
    case setOutputNumberChannels
    case setActive
    case stop
    
}

class AudioSession {
    static var shared = AudioSession()
    
    func start() throws {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
        } catch {
            throw AudioSessionError.setCategory
        }
        
        do {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(48000)
        } catch {
            throw AudioSessionError.setSampleRate
        }
        
        
        
//        do {
//            try AVAudioSession.sharedInstance().setPreferredInputNumberOfChannels(1)
//        } catch {
//            throw AudioSessionError.setInputNumberChannels
//        }
        
        do {
            if AVAudioSession.sharedInstance().maximumOutputNumberOfChannels >= 2 {
                try AVAudioSession.sharedInstance().setPreferredOutputNumberOfChannels(2)
            }
        } catch {
            throw AudioSessionError.setOutputNumberChannels
        }
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            throw AudioSessionError.setActive
        }
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        Logger.shared.info("AudioSession:start:Available input count: \(inputs.count)")
        
        Logger.shared.info("AudioSession: sampleRate: \(AVAudioSession.sharedInstance().sampleRate)")
        
    }
    
    func stop() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            Logger.shared.info("AudioSession:stop")
        }
    }
}
