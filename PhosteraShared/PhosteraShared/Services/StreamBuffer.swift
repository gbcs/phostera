//
//  StreamBuffer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/16/23.
//

import Foundation
import AVFoundation

public class StreamBuf {
    public var buffers:[CVImageBuffer] = []
}

public class StreamBuffer {
   public static var shared = StreamBuffer()
    
    private let queue = DispatchQueue(label: "StreamBufferQueue", attributes: [], autoreleaseFrequency: .workItem)
    
    private var buffer:[String:StreamBuf] = [:]
    
    public func ingest(uuid:String, image:CVImageBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            let s = buffer[uuid]?.buffers ?? []
            if s.count > 5 {
                buffer[uuid]?.buffers.removeFirst()
            }
            
            if let buf = buffer[uuid] {
                buf.buffers.append(image)
            } else {
                let buf = StreamBuf()
                buffer[uuid] = buf
                buf.buffers.append(image)
            }
        }
    }
    
    var startPull:Set<String> = []
    
    public func getBuffer(uuid:String) -> CVImageBuffer? {
        var found:CVImageBuffer?
        queue.sync { [weak self] in
            guard let self else { return }
            if let buf = buffer[uuid] {
                if let b = buf.buffers.first {
                    let count = buf.buffers.count
                    if count >= 4 {
                        startPull.insert(uuid)
                    }
                    if startPull.contains(uuid) {
                        found = b
                        if count > 1 {
                            buf.buffers.removeFirst()
                        }
                    }
                } else {
                    startPull.remove(uuid)
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
