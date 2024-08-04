//
//  VideoImporter.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/4/23.
//

import UIKit
import AVFoundation
import PhosteraShared

actor VideoImporter {
    var asset: AVAsset?
    var exportSession: AVAssetExportSession?
    var composition:AVMutableComposition = AVMutableComposition()
    
    func convert(externalStorage:Bool, inputURL: URL, targetFrameRate: Int, outputURL: URL, completion: @escaping (AVAssetExportSession.Status, URL?) -> Void) async {
        
        let url = URL(filePath: inputURL.path)
        Logger.shared.info("Importing video from:\(url)")
        
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
        
        guard let asset else { return }
        let tracks = try? await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks?.first else {
            completion(AVAssetExportSession.Status.failed, nil)
            return
        }
        
        var duration:CMTime = .zero
        if let d = try? await self.asset?.load(.duration) {
            duration = d
        }
        
        var naturalSize:CGSize = .zero
        if let d = try? await videoTrack.load(.naturalSize) {
            naturalSize = d
        }
        
        var frameRate:Int = 0
        if let f = try? await videoTrack.load(.nominalFrameRate) {
            frameRate = Int(f.rounded())
        }
        
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: duration), of: videoTrack, at: CMTime.zero)
        } catch {
            completion(AVAssetExportSession.Status.failed, nil)
            return
        }
        
        if (frameRate == targetFrameRate) && (naturalSize.width == 1920) && (naturalSize.height == 1080) {
            completion(AVAssetExportSession.Status.completed, inputURL)
            return
        }

        exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1920x1080)
        
        guard let exportSession else {
            completion(AVAssetExportSession.Status.failed, nil)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mov

        let targetSize = CGSizeMake(1920, 1080)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: CMTime.zero, duration: duration)

        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let transform = CGAffineTransform(scaleX: targetSize.width / naturalSize.width, y: targetSize.height / naturalSize.height)
        transformer.setTransform(transform, at: CMTime.zero)

        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]

        exportSession.videoComposition = videoComposition

        await exportSession.export()
        
        Logger.shared.info("Video Complete. status = \(exportSession.status.rawValue) - progress = \(exportSession.progress)")
        
        if externalStorage {
            storageURL?.stopAccessingSecurityScopedResource()
        }
        
        completion(exportSession.status, exportSession.outputURL)
    }
}
