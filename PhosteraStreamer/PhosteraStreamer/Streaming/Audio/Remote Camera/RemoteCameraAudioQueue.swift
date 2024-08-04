//
//  RemoteCameraAudioManager.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/16/23.
//

import Foundation

class RemoteCameraAudioQueue {
    private var timer: DispatchSourceTimer?
    private let sampleRate: Double // Samples per second
    private let samplesPerInterval: Int
    private let queue: DispatchQueue
    
    var sampleQueue:[Data] = []
    
    func ingest(sample:Data) {
        if let _ = timer {
            if sampleQueue.count > 5 {
                sampleQueue.removeFirst()
            }
            sampleQueue.append(sample)
        }
    }

    init(sampleRate: Double, samplesPerInterval: Int, queue: DispatchQueue = .global(qos: .default)) {
        self.sampleRate = sampleRate
        self.samplesPerInterval = samplesPerInterval
        self.queue = queue
    }

    func startTimer(handler: @escaping () -> Void) {
        let interval = Double(samplesPerInterval) / sampleRate

        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval)
        timer?.setEventHandler(handler: handler)
        timer?.resume()
    }

    func stopTimer() {
        timer?.cancel()
        timer = nil
        sampleQueue.removeAll()
    }

    deinit {
        stopTimer()
    }
}
