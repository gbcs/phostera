//
//  HistogramCalculator.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/19/23.
//

import Foundation
import Accelerate
import AVFoundation
import UIKit

class HistogramCalculator {
    private var histogram: UnsafeMutablePointer<vImagePixelCount>
    private let queue = DispatchQueue(label: "com.phostera.camera.histogram")
    var layer:CALayer?
    
    //Investigate why the last entry in the array acts oddly (visible as a line at right end; either a bucket for leftovers or perhaps indicates an issue with coverage that should be fixed?
    let widths: [CGFloat] = Array(stride(from: 0.0, to: 255.0, by: 1.0))
    
    func updateLayer(visualLayer:CALayer) {
        precondition(Thread.isMainThread)
        layer = visualLayer
        layer?.backgroundColor = UIColor.clear.cgColor
    }
    
    init() {
        histogram = UnsafeMutablePointer<vImagePixelCount>.allocate(capacity: 4 * 256)
        histogram.initialize(repeating: 0, count: 4 * 256)
    }

    deinit {
        histogram.deallocate()
    }
    
    func calculate(for sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
            let width = vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer))
            let height = vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer))
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            
            var srcBuffer = vImage_Buffer(data: baseAddress, height: height, width: width, rowBytes: bytesPerRow)
            
            var histogramPointers: [UnsafeMutablePointer<vImagePixelCount>?] = [
                self.histogram,                    // alpha
                self.histogram.advanced(by: 256),   // red
                self.histogram.advanced(by: 512),   // green
                self.histogram.advanced(by: 768)    // blue
            ]

            histogramPointers.withUnsafeMutableBufferPointer { bufferPointer in
                let flags: vImage_Flags = 0
                if let ba = bufferPointer.baseAddress {
                    vImageHistogramCalculation_ARGB8888(&srcBuffer, ba, flags)
                }
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
  
            guard let layer else { return }
            layer.bounds.size = CGSizeMake(256,64)
            
            UIGraphicsBeginImageContextWithOptions(layer.bounds.size, false, layer.contentsScale)
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            let maxCount = self.maxHistogramValue()
            let scaleFactor = maxCount == 0 ? 0 : Float(height) / Float(maxCount)
            
            let channelColors: [UIColor] = [.red, .green, .blue, .white]
            
            var point:CGPoint = .zero

            for y in [0.0, 1.0, 2.0, 3.0] {
                context.setStrokeColor(channelColors[Int(y)].cgColor)
                for x in widths {
                    point.x = x
                    point.y = 64 - (CGFloat(Float(self.histogram[(Int(y) * 256) + Int(x)]) * scaleFactor))
                    if x == 0.0 {
                        context.move(to: point)
                    } else {
                        context.addLine(to: point)
                    }
                }
                context.strokePath()
            }
            
            if let image = UIGraphicsGetImageFromCurrentImageContext()?.cgImage {
                DispatchQueue.main.async {
                    layer.contents = image
                }
            }
            UIGraphicsEndImageContext()
        }
    }

    private func maxHistogramValue() -> vImagePixelCount {
        return (0..<4 * 256).map { histogram[$0] }.max() ?? 0
    }
}
