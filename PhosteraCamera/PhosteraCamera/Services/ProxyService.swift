//
//  ProxyService.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/19/23.
//

import Foundation
import UIKit
import AVFoundation
import PhosteraShared

class ProxyService {
    static var shared = ProxyService()
    
    
    var asset: AVAsset?
    var exportSession: AVAssetExportSession?
    var videoComposition: AVMutableVideoComposition?
    
    func convert(externalStorage:Bool, inputURL: URL, targetFrameRate: Int, outputURL: URL, completion: @escaping (AVAssetExportSession.Status, URL?) -> Void) async {
        
        let url = URL(filePath: inputURL.path)
        Logger.shared.info("Converting:\(url) to \(outputURL)")
        
        var storageURL:URL?
        
        if externalStorage {
            if let storageMedia = SettingsService.shared.currentStorageMedia {
                storageURL = ExternalStorageManager.loadExernalStorage(media: storageMedia)
                if let storageURL {
                    if storageURL.startAccessingSecurityScopedResource() {
                        Logger.shared.info("scr worked:\(storageURL)")
                        
                    }
                }
            }
        }
        
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
        
        
        var duration:CMTime = .zero
        if let d = try? await self.asset?.load(.duration) {
            duration = d
        }
        
        var originalTransform:CGAffineTransform = .identity
        
        if let t = try? await videoTrack.load(.preferredTransform) {
            originalTransform = t
        }
        
        var originalSize:CGSize = .zero
        if let n = try? await videoTrack.load(.naturalSize) {
            originalSize = n
        }
        
        var renderSize = CGSizeMake(1920, 1080)
        
        if originalSize.width < originalSize.height {
            renderSize = CGSizeMake(1080, 1920)
        }
        var transform = originalTransform
        
        let angle = atan2(originalTransform.b, originalTransform.a)
        if angle == .pi / 2 {
            Logger.shared.info("Rotating 90 degrees for proxy session.")
            let naturalFrame:CGRect = CGRectMake(0, 0, 1920, 1080)
            transform = originalTransform
            let preferredFrame = CGRectApplyAffineTransform(naturalFrame, transform)
            transform = originalTransform.translatedBy(x: +preferredFrame.origin.y, y: +preferredFrame.origin.x)
            //let preferredFrame2 = CGRectApplyAffineTransform(naturalFrame, transform)
            renderSize = CGSizeMake(1080, 1920)
        } else if angle == -.pi / 2 {
            Logger.shared.info("Rotating 270 degrees for proxy session.")
            let naturalFrame:CGRect = CGRectMake(0, 0, 1920, 1080)
            transform = originalTransform
            let preferredFrame = CGRectApplyAffineTransform(naturalFrame, transform)
            Logger.shared.info("nnnpreferred frame is :\(preferredFrame)")
            transform = originalTransform.translatedBy(x: +preferredFrame.origin.y, y: +preferredFrame.origin.x)
            let preferredFrame2 = CGRectApplyAffineTransform(naturalFrame, transform)
            Logger.shared.info("nnnpreferred fram2e is :\(preferredFrame2)")
            renderSize = CGSizeMake(1080, 1920)
        } else if transform != .identity {
            Logger.shared.info("Rotating 180 degrees for proxy session.")
            let naturalFrame:CGRect = CGRectMake(0, 0, originalSize.width, originalSize.height)
            transform = CGAffineTransform.identity.rotated(by: .pi)
            
            let preferredFrame = CGRectApplyAffineTransform(naturalFrame, transform)
            transform = transform.translatedBy(x: preferredFrame.origin.x, y: preferredFrame.origin.y)
        } else {
            Logger.shared.info("Using identity transform for proxy session.")
        }
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.setTransform(transform, at: CMTime.zero)
        let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
        videoCompositionInstruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        videoCompositionInstruction.layerInstructions = [instruction]
        videoComposition.instructions = [videoCompositionInstruction]
        
        guard let exportSession = AVAssetExportSession(asset: assetIn, presetName: AVAssetExportPresetHighestQuality) else {
            Logger.shared.error("Unable to create export session.")
            completion(.failed, nil)
            return
        }
    
        exportSession.videoComposition = videoComposition
        
//        if let n = try? await videoTrack.load(.metadata) {
//            exportSession.metadata = metadata
//        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mov
        
        await exportSession.export()
        
        if externalStorage {
            storageURL?.stopAccessingSecurityScopedResource()
        }
        
        Logger.shared.info("Conversion Complete. status = \(exportSession.status.rawValue) - progress = \(exportSession.progress)")
        completion(exportSession.status, exportSession.outputURL)
    }
    
    
}
