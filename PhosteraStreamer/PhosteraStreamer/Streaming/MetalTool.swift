//
//  Merger.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/13/23.
//
// Greedily combine the listed cameras into a grid.
// Add a background
// Add the streamer
// Add titling


import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import MetalKit
import VideoToolbox
import PhosteraShared
import Combine
import OSLog

enum CameraSetupError: Error {
    case isSimulator
    case noCameras
    case badSetup
}

class MetalTool  {
    static var shared = MetalTool()
    
    private var displayView:PreviewMetalView?
    private var metalCommandQueue:MTLCommandQueue?
    
    private var renderingEnabled:Bool = false
    
    private let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    //private let processingQueue = DispatchQueue(label: "photo processing queue", attributes: [], autoreleaseFrequency: .workItem)
    
    private var ciContext : CIContext?
    private var filteredImage: CIImage?
    private var cleanImage: CIImage?
    
    private var project:StreamProjectModel?
    
    var streamer:Streamer = Streamer()
    var camera:Camera = Camera()
    var mediaPlayer:MediaPlayer = MediaPlayer()
    var documentPlayer:DocumentPlayer = DocumentPlayer()
    
    var mediaShown:Bool = false
    
    var colorConverter:ColorConverter?
    
    var orientationSub:AnyCancellable?
    
    func startMedia(url:URL) {
        Logger.shared.info("Add media: \(url)")
        let p = url.lastPathComponent
        
        let url = FootageService.footageDirectory.appending(path: p)
        if FileManager.default.fileExists(atPath: url.path) {
            let urlAudio = url.appendingPathExtension("caf")
            try? MediaAudioPlayer.shared.loadAudioFile(with: urlAudio)
            MetalTool.shared.startMediaBuffer()
            MetalTool.shared.mediaPlayer.playMedia(url: url, videoUUID: "video1", startTime: .zero)
            Logger.shared.info("atsv(good)Play media using url: \(url.path)")
        } else {
            Logger.shared.error("Media not found at url \(url.path)")
        }
    }
    
    func getDisplayView() -> PreviewMetalView? {
        return displayView
    }
    
    var frameInterval:UInt64 = 33_000_000
    var frameRate:Int32 = 30
    
    func startRendering(withProject:StreamProjectModel) {
        project = withProject
        switch withProject.streamFrameRate {
        case .fr24:
            frameInterval = 41_670_000 // 24.fps
            frameRate = 24
        case .fr25:
            frameInterval = 40_000_000 // 25 fps
            frameRate = 25
        case .fr30:
            frameInterval = 33_000_000 // 30fps
            frameRate = 30
        }
        
        update(rendering: true)
        //  self.startDataTimer()
    }
    
    func updateBaseImage() {
        createBaseImage(completion: { [weak self] result in
            guard let self else { return }
            if let image = try? result.get() {
                update(baseImage: image)
            }
        })
    }
    
    func stopRendering() {
        update(rendering: false)
        displayView?.removeFromSuperview()
        displayView = nil
    }
    
    func startDisplayView() {
        displayView = PreviewMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        orientationSub = PubCentral.shared.orientationChanged.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            orientationUpdate()
        }
        
        orientationUpdate()
        
