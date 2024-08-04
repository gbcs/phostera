//
//  PixelBufferPoolManager.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/23/23.
//

import Foundation
import CoreVideo

class PixelBufferPoolManager {
    private var pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPoolAttributes: [String: Any]?
    private var pixelBufferAttributes: [String: Any]?
    
    init(width: Int, height: Int, pixelFormat: OSType, minBufferCount: Int) {
        setupPixelBufferPool(width: width, height: height, pixelFormat: pixelFormat, minBufferCount: minBufferCount)
    }
    
    private func setupPixelBufferPool(width: Int, height: Int, pixelFormat: OSType, minBufferCount: Int) {
        pixelBufferPoolAttributes = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: minBufferCount
        ]
        
        pixelBufferAttributes = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferMetalCompatibilityKey as String: kCFBooleanTrue as CFBoolean,
            kCVPixelBufferCGImageCompatibilityKey as String: kCFBooleanTrue as CFBoolean,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: kCFBooleanTrue as CFBoolean
        ]
    
        
        CVPixelBufferPoolCreate(nil,
                                pixelBufferPoolAttributes as CFDictionary?,
                                pixelBufferAttributes as CFDictionary?,
                                &pixelBufferPool)
    }
    
    func vendPixelBuffer() -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        guard let pixelBufferPool else { return nil }
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }
    
    deinit {
        pixelBufferPool = nil
    }
}
