//
//  StreamTimer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/18/23.
//

import Foundation

class StreamTimer {
    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval
    private var currentIndex: Int = 0
    private var action: (() -> Void)
    private let queue = DispatchQueue(label: "StreamTimer", attributes: [], autoreleaseFrequency: .workItem)
   
    init(milliseconds: Double, action: @escaping () -> Void) {
        self.interval = TimeInterval(milliseconds) / 1000
        self.action = action
    }

    func start() {
        currentIndex = 0
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval)
        timer?.setEventHandler(handler: {
            self.currentIndex += 1
            MetalTool.shared.nextFrame()
        })
        timer?.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func getCurrentIndex() -> Int {
        return currentIndex
    }
}