        startFrameTimer()
        
    }
    
    func orientationUpdate() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                update(orientation: windowScene.interfaceOrientation)
                Logger.shared.info("orientation:\(windowScene.interfaceOrientation.rawValue)")
            }
        }
    }
    
    func update(baseImage:CIImage) {
        self.baseImage = baseImage
    }
    
    private func update(displayView:PreviewMetalView) {
        self.displayView = displayView
    }
    
    func update(rendering:Bool) {
        Logger.shared.info("Rendering: \(rendering)")
        renderingEnabled = rendering
        if renderingEnabled {
            updatePreset()
            updateBaseImage()
        }
    }
    
    var streamSourceOrientations:[String:UIInterfaceOrientation] = [:]
    
    func updateSource(orientation:UIInterfaceOrientation, uuid:String) {
        streamSourceOrientations[uuid] = orientation
    }
    
    private var isFillingStreamPixelBuffers:Bool = false
    
    func startFillingStreamPixelBuffers() {
        updatePreset()
        dataOutputQueue.async {
            StreamBuffer.shared.clearAll()
        }
    }
    
    private var frontCameraBuffer:CMSampleBuffer?
    private var rearCameraBuffer:CMSampleBuffer?
    
    private var mediaPlayerBuffer:CVImageBuffer?
    
    
    var frameCount:Int = 0
    var frameMax:Int = 15
    
    var mediaBuffer:MediaAudioBuffer?
    
    func startMediaBuffer() {
        mediaBuffer = MediaAudioBuffer()
        frameCount = -30
    }
    
    func stopMediaBuffer() {
        mediaBuffer = nil
        frameCount = -30
    }
    
    
    func useMediaPlayerBuffer(video:CVImageBuffer?) {
        dataOutputQueue.sync {
            mediaPlayerBuffer = video
        }
    }
    
    func useCameraBuffer(rear:CMSampleBuffer?) {
        dataOutputQueue.sync {
            rearCameraBuffer = rear
        }
    }
    
    func useCameraBuffer(front:CMSampleBuffer?) {
        dataOutputQueue.sync {
            frontCameraBuffer = front
        }
    }
    
    func stopFillingStreamPixelBuffers() {
        dataOutputQueue.async {
            StreamBuffer.shared.clearAll()
        }
    }
    
    func createBlankCIImage(width: CGFloat, height: CGFloat, color: CIColor) -> CIImage {
        let filter = CIFilter(name: "CIConstantColorGenerator")!
        filter.setValue(color, forKey: kCIInputColorKey)
        
        let i = filter.outputImage!
        let croppedImage = i.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        
        return croppedImage
    }
    
    func createCIImageFromPNG(url: URL) -> CIImage? {
        let p = url.lastPathComponent
        let p2 = FootageService.footageDirectory.appendingPathComponent(p)
        if FileManager.default.fileExists(atPath: p2.path) {
            Logger.shared.info("File exists: \(p2) - \(p2.isFileURL)")
        } else {
            Logger.shared.info("File NOT exist: \(p2) - \(p2.isFileURL)")
        }
        
        guard let d = try? Data(contentsOf: p2) else { return nil }
        guard let u = UIImage(data: d) else { return nil }
        guard let c = u.cgImage else { return nil }
        let image = CIImage(cgImage: c)
        return image
    }
    
    lazy var affineTransformFilter = CIFilter(name: "CIAffineTransform")!
    lazy var sourceOverFilter = CIFilter(name: "CISourceOverCompositing")!
    
    var currentInterfaceOrientation:UIInterfaceOrientation = UIInterfaceOrientation.landscapeLeft
    
    func update(orientation:UIInterfaceOrientation) {
        currentInterfaceOrientation = orientation
        streamer.update(orientation: orientation)
        Logger.shared.info("orientation:\(currentInterfaceOrientation)")
    }
    
    
    var bufferList:[String] = []
    
    private func updateBufferList() {
        Task {
            let keys = await StreamBuffer.shared.bufferList()
            var keyList:[String] = []
            for k in keys {
                keyList.append(k)
            }
            DispatchQueue.main.async { [weak self, keyList] in
                guard let self else { return }
                bufferList = keyList
            }
        }
    }
    
    private var frontCameraRect = CGRectMake(0, 762, 565, 317)
    
    func combineImagesByGrid(baseImage:CIImage) -> CIImage? {
        
        //        if colorConverter == nil {
        //            if let url = Bundle.main.url(forResource: "AppleLogToRec709-v1.0", withExtension: "cube") {
        //                colorConverter = ColorConverter(cubeFileURL: url)
        //            }
        //        }
        
        var combinedImage: CIImage = baseImage
        
        if mediaShown {
           // dataOutputQueue.sync {
                if let buffer = mediaPlayerBuffer {
                    let frame = CIImage(cvImageBuffer: buffer)
                    combinedImage = frame
                } else {
                    combinedImage = blankBaseImage
                }
           // }
        } else {
            let hasRearCamera:Bool = rearCameraBuffer != nil
            
            var hasRemoteCameras:Bool = false
            
            var gridKeys:[String] = []
            
            for k in bufferList {
                hasRemoteCameras = true
                gridKeys.append(k)
            }
            
            if hasRemoteCameras {
                if let key = gridKeys.first {
                    if let buffer = StreamBuffer.shared.getBuffer(uuid: key) {
                        let remoteTransform = streamSourceOrientation(uuid: key)
                        let cameraImage = CIImage(cvImageBuffer: buffer )
                        
                        var transform = CGAffineTransform.identity
                        switch remoteTransform {
                        case UIInterfaceOrientation.portrait:
                            break
                        case UIInterfaceOrientation.portraitUpsideDown:
                            break
                        case UIInterfaceOrientation.landscapeLeft:  //Camera on right
                            transform = transform.scaledBy(x: 1.0, y: -1.0)
                            transform = transform.translatedBy(x: 0, y: -1080)
                        case UIInterfaceOrientation.landscapeRight: //Camera on left
                            break
                        default:
                            break
                        }
                        
                        combinedImage = cameraImage.transformed(by: transform)
                        
                        //                        if let colorConverter {
                        //                            combinedImage = colorConverter.convert(image: cameraImage) ?? cameraImage
                        //                        } else {
                        //                            combinedImage = cameraImage
                        //                        }
                        
                    } else {
                        Logger.shared.info("Remote camera starved")
                    }
                    gridKeys.removeFirst()
                }
            } else {
                if hasRearCamera {
                    if let buffer = rearCameraBuffer {
                        if let imageBuffer = CMSampleBufferGetImageBuffer(buffer) {
                            let image = CIImage(cvImageBuffer: imageBuffer )
                            var transform = CGAffineTransform.identity
                            switch currentInterfaceOrientation {
                            case UIInterfaceOrientation.portrait:
                                transform = transform.scaledBy(x: 0.55, y: 0.55)
                                transform = transform.translatedBy(x:1000, y:0)
                            case UIInterfaceOrientation.portraitUpsideDown:
                                let cameraSize: CGSize = CGSize(width: 607, height: 1080)
                                let factor = cameraSize.width / image.extent.width
                                transform = transform.scaledBy(x: factor, y: factor)
                                transform = transform.translatedBy(x: 700, y:0)
                            case UIInterfaceOrientation.landscapeLeft:  //Camera on right
                                //                                transform = transform.scaledBy(x: 1.0, y: -1.0)
                                //                                transform = transform.translatedBy(x: 0, y: -1080)
                                break
                            case UIInterfaceOrientation.landscapeRight: //Camera on left
                                break
                            default:
                                break
                            }
                            
                            let transformedImage = image.transformed(by: transform)
                            
                            if let newCombinedImage = CIFilter(name: "CISourceOverCompositing", parameters: [kCIInputImageKey: transformedImage, kCIInputBackgroundImageKey: combinedImage])?.outputImage {
                                combinedImage = newCombinedImage
                            }
                        }
                    }
                }
            }
            
            if gridKeys.count > 0 {
                combinedImage = createErrorCIImage(width: 1920, height: 1080, color: .blue, message: "Grid mode not available.")
            }
            
        }
        
        let cameraSize = frontCameraRect.size
        
        if let frontCameraBuffer {
           // dataOutputQueue.sync {
                if let imageBuffer = CMSampleBufferGetImageBuffer(frontCameraBuffer) {
                    let image = CIImage(cvImageBuffer: imageBuffer)
                    var transformedImage: CIImage?
                    
                    var transform = CGAffineTransform.identity
                    switch currentInterfaceOrientation {
                    case UIInterfaceOrientation.portrait:
                        let factor = cameraSize.width / image.extent.width
                        transform = transform.scaledBy(x: factor, y: factor)
                    case UIInterfaceOrientation.portraitUpsideDown:
                        let factor = cameraSize.width / image.extent.width
                        transform = transform.scaledBy(x: factor, y: factor)
                    case UIInterfaceOrientation.landscapeLeft:  //Camera on right
                        transform = transform.translatedBy(x: frontCameraRect.origin.x, y: 1080 - (frontCameraRect.origin.y + frontCameraRect.size.height))
                        transform = transform.scaledBy(x: cameraSize.width / image.extent.width, y: cameraSize.height / image.extent.height)
                    case UIInterfaceOrientation.landscapeRight: //Camera on left
                        transform = transform.translatedBy(x: frontCameraRect.origin.x, y: 1080 - (frontCameraRect.origin.y + frontCameraRect.size.height))
                        transform = transform.scaledBy(x: cameraSize.width / image.extent.width, y: cameraSize.height / image.extent.height)
                    default:
                        break
                    }
                    
                    transformedImage = image.transformed(by: transform)
                    
                    if let newImage = transformedImage {
                        if let newCombinedImage = CIFilter(name: "CISourceOverCompositing",
                                                           parameters: [kCIInputImageKey: newImage,
                                                              kCIInputBackgroundImageKey: combinedImage
                                                                       ])?.outputImage {
                            combinedImage = newCombinedImage
                        }
                    }
                }
          //  }
        }
        
        if (combinedImage.extent.width != 1920) ||
            (combinedImage.extent.height != 1080) ||
            (combinedImage.extent.origin.x != 0.0) ||
            (combinedImage.extent.origin.y != 0.0) {
            
            let s = "Extent: \(combinedImage.extent)"
            
            combinedImage = createErrorCIImage(width: 1920, height: 1080, color: .blue, message: s)
        }
        
        return combinedImage
    }
    
    func createErrorCIImage(width: CGFloat, height: CGFloat, color: CIColor, message: String) -> CIImage {
        let filter = CIFilter(name: "CIConstantColorGenerator")!
        filter.setValue(color, forKey: kCIInputColorKey)
        
        let colorImage = filter.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        
        let font = UIFont.systemFont(ofSize: 48)  // Set font size as needed
        let textAttributes: [NSAttributedString.Key : Any] = [
            .font: font,
            .foregroundColor: UIColor.white  // Set text color as needed
        ]
        
        let text = NSAttributedString(string: message, attributes: textAttributes)
        let textFilter = CIFilter.attributedTextImageGenerator()
        textFilter.text = text
        
        
        let textImage = textFilter.outputImage!
        
        let combinedImage = textImage.composited(over: colorImage)
        
        return combinedImage
    }
    
    private var streamPanes:[StreamPane] = []
    
    
    func streamSourceOrientation(uuid:String) -> UIInterfaceOrientation {
        return streamSourceOrientations[uuid] ?? .landscapeLeft
    }
    
    func createBlankPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [kCVPixelBufferMetalCompatibilityKey as String: true]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         options as CFDictionary,
                                         &pixelBuffer)
        
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    func updatePreset() {
        //Read the stream pane data so the compositor can have fun
        Task {
            let project = await ProjectService.shared.currentProject()
            let panes = project.presets[project.currentPreset]
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                streamPanes = panes
                
                for pane in streamPanes {
                    if  pane.streamPixelRef == "front" {
                        frontCameraRect = pane.frame
                        Logger.shared.info("Found front camera pane.")
                        break
                    }
                }
            }
        }
    }
    
    let frameDuration = CMTime(value: 1, timescale: 24)
    
    func pixelBufferToSampleBuffer(pixelBuffer: CVPixelBuffer, formatDescription: CMFormatDescription, timestamp:CMTime, duration:CMTime) -> CMSampleBuffer? {
        
        
        var timingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: CMTime.invalid // decodeTimeStamp is often set to invalid for video
        )
        
        frameCount += 1
        
        var sampleBuffer: CMSampleBuffer?
        
        let err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: pixelBuffer,
                                                     dataReady: true,
                                                     makeDataReadyCallback: nil,
                                                     refcon: nil,
                                                     formatDescription: formatDescription,
                                                     sampleTiming: &timingInfo,
                                                     sampleBufferOut: &sampleBuffer)
        
        if err == noErr {
            return sampleBuffer
        } else {
            Logger.shared.error("Error: \(err)")
            return nil
        }
    }
    
    func createFormatDescription(width: Int32, height: Int32) -> CMFormatDescription? {
        var formatDescription: CMFormatDescription? = nil
        let dimensions = CMVideoDimensions(width: width, height: height)
        
        let status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                    codecType: kCVPixelFormatType_32BGRA,
                                                    width: dimensions.width,
                                                    height: dimensions.height,
                                                    extensions: nil,
                                                    formatDescriptionOut: &formatDescription)
        
        return (status == noErr) ? formatDescription : nil
    }
    
    lazy var formatDescription = createFormatDescription(width: 1920, height: 1080)
    
    func createBaseImage(completion: @escaping (Result<CIImage, Error>) -> Void) {
        Task {
            let project = await ProjectService.shared.currentProject()
            if let background = project.mediaBackgroundImage {
                if let image = createCIImageFromPNG(url: background.url) {
                    completion(.success(image))
                    return
                }
            }
            
            completion(.success(createBlankCIImage(width: 1920, height: 1080, color: CIColor(red: 0, green: 0, blue: 0, alpha: 1))))
        }
    }
    
    var baseImage:CIImage?
    lazy var blankBaseImage:CIImage = createBlankCIImage(width: 1920, height: 1080, color: CIColor(red: 0, green: 0, blue: 0, alpha: 1))
    
    let bufferUpdateInterval = 12
    var bufferUpdateCounter:Int = 0
    var bufferIndex:UInt64 = 0
    // Helper function to create a Metal-compatible pixel buffer
    func createMetalCompatiblePixelBuffer(from ciImage: CIImage) -> CVPixelBuffer? {
        let width = Int(ciImage.extent.width)
        let height = Int(ciImage.extent.height)
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue as CFBoolean,
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue as CFBoolean,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue as CFBoolean
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer)
        if status != kCVReturnSuccess {
            Logger.shared.error("Failed to create pixel buffer with error: \(status)")
            return nil
        }
        
        let context = CIContext()
        context.render(ciImage, to: pixelBuffer!)
        
        return pixelBuffer
    }
    
    // Helper function to create a sample buffer from a pixel buffer
    func createSampleBuffer(from pixelBuffer: CVPixelBuffer, using timingInfo: CMSampleTimingInfo, formatDescription: CMFormatDescription) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var timingInfoOut = timingInfo
        let sampleBufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfoOut,
            sampleBufferOut: &sampleBuffer
        )
        
        if sampleBufferStatus != kCVReturnSuccess {
            Logger.shared.error("Failed to create sample buffer with error: \(sampleBufferStatus)")
            return nil
        }
        
        return sampleBuffer
    }
    
    
    var frameTimer:StreamTimer?
    
    
    func startFrameTimer() {
        if frameTimer != nil {
            stopFrameTimer()
        }
        Task {
            let project = await ProjectService.shared.currentProject()
            let frameRate = ProjectService.frameRate(project: project)
            frameTimer = StreamTimer(milliseconds:frameRate, action: nextFrame)
            frameTimer?.start()
        }
    }
    
    func stopFrameTimer() {
        frameTimer?.stop()
        frameTimer = nil
    }
    
    var pixelBufferPool:PixelBufferPoolManager = PixelBufferPoolManager(width: 1920,
                                                                        height: 1080,
                                                                        pixelFormat:kCVPixelFormatType_32BGRA,
                                                                        minBufferCount: 4)
    
    func nextFrame() {
        
        frameCount += 1
        if frameCount >= frameMax {
            frameCount = 0
            if let mediaBuffer {
                if !MetalTool.shared.mediaPlayer.isPaused() {
                    if let buffer = mediaBuffer.getSampleChunk() {
                        AudioTool.shared.play(media: buffer)
                    }
                }
            }
        }
        
        
        if ciContext == nil {
            if let displayView, let d = displayView.device {
                ciContext = CIContext(mtlDevice: d)
            }
        }
        
        if ciContext == nil { return }
        
        guard let baseImage else { return }
        
        var outputImage = (streamer.streamState == .live) || (streamer.streamState == .offline) ? baseImage : blankBaseImage
        
        if mediaShown {
            if !mediaPlayer.isPaused() {
                mediaPlayer.getNextFrame(type: .video, completion: { videoSample, uuid in
                    guard let videoSample else { return }
                    if let imageBuffer = CMSampleBufferGetImageBuffer(videoSample) {
                        MetalTool.shared.useMediaPlayerBuffer(video: imageBuffer)
                    }
                })
            }
            
            if !mediaPlayer.hasMedia() {
                if WatchEntryManager.shared.mediaQueue.count > 0 {
                    if let url = URL(string: WatchEntryManager.shared.mediaQueue.first ?? "") {
                        startMedia(url: url)
                    }
                }
            }
        }
        
        bufferUpdateCounter += 1
        if bufferUpdateCounter > 0 {
            updateBufferList()
            bufferUpdateCounter = 0
        }
        
        dataOutputQueue.sync {
            if let combined = combineImagesByGrid(baseImage: outputImage) {
                outputImage = combined
            }
        }
        
        guard let displayView else { return }
        
//        if !displayView.isPaused {
//            displayView.isPaused = true
//        }
        
        if displayView.isPaused {
            displayView.isPaused = false
        }
        
        //displayView.preferredFramesPerSecond = 31
        
        guard let pixelBuffer = pixelBufferPool.vendPixelBuffer() else {
            Logger.shared.error("Could not create pixel buffer")
            return
        }
        
        let context = CIContext()
        context.render(outputImage, to: pixelBuffer)
//                
//        guard let pixelBuffer = createMetalCompatiblePixelBuffer(from: outputImage) else {
//            Logger.shared.error("Could not create pixel buffer from CIImage.")
//            return
//        }
        
        // Retrieve timing info from the source sample buffer
        //        let timingInfo = CMSampleTimingInfo(
        ////            duration: CMSampleBufferGetDuration(frontCamerabuffer),
        ////            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(frontCamerabuffer),
        ////            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(frontCamerabuffer)
        //
        //        )
        
        let timingInfo = CMSampleTimingInfo(
            duration: CMTimeMake(value: 1, timescale: frameRate),
            presentationTimeStamp: FrameTimer.shared.nextVideoTimestamp(),
            decodeTimeStamp: .invalid
        )
        
        // Use the format description from the source sample buffer or create a new one if necessary
        guard let formatDescription =  createFormatDescription(width: 1920, height: 1080) else {
            Logger.shared.error("Failed to get format description from the source sample buffer.")
            return
        }
        
        guard let newSampleBuffer = createSampleBuffer(from: pixelBuffer, using: timingInfo, formatDescription: formatDescription) else {
            Logger.shared.error("Could not create new sample buffer.")
            return
        }
        
        displayView.pixelBuffer = pixelBuffer
        DispatchQueue.main.async {
            displayView.setNeedsDisplay()
        }
   
        recordBuffer(sampleBuffer: newSampleBuffer)
        streamer.acceptVideoSampleBuffer(buffer: newSampleBuffer)
        
    }
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    
    private var recordingState:RecordingState = .idle
    private var outputFileName:URL?
    private var startTime:CMTime = .zero
    private var pixelBufferAdaptor:AVAssetWriterInputPixelBufferAdaptor?
    
    private var audioTimestamp:CMTime = .zero
    
    func recordBuffer(sampleBuffer: CMSampleBuffer) {
        if recordingState == .idle { return }
        
        guard let project else { return }
        guard let formatDesc:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            Logger.shared.error("captureOutput formatDesc nil")
            return
        }
        
        let mediaType:CMMediaType = CMFormatDescriptionGetMediaType(formatDesc);
        if (mediaType == kCMMediaType_Audio) {
            //            if recordingState == .assetWriterCapturing {
            //                if (assetWriterAudioInput != nil) && assetWriterAudioInput!.isReadyForMoreMediaData {
            //                    assetWriterAudioInput?.append(sampleBuffer)
            //                }
            //            }
            return // Done with audio
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        switch recordingState {
        case .assetWriterStart:
            
            let filename = "\(project.title)_" + DateService.shared.filenameForCurrentDateTime()
            
            self.outputFileName = URL.documentsDirectory
                .appending(component: project.id, directoryHint: .isDirectory)
                .appending(component: filename, directoryHint: .notDirectory)
                .appendingPathExtension(for: .quickTimeMovie)
            
            let audioOutputFilename = URL.documentsDirectory
                .appending(component: project.id, directoryHint: .isDirectory)
                .appending(component: filename, directoryHint: .notDirectory)
                .appendingPathExtension("caf")
            
            try? FileManager.default.createDirectory(at:  URL.documentsDirectory
                .appending(component: project.id, directoryHint: .isDirectory), withIntermediateDirectories: true)
            
            //Come up with a useful filename convention - project, date, time maybe
            //Come up with both audio and video urls
            //init audio writer
            
            guard let outputFileName else { return }
            
            AudioTool.shared.startWriter(url: audioOutputFilename)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,  // 10 Mbps
                    
                ]
            ]
            
            Logger.shared.info("Creating stream recording at: \(outputFileName.path()) - \(audioOutputFilename.path())")
            
            let writer = try! AVAssetWriter(outputURL: outputFileName, fileType: .mov)
            
            let avInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            
            avInput.expectsMediaDataInRealTime = true
            
            let pixelAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: avInput, sourcePixelBufferAttributes: nil)
            
            startTime = timestamp + CMTime(seconds: 5.0, preferredTimescale: timestamp.timescale)
            recordingState = .assetWriterStartWait
            
            if writer.canAdd(avInput) {
                Logger.shared.info("Addding input with transform")
                if currentInterfaceOrientation == UIInterfaceOrientation.landscapeRight {
                    Logger.shared.info("Rotating 180")
                    avInput.transform = avInput.transform.rotated(by: -.pi)
                } else if currentInterfaceOrientation == UIInterfaceOrientation.portrait {
                    Logger.shared.info("Rotating 90")
                    avInput.transform = avInput.transform.rotated(by: .pi / 2.0)
                } else if currentInterfaceOrientation == UIInterfaceOrientation.portraitUpsideDown {
                    Logger.shared.info("Rotating -90")
                    avInput.transform = avInput.transform.rotated(by: -.pi / 2.0)
                }
                
                writer.add(avInput)
            }
            
            
            assetWriter = writer
            assetWriterVideoInput = avInput
            pixelBufferAdaptor = pixelAdapter
            
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                if let assetWriter {
                    assetWriter.startWriting()
                }
            }
            
        case .assetWriterStartWait:
            if let assetWriter {
                if assetWriter.status == .writing {
                    startTime = timestamp
                    Logger.shared.info("Start Time:\(self.startTime.value) - \(self.startTime.timescale)")
                    
                    assetWriter.startSession(atSourceTime: startTime)
                    recordingState = .assetWriterCapturing
                    
                }
            }
        case .assetWriterCapturing:
            if let assetWriterVideoInput {
                if assetWriterVideoInput.isReadyForMoreMediaData == true {
                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        pixelBufferAdaptor?.append(imageBuffer, withPresentationTime:timestamp)
                    }
                }
            }
            
            break
        case .assetWriterEnding:
            AudioTool.shared.stopWriting()
            
            if assetWriter == nil {
                Logger.shared.error("assetwriter nil at .assetWriterEnding: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
                // DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
                return
            }
            
            if assetWriterVideoInput == nil {
                Logger.shared.error("assetwriterinput nil at .assetWriterEnding: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
                //  DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
                return
            }
            
            
            if assetWriter?.status == .writing {
                assetWriterVideoInput?.markAsFinished()
            }
            
            recordingState = .idle
            assetWriter?.finishWriting { [weak self] in
                guard let self else { return }
                Logger.shared.info("assetWriter finishing")
                recordingState = .idle
                assetWriter = nil
                assetWriterVideoInput = nil
                return
            }
            
            if assetWriter?.error != nil {
                Logger.shared.error("assetwriter failed: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
            }
            
        default:
            break
        }
    }
    
    func startRecording() {
        if recordingState == .idle {
            recordingState = .assetWriterStart
        }
    }
    
    func endRecording() {
        if recordingState == .assetWriterCapturing {
            recordingState = .assetWriterEnding
        }
    }
    
}

