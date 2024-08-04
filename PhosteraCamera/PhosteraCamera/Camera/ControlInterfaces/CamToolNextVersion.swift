///*
// See LICENSE folder for this sample’s licensing information.
// 
// Abstract:
// The mixer to combine video frames and grayscale depth frames.
// */
//
//import CoreMedia
//import CoreVideo
//import UIKit
//import AVFoundation
//import Combine
//import VideoToolbox
//import CoreGraphics
//import Accelerate
//import CoreServices
//import PhosteraShared
//
//enum RecordingState: Int {
//    case idle = 0
//    case assetWriterStart
//    case assetWriterStartWait
//    case assetWriterCapturing
//    case assetWriterEnding
//    case movieFileCapturing
//}
//
//enum CameraSetupError: Error {
//    case isSimulator
//    case noCameras
//    case badSetup
//}
//
//class CamToolNextVersion: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate, AVCaptureDataOutputSynchronizerDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
//    static var shared = CamTool()
//    
//    private var subscriptions:[Cancellable] = [Cancellable]()
//    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
//    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
//    private var videoPreviewView: PreviewMetalView?
//
//    private var videoEncoder:H264Encoder = H264Encoder()
//    private var session = AVCaptureSession()
//    private let sessionQueue = DispatchQueue(label: "SessionQueue", attributes: [], autoreleaseFrequency: .workItem)
//    private let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
//    private var videoInput: AVCaptureDeviceInput!
//    private var audioInput: AVCaptureDeviceInput!
//    private var videoDataOutput:AVCaptureVideoDataOutput?
//    private let depthDataOutput = AVCaptureDepthDataOutput()
//    private var audioOutput: AVCaptureAudioDataOutput!
//    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
//    private let photoOutput = AVCapturePhotoOutput()
//    private let photoDelegate = PhotoOutput()
//    private let filterRenderers: [FilterRenderer] = [RosyMetalRenderer(), RosyCIRenderer()]
//    private let photoRenderers: [FilterRenderer] = [RosyMetalRenderer(), RosyCIRenderer()]
//    private let videoDepthMixer = VideoMixer()
//    private let photoDepthMixer = VideoMixer()
//    private var filterIndex: Int = 0
//    private var videoFilter: FilterRenderer?
//    private var photoFilter: FilterRenderer?
//    private let videoDepthConverter = DepthToGrayscaleConverter()
//    private let photoDepthConverter = DepthToGrayscaleConverter()
//    private var currentDepthPixelBuffer: CVPixelBuffer?
//    private let processingQueue = DispatchQueue(label: "photo processing queue", attributes: [], autoreleaseFrequency: .workItem)
//    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
//    private var cameraDevice: AVCaptureDevice!
//    private var audioDevice: AVCaptureDevice!
//    private var cameraDeviceExposure:DeviceExposure = DeviceExposure()
//    private var cameraDeviceFocus:DeviceFocus = DeviceFocus()
//    private var cameraDeviceWhiteBalance:DeviceWhitebalance = DeviceWhitebalance()
//    private var currentMode:DirectorProjectCameraMode?
//    private var currentProject:DirectorProjectModel?
//    private var aspectRatio:CGSize = CGSizeMake(16,9)
//    private var statusBarOrientation: UIInterfaceOrientation = .landscapeLeft
//    private var movieFileOutput: AVCaptureMovieFileOutput?
//    private var assetWriter: AVAssetWriter?
//    private var assetWriterVideoInput: AVAssetWriterInput?
//    private var assetWriterAudioInput: AVAssetWriterInput?
//    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
//    private var videoVisualizer:Visualizer = Visualizer(frame: .zero)
//    private var startTime:CMTime = CMTime.zero
//    private var recordingState:RecordingState = .idle
//    private var useVideoEncoder = false
//    private var generateHistogram = false
//    private var stillImageOutput: AVCapturePhotoOutput!
//    private var outputFileName:URL?
//    private var histogramCalculator:HistogramCalculator = HistogramCalculator()
//    private var lastOrientation:UIDeviceOrientation = .portrait
//    private var histogramFrameSkipCount = 5
//    private var histogramFrameSkipCurrentCount = 0
//    private let screenShotFactor:Int = 30 * 15
//    private lazy var screenShotDelay:Int = screenShotFactor - 10
//    
//    @objc dynamic var isCurrentlyRecording:Bool = false
//    @objc dynamic var outputSize:CGSize = .zero
//    @objc dynamic var outputFrameRate:CMTime = .zero
//    @objc dynamic var outputEncoderName:String = ""
//    @objc dynamic var modeName:String = ""
//    
//    var audioFifo = SampleFIFO(category: "audio")
//    var videoFifo = SampleFIFO(category: "video")
//    var photoFlashRequest:AVCaptureDevice.FlashMode = .off
//    
//    private var renderingEnabled = true
//    private var depthVisualizationEnabled = false
//    private var audioStreamRequested:Bool = false
//    private var videoFilterOn: Bool = false
//    private var depthVisualizationOn: Bool = false
//    private var depthSmoothingOn: Bool = false
//    
//    func getCameraDevice() -> AVCaptureDevice? {
//        return cameraDevice
//    }
//    
//    
//    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
//        return videoPreviewLayer
//    }
//    
//    func getPreviewView() -> PreviewMetalView? {
//        return videoPreviewView
//    }
//    
//    func getPhotoOutput() -> AVCapturePhotoOutput {
//        return photoOutput
//    }
//    
//    func getPhotoDepthMixer() -> VideoMixer {
//        return photoDepthMixer
//    }
//    
//    func getVideoDepthMixer() -> VideoMixer {
//        return videoDepthMixer
//    }
//    
//    private func getVideoDepthConverter() -> DepthToGrayscaleConverter? {
//        return videoDepthConverter
//    }
//    
//    func getPhotoDepthConverter() -> DepthToGrayscaleConverter? {
//        return photoDepthConverter
//    }
//    
//    func getSessionQueue() -> DispatchQueue {
//        return sessionQueue
//    }
//    
//    func getProcessingQueue() -> DispatchQueue {
//        return processingQueue
//    }
//    
//    func getVideoFilter() -> FilterRenderer? {
//        return videoFilter
//    }
//    
//    func getPhotoFilter() -> FilterRenderer? {
//        return photoFilter
//    }
//    
//    func getVisualizer() -> Visualizer {
//        return videoVisualizer
//    }
//    
//    func getCameraDeviceFocus() -> DeviceFocus {
//        return cameraDeviceFocus
//    }
//    
//    func getCameraDeviceExposure() -> DeviceExposure {
//        return cameraDeviceExposure
//    }
//    
//    func getCameraDeviceWhitebalance() -> DeviceWhitebalance {
//        return cameraDeviceWhiteBalance
//    }
//    
//    func getCurrentProject() -> DirectorProjectModel? {
//        return currentProject
//    }
//    
//    func getCameraType() -> DirectorProjectCameraType {
//        guard let currentMode else { return .dual }
//        return currentMode.cameraType
//    }
//    
//    func getCameraTech() -> DirectorProjectCameraTechType {
//        guard let currentMode else { return .cifilter }
//        return currentMode.techType
//    }
//    
//    func getAspectRatio() -> CGSize {
//        return aspectRatio
//    }
//    
//    private func getRotationCoordinator() -> AVCaptureDevice.RotationCoordinator? {
//        return rotationCoordinator
//    }
//    
//    func externalDisplay(allowSecondary:Bool, preview:PreviewMetalView) {
//        Logger.shared.info("Checking for external display.")
//        guard let mainDisplayScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive && $0 is UIWindowScene }) as? UIWindowScene,
//              let mainRootViewController = mainDisplayScene.windows.first?.rootViewController else {
//            Logger.shared.error("Main display's root view controller not found")
//            return
//        }
//        
//        if allowSecondary {
//            if let v = SettingsService.shared.externalDisplayView {
//                if preview.superview != v {
//                    preview.removeFromSuperview()
//                    v.addSubview(preview)
//                    preview.frame = CGRectMake(0, 0, v.frame.size.width, v.frame.size.height)
//                }
//                Logger.shared.info("Switch to secondary display for preview.")
//                return
//            }
//        }
//        
//        if preview.superview != mainRootViewController.view {
//            preview.removeFromSuperview()
//            mainRootViewController.view.addSubview(preview)
//            preview.frame = CGRectMake(0, 0, mainRootViewController.view.frame.size.width, mainRootViewController.view.frame.size.height)
//            Logger.shared.info("Switch to primary display for preview.")
//        } else {
//            Logger.shared.info("Continue using primary display for preview.")
//        }
//    }
//    
//    func makePreviewView(frame:CGRect) -> PreviewMetalView? {
//        if videoPreviewView == nil { videoPreviewView = PreviewMetalView(frame: frame, device: MTLCreateSystemDefaultDevice()) }
//        return videoPreviewView
//    }
//    
//    
//    func update(project:DirectorProjectModel) {
//        SettingsService.shared.settings.currentProjectId = project.uuid
//        SettingsService.shared.save()
//        currentProject = project
//    }
//    
//    
//    func requestPermission() {
//        //sessionQueue.suspend()
//        AVCaptureDevice.requestAccess(for: .video, completionHandler: { _ in
//            //self.sessionQueue.resume()
//            DispatchQueue.main.async { NotificationCenter.default.post(name: .cameraAccessChanged, object: nil) }
//        })
//    }
//    
//    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//        if let outputFileName = self.outputFileName {
//            if !LibraryController.makeThumbnailFor(url: outputFileName) {
//                Logger.shared.error("Unable to create thumbnail for: \(outputFileName.path)")
//            }
//        }
//        
//        DispatchQueue.main.async {
//            self.recordingState = .idle
//            self.isCurrentlyRecording = false
//        }
//    }
//    
//    private func updateStatusBarOrientation(orientation:UIInterfaceOrientation) {
//        statusBarOrientation = orientation
//    }
//    
//    func isSessionRunning() -> Bool {  return session.isRunning }
//    func hasPermission() -> Bool {  return AVCaptureDevice.authorizationStatus(for: .video) == .authorized  }
//    func hasPermissionDenied() -> Bool {  return AVCaptureDevice.authorizationStatus(for: .video) == .denied }
//    private func isRecording() -> Bool {
//        var answer:Bool = false
//        
//        if let assetWriter {
//            answer = assetWriter.status == .writing
//        } else if let movieFileOutput {
//            answer = movieFileOutput.isRecording == true
//        }
//        Logger.shared.info("isRecording:\(answer)")
//        return answer
//    }
//    
//    private func setupMode(mode:DirectorProjectCameraMode) {
//        currentMode = mode
//        aspectRatio = mode.aspectRatio
//        modeName = mode.title
//        
//        SettingsService.shared.settings.currentModeId = mode.uuid
//        SettingsService.shared.save()
//    }
//    
//    func useMode(uuid:String, completion: @escaping (Result<Bool, Error>) -> Void) {
//        var mode:DirectorProjectCameraMode?
//        
//        mode = ModeHandler.shared.directorModeWithUUID(modeUUID: uuid)
//        
//        if let mode {
//            let projId = SettingsService.shared.settings.currentProjectId
//            if projId != mode.projectUUID {
//                SettingsService.shared.settings.currentProjectId = mode.projectUUID
//                SettingsService.shared.save()
//                currentProject = DirectorProjectService.shared.loadProject(uuid: mode.projectUUID)
//            }
//        } else {
//            currentProject = nil
//        }
//        
//        if mode == nil {
//            mode = ModeHandler.shared.mainBundleModeWithUUID(uuid: uuid)
//        }
//        
//        if mode == nil {
//            Logger.shared.error("Unable to find a builtin or director mode for uuid: \(uuid)")
//            Logger.shared.error("Switching to default mode.")
//            mode = ModeHandler.shared.defaultCameraMode()
//            if mode == nil {
//                Logger.shared.error("Unable to switch to a default mode. This is fatal.\(uuid)")
//                fatalError()
//            }
//        }
//        
//        guard let mode else { return } //We know it's good, but the compiler doesn't
//        
//        let printMode = true
//        if printMode {
//            let e = JSONEncoder()
//            if let d = try? e.encode(mode) {
//                if let a = String(data: d, encoding: .utf8) {
//                    print ("\(a)")
//                }
//            }
//        }
//        
//        setupMode(mode: mode)
//
//        Logger.shared.info("mode:aspectRatio=\(aspectRatio) - starting session: \(mode.title)")
//        
//        sessionQueue.async {
//            let result = Result { try self.startSession() }
//            DispatchQueue.main.sync {
//                completion(result)
//            }
//        }
//    }
//    
//    func stopSession() {
//        sessionQueue.async { [weak self] in
//            guard let self else { return }
//            rendering(enabled:false)
//            session.stopRunning()
//            DispatchQueue.main.sync { [weak self] in
//                guard let self else { return }
//                guard let videoPreviewView else { return }
//                videoPreviewView.pixelBuffer = nil
//            }
//        }
//        DispatchQueue.main.async {
//            AudioController.shared.stop()
//        }
//    }
//    
//    private func startSession() throws -> Bool {
//        rendering(enabled:false)
//        
//        dataOutputQueue.sync {
//            if let filter = videoFilter { filter.reset() }
//            videoDepthMixer.reset()
//            currentDepthPixelBuffer = nil
//            videoDepthConverter.reset()
//            if let p = CamTool.shared.getPreviewView() { p.pixelBuffer = nil }
//        }
//        
//        processingQueue.async {
//            if let filter = self.photoFilter { filter.reset() }
//            self.photoDepthMixer.reset()
//            self.photoDepthConverter.reset()
//        }
//        
//        videoPreviewLayer = nil
//        
//        session = AVCaptureSession()
//        session.automaticallyConfiguresApplicationAudioSession = false
//        session.sessionPreset = .inputPriority
//        
//        let discovery:AVCaptureDevice.DiscoverySession?
//        
//        guard let currentMode else {
//            throw CameraSetupError.noCameras
//        }
//        
//        switch currentMode.cameraType {
//        case .external:
//            Logger.shared.info("Using camera: external")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
//                                                         mediaType: .video,
//                                                         position: .unspecified)
//        case .wide:
//            Logger.shared.info("Using camera: wide")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
//                                                         mediaType: .video,
//                                                         position: currentMode.frontCamera ? .front : .back)
//        case .telephoto:
//            Logger.shared.info("Using camera: telephoto")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTelephotoCamera],
//                                                         mediaType: .video,
//                                                         position: currentMode.frontCamera ? .front : .back)
//        case .ultrawide:
//            Logger.shared.info("Using camera: ultrawide")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera],
//                                                         mediaType: .video,
//                                                         position: currentMode.frontCamera ? .front : .back)
//        case .dual:
//            Logger.shared.info("Using camera: dual")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
//                                                         mediaType: .video,
//                                                         position: currentMode.frontCamera ? .front : .back)
//        case .dualWide:
//            Logger.shared.info("Using camera: dualwide")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
//                                                         mediaType: .video,
//                                                         position: currentMode.frontCamera ? .front : .back)
//        case .triple:
//            Logger.shared.info("Using camera: triple")
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera],
//                                                         mediaType: .video,
//                                                         position: currentMode.frontCamera ? .front : .back)
//        case .trueDepth:
//            throw CameraSetupError.noCameras
//        case .lidarDepth:
//            throw CameraSetupError.noCameras
//        }
//        
//        guard let discovery else {
//            throw CameraSetupError.noCameras
//        }
//        
//        session.beginConfiguration()
//    
//        var cameraFound:Bool = false
//        for d in discovery.devices {
//            for f in d.formats {
//                switch currentMode.settings.resolution {
//                case .v1280x720:
//                    if (f.formatDescription.dimensions.width != 1280) || (f.formatDescription.dimensions.height != 720) {
//                        continue
//                    }
//                case .v1920x1080:
//                    if (f.formatDescription.dimensions.width != 1920) || (f.formatDescription.dimensions.height != 1080) {
//                        continue
//                    }
//                case .v3840x2160:
//                    if (f.formatDescription.dimensions.width != 3840) || (f.formatDescription.dimensions.height != 2160) {
//                        continue
//                    }
//                }
//                
//                //                switch currentModeMetadata.frameRate {
//                //                case .fr24:
//                //                    if f.form
//                //                case .fr25:
//                //                    <#code#>
//                //                case .fr30:
//                //                    <#code#>
//                //                }
//                
//                switch currentMode.settings.colorspace {
//                case .rec709:
//                    if !f.supportedColorSpaces.contains(.sRGB) {
//                        continue
//                    }
//                case .appleLog:
//                    if !(f.isVideoHDRSupported && f.supportedColorSpaces.contains(.appleLog)) {
//                        continue
//                    }
//                case .p3d65:
//                    if !(f.isVideoHDRSupported && f.supportedColorSpaces.contains(.P3_D65)) {
//                        continue
//                    }
//                }
//                do {
//                    Logger.shared.info("Using dimensions: \(f.formatDescription.dimensions.width)x\(f.formatDescription.dimensions.height)")
//                    
//                    switch currentMode.settings.colorspace {
//                    case .rec709:
//                        if !f.supportedColorSpaces.contains(.sRGB) { continue }
//                        Logger.shared.info("Using colorspace: sRGB")
//                        try d.lockForConfiguration()
//                        d.activeFormat = f
//                        d.activeColorSpace = .sRGB
//                        
//                        d.unlockForConfiguration()
//                    case .appleLog:
//                        if !f.supportedColorSpaces.contains(.appleLog) { continue }
//                        Logger.shared.info("Using colorspace: appleLog")
//                        try d.lockForConfiguration()
//                        d.activeFormat = f
//                        d.activeColorSpace = .appleLog
//                        if f.isVideoHDRSupported {
//                            d.automaticallyAdjustsVideoHDREnabled = false
//                            d.isVideoHDREnabled = true
//                        }
//                        d.unlockForConfiguration()
//                    case .p3d65:
//                        if !f.supportedColorSpaces.contains(.P3_D65) { continue }
//                        Logger.shared.info("Using colorspace: P3 D65")
//                        try d.lockForConfiguration()
//                        d.activeFormat = f
//                        d.activeColorSpace = .P3_D65
//                        if f.isVideoHDRSupported {
//                            d.automaticallyAdjustsVideoHDREnabled = false
//                            d.isVideoHDREnabled = true
//                        }
//                        d.unlockForConfiguration()
//                    }
//                    cameraDevice = d
//                    cameraFound = true
//                    Logger.shared.info("Found camera with colorspace and dimensions")
//                    Logger.shared.info("Device: \(cameraDevice.localizedName)")
//                    Logger.shared.info("Active Format: \(cameraDevice.activeFormat.formatDescription)")
//                    Logger.shared.info("Active Color Space: \(cameraDevice.activeColorSpace)")
//                    
//                } catch {
//                    Logger.shared.error("invalid colorspace set")
//                }
//                if cameraFound { break }
//            }
//            if cameraFound { break }
//        }
//        
//        if !cameraFound {
//            throw CameraSetupError.noCameras
//        }
//        
//        
//        guard let cameraDevice else {
//            Logger.shared.error("Could not find any video device")
//            throw CameraSetupError.noCameras
//        }
//     
//        do {
//            videoInput = try AVCaptureDeviceInput(device: cameraDevice)
//        } catch {
//            Logger.shared.error("Could not create video device input: \(error)")
//            throw CameraSetupError.noCameras
//        }
//
//        var addAudio:Bool = true
//        if getCameraTech() == .photo { addAudio = false }
//        if !AudioController.hasPermission() { addAudio = false }
//
//        guard session.canAddInput(videoInput) else {
//            Logger.shared.error("Could not add video device input to the session")
//            session.commitConfiguration()
//            throw CameraSetupError.noCameras
//        }
//        
//        session.addInput(videoInput)
// 
//        if addAudio {
//            for option in AudioController.recordingOptions {
//                if option.name.contains("Back") {
//                    AudioController.shared.selectRecordingOption(option, orientation: .landscapeLeft) { layout in
//                        Logger.shared.info("LAYOUT:\(layout)")
//                    }
//                }
//            }
//            
//            if audioDevice == nil {
//                audioDevice = AVCaptureDevice.default(for: .audio)
//            }
//            
//            
//            //audioDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.microphone, for: .audio, position: .back)
//            
//            if (audioDevice == nil) { addAudio = false }
//            let y = AudioController.shared.isDeviceSupported
//            let z = AudioController.shared.isStereoSupported
//            Logger.shared.info("device: \(y) - stereo: \(z)")
//        }
//       
//        if addAudio {
//            do {
//                audioInput = try AVCaptureDeviceInput(device: audioDevice)
//            } catch {
//                Logger.shared.error("Could not create audio device input: \(error)")
//                throw CameraSetupError.noCameras
//            }
//            
//            // Add an audio input.
//            guard session.canAddInput(audioInput) else {
//                Logger.shared.error("Could not add audio device input to the session")
//                session.commitConfiguration()
//                throw CameraSetupError.noCameras
//            }
//            session.addInput(audioInput)
//            Logger.shared.error("Audio input added")
//        } else {
//            Logger.shared.error("Audio not enabled")
//        }
//        
//        videoDataPreviewOutput = AVCaptureVideoDataOutput()
//        guard let videoDataPreviewOutput else {
//            Logger.shared.error("Unable to create videoDataPreviewOutput")
//            throw CameraSetupError.noCameras
//        }
//        
//        videoDataRecordingOutput = AVCaptureVideoDataOutput()
//        guard let videoDataRecordingOutput else {
//            Logger.shared.error("Unable to create videoDataRecordingOutput")
//            throw CameraSetupError.noCameras
//        }
//        
//       
//        
////        videoDataOutput.videoSettings = [
////            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_422YpCbCr10),
////            kCVPixelBufferWidthKey as String: NSNumber(value: 1920),
////            kCVPixelBufferHeightKey as String: NSNumber(value: 1080)
////        ]
//        
////        let settings = videoDataOutput.recommendedVideoSettings(forVideoCodecType: .proRes422HQ, assetWriterOutputFileType: .mov)
////        videoDataOutput.videoSettings = settings
//        
////        videoDataOutput.videoSettings = settings
////        for t in videoDataOutput.availableVideoCodecTypes {
////            Logger.shared.error("Available codec:\(t)")
////        }
////
////        for t in videoDataOutput.availableVideoPixelFormatTypes{
////            Logger.shared.error("pixel formats:\(t)")
////        }
//        
//        videoDataPreviewOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
//        videoDataPreviewOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
//        
////        videoDataRecordingOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
////        videoDataRecordingOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
//        
//         let settings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .hevc, assetWriterOutputFileType: .mov)
//        videoDataRecordingOutput.videoSettings = settings
//        videoDataRecordingOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
//        
//        if session.canAddOutput(videoDataPreviewOutput) {
//            session.addOutputWithNoConnections(videoDataPreviewOutput)
//        } else {
//            Logger.shared.error("Could not add videoDataPreviewOutput to the session")
//            session.commitConfiguration()
//            throw CameraSetupError.noCameras
//        }
//       
//        if getCameraTech() == .photo {
//            if session.canAddOutput(photoOutput) {
//                session.addOutput(photoOutput)
//                
//                photoOutput.maxPhotoQualityPrioritization = .quality
//            } else {
//                Logger.shared.error("Could not add photo output to the session")
//                
//                session.commitConfiguration()
//                throw CameraSetupError.noCameras
//            }
//        } else {
//            if session.canAddOutput(videoDataRecordingOutput) {
//                session.addOutputWithNoConnections(videoDataRecordingOutput)
//            } else {
//                Logger.shared.error("Could not add videoDataRecordingOutput to the session")
//                session.commitConfiguration()
//                throw CameraSetupError.noCameras
//            }
//        }
//        
//       
//        
////        videoDataOutput.videoSettings = [
////            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_422YpCbCr10),
////            kCVPixelBufferWidthKey as String: NSNumber(value: 1920),
////            kCVPixelBufferHeightKey as String: NSNumber(value: 1080)
////        ]
//        
////        let settings = videoDataOutput.recommendedVideoSettings(forVideoCodecType: .proRes422HQ, assetWriterOutputFileType: .mov)
////        videoDataOutput.videoSettings = settings
//        
////        videoDataOutput.videoSettings = settings
////        for t in videoDataOutput.availableVideoCodecTypes {
////            Logger.shared.error("Available codec:\(t)")
////        }
////        
////        for t in videoDataOutput.availableVideoPixelFormatTypes{
////            Logger.shared.error("pixel formats:\(t)")
////        }
//        
//        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
//        videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
//        
//        if session.canAddOutput(videoDataOutput) {
//            session.addOutput(videoDataOutput)
//        } else {
//            Logger.shared.error("Could not add video data output to the session")
//            session.commitConfiguration()
//            throw CameraSetupError.noCameras
//        }
//        
//        if getCameraTech() == .photo {
//            if session.canAddOutput(photoOutput) {
//                session.addOutput(photoOutput)
//                
//                photoOutput.maxPhotoQualityPrioritization = .quality
//                
//                if depthVisualizationEnabled {
//                    if photoOutput.isDepthDataDeliverySupported {
//                        photoOutput.isDepthDataDeliveryEnabled = true
//                    } else {
//                        depthVisualizationEnabled = false
//                    }
//                }
//                
//            } else {
//                Logger.shared.error("Could not add photo output to the session")
//                
//                session.commitConfiguration()
//                throw CameraSetupError.noCameras
//            }
//        }
//        
//        if addAudio {
//            audioOutput = AVCaptureAudioDataOutput()
//            //Gives us videodataoutput callback
//            if session.canAddOutput(audioOutput) {
//                session.addOutput(audioOutput)
//                audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
//                Logger.shared.error("Audio output added")
//            }
//        }
//        
//        //        // Add a depth data output
//        //        if session.canAddOutput(depthDataOutput) {
//        //            session.addOutput(depthDataOutput)
//        //            depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
//        //            depthDataOutput.isFilteringEnabled = false
//        //            if let connection = depthDataOutput.connection(with: .depthData) {
//        //                connection.isEnabled = depthVisualizationEnabled
//        //            } else {
//        //                Logger.shared.error("No AVCaptureConnection for depth data")
//        //            }
//        //        } else {
//        //            Logger.shared.error("Could not add depth data output to the session")
//        //
//        //            session.commitConfiguration()
//        //            throw CameraSetupError.noCameras
//        //        }
//        //
//        //        if depthVisualizationEnabled {
//        //            // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
//        //            // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
//        //            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
//        //            if let unwrappedOutputSynchronizer = outputSynchronizer {
//        //                unwrappedOutputSynchronizer.setDelegate(self, queue: dataOutputQueue)
//        //            }
//        //        } else {
//        //            outputSynchronizer = nil
//        //        }
//        
//        //capFrameRate(videoDevice: videoDevice)
//        
//        //videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
//        //rotationCoordinator = AVCaptureDevice.RotationCoordinator.init(device: cameraDevice, previewLayer: videoPreviewLayer)
//        
//        session.commitConfiguration()
//        
//        videoFilterOn = false
//        depthVisualizationOn = false
//        depthSmoothingOn = false
//        
//        cameraDeviceExposure = DeviceExposure()
//        cameraDeviceFocus = DeviceFocus()
//        cameraDeviceWhiteBalance = DeviceWhitebalance()
//        
//        do {
//            try videoEncoder.configureCompressSession()
//            videoEncoder.naluHandling = { data in
//                Task(priority: .userInitiated, operation: { [weak self] in
//                    guard let self else { return }
//                    await videoFifo.enqueue(data)
//                })
//            }
//        } catch {
//            Logger.shared.error("unable to configure video encoder")
//        }
//
//        PubCentral.shared.setupDevicePublishers()
//        
//        cameraDeviceExposure.useDevice(currentDevice: cameraDevice)
//        cameraDeviceWhiteBalance.useDevice(currentDevice:cameraDevice)
//        cameraDeviceFocus.useDevice(currentDevice: cameraDevice)
//        
//        PubCentral.shared.setupDevicePublishers()
//        
//        if let p = CamTool.shared.getPreviewView() {
//            p.mirroring = (cameraDevice.position == .front)
//        }
//        
//        session.startRunning()
//        
//        
//        for f in cameraDevice.formats {
//            switch currentMode.settings.resolution {
//            case .v1280x720:
//                if (f.formatDescription.dimensions.width != 1280) || (f.formatDescription.dimensions.height != 720) {
//                    continue
//                }
//            case .v1920x1080:
//                if (f.formatDescription.dimensions.width != 1920) || (f.formatDescription.dimensions.height != 1080) {
//                    continue
//                }
//            case .v3840x2160:
//                if (f.formatDescription.dimensions.width != 3840) || (f.formatDescription.dimensions.height != 2160) {
//                    continue
//                }
//            }
//            
//            //                switch currentModeMetadata.frameRate {
//            //                case .fr24:
//            //                    if f.form
//            //                case .fr25:
//            //                    <#code#>
//            //                case .fr30:
//            //                    <#code#>
//            //                }
//            
//            switch currentMode.settings.colorspace {
//            case .rec709:
//                if !f.supportedColorSpaces.contains(.sRGB) {
//                    continue
//                }
//            case .appleLog:
//                if !(f.isVideoHDRSupported && f.supportedColorSpaces.contains(.appleLog)) {
//                    continue
//                }
//            case .p3d65:
//                if !(f.isVideoHDRSupported && f.supportedColorSpaces.contains(.P3_D65)) {
//                    continue
//                }
//            }
//            do {
//                Logger.shared.info("Using dimensions: \(f.formatDescription.dimensions.width)x\(f.formatDescription.dimensions.height)")
//                
//                switch currentMode.settings.colorspace {
//                case .rec709:
//                    if !f.supportedColorSpaces.contains(.sRGB) { continue }
//                    Logger.shared.info("Using colorspace: sRGB")
//                    try cameraDevice.lockForConfiguration()
//                    cameraDevice.activeFormat = f
//                    cameraDevice.activeColorSpace = .sRGB
//                    cameraDevice.unlockForConfiguration()
//                case .appleLog:
//                    if !f.supportedColorSpaces.contains(.appleLog) { continue }
//                    Logger.shared.info("Using colorspace: appleLog")
//                    try cameraDevice.lockForConfiguration()
//                    cameraDevice.activeFormat = f
//                    cameraDevice.activeColorSpace = .appleLog
//                    if f.isVideoHDRSupported {
//                        cameraDevice.automaticallyAdjustsVideoHDREnabled = false
//                        cameraDevice.isVideoHDREnabled = true
//                    }
//                    cameraDevice.unlockForConfiguration()
//                case .p3d65:
//                    if !f.supportedColorSpaces.contains(.P3_D65) { continue }
//                    Logger.shared.info("Using colorspace: P3 D65")
//                    try cameraDevice.lockForConfiguration()
//                    if f.isVideoHDRSupported {
//                        cameraDevice.automaticallyAdjustsVideoHDREnabled = false
//                        cameraDevice.isVideoHDREnabled = true
//                    }
//                    cameraDevice.activeFormat = f
//                    
//                    cameraDevice.activeColorSpace = .P3_D65
//                  
//                    cameraDevice.unlockForConfiguration()
//                }
//                Logger.shared.info("Found camera with colorspace and dimensions")
//                Logger.shared.info("Device: \(cameraDevice.localizedName)")
//                Logger.shared.info("Active Format: \(cameraDevice.activeFormat.formatDescription)")
//                Logger.shared.info("Active Color Space: \(cameraDevice.activeColorSpace)")
//                break
//            } catch {
//                Logger.shared.error("invalid colorspace set")
//            }
//        }
//
//        rendering(enabled:true)
//        
//        self.updateSessionInfoForDisplay()
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self else { return }
//            histogramCalculator.updateLayer(visualLayer: videoVisualizer.layer)
//            printDeviceInformation(for: cameraDevice)
//            setupEventSubscriptions()
//        }
//        
//        return true
//    }
//    
//    private func printDeviceInformation(for device: AVCaptureDevice) {
//        Logger.shared.info("Current Camera Specs")
//        Logger.shared.info("Device: \(device.localizedName)")
//        Logger.shared.info("Active Format: \(device.activeFormat.formatDescription)")
//        
//        let currentColorSpace = device.activeColorSpace
//        Logger.shared.info("Current Color Space: \(currentColorSpace)")
//        
//        let allColorSpaces: [AVCaptureColorSpace] = device.activeFormat.supportedColorSpaces
//        for colorSpace in allColorSpaces {
//            Logger.shared.info("Supported Color Space: \(colorSpace)")
//        }
//    }
//    
//    private func rendering(enabled:Bool) {
//        dataOutputQueue.sync { [weak self] in
//            guard let self else { return }
//            renderingEnabled = enabled
//            Logger.shared.info("Rendering: \(enabled)")
//        }
//    }
//    
//    private func frameRate(session: AVCaptureSession) -> CMTime? {
//        guard let input = session.inputs.first as? AVCaptureDeviceInput else {
//            return nil
//        }
//        
//        return input.device.activeVideoMinFrameDuration
//    }
//    
//    private func outputResolution(session: AVCaptureSession) -> CGSize? {
//        guard let output = session.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput else {
//            return nil
//        }
//        
//        guard let videoSettings = output.videoSettings else {
//            return nil
//        }
//        
//        guard let width = videoSettings["Width"] as? Int,
//              let height = videoSettings["Height"] as? Int else {
//            return nil
//        }
//        
//        return CGSize(width: width, height: height)
//    }
//    
//    private func updateSessionInfoForDisplay() {
//        self.outputSize = self.outputResolution(session: session) ?? .zero
//        self.outputFrameRate = self.frameRate(session: session) ?? .zero
//        self.outputEncoderName = "h264"
//    }
//
//    private func makeAndStoreScreenshot(image: UIImage) {
//        let resolution: CGSize = CGSize(width: 200.0, height: 112.5)
//        let renderer = UIGraphicsImageRenderer(size: resolution)
//        let scaledImage = renderer.image { (context) in
//            image.draw(in: CGRect(origin: .zero, size: resolution))
//        }
//        guard let imageData = scaledImage.jpegData(compressionQuality: 0.5) else { return }
//        
//        DispatchQueue.main.async { [weak self] in
//            guard let self else { return }
//            PubCentral.shared.screenShot = imageData
//            screenShotDelay = 0
//        }
//    }
//
//    func sendScreenshotNow() {
//        screenShotDelay = screenShotFactor + 100
//    }
//    
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let formatDesc:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
//            //Logger.shared.error("captureOutput formatDesc nil")
//            return
//        }
//        
//        let mediaType:CMMediaType = CMFormatDescriptionGetMediaType(formatDesc);
//        if (mediaType == kCMMediaType_Audio) && (output == audioOutput) {
//            if recordingState == .assetWriterCapturing {
//                if (assetWriterAudioInput != nil) && assetWriterAudioInput!.isReadyForMoreMediaData {
//                    assetWriterAudioInput?.append(sampleBuffer)
//                }
//            }
//            
//            var firstAudioChannel:Bool = true
//            guard let audioOutput else { return }
//            guard let connection = audioOutput.connection(with: .audio) else { return }
//            for channel in connection.audioChannels {
//                let normalizedLevel = (channel.averagePowerLevel + 160) / 160
//                let normalizedPeak = (channel.peakHoldLevel + 160) / 160
//                StatusService.shared.pushPowerLevel(level: CGFloat(normalizedLevel), peak: CGFloat(normalizedPeak), left: firstAudioChannel ? true : false)
//                firstAudioChannel.toggle()
//            }
//            
//            //            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
//            //
//            //
//            //
//            //
//            //                var summaryFormatDesc: CMAudioFormatDescription?
//            //                let formatDescriptions: [CMAudioFormatDescription] = [formatDescription]
//            //                let formatDescriptionsArray = formatDescriptions as CFArray
//            //                let err = CMAudioFormatDescriptionCreateSummary(allocator: nil, formatDescriptionArray: formatDescriptionsArray, flags: 0, formatDescriptionOut: &summaryFormatDesc)
//            //
//            //                if err == noErr, let summaryFormatDesc = summaryFormatDesc {
//            //                    Logger.shared.info("sum:\(summaryFormatDesc)")
//            //                } else {
//            //                    Logger.shared.error("Error creating summary: \(err)")
//            //                }
//            //                if let desc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
//            //
//            //                    Logger.shared.info("desc:\(desc.debugDescription)")
//            //                }
//            //            }
//            
//            audioStreamRequested = true
//            if audioStreamRequested {
//                //                if let samples = AudioSampleFIFO.extractAndCompressAudioSamples2(from: sampleBuffer) {
//                //
//                //                }
//                
//                
//                if let samples = SampleFIFO.extractAndCompressAudioSamples(from: sampleBuffer) {
//                    Task(priority: .userInitiated, operation: {
//                        await audioFifo.enqueue(samples)
//                    })
//                }
//            }
//            
//            //            if let desc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
//            //                let sampleRate = desc.pointee.mSampleRate
//            //                let formatID = desc.pointee.mFormatID
//            //                let mFormatFlags = desc.pointee.mFormatFlags
//            //                let mBytesPerPacket = desc.pointee.mBytesPerPacket
//            //                let mFramesPerPacket = desc.pointee.mFramesPerPacket
//            //                let mBytesPerFrame = desc.pointee.mBytesPerFrame
//            //                let mChannelsPerFrame = desc.pointee.mChannelsPerFrame
//            //                let mBitsPerChannel = desc.pointee.mBitsPerChannel
//            //
//            //
//            //                Logger.shared.info("asbd:\(desc.debugDescription) - \(sampleRate) - \(formatID) - \(mFormatFlags) - \(mBytesPerPacket) - \(mBytesPerFrame) - \(mChannelsPerFrame) - \(mBitsPerChannel)")
//            //            }
//            
//            return // Done with audio
//        } else {
//            let useVideoEncoder = true
//            if useVideoEncoder {
//                videoEncoder.captureOutput(output, didOutput: sampleBuffer, from: connection)
//            }
//            processVideo(sampleBuffer: sampleBuffer)
//            
//            histogramFrameSkipCurrentCount += 1
//            if histogramFrameSkipCurrentCount > histogramFrameSkipCount {
//                histogramCalculator.calculate(for: sampleBuffer)
//                histogramFrameSkipCurrentCount = 0
//            }
//            
//            if screenShotDelay > screenShotFactor {
//                screenShotDelay = -1
//                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//                
//                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
//                let context = CIContext()
//                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
//                let uiImage = UIImage(cgImage: cgImage)
//                Logger.shared.info("making screenshot")
//                Task {
//                    makeAndStoreScreenshot(image: uiImage)
//                }
//            } else if screenShotDelay > -1 {
//                screenShotDelay += 1
//            }
//        }
//        
//        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//        
//        switch recordingState {
//        case .assetWriterStart:
//            CameraTakeService.shared.startTake()
//            
//            if let currentTake = CameraTakeService.shared.getCurrentTake() {
//                self.outputFileName = URL(fileURLWithPath: currentTake.localTakeDirectory)
//                    .appending(component: currentTake.uuid, directoryHint: .notDirectory)
//                    .appendingPathExtension(for: .quickTimeMovie)
//            }
//            
//            if outputFileName == nil {
//                return //can't write
//            }
//            
//            let writer = try! AVAssetWriter(outputURL: outputFileName!, fileType: .mov)
//            
//            guard let videoDataOutput else {
//                Logger.shared.error("videoDataOutput notexist in assetWriterStart")
//                return
//            }
//            let videoSettings = videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
//            
//            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
//            
//            if (UIDevice.current.orientation == .landscapeLeft) ||
//                (UIDevice.current.orientation == .landscapeRight) ||
//                (UIDevice.current.orientation == .portrait) ||
//                (UIDevice.current.orientation == .portraitUpsideDown) {
//                lastOrientation = UIDevice.current.orientation
//            }
//            
//            guard let _ = videoDataOutput.connection(with: .video) else {
//                Logger.shared.error("no connection for rotation in assetwriter begin")
//                return
//            }
//            
//            videoInput.expectsMediaDataInRealTime = true
//            
//            var audioSettings:[String:Any]?
//            if let audioOutput {
//                audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .m4a)
//                
//                audioSettings?[AVNumberOfChannelsKey] = 2  // Force stereo
//            }
//            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
//            audioInput.expectsMediaDataInRealTime = true
//            
//            let pixelAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: nil)
//            
//            startTime = timestamp + CMTime(seconds: 5.0, preferredTimescale: timestamp.timescale)
//            recordingState = .assetWriterStartWait
//            
//            if writer.canAdd(videoInput) {
//                Logger.shared.info("Addding input with transform")
//                if lastOrientation == .landscapeRight {
//                    Logger.shared.info("Rotating 180")
//                    videoInput.transform = videoInput.transform.rotated(by: -.pi)
//                } else if lastOrientation == .portrait {
//                    Logger.shared.info("Rotating 180")
//                    videoInput.transform = videoInput.transform.rotated(by: .pi / 2.0)
//                } else if lastOrientation == .portraitUpsideDown {
//                    Logger.shared.info("Rotating 180")
//                    videoInput.transform = videoInput.transform.rotated(by: -.pi / 2.0)
//                }
//                
//                writer.add(videoInput)
//            }
//            
//            if writer.canAdd(audioInput) {
//                writer.add(audioInput)
//                Logger.shared.error("Assetwriter Audio input added")
//            }
//            assetWriter = writer
//            assetWriterVideoInput = videoInput
//            assetWriterAudioInput = audioInput
//            pixelBufferAdaptor = pixelAdapter
//            
//            DispatchQueue.global(qos: .utility).async { [weak self] in
//                guard let self else { return }
//                if let assetWriter {
//                    assetWriter.startWriting()
//                }
//            }
//            
//        case .assetWriterStartWait:
//            if let assetWriter {
//                if assetWriter.status == .writing {
//                    startTime = timestamp
//                    Logger.shared.info("Start Time:\(self.startTime.value) - \(self.startTime.timescale)")
//                    
//                    assetWriter.startSession(atSourceTime: startTime)
//                    recordingState = .assetWriterCapturing
//                    
//                    if let o = outputFileName { StatusService.shared.startFileMonitor(url: o) }
//                }
//            }
//        case .assetWriterCapturing:
//            if let assetWriterVideoInput {
//                if assetWriterVideoInput.isReadyForMoreMediaData == true {
//                    //  let t = timestamp - startTime
//                    
//                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
//                        pixelBufferAdaptor?.append(imageBuffer, withPresentationTime:timestamp)
//                    }
//                }
//            }
//            
//            break
//        case .assetWriterEnding:
//            
//            if assetWriter == nil {
//                Logger.shared.error("assetwriter nil at .assetWriterEnding: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
//                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
//                return
//            }
//            
//            if assetWriterVideoInput == nil {
//                Logger.shared.error("assetwriterinput nil at .assetWriterEnding: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
//                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
//                return
//            }
//            
//            
//            if assetWriter?.status == .writing {
//                assetWriterVideoInput?.markAsFinished()
//                assetWriterAudioInput?.markAsFinished()
//            }
//            
//            recordingState = .idle
//            assetWriter?.finishWriting { [weak self] in
//                guard let self else { return }
//                Logger.shared.error("assetWriter finishing")
//                recordingState = .idle
//                assetWriter = nil
//                assetWriterVideoInput = nil
//                assetWriterAudioInput = nil
//                isCurrentlyRecording = false
//                
//                if let outputFileName {
//                    if !LibraryController.makeThumbnailFor(url: outputFileName) {
//                        Logger.shared.error("Unable to create thumbnail for: \(outputFileName.path)")
//                    }
//                    
//                }
//                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
//                return
//            }
//            
//            if assetWriter?.error != nil {
//                Logger.shared.error("assetwriter failed: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
//                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
//            }
//            CameraTakeService.shared.endTake()
//        default:
//            break
//        }
//    }
//    
//    private func processVideo(sampleBuffer: CMSampleBuffer) {
//        if !renderingEnabled {
//            return
//        }
//        
//        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
//              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
//            return
//        }
//        
//        var finalVideoPixelBuffer = videoPixelBuffer
//        if let filter = videoFilter {
//            if !filter.isPrepared {
//                /*
//                 outputRetainedBufferCountHint is the number of pixel buffers the renderer retains. This value informs the renderer
//                 how to size its buffer pool and how many pixel buffers to preallocate. Allow 3 frames of latency to cover the dispatch_async call.
//                 */
//                filter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
//            }
//            
//            // Send the pixel buffer through the filter
//            guard let filteredBuffer = filter.render(pixelBuffer: finalVideoPixelBuffer) else {
//                Logger.shared.error("Unable to filter video buffer")
//                return
//            }
//            
//            finalVideoPixelBuffer = filteredBuffer
//        }
//        
//        if depthVisualizationEnabled {
//            if !videoDepthMixer.isPrepared {
//                videoDepthMixer.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
//            }
//            
//            if let depthBuffer = currentDepthPixelBuffer {
//                
//                // Mix the video buffer with the last depth data received.
//                guard let mixedBuffer = videoDepthMixer.mix(videoPixelBuffer: finalVideoPixelBuffer, depthPixelBuffer: depthBuffer) else {
//                    Logger.shared.error("Unable to combine video and depth")
//                    return
//                }
//                
//                finalVideoPixelBuffer = mixedBuffer
//            }
//        }
//        if let p = CamTool.shared.getPreviewView() {
//            p.pixelBuffer = finalVideoPixelBuffer
//        } else if getCameraTech() != .movie {
//            Logger.shared.info("No getPreviewView yet; dropping pixelBuffer")
//        }
//    }
//    
//    func depthDataOutput(_ depthDataOutput: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
//        processDepth(depthData: depthData)
//    }
//    
//    private func processDepth(depthData: AVDepthData) {
//        if !renderingEnabled {
//            return
//        }
//        
//        if !depthVisualizationEnabled {
//            return
//        }
//        
//        if !videoDepthConverter.isPrepared {
//            var depthFormatDescription: CMFormatDescription?
//            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
//                                                         imageBuffer: depthData.depthDataMap,
//                                                         formatDescriptionOut: &depthFormatDescription)
//            if let unwrappedDepthFormatDescription = depthFormatDescription {
//                videoDepthConverter.prepare(with: unwrappedDepthFormatDescription, outputRetainedBufferCountHint: 2)
//            }
//        }
//        
//        guard let depthPixelBuffer = videoDepthConverter.render(pixelBuffer: depthData.depthDataMap) else {
//            Logger.shared.error("Unable to process depth")
//            return
//        }
//        
//        currentDepthPixelBuffer = depthPixelBuffer
//    }
//    
//    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
//        
//        if let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData {
//            if !syncedDepthData.depthDataWasDropped {
//                let depthData = syncedDepthData.depthData
//                processDepth(depthData: depthData)
//            }
//        }
//        guard let videoDataOutput else {
//            Logger.shared.info("no videoDataOutput in dataOutputSynchronizer")
//            return
//        }
//        if let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData {
//            if !syncedVideoData.sampleBufferWasDropped {
//                let videoSampleBuffer = syncedVideoData.sampleBuffer
//                processVideo(sampleBuffer: videoSampleBuffer)
//            }
//        }
//    }
//    
//    func transitionToSize(size:CGSize, orientation:UIInterfaceOrientation) {
//        self.sessionQueue.async { [weak self] in
//            guard let self else { return }
//            if let photoOrientation = AVCaptureVideoOrientation(interfaceOrientation: orientation) {
//                if let c = self.photoOutput.connection(with: .video) {
//                    Logger.shared.info("getting a bail message here. need to switch to angle.")
//                    c.videoOrientation = photoOrientation
//                }
//            }
//            
//            if let c = CamTool.shared.getPreviewLayer()?.connection {
//                if let rotationCoordinator {
//                    c.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
//                }
//            }
//            
//            if let videoDataOutput, let c = videoDataOutput.connection(with: .video) {
//                if let rotation = PreviewMetalView.Rotation(with: orientation,
//                                                            videoOrientation: c.videoOrientation,
//                                                            cameraPosition: self.videoInput.device.position) {
//                    if let p = CamTool.shared.getPreviewView() {
//                        p.rotation = rotation
//                    }
//                }
//            }
//        }
//    }
//    
//   
//    func beginRecording() {
//        if self.isRecording() {
//            return
//        }
//        
//        switch(getCameraTech()) {
//        case .movie:
//            CameraTakeService.shared.startTake()
//            sessionQueue.async { [weak self] in
//                guard let self else {
//                    return
//                }
//                
//                if (self.movieFileOutput == nil) {
//                    
//                    self.movieFileOutput = AVCaptureMovieFileOutput()
//                    
//                    guard let movieFileOutput else {
//                        Logger.shared.error("moviefileoutput in beginrecording - unable to create")
//                        return
//                    }
//                    
//                    if let currentTake = CameraTakeService.shared.getCurrentTake() {
//                        self.outputFileName = URL(fileURLWithPath: currentTake.localTakeDirectory)
//                            .appending(component: currentTake.uuid, directoryHint: .notDirectory)
//                            .appendingPathExtension(for: .quickTimeMovie)
//                    }
//                    
//                    guard let _ = outputFileName else {
//                        Logger.shared.error("moviefileoutput unable to create a filename")
//                        return
//                    }
//                    
//                    
//                    if session.canAddOutput(movieFileOutput) {
//                        session.beginConfiguration()
//                        session.addOutput(movieFileOutput)
//                        session.commitConfiguration()
//                    } else {
//                        Logger.shared.error("Unable to add moviefileoutput")
//                        return
//                    }
//                    
//                    guard let movieFileOutputConnection = movieFileOutput.connection(with: .video) else {
//                        Logger.shared.error("moviefileoutput unable to connect to connection")
//                        return
//                    }
//                    
//                    if movieFileOutput.availableVideoCodecTypes.contains(.hevc) {
//                        movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection)
//                    }
//                }
//                
//                if let outputFileName {
//                    Logger.shared.info("Starting movie file \(outputFileName)")
//                    movieFileOutput?.startRecording(to: outputFileName, recordingDelegate: self)
//                    recordingState = .movieFileCapturing
//                    isCurrentlyRecording = true
//                    StatusService.shared.startFileMonitor(url: outputFileName)
//                } else {
//                    Logger.shared.info("Unable to start recording. no outputFileName.")
//                }
//            }
//        case .photo:
//            CameraTakeService.shared.startTake()
//            let depthEnabled = depthVisualizationOn
//            sessionQueue.async { [weak self] in
//                guard let self else { return }
//                let photoSettings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
//                if depthEnabled && self.photoOutput.isDepthDataDeliverySupported {
//                    photoSettings.isDepthDataDeliveryEnabled = true
//                    photoSettings.embedsDepthDataInPhoto = false
//                    
//                } else {
//                    photoSettings.isDepthDataDeliveryEnabled = depthEnabled
//                }
//                photoSettings.flashMode = photoFlashRequest
//                photoOutput.capturePhoto(with: photoSettings, delegate: photoDelegate)
//            }
//        case .cifilter:
//            recordingState = .assetWriterStart
//            isCurrentlyRecording = true
//        }
//    }
//    
//    func endRecording() {
//        if !self.isRecording() {
//            return
//        }
//        
//        StatusService.shared.stopFileMonitor()
//        
//        switch (getCameraTech()) {
//        case .movie:
//            sessionQueue.async { [weak self] in
//                guard let self else { return }
//                if let movieFileOutput {
//                    if !movieFileOutput.isRecording { Logger.shared.error("Attempt to endRecording while not recording (moviefile)"); return }
//                    movieFileOutput.stopRecording()
//                    CameraTakeService.shared.endTake()
//                }
//            }
//        case .photo:
//            CameraTakeService.shared.endTake()
//            break
//        case .cifilter:
//            if recordingState == .assetWriterCapturing {
//                recordingState = .assetWriterEnding
//                isCurrentlyRecording = false
//            }
//        }
//    }
//    
//    private func setupEventSubscriptions() {
//        subscriptions.removeAll()
//        self.subscriptions.append(PubCentral.shared.pubThermalStateChanged.receive(on: DispatchQueue.main).sink { value in
//            //            if let userInfoValue = value.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
//            //                let reasonIntegerValue = userInfoValue.integerValue,
//            //                let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
//            //                Logger.shared.error("Capture session was interrupted with reason \(reason)")
//            //
//            //                if reason == .videoDeviceInUseByAnotherClient {
//            //
//            //                } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
//            //
//            //                }
//            //            }
//        })
//        
//        self.subscriptions.append(PubCentral.shared.pubSessionRuntimeError.receive(on: DispatchQueue.main).sink { [weak self] value in
//            guard let self else { return }
//            
//            if isRecording() {
//                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
//            }
//            
//            guard let errorValue = value.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
//                return
//            }
//            
//            let error = AVError(_nsError: errorValue)
//            Logger.shared.error("Capture session runtime error: \(error)")
//            
//            if error.code == .mediaServicesWereReset {
//                sessionQueue.async {
//                    
//                }
//            } else {
//                
//            }
//        })
//        
//        self.subscriptions.append(PubCentral.shared.pubSessionWasInterrupted.receive(on: DispatchQueue.main).sink { [weak self] value in
//            guard let self else { return }
//            
//            if isRecording() {
//                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
//            }
//            
//            guard let errorValue = value.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
//                return
//            }
//            
//            let error = AVError(_nsError: errorValue)
//            Logger.shared.info("Capture session was interrupted: \(error)")
//            
//            if error.code == .mediaServicesWereReset {
//                sessionQueue.async {
//                    
//                }
//            } else {
//                
//            }
//            
//        })
//        
//        self.subscriptions.append(PubCentral.shared.pubSessionInterruptionEnded.receive(on: DispatchQueue.main).sink { value in
//            Logger.shared.error("Capture session interuption ended")
//        })
//        
//        self.subscriptions.append(PubCentral.shared.pubExternalDisplayChanged.receive(on: DispatchQueue.main).sink { [weak self] value in
//            guard let self else { return }
//            if let v = getPreviewView() {
//                externalDisplay(allowSecondary: true, preview: v)
//            }
//        })
//    }
//}
//
//extension AVCaptureVideoOrientation {
//    init?(interfaceOrientation: UIInterfaceOrientation) {
//        switch interfaceOrientation {
//        case .portrait: self = .portrait
//        case .portraitUpsideDown: self = .portraitUpsideDown
//        case .landscapeLeft: self = .landscapeLeft
//        case .landscapeRight: self = .landscapeRight
//        default: return nil
//        }
//    }
//}
//
//extension PreviewMetalView.Rotation {
//    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevice.Position) {
//        /*
//         Calculate the rotation between the videoOrientation and the interfaceOrientation.
//         The direction of the rotation depends upon the camera position.
//         */
//        switch videoOrientation {
//        case .portrait:
//            switch interfaceOrientation {
//            case .landscapeRight:
//                if cameraPosition == .front {
//                    self = .rotate90Degrees
//                } else {
//                    self = .rotate270Degrees
//                }
//                
//            case .landscapeLeft:
//                if cameraPosition == .front {
//                    self = .rotate270Degrees
//                } else {
//                    self = .rotate90Degrees
//                }
//                
//            case .portrait:
//                self = .rotate0Degrees
//                
//            case .portraitUpsideDown:
//                self = .rotate180Degrees
//                
//            default: return nil
//            }
//        case .portraitUpsideDown:
//            switch interfaceOrientation {
//            case .landscapeRight:
//                if cameraPosition == .front {
//                    self = .rotate270Degrees
//                } else {
//                    self = .rotate90Degrees
//                }
//                
//            case .landscapeLeft:
//                if cameraPosition == .front {
//                    self = .rotate90Degrees
//                } else {
//                    self = .rotate270Degrees
//                }
//                
//            case .portrait:
//                self = .rotate180Degrees
//                
//            case .portraitUpsideDown:
//                self = .rotate0Degrees
//                
//            default: return nil
//            }
//            
//        case .landscapeRight:
//            switch interfaceOrientation {
//            case .landscapeRight:
//                self = .rotate0Degrees
//                
//            case .landscapeLeft:
//                self = .rotate180Degrees
//                
//            case .portrait:
//                if cameraPosition == .front {
//                    self = .rotate270Degrees
//                } else {
//                    self = .rotate90Degrees
//                }
//                
//            case .portraitUpsideDown:
//                if cameraPosition == .front {
//                    self = .rotate90Degrees
//                } else {
//                    self = .rotate270Degrees
//                }
//                
//            default: return nil
//            }
//            
//        case .landscapeLeft:
//            switch interfaceOrientation {
//            case .landscapeLeft:
//                self = .rotate0Degrees
//                
//            case .landscapeRight:
//                self = .rotate180Degrees
//                
//            case .portrait:
//                if cameraPosition == .front {
//                    self = .rotate90Degrees
//                } else {
//                    self = .rotate270Degrees
//                }
//                
//            case .portraitUpsideDown:
//                if cameraPosition == .front {
//                    self = .rotate270Degrees
//                } else {
//                    self = .rotate90Degrees
//                }
//                
//            default: return nil
//            }
//        @unknown default:
//            fatalError("Unknown orientation.")
//        }
//    }
//}
