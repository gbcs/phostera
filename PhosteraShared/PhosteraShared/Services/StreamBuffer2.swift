//
//  StreamBuffer2.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 11/22/23.
//

import Foundation
import AVFoundation

public actor StreamBuffer2 {
    public static var shared = StreamBuffer()

    private var buffer:[String:StreamBuf] = [:]
    
    public func ingest(uuid:String, image:CVImageBuffer) {
        let s = buffer[uuid]?.buffers ?? []
        print("Ingest starting at: \(s.count)")
        if s.count > 10 {
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
    
    var startPull:Set<String> = []
    
    public func getBuffer(uuid:String) -> CVImageBuffer? {
        var found:CVImageBuffer?
         if let buf = buffer[uuid] {
            if let b = buf.buffers.first {
                if buf.buffers.count >= 9 {
                    startPull.insert(uuid)
                }
                if startPull.contains(uuid) {
                    buf.buffers.removeFirst()
                    found = b
                    print("Pulled. remaining: \(buf.buffers.count)")
                }
            } else {
                startPull.remove(uuid)
            }
        }
        return found
    }
    
    public func clear(uuid:String) {
        buffer.removeValue(forKey: uuid)
    }
    
    public func clearAll() {
        buffer.removeAll()
    }
    
    public func bufferList() -> [String] {
        return Array(self.buffer.keys)
    }
}
