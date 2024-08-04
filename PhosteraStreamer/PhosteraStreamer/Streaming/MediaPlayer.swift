//
//  MediaPlayer.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/15/23.
//

//Play and render like a remote camera

import UIKit
import AVFoundation
import PhosteraShared
import Combine

let PX_BUFFER_OPTS = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

class MediaPlayer {
    private var asset:AVAsset?
    private var assetReader:AVAssetReader?
    private var videoTrack:AVAssetTrack?
    private var audioTrack:AVAssetTrack?
    private var videoOutput:AVAssetReaderTrackOutput?
    private var audioOutput:AVAssetReaderTrackOutput?
    private var mediaURL:URL?
    private var uuid:String = ""
    private var videoReady:Bool = false
    private var audioReady:Bool = false
    private var assetReaderHappy:Bool = false
    private var mediaSaysReady:Bool = false
    private var transform:CGAffineTransform = .identity
    private var began:Bool = false
    private var imageGenerator:AVAssetImageGenerator?
    private var duration:CMTime = .zero
    private var paused:Bool = false
    private var seekingURL:URL?
    private var seekingUUID:String?
    private let useAudioTrack:Bool = false
    private var playingURL:URL?
    
    var firstTimestamp:CMTime = .zero
    @Published var mediaPosition: CMTime = .zero
    
    func getPlayingURL() -> URL? {
        return playingURL
    }
    
    func isPaused() -> Bool {
        return paused
    }
    
    func togglePaused() -> Bool {
        paused.toggle()
        return paused
    }
    
    func hasFramesToPull() -> Bool {
        return assetReaderHappy && assetReader?.status == .reading
    }
    
    func hasMedia() -> Bool {
        return mediaURL != nil 
    }
    
    private func failed(why:String) {
        let localUUID = uuid
        stop()
        DispatchQueue.main.async {
            Logger.shared.error("MediaPlayer failed: \(localUUID) - \(why)")
            NotificationCenter.default.post(name: Notification.Name.mediaFailed, object: nil,  userInfo: ["uuid" : localUUID])
        }
    }
    
    func complete() {
        let localUUID = uuid
        stop()
        DispatchQueue.main.async {
            Logger.shared.info("MediaPlayer completed: \(localUUID)")
            NotificationCenter.default.post(name: Notification.Name.mediaCompleted, object: nil,  userInfo: ["uuid" : localUUID])
        }
    }
    
    private func figureRemainingDuration(start:CMTime) -> CMTime {
        return CMTimeSubtract(duration, start)
    }
    
    private func startReading(at:CMTime?) -> Void {
        if useAudioTrack {
            if !(videoReady && audioReady) {
                return
            }
        } else {
            if !videoReady {
                return
            }
        }
        
        if mediaSaysReady { return } //the other one was first
        mediaSaysReady = true
        assetReaderHappy = false
    
        guard let asset else {
            failed(why: "No asset from Asset \(String(describing: mediaURL))")
            return
        }
        
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            failed(why: "No assetReader from Asset \(uuid)")
            return
        }
        
        guard let assetReader else {
            failed(why: "No assetReader  \(String(describing: mediaURL))")
            return
        }
        
        guard let at else { return }
        
        if let videoTrack {
            videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: PX_BUFFER_OPTS)
           
            if let videoOutput {
                videoOutput.alwaysCopiesSampleData = false
                videoOutput.supportsRandomAccess = true
                assetReader.add(videoOutput)
            }
        }

