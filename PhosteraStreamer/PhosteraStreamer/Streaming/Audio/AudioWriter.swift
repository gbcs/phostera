//
//  AudioWriter.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/17/23.
//

import Foundation
import AVFoundation

class AudioWriter {
    private var audioFile: AVAudioFile?
    private var isWriting: Bool = false

    init?(outputURL: URL, format: AVAudioFormat) {
        do {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            // Initialize the audio file with the specified format
            audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        } catch {
            Logger.shared.error("Error initializing AVAudioFile: \(error)")
            return nil
        }
    }

    func startWriting() {
        isWriting = true
    }

    func stopWriting() {
        isWriting = false
    }

    func write(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isWriting, let audioFile = audioFile else { return }

        do {
            // Write the buffer to the audio file
            try audioFile.write(from: buffer)
        } catch {
            Logger.shared.error("Error writing audio buffer: \(error)")
        }
    }
}
