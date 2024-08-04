//
//  VideoImporter.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/22/23.
//

import Foundation
//
//  VideoImporter.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/4/23.
//

import UIKit
import AVFoundation

public class SharedVideoImporter {
    private var asset: AVAsset?
    var exportSession: AVAssetExportSession?
    private var videoComposition: AVMutableVideoComposition?
    
    public init() {
    }
    
    public func getProgress() -> Float {
        return exportSession?.progress ?? 0.0
    }
    
    public func convert(inputURL: URL, targetFrameRate: Int, outputURL: URL, completion: @escaping (AVAssetExportSession.Status, URL?) -> Void) async {
        let url = URL(filePath: inputURL.path)
  
        let assetIn = AVAsset(url: url)
        self.asset = assetIn
        let tracks = try? await self.asset?.load(.tracks)
        guard let videoTrack = tracks?.first(where: { $0.mediaType == .video }),
              let _ = tracks?.first(where: { $0.mediaType == .audio }) else {
            completion(AVAssetExportSession.Status.failed, nil)
            return
        }
        
        guard let exportSession = AVAssetExportSession(asset: assetIn, presetName: AVAssetExportPresetHEVC1920x1080) else {
            completion(AVAssetExportSession.Status.failed, nil)
            return
        }
        
        self.exportSession = exportSession
        
        let targetSize = CGSize(width: 1920, height: 1080)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mov
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // Assuming 30 fps
        
        let instruction = AVMutableVideoCompositionInstruction()
        
        var duration:CMTime = .zero
        if let d = try? await self.asset?.load(.duration) {
            duration = d
        }
        
        var naturalSize:CGSize = .zero
        if let n = try? await videoTrack.load(.naturalSize) {
            naturalSize = n
        }
        
        instruction.timeRange = CMTimeRange(start: CMTime.zero, duration: duration)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let transform = CGAffineTransform(scaleX: targetSize.width / naturalSize.width,
                                          y: targetSize.height / naturalSize.height)
        transformer.setTransform(transform, at: CMTime.zero)
        
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        exportSession.videoComposition = videoComposition
        
        await exportSession.export()

        completion(exportSession.status, exportSession.outputURL)
    }
}