//        if let audioTrack {
//            let audioSettings: [String: Any] = [
//                           AVFormatIDKey: kAudioFormatLinearPCM,
//                           AVSampleRateKey: 44100,
//                           AVNumberOfChannelsKey: 2,
//                           AVLinearPCMBitDepthKey: 32,
//                           AVLinearPCMIsBigEndianKey: true,
//                           AVLinearPCMIsFloatKey: false,
//                           AVLinearPCMIsNonInterleaved: false
//                       ]
// 
//            audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioSettings)
//           
//            if let audioOutput {
//                audioOutput.alwaysCopiesSampleData = true
//                audioOutput.supportsRandomAccess = true
//                assetReader.add(audioOutput)
//            }
//        }
        
        Task { [weak self] in
            guard let self else { return }
            guard let videoTrack else { return }
            
            do {
                transform = try await videoTrack.load(.preferredTransform)
            } catch {
                
            }
  
            do {
                duration = try await asset.load(.duration)
            } catch {
                Logger.shared.info("Media didn't load duration \(String(describing: mediaURL)).")
            }
            
            _ = try? await asset.load(.commonMetadata)
            
            let range = CMTimeRange(start: at, duration: figureRemainingDuration(start: at))
            assetReader.timeRange = range
            
            if !assetReader.startReading() {
                failed(why: "assetReader.startReading returned no")
            } else {
                Logger.shared.info("Media player started reading \(uuid).")
                imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator?.appliesPreferredTrackTransform = true
                imageGenerator?.maximumSize = CGSizeMake(300, 300 * 9/16)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    assetReaderHappy = true
                    if at == .zero {
                        NotificationCenter.default.post(name: NSNotification.Name.mediaStarted, object: nil)
                    }
                }
            }
        }
    }
    
    func playMedia(url:URL, videoUUID:String, startTime:CMTime) {
        playingURL = url
        Task(priority: .userInitiated, operation: {
            
            
            Logger.shared.info("Attempt media \(videoUUID) using url: \(url)")
            if began {
                return
            }
            
            mediaURL = URL.documentsDirectory.appending(path: "footage").appendingPathComponent(url.lastPathComponent)
            
            guard let mediaURL else { return }
            
            if !FileManager.default.fileExists(atPath: mediaURL.path) {
                failed(why: "No file at url provided \(mediaURL)")
                return
            }
            
            uuid = videoUUID
            asset = AVAsset(url: url)
            
            guard let asset else {
                failed(why: "No asset url provided")
                return
            }
            
            audioTrack = nil
            videoTrack = nil
            
            Logger.shared.info("Play media loading tracks \(videoUUID) using url: \(url)")
            
            asset.loadTracks(withMediaType: .video, completionHandler: { [weak self] tracks, error in
                guard let self else { return }
                if let tracks {
                    if tracks.count > 0 {
                        videoTrack = tracks.first
                    }
                }
                if let videoTrack {
                    Task {
                        do {
                            let naturalTimeScale = try await videoTrack.load(.naturalTimeScale)
                            Logger.shared.info("naturalTimeScale:\(naturalTimeScale)")
                        } catch {
                            
                        }
                    }
                }
                videoReady = true
                startReading(at:startTime)
            })
            
//            if useAudioTrack {
//                asset.loadTracks(withMediaType: .audio, completionHandler: { [weak self] tracks, error in
//                    guard let self else { return }
//                    if let tracks {
//                        if tracks.count > 0 {
//                            audioTrack = tracks.first
//                        }
//                    }
//                    audioReady = true
//                    startReading(at:startTime)
//                })
//            }
        })
    }
    
    func stop() {
        playingURL = nil
        imageGenerator = nil
        assetReader?.cancelReading()
        videoTrack = nil
        audioTrack = nil
        videoOutput = nil
        audioOutput = nil
 
        assetReader = nil
        duration = .zero
        asset = nil
        mediaURL = nil
        StreamBuffer.shared.clear(uuid: uuid)
        uuid = ""
        
        videoReady = false
        audioReady = false
        assetReaderHappy = false
        mediaSaysReady = false
        paused = false
        firstTimestamp = .zero
        began = false
    }
    
    enum MediaPlayFrameType: Int {
        case video = 0
        case audio = 1
    }
    
    let frameSkipConstant = 8
    var frameSkip:Int = 0
    
    func getNextFrame(type:MediaPlayFrameType, completion: @escaping (CMSampleBuffer?, String) -> Void) {
        let localUUID = uuid
        
        frameSkip += 1
        if frameSkip > frameSkipConstant {
            frameSkip = 1
            handleSeekQueue()
        }
        
        if assetReader?.status == .completed {
            complete()
            completion(nil, localUUID)
            return
        }
        
        if mediaSaysReady && assetReaderHappy {
            switch(assetReader?.status) {
            case .failed:
                failed(why:"assetReader failed after being happy")
                completion(nil, localUUID)
                return
            default:
                break
            }
            
            Task(priority: .userInitiated, operation: {
                switch(type) {
                case .audio:
                    if useAudioTrack {
                        if audioTrack != nil {
                            if let buffer = audioOutput?.copyNextSampleBuffer() {
                                completion(buffer, uuid)
                            }
                        }
                    }
                case .video:
                    if let assetReader, assetReader.status == .reading {
                        if let buffer = videoOutput?.copyNextSampleBuffer() {
                            let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                            DispatchQueue.main.async { [weak self] in
                                guard let self else { return }
                                mediaPosition = pts
                            }
                            completion(buffer, uuid)
                        } else {
                            complete()
                            completion(nil, localUUID)
                        }
                    } else {
                        completion(nil, localUUID)
                    }
                }
            })
        } else {
            completion(nil, localUUID)
        }
    }
    
    func mediaDuration() -> CMTime {
        return duration
    }
    
    var seekQueue:[(URL, String, CMTime)] = []
    
    func seek(to:CMTime) {
        guard let mediaURL else { return }
        seekQueue.append((mediaURL, uuid, to))
    }
    
    func handleSeekQueue() {
        if let (localURL, localUUID, to) = seekQueue.first {

            seekQueue.removeFirst()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                stop()
                let urlAudio = localURL.appendingPathExtension("caf")
                try? MediaAudioPlayer.shared.loadAudioFile(with: urlAudio)
                MediaAudioPlayer.shared.seek(to: to)
                MetalTool.shared.startMediaBuffer()
                playMedia(url: localURL, videoUUID: localUUID, startTime: to)
            }
        }
    }
    
    func generateThumbnail(time: CMTime) -> UIImage? {
        if !assetReaderHappy { return nil }
        guard let imageGenerator else { return nil }
  
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            Logger.shared.error("Error generating thumbnail: for \(String(describing: mediaURL)) - \(error.localizedDescription)")
            return nil
        }
    }
    
}
