//
//  SampleFIFO.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/9/23.
//

import Foundation
import zlib
import AVFoundation

public actor SampleFIFO {
    private var queue: [Data] = []
    private var skipMessaging:Bool = false
    var category:String = ""
    
    public func count() -> Int {
        return queue.count
    }
    
   public init(category: String) {
        self.category = category
    }
    
   public func enqueue(_ data: Data) {
       if size() > 15 {
            if !skipMessaging {
                skipMessaging = true
                print("Skipping frames (backpressure) \(category)")
            }
           return
        } else {
            skipMessaging = false
        }
        queue.append(data)
    }
    
    public  func dequeue() -> Data? {
        if queue.isEmpty {
            return nil
        }
        return queue.removeFirst()
    }
    
    public  func dequeueAll() -> [Data] {
        let returned = queue
        queue.removeAll()
        return returned
    }
    
    public func clean() {
        queue.removeAll()
    }
    
    public  func peek() -> Data? {
        return queue.first
    }
    
    public func size() -> Int {
        return queue.count
    }
}

extension SampleFIFO {

    public static func compressSamples(srcSamples: UnsafePointer<Float32>, frameCount: Int) -> Data? {
        // Initialize zlib stream
        var zStream = z_stream()
        deflateInit_(&zStream, Z_DEFAULT_COMPRESSION, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))

        // Allocate memory for compressed data
        let bufferSize = frameCount * MemoryLayout<Float32>.size
        let compressedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        
        // Set up z_stream
        zStream.next_in = UnsafeMutablePointer(mutating: srcSamples).withMemoryRebound(to: UInt8.self, capacity: bufferSize) { $0 }
        zStream.avail_in = uInt(bufferSize)
        zStream.next_out = compressedBuffer
        zStream.avail_out = uInt(bufferSize)
        
        // Compress
        if deflate(&zStream, Z_FINISH) != Z_STREAM_END {
            // Handle compression error
            return nil
        }
        
        let compressedSize = bufferSize - Int(zStream.avail_out)
        let compressedData = Data(bytes: compressedBuffer, count: compressedSize)
        
        // Clean up
        deflateEnd(&zStream)
        compressedBuffer.deallocate()
        
        return compressedData
    }

    public static func extractAndCompressAudioSamples(from sampleBuffer: CMSampleBuffer) -> Data? {
        
        guard let p = AVAudioPCMBuffer.create(from: sampleBuffer) else { return nil }
      
        guard let srcSamples = p.floatChannelData?[0] else { return nil }
        
        guard let data = SampleFIFO.compressSamples(srcSamples: srcSamples, frameCount: 1024) else {
            print("audio sample unable to compress.")
            return nil
        }
    
        //Logger.shared.log.info("audio sample data: \(data.bytes.count)")
        return data
    }
}

extension AVAudioPCMBuffer {
    static func create(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        
        guard let description: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let sampleRate: Float64 = description.audioStreamBasicDescription?.mSampleRate,
              let channelsPerFrame: UInt32 = description.audioStreamBasicDescription?.mChannelsPerFrame /*,
                                                                                                         let numberOfChannels = description.audioChannelLayout?.numberOfChannels */
        else { return nil }
        
        guard let blockBuffer: CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        let samplesCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        //let length: Int = CMBlockBufferGetDataLength(blockBuffer)
        
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: AVAudioChannelCount(2), interleaved: false)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: AVAudioFrameCount(samplesCount))!
        buffer.frameLength = buffer.frameCapacity
        
        // GET BYTES
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: nil, dataPointerOut: &dataPointer)
        
        guard var channel: UnsafeMutablePointer<Float> = buffer.floatChannelData?[0],
              let data = dataPointer else { return nil }
        
        var data16 = UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self)
        
        for _ in 0...samplesCount - 1 {
            channel.pointee = Float32(data16.pointee) / Float32(Int16.max)
            channel += 1
            for _ in 0...channelsPerFrame - 1 {
                data16 += 1
            }
            
        }
        
        return buffer
    }
}
