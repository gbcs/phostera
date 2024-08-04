//
//  VideoDecoder.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/25/23.
//

import Foundation
import VideoToolbox

class VideoDecoder {
    private var decompressionSession: VTDecompressionSession?
    private var callback: ((CVImageBuffer?) -> Void)?
    
    init(videoFormatDescription: CMVideoFormatDescription, callback: @escaping (CVImageBuffer?) -> Void) {
        self.callback = callback
        
        var attributes: [String: Any] = [:]
        attributes[kCVPixelBufferMetalCompatibilityKey as String] = kCFBooleanTrue
        let destinationImageBufferAttributes = attributes as CFDictionary
        let decoderSpecification: [String: Any] = [:]
        
        var outputCallback = VTDecompressionOutputCallbackRecord(decompressionOutputCallback: decompressionOutputCallback, decompressionOutputRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        _ = VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: videoFormatDescription, decoderSpecification: decoderSpecification as CFDictionary, imageBufferAttributes: destinationImageBufferAttributes, outputCallback: &outputCallback, decompressionSessionOut: &decompressionSession)
  
    }
    
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        var infoFlags = VTDecodeInfoFlags(rawValue: 0)
        VTDecompressionSessionDecodeFrame(decompressionSession!, sampleBuffer: sampleBuffer, flags: [], frameRefcon: nil, infoFlagsOut: &infoFlags)
     
    }
    
    deinit {
        decompressionSession = nil
    }
    
    func handleDecompressedFrame(imageBuffer: CVImageBuffer?) {
        callback?(imageBuffer)
    }
}

// Global function for callback
func decompressionOutputCallback(decompressionOutputRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon: UnsafeMutableRawPointer?, status: OSStatus, infoFlags: VTDecodeInfoFlags, imageBuffer: CVImageBuffer?, presentationTimeStamp: CMTime, presentationDuration: CMTime) {
    guard let refCon = decompressionOutputRefCon else { return }
    let decoder = Unmanaged<VideoDecoder>.fromOpaque(refCon).takeUnretainedValue()
    decoder.handleDecompressedFrame(imageBuffer: imageBuffer)
}

