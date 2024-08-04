//
//  AIFFAudioBuffer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/15/23.
//

import Foundation
import AVFoundation

class MediaAudioBuffer {
    private var bufferQueue: [AVAudioPCMBuffer]
    private var queueDepth: Int = 3
    private let queueLock = DispatchQueue(label: "com.phostera.aiffaudiobuffer.lock")
    private var readAheadTask: DispatchWorkItem?

    private var framePosition:AVAudioFramePosition = 0
    
    init() {
        self.bufferQueue = []
        self.startReadAheadTask()
    }

    deinit {
        readAheadTask?.cancel()
    }
    
    func clear() {
        queueLock.sync {
            bufferQueue.removeAll()
        }
    }

    private func startReadAheadTask() {
        readAheadTask = DispatchWorkItem {
            while let task = self.readAheadTask, !task.isCancelled {
                self.fillQueueIfNeeded()
                Thread.sleep(forTimeInterval: 0.33)
            }
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: readAheadTask!)
    }

    private func fillQueueIfNeeded() {
        queueLock.sync {
            while bufferQueue.count < queueDepth, let buffer = self.readNextBuffer() {
                bufferQueue.append(buffer)
            }
        }
    }

    private func readNextBuffer() -> AVAudioPCMBuffer? {
        return try? MediaAudioPlayer.shared.readPCMBuffer(duration: 0.5, atFramePosition: -1)
    }

    func getSampleChunk() -> AVAudioPCMBuffer? {
        return queueLock.sync {
            guard !bufferQueue.isEmpty else { return nil }
            return bufferQueue.removeFirst()
        }
    }
}
