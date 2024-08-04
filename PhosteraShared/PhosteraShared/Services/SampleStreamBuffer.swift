//
//  SampleStreamBuffer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/16/23.
//

import Foundation
import AVFoundation

public class SampleStreamBuf {
    public var buffers:[CMSampleBuffer] = []
}

public class SampleStreamBuffer {
   public static var shared = SampleStreamBuffer()
    
    private let queue = DispatchQueue(label: "StreamBufferQueue", attributes: [], autoreleaseFrequency: .workItem)
    
    private var buffer:[String:SampleStreamBuf] = [:]
    
    public func ingest(uuid:String, sampleBuffer:CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            if let buf = buffer[uuid] {
                buf.buffers.append(sampleBuffer)
            } else {
                let buf = SampleStreamBuf()
                buffer[uuid] = buf
                buf.buffers.append(sampleBuffer)
            }
        }
    }
    
    var startPull:[String] = []
    
    public func getBuffer(uuid:String) -> CMSampleBuffer? {
        var found:CMSampleBuffer?
        queue.sync { [weak self] in
            guard let self else { return }
            if let buf = buffer[uuid] {
                if buf.buffers.count > 0 {
                    if startPull.contains(uuid)  && buf.buffers.count > 0 {
                        let b = buf.buffers.first
                        buf.buffers.removeFirst()
                        found = b
                    } else if buf.buffers.count > 10 {
                        startPull.append(uuid)
                    }
                }
            }
        }
        return found
    }
        
   public func clear(uuid:String) {
        queue.async { [weak self] in
            guard let self else { return }
            buffer.removeValue(forKey: uuid)
        }
    }
    
    public func clearAll() {
        queue.async { [weak self] in
            guard let self else { return }
            buffer.removeAll()
        }
    }
    
    public func bufferList() async -> [String] {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: Array(self.buffer.keys))
            }
        }
    }
}