//            var paneCount = gridKeys.count
//
//            var rows = 1
//            var columns = 1
//
//            if paneCount > 2 {
//                rows = 2
//                columns = 2
//            }
//
//            if paneCount > 4 {
//                paneCount = 4
//                Logger.shared.error("More than 4 remotePanes. Maxxed to 4")
//            }
//
//            let width: CGFloat = 1920
//            let height: CGFloat = 1080
//
//            let cellWidth = (width * 0.9) / CGFloat(columns)
//            let cellHeight = (width * 9.0 / 16.0)
//
//            for (index, pane) in gridKeys.enumerated() {
//                let row = index / columns
//                let column = index % columns
//                let buffer = StreamBuffer.shared.getBuffer(uuid: gridKeys[index])
//                guard let buffer else { continue }
//                let image = CIImage(cvImageBuffer: buffer )
//
//                let scaleFactor = min(cellWidth / image.extent.width, cellHeight / image.extent.height)
//                let scaledWidth = image.extent.width * scaleFactor
//                let scaledHeight = image.extent.height * scaleFactor
//                let translateX = CGFloat(column) * cellWidth + (cellWidth - scaledWidth) / 2
//                let translateY = (CGFloat(rows - row - 1)) * cellHeight + (cellHeight - scaledHeight) / 2
//                var transform = CGAffineTransform.identity
//
//                transform = transform.translatedBy(x: translateX, y: translateY)
//                transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)
//
//                //Transform is wrong
//
//                let transformedImage = image.transformed(by: transform)
//
//                if let newCombinedImage = CIFilter(name: "CISourceOverCompositing", parameters: [kCIInputImageKey: transformedImage, kCIInputBackgroundImageKey: combinedImage])?.outputImage {
//                    combinedImage = newCombinedImage
//                }
