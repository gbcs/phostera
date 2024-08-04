//
//  MovieConverter.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 10/3/23.
//

import UIKit
import AVFoundation

class VideoImporter {
    var asset: AVAsset!
    var exportSession: AVAssetExportSession!
    var videoComposition: AVMutableVideoComposition!
    var timer:Timer?
    
    init(inputURL: URL, targetFrameRate: Int, outputURL: URL, progressHandler: @escaping (Double) -> Void) {
        let url = URL(filePath: inputURL.path)

        Task {
            Logger.shared.info("Importing:\(url)")
            if let storageMedia = SettingsService.shared.currentStorageMedia {
                if let storageURL = ExternalStorageManager.loadExernalStorage(media: storageMedia) {
                    if storageURL.startAccessingSecurityScopedResource() {
                        Logger.shared.info("scr worked:\(storageURL)")
                        
                        
                        
                        self.asset = AVAsset(url: url)
                        do {
                            let tracks = try await self.asset.load(.tracks)
                            guard let videoTrack = tracks.first(where: { $0.mediaType == .video }),
                                  let _ = tracks.first(where: { $0.mediaType == .audio }) else {
                                // Handle missing tracks error
                                return
                            }
                            
                            let videoComposition = AVMutableVideoComposition()
                            let instruction = AVMutableVideoCompositionInstruction()
                            let videoLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                            instruction.layerInstructions = [videoLayerInstruction]
                            videoComposition.instructions = [instruction]
                            
                            videoComposition.renderSize = CGSize(width: 1920, height: 1080)
                            videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFrameRate))
                            
                            let exportSession = AVAssetExportSession(asset: self.asset, presetName: AVAssetExportPresetHighestQuality)
                            exportSession?.outputURL = outputURL
                            exportSession?.outputFileType = .mov
                            exportSession?.videoComposition = videoComposition
                            
                            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                                progressHandler(Double(exportSession?.progress ?? 0))
                                if exportSession?.status == .completed || exportSession?.status == .failed || exportSession?.status == .cancelled {
                                    timer.invalidate()
                                }
                            }
                            
                            try? FileManager.default.copyItem(at: url, to: outputURL)
                            storageURL.stopAccessingSecurityScopedResource()
                            return
                            
//                            exportSession?.exportAsynchronously {
//                                Logger.shared.info("export status:\(String(describing: exportSession?.status.rawValue))")
//                                timer.invalidate()
//                                storageURL.stopAccessingSecurityScopedResource()
//                                Logger.shared.error("Export complete. \(outputURL)")
//                            }
                        } catch {
                            Logger.shared.error("Unable to import video: \(inputURL) - \(error.localizedDescription)")
                            storageURL.stopAccessingSecurityScopedResource()
                        }
                    }
  
                }
            }
        }
    }
    
}
