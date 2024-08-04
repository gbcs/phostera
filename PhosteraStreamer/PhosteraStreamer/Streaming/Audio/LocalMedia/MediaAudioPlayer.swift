//
//  MediaAudioPlayer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/16/23.
//

import Foundation
import AVFoundation

class MediaAudioPlayer {
    static let shared = MediaAudioPlayer()
    
    private var audioFile: AVAudioFile?
    private var audioFormat: AVAudioFormat?
    private var currentFramePosition: AVAudioFramePosition = 0
    
    private init() {}
    
    func stop() {
        audioFile = nil
    }
    
    func loadAudioFile(with url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
        audioFormat = audioFile?.processingFormat
        currentFramePosition = 0
    }
    
    func seek(to:CMTime) {
        guard let audioFormat else { return }
        MetalTool.shared.mediaBuffer?.clear()
        let x = CMTimeGetSeconds(to)
        currentFramePosition = Int64(x * audioFormat.sampleRate)
    }
    
    func readPCMBuffer(duration: TimeInterval, atFramePosition:AVAudioFramePosition) throws -> AVAudioPCMBuffer? {
        guard let audioFile = audioFile, let audioFormat = audioFormat else {
            return nil
        }

        if atFramePosition == -1 {
            //Append the read
            if Int64(duration * audioFormat.sampleRate) > audioFile.length - currentFramePosition {
                return nil
            }
        } else if atFramePosition == 0 {
            //Begin
            currentFramePosition = 0
        } else {
            //Specified
            if atFramePosition >= audioFile.length {
                return nil
            }
            currentFramePosition = atFramePosition
        }
        
        let requestedFrames = AVAudioFrameCount(duration * audioFormat.sampleRate)
        let availableFrames = AVAudioFrameCount(audioFile.length - currentFramePosition)
        
        if requestedFrames > availableFrames { return nil }
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: requestedFrames) else {
            return nil
        }

        audioFile.framePosition = currentFramePosition
        
        do {
            try audioFile.read(into: pcmBuffer, frameCount: requestedFrames)
        } catch {
            return nil
        }
        
        currentFramePosition += AVAudioFramePosition(requestedFrames)
        
        return pcmBuffer
    }
    
    
}
