//
//  CamTool.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 10/30/23.
//

import CoreMedia
import CoreVideo
import UIKit
import AVFoundation
import Combine
import VideoToolbox
import CoreGraphics
import Accelerate
import CoreServices
import PhosteraShared

enum CameraSetupError: Error {
    case isSimulator
    case noCameras
    case badSetup
}

class CamTool: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    static var shared = CamTool()
    
    private var subscriptions:[Cancellable] = [Cancellable]()
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var videoPreviewView: PreviewMetalView?
    
    private var videoEncoder:H264Encoder = H264Encoder()
    private var session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "SessionQueue", attributes: [], autoreleaseFrequency: .workItem)
    private let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var videoInput: AVCaptureDeviceInput!
    private var audioInput: AVCaptureDeviceInput!
    private var videoDataPreviewOutput:AVCaptureVideoDataOutput?
    private var videoDataRecordingOutput:AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput!
    private let photoOutput = AVCapturePhotoOutput()
    private let photoDelegate = PhotoOutput()
    private let processingQueue = DispatchQueue(label: "photo processing queue", attributes: [], autoreleaseFrequency: .workItem)
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    private var cameraDevice: AVCaptureDevice!
    private var audioDevice: AVCaptureDevice!
    private var cameraDeviceExposure:DeviceExposure = DeviceExposure()
    private var cameraDeviceFocus:DeviceFocus = DeviceFocus()
    private var cameraDeviceWhiteBalance:DeviceWhitebalance = DeviceWhitebalance()
    private var cameraDeviceFrameRate:DeviceFramerate = DeviceFramerate()
    private var currentMode:DirectorProjectCameraMode?
    private var currentProject:DirectorProjectModel?
    private var aspectRatio:CGSize = CGSizeMake(16,9)
    private var statusBarOrientation: UIInterfaceOrientation = .landscapeLeft
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoVisualizer:Visualizer = Visualizer(frame: .zero)
    private var startTime:CMTime = CMTime.zero
    private var recordingState:RecordingState = .idle
    private var useVideoEncoder = false
    private var stillImageOutput: AVCapturePhotoOutput!
    private var outputFileName:URL?
    private var lastOrientation:UIDeviceOrientation = .portrait
    
    
    @objc dynamic var isCurrentlyRecording:Bool = false
    @objc dynamic var outputSize:CGSize = .zero
    @objc dynamic var outputFrameRate:CMTime = .zero
    @objc dynamic var outputEncoderName:String = ""
    @objc dynamic var modeName:String = ""
    @objc dynamic var cameraPositionIsFront:Bool = false
    
    var audioFifo = SampleFIFO(category: "audio")
    var videoFifo = SampleFIFO(category: "video")
    var photoFlashRequest:AVCaptureDevice.FlashMode = .off
    
    private var renderingEnabled = true
    private var audioStreamRequested:Bool = false
    private var cameraPreviewConnection:AVCaptureConnection?
    private var cameraRecordConnection:AVCaptureConnection?
    
    func getCameraDevice() -> AVCaptureDevice? {
        return cameraDevice
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return videoPreviewLayer
    }
    
    func getPreviewView() -> PreviewMetalView? {
        return videoPreviewView
    }
    
    func getPhotoOutput() -> AVCapturePhotoOutput {
        return photoOutput
    }
    
    func getSessionQueue() -> DispatchQueue {
        return sessionQueue
    }
    
    func getProcessingQueue() -> DispatchQueue {
        return processingQueue
    }
    
    func getVisualizer() -> Visualizer {
        return videoVisualizer
    }
    
    func getCameraDeviceFocus() -> DeviceFocus {
        return cameraDeviceFocus
    }
    
    func getCameraDeviceExposure() -> DeviceExposure {
        return cameraDeviceExposure
    }
    
    func getCameraDeviceWhitebalance() -> DeviceWhitebalance {
        return cameraDeviceWhiteBalance
    }
    
    func getCurrentProject() -> DirectorProjectModel? {
        return currentProject
    }
    
    func getCameraType() -> DirectorProjectCameraType {
        guard let currentMode else { return .dual }
        return currentMode.cameraType
    }
    
    func getCameraTech() -> DirectorProjectCameraTechType {
        guard let currentMode else { return .cifilter }
        return currentMode.techType
    }
    
    func getAspectRatio() -> CGSize {
        return aspectRatio
    }
    
    private func getRotationCoordinator() -> AVCaptureDevice.RotationCoordinator? {
        return rotationCoordinator
    }
    
    func externalDisplay(allowSecondary:Bool, preview:PreviewMetalView) {
        Logger.shared.info("Checking for external display.")
        guard let mainDisplayScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive && $0 is UIWindowScene }) as? UIWindowScene,
              let mainRootViewController = mainDisplayScene.windows.first?.rootViewController else {
            Logger.shared.error("Main display's root view controller not found")
            return
        }
        
        if allowSecondary {
            if let v = SettingsService.shared.externalDisplayView {
                if preview.superview != v {
                    preview.removeFromSuperview()
                    v.addSubview(preview)
                    preview.frame = CGRectMake(0, 0, v.frame.size.width, v.frame.size.height)
                }
                Logger.shared.info("Switch to secondary display for preview.")
                return
            }
        }
        
        if preview.superview != mainRootViewController.view {
            preview.removeFromSuperview()
            mainRootViewController.view.addSubview(preview)
            preview.frame = CGRectMake(0, 0, mainRootViewController.view.frame.size.width, mainRootViewController.view.frame.size.height)
            Logger.shared.info("Switch to primary display for preview.")
        } else {
            Logger.shared.info("Continue using primary display for preview.")
        }
    }
    
    func makePreviewView(frame:CGRect) -> PreviewMetalView? {
        if videoPreviewView == nil { videoPreviewView = PreviewMetalView(frame: frame, device: MTLCreateSystemDefaultDevice()) }
        return videoPreviewView
    }
    
    func update(project:DirectorProjectModel) {
        SettingsService.shared.settings.currentProjectId = project.uuid
        SettingsService.shared.save()
        currentProject = project
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .cameraAccessChanged, object: nil) }
        })
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let outputFileName = self.outputFileName {
            if !LibraryController.makeThumbnailFor(url: outputFileName) {
                Logger.shared.error("Unable to create thumbnail for: \(outputFileName.path)")
            }
        }
        
        DispatchQueue.main.async {
            self.recordingState = .idle
            self.isCurrentlyRecording = false
        }
    }
    
    private func updateStatusBarOrientation(orientation:UIInterfaceOrientation) {
        statusBarOrientation = orientation
    }
    
    func isSessionRunning() -> Bool {  return session.isRunning }
    func hasPermission() -> Bool {  return AVCaptureDevice.authorizationStatus(for: .video) == .authorized  }
    func hasPermissionDenied() -> Bool {  return AVCaptureDevice.authorizationStatus(for: .video) == .denied }
    private func isRecording() -> Bool {
        var answer:Bool = false
        
        if let assetWriter {
            answer = assetWriter.status == .writing
        } else if let movieFileOutput {
            answer = movieFileOutput.isRecording == true
        }
        return answer
    }
    
    private func setupMode(mode:DirectorProjectCameraMode) {
        currentMode = mode
        aspectRatio = mode.aspectRatio
        modeName = mode.title
        
        SettingsService.shared.settings.currentModeId = mode.uuid
        SettingsService.shared.save()
    }
    
    func useMode(uuid:String, completion: @escaping (Result<Bool, Error>) -> Void) {
        var mode:DirectorProjectCameraMode?
        
        mode = ModeHandler.shared.directorModeWithUUID(modeUUID: uuid)
        
        if let mode {
            let projId = SettingsService.shared.settings.currentProjectId
            if projId != mode.projectUUID {
                SettingsService.shared.settings.currentProjectId = mode.projectUUID
                SettingsService.shared.save()
                currentProject = DirectorProjectService.shared.loadProject(uuid: mode.projectUUID)
            }
        } else {
            currentProject = nil
        }
        
        if mode == nil {
            mode = ModeHandler.shared.mainBundleModeWithUUID(uuid: uuid)
        }
        
        if mode == nil {
            Logger.shared.error("Unable to find a builtin or director mode for uuid: \(uuid)")
            Logger.shared.info("Switching to default mode.")
            mode = ModeHandler.shared.defaultCameraMode()
            if mode == nil {
                Logger.shared.error("Unable to switch to a default mode. This is fatal.\(uuid)")
                fatalError()
            }
        }
        
        guard let mode else { return } //We know it's good, but the compiler doesn't
        
        let printMode = true
        if printMode {
            let e = JSONEncoder()
            if let d = try? e.encode(mode) {
                if let a = String(data: d, encoding: .utf8) {
                    print ("\(a)")
                }
            }
        }
        
        setupMode(mode: mode)
        
        Logger.shared.info("mode:aspectRatio=\(aspectRatio) - starting session: \(mode.title)")
        
        sessionQueue.async {
            
            //FourCodePixelFormatReference.shared.display()
            let result = Result { try self.startSession() }
            DispatchQueue.main.sync {
                completion(result)
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            rendering(enabled:false)
            session.stopRunning()
            DispatchQueue.main.sync { [weak self] in
                guard let self else { return }
                guard let videoPreviewView else { return }
                videoPreviewView.pixelBuffer = nil
            }
        }
        DispatchQueue.main.async {
            AudioController.shared.stop()
        }
    }
    
    private func startSession() throws -> Bool {
        rendering(enabled:false)
        
        dataOutputQueue.sync {
            if let p = CamTool.shared.getPreviewView() { p.pixelBuffer = nil }
        }
        
        videoPreviewLayer = nil
        
        session = AVCaptureSession()
        session.automaticallyConfiguresApplicationAudioSession = false
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        session.sessionPreset = .inputPriority
        
        let discovery:AVCaptureDevice.DiscoverySession?
        
        guard let currentMode else {
            throw CameraSetupError.noCameras
        }
        
        switch currentMode.cameraType {
            //        case .external:
            //            Logger.shared.info("Using camera: external")
            //            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
            //                                                         mediaType: .video,
            //                                                         position: .unspecified)
        case .wide:
            Logger.shared.info("Using camera: wide")
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                         mediaType: .video,
                                                         position: currentMode.frontCamera ? .front : .back)
        case .telephoto:
            Logger.shared.info("Using camera: telephoto")
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTelephotoCamera],
                                                         mediaType: .video,
                                                         position: currentMode.frontCamera ? .front : .back)
        case .ultrawide:
            Logger.shared.info("Using camera: ultrawide")
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera],
                                                         mediaType: .video,
                                                         position: currentMode.frontCamera ? .front : .back)
        case .dual:
            Logger.shared.info("Using camera: dual")
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
                                                         mediaType: .video,
                                                         position: currentMode.frontCamera ? .front : .back)
        case .dualWide:
            Logger.shared.info("Using camera: dualwide")
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
                                                         mediaType: .video,
                                                         position: currentMode.frontCamera ? .front : .back)
        case .triple:
            Logger.shared.info("Using camera: triple")
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera],
                                                         mediaType: .video,
                                                         position: currentMode.frontCamera ? .front : .back)
            //        case .trueDepth:
            //            throw CameraSetupError.noCameras
            //        case .lidarDepth:
            //            throw CameraSetupError.noCameras
        }
        
        guard let discovery else {
            throw CameraSetupError.noCameras
        }
        
        cameraPositionIsFront = currentMode.frontCamera
        
        session.beginConfiguration()
        
        var resolution = CGSizeMake(1920,1080)
        if currentMode.settings.resolution == .v3840x2160 {
            resolution = CGSizeMake(3840, 2160)
        }
        
        if let camera = findDevice(devices: discovery.devices,
                                   resolution: resolution,
                                   colorspace: currentMode.settings.colorspace,
                                   frameRate: currentMode.settings.frameRate) {
            cameraDevice = camera
        } else {
            currentMode.settings.colorspace = .rec709
            if let camera = findDevice(devices: discovery.devices,
                                       resolution: resolution,
                                       colorspace: .rec709,
                                       frameRate: currentMode.settings.frameRate) {
                cameraDevice = camera
            } else {
                if let camera = discovery.devices.first {
                    cameraDevice = camera
                } else {
                    throw CameraSetupError.noCameras
                }
            }
        }
        
        guard let cameraDevice else {
            Logger.shared.error("Could not find any video device")
            throw CameraSetupError.noCameras
        }
        
        do {
            videoInput = try AVCaptureDeviceInput(device: cameraDevice)
        } catch {
            Logger.shared.error("Could not create video device input: \(error)")
            throw CameraSetupError.noCameras
        }
        
        var addAudio:Bool = true
        if getCameraTech() == .photo { addAudio = false }
        if !AudioController.hasPermission() { addAudio = false }
        
        
        guard session.canAddInput(videoInput) else {
            Logger.shared.error("Could not add video device input to the session")
            session.commitConfiguration()
            throw CameraSetupError.noCameras
        }
        
        session.addInput(videoInput)
        
        if addAudio {
            for option in AudioController.recordingOptions {
                if option.name.contains("Back") {
                    AudioController.shared.selectRecordingOption(option, orientation: .landscapeLeft) { layout in
                        Logger.shared.info("LAYOUT:\(layout)")
                    }
                }
            }
            
            if audioDevice == nil {
                audioDevice = AVCaptureDevice.default(for: .audio)
            }
            
            if (audioDevice == nil) { addAudio = false }
            let y = AudioController.shared.isDeviceSupported
            let z = AudioController.shared.isStereoSupported
            Logger.shared.info("device: \(y) - stereo: \(z)")
        }
        
        if addAudio {
            do {
                audioInput = try AVCaptureDeviceInput(device: audioDevice)
            } catch {
                Logger.shared.error("Could not create audio device input: \(error)")
                throw CameraSetupError.noCameras
            }
            
            // Add an audio input.
            guard session.canAddInput(audioInput) else {
                Logger.shared.error("Could not add audio device input to the session")
                session.commitConfiguration()
                throw CameraSetupError.noCameras
            }
            session.addInput(audioInput)
            Logger.shared.info("Audio input added")
        } else {
            Logger.shared.info("Audio not enabled")
        }
        
        videoDataPreviewOutput = AVCaptureVideoDataOutput()
        guard let videoDataPreviewOutput else {
            Logger.shared.error("Unable to create videoDataPreviewOutput")
            throw CameraSetupError.noCameras
        }
        
        videoDataRecordingOutput = AVCaptureVideoDataOutput()
        guard let videoDataRecordingOutput else {
            Logger.shared.error("Unable to create videoDataRecordingOutput")
            throw CameraSetupError.noCameras
        }
        
        videoDataPreviewOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                                                kCVPixelBufferWidthKey as String: NSNumber(value: 1920),
                                                kCVPixelBufferHeightKey as String: NSNumber(value: 1080)]
        
        videoDataPreviewOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        videoDataRecordingOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        if session.canAddOutput(videoDataPreviewOutput) {
            session.addOutputWithNoConnections(videoDataPreviewOutput)
        } else {
            Logger.shared.error("Could not add videoDataPreviewOutput to the session")
            session.commitConfiguration()
            throw CameraSetupError.noCameras
        }
        
        if getCameraTech() == .photo {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                
                photoOutput.maxPhotoQualityPrioritization = .quality
            } else {
                Logger.shared.error("Could not add photo output to the session")
                
                session.commitConfiguration()
                throw CameraSetupError.noCameras
            }
        } else {
            if session.canAddOutput(videoDataRecordingOutput) {
                session.addOutputWithNoConnections(videoDataRecordingOutput)
            } else {
                Logger.shared.error("Could not add videoDataRecordingOutput to the session")
                session.commitConfiguration()
                throw CameraSetupError.noCameras
            }
        }
        
        if addAudio {
            audioOutput = AVCaptureAudioDataOutput()
            //Gives us videodataoutput callback
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                Logger.shared.info("Audio output added")
            }
        }
        
        //        // Add a depth data output
        //        if session.canAddOutput(depthDataOutput) {
        //            session.addOutput(depthDataOutput)
        //            depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
        //            depthDataOutput.isFilteringEnabled = false
        //            if let connection = depthDataOutput.connection(with: .depthData) {
        //                connection.isEnabled = depthVisualizationEnabled
        //            } else {
        //                Logger.shared.error("No AVCaptureConnection for depth data")
        //            }
        //        } else {
        //            Logger.shared.error("Could not add depth data output to the session")
        //
        //            session.commitConfiguration()
        //            throw CameraSetupError.noCameras
        //        }
        //
        //        if depthVisualizationEnabled {
        //            // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        //            // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        //            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        //            if let unwrappedOutputSynchronizer = outputSynchronizer {
        //                unwrappedOutputSynchronizer.setDelegate(self, queue: dataOutputQueue)
        //            }
        //        } else {
        //            outputSynchronizer = nil
        //        }
        
        //capFrameRate(videoDevice: videoDevice)
        
        //videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        //rotationCoordinator = AVCaptureDevice.RotationCoordinator.init(device: cameraDevice, previewLayer: videoPreviewLayer)
        
        if let videoInput {
            guard let videoInputPort = videoInput.ports(for: .video,
                                                        sourceDeviceType: cameraDevice.deviceType,
                                                        sourceDevicePosition: cameraDevice.position).first else {
                Logger.shared.error("Could not find the camera device input's video port")
                throw CameraSetupError.noCameras
            }
            
            cameraPreviewConnection = AVCaptureConnection(inputPorts: [videoInputPort], output: videoDataPreviewOutput)
            if let cameraPreviewConnection {
                guard session.canAddConnection(cameraPreviewConnection) else {
                    Logger.shared.error("Could not add a connection to the cameraPreviewConnection")
                    throw CameraSetupError.noCameras
                }
                session.addConnection(cameraPreviewConnection)
            }
            
            cameraRecordConnection = AVCaptureConnection(inputPorts: [videoInputPort], output: videoDataRecordingOutput)
            if let cameraRecordConnection {
                guard session.canAddConnection(cameraRecordConnection) else {
                    Logger.shared.error("Could not add a connection to the cameraRecordConnection")
                    throw CameraSetupError.noCameras
                }
                session.addConnection(cameraRecordConnection)
            }
        }
        
        session.commitConfiguration()
        
        cameraDeviceExposure = DeviceExposure()
        cameraDeviceFocus = DeviceFocus()
        cameraDeviceWhiteBalance = DeviceWhitebalance()
        cameraDeviceFrameRate = DeviceFramerate()
        
        do {
            try videoEncoder.configureCompressSession()
            videoEncoder.naluHandling = { data in
                Task(priority: .high, operation: {
                    await VideoStreamServer.shared.sendVideo(frame: data)
                })
            }
        } catch {
            Logger.shared.error("unable to configure video encoder")
        }
        
        PubCentral.shared.setupDevicePublishers()
        
        cameraDeviceExposure.useDevice(currentDevice: cameraDevice)
        cameraDeviceWhiteBalance.useDevice(currentDevice:cameraDevice)
        cameraDeviceFocus.useDevice(currentDevice: cameraDevice)
        cameraDeviceFrameRate.useDevice(currentDevice: cameraDevice)
        
        PubCentral.shared.setupDevicePublishers()
        
        if let p = CamTool.shared.getPreviewView() {
            p.mirroring = (cameraDevice.position == .front)
        }
        
        session.startRunning()
        
        switch currentMode.settings.frameRate {
        case .fr24:
            cameraDeviceFrameRate.capFrameRate(rate: 24.0)
        case .fr25:
            cameraDeviceFrameRate.capFrameRate(rate: 25.0)
        case .fr30:
            cameraDeviceFrameRate.capFrameRate(rate: 30.0)
        }
        
        rendering(enabled:true)
        
        self.updateSessionInfoForDisplay()
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            printDeviceInformation(for: cameraDevice)
            setupEventSubscriptions()
            if let mainDisplayScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive && $0 is UIWindowScene }) as? UIWindowScene {
                if let c = videoDataPreviewOutput.connection(with: .video) {
                    if let rotation = PreviewMetalView.Rotation(with: mainDisplayScene.interfaceOrientation,
                                                                videoOrientation: c.videoOrientation,
                                                                cameraPosition: self.videoInput.device.position) {
                        if let p = CamTool.shared.getPreviewView() {
                            p.rotation = rotation
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    private func findDevice(devices:[AVCaptureDevice], resolution:CGSize, colorspace:DirectorProjectColorspace, frameRate:DirectorProjectFrameRate) -> AVCaptureDevice? {
        for device in devices {
            let list = device.formats.filter { format in
                var fourCCString:String = ""
                var goodFormat:Bool = false
                let formatDescription = format.formatDescription
                let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
                if mediaType == kCMMediaType_Video {
                    let fourCC = CMFormatDescriptionGetMediaSubType(formatDescription)
                    var str = ""
                    for i in 0..<4 {
                        let byte = UInt8((fourCC >> (i * 8)) & 0xFF)
                        str = String(UnicodeScalar(byte)) + str
                    }
                    fourCCString = str
                }
                
                let resolutionAnswer:Bool = (format.formatDescription.dimensions.width == Int(resolution.width)) && (format.formatDescription.dimensions.height == Int(resolution.height))
                
                var colorspaceAnswer:Bool = false
                switch colorspace {
                case .rec709:
                    colorspaceAnswer = format.supportedColorSpaces.contains(.sRGB)
                    if fourCCString.prefix(1) != "x" {
                        goodFormat = true
                    }
                case .appleLog:
                    if fourCCString == "x422" {
                        goodFormat = true
                    }
                    colorspaceAnswer = format.supportedColorSpaces.contains(.appleLog)
                    //                case .p3d65:
                    //                    if fourCCString.prefix(1) == "x"{
                    //                        goodFormat = true
                    //                    }
                    //                    colorspaceAnswer = format.supportedColorSpaces.contains(.P3_D65)
                }
                
                //                if resolutionAnswer && format.isVideoHDRSupported && goodFormat {
                //                    Logger.shared.info("Good test:")
                //                    for x in format.supportedColorSpaces {
                //                        Logger.shared.info("cs:\(x.rawValue)")
                //                    }
                //                }
                //
                //                Logger.shared.info("testing: colorspace found: \(colorspaceAnswer)")
                
                return colorspaceAnswer && resolutionAnswer && format.isVideoHDRSupported && goodFormat
            }
            
            if list.count == 0 {
                return nil
            } else if list.count > 1 {
                Logger.shared.info("More than one format matched. Using first.")
            }
            
            let f = list[0]
            
            do {
                Logger.shared.info("Using dimensions: \(f.formatDescription.dimensions.width)x\(f.formatDescription.dimensions.height)")
                
                switch colorspace {
                case .rec709:
                    Logger.shared.info("Using colorspace: rec709")
                    try device.lockForConfiguration()
                    device.automaticallyAdjustsVideoHDREnabled = false
                    device.isVideoHDREnabled = false
                    device.activeFormat = f
                    device.activeColorSpace = .sRGB
                    device.unlockForConfiguration()
                case .appleLog:
                    if !f.supportedColorSpaces.contains(.appleLog) { continue }
                    Logger.shared.info("Using colorspace: appleLog")
                    try device.lockForConfiguration()
                    device.activeFormat = f
                    device.automaticallyAdjustsVideoHDREnabled = false
                    device.isVideoHDREnabled = true
                    device.activeColorSpace = .appleLog
                    device.unlockForConfiguration()
                    //                    case .p3d65:
                    //                        if !f.supportedColorSpaces.contains(.P3_D65) { continue }
                    //                        Logger.shared.info("Using colorspace: P3 D65")
                    //                        try d.lockForConfiguration()
                    //                        d.activeFormat = f
                    //                        d.automaticallyAdjustsVideoHDREnabled = false
                    //                        d.isVideoHDREnabled = true
                    //                        d.activeColorSpace = .P3_D65
                    //                        d.unlockForConfiguration()
                }
                Logger.shared.info("Found camera with colorspace and dimensions")
                Logger.shared.info("Device: \(device.localizedName)")
                Logger.shared.info("Active Format: \(device.activeFormat.formatDescription)")
                Logger.shared.info("Active Color Space: \(device.activeColorSpace)")
                return device
            } catch {
                Logger.shared.error("invalid colorspace set")
            }
        }
        
        return nil
    }
    
    private func printDeviceInformation(for device: AVCaptureDevice) {
        Logger.shared.info("Current Camera Specs")
        Logger.shared.info("--------------------------------------------")
        Logger.shared.info("Device: \(device.localizedName)")
        Logger.shared.info("Active Format: \(device.activeFormat.formatDescription)")
        
        let currentColorSpace = device.activeColorSpace
        Logger.shared.info("Current Color Space: \(currentColorSpace)")
        
        let allColorSpaces: [AVCaptureColorSpace] = device.activeFormat.supportedColorSpaces
        for colorSpace in allColorSpaces {
            Logger.shared.info("Supported Color Space: \(colorSpace)")
        }
        Logger.shared.info("--------------------------------------------")
    }
    
    private func rendering(enabled:Bool) {
        dataOutputQueue.sync { [weak self] in
            guard let self else { return }
            renderingEnabled = enabled
            Logger.shared.info("Rendering: \(enabled)")
        }
    }
    
    private func frameRate(session: AVCaptureSession) -> CMTime? {
        guard let input = session.inputs.first as? AVCaptureDeviceInput else {
            return nil
        }
        
        return input.device.activeVideoMinFrameDuration
    }
    
    private func outputResolution(session: AVCaptureSession) -> CGSize? {
        guard let output = session.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput else {
            return nil
        }
        
        guard let videoSettings = output.videoSettings else {
            return nil
        }
        
        guard let width = videoSettings["Width"] as? Int,
              let height = videoSettings["Height"] as? Int else {
            return nil
        }
        
        return CGSize(width: width, height: height)
    }
    
    private func updateSessionInfoForDisplay() {
        self.outputSize = self.outputResolution(session: session) ?? .zero
        self.outputFrameRate = self.frameRate(session: session) ?? .zero
        self.outputEncoderName = "h264"
    }
    
    private func makeAndStoreScreenshot(image: UIImage) {
        let resolution: CGSize = CGSize(width: 200.0, height: 112.5)
        let renderer = UIGraphicsImageRenderer(size: resolution)
        let scaledImage = renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: resolution))
        }
        guard let imageData = scaledImage.jpegData(compressionQuality: 0.5) else { return }
        
        DispatchQueue.main.async {
            PubCentral.shared.screenShot = imageData
        }
    }
    
    func sendScreenshotNow() {
        makeScreenshotNow = true
    }
    
    private var magicCookie:Data?
    
    private let magicCookieCheckMax:Int = 9000 //5 min at 30fps
    private lazy var magicCookieCheckCount:Int = magicCookieCheckMax - 150 // Give 5 seconds for encoder to figure out the cookie
    
    func getAACCookie() -> Data? {
        return magicCookie
    }
    
    private var makeScreenshotNow:Bool = false
    
    private var monoStreamer:AudioStreamerMono = AudioStreamerMono()
    
    func addLocationMetadataToVideo(assetWriter: AVAssetWriter) {
        if let locationString = LocationController.shared.locationString() as? NSString {
            let metadataItem = AVMutableMetadataItem()
            metadataItem.keySpace = .quickTimeMetadata
            metadataItem.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as NSString
            metadataItem.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
            metadataItem.value = locationString
            assetWriter.metadata = [metadataItem]
            Logger.shared.info("Requested current location and added it to the video metadata.")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDesc:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        
        let mediaType:CMMediaType = CMFormatDescriptionGetMediaType(formatDesc);
        if (mediaType == kCMMediaType_Audio) && (output == audioOutput) {
            if recordingState == .assetWriterCapturing {
                if (assetWriterAudioInput != nil) && assetWriterAudioInput!.isReadyForMoreMediaData {
                    assetWriterAudioInput?.append(sampleBuffer)
                }
            }
            
            var firstAudioChannel:Bool = true
            guard let audioOutput else { return }
            guard let connection = audioOutput.connection(with: .audio) else { return }
            for channel in connection.audioChannels {
                let normalizedLevel = channel.averagePowerLevel
                let normalizedPeak = channel.peakHoldLevel
                StatusService.shared.pushPowerLevel(level: CGFloat(normalizedLevel), peak: CGFloat(normalizedPeak), left: firstAudioChannel ? true : false)
                firstAudioChannel.toggle()
            }
            
            //            if !audioStreamRequested {
            //                Task {
            //                    audioStreamRequested = await audioFifo.count() < 5
            //                    Logger.shared.info("Audio stream fifo overrun; no takers it seems.")
            //                }
            //            }
            //
            //            if let data = monoStreamer.convertSampleBuffer(sampleBuffer) {
            //                Task(priority: .userInitiated, operation: { [weak self] in
            //                    guard let self else { return }
            //                    await audioFifo.enqueue(data)
            //                    audioStreamRequested = await audioFifo.count() < 5
            //                })
            //            }
            
            return // Done with audio
        } else {
            if connection != cameraRecordConnection {
                let useVideoEncoder = true
                if useVideoEncoder {
                    videoEncoder.captureOutput(output, didOutput: sampleBuffer, from: connection)
                }
                processVideo(sampleBuffer: sampleBuffer)
                if makeScreenshotNow {
                    if !isRecording() {
                        makeScreenshotNow = false
                        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                        let context = CIContext()
                        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
                        let uiImage = UIImage(cgImage: cgImage)
                        Logger.shared.info("making screenshot")
                        Task {
                            makeAndStoreScreenshot(image: uiImage)
                        }
                    }
                }
                return //Done with preview
            }
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        switch recordingState {
        case .assetWriterStart:
            CameraTakeService.shared.startTake()
            startTime = timestamp + CMTime(seconds: 1.0, preferredTimescale: timestamp.timescale)
            recordingState = .assetWriterStartWait
            
            guard let currentMode else {
                Logger.shared.error("assetWriterStart no currentMode")
                return
            }
            
            guard let videoDataRecordingOutput else {
                Logger.shared.error("videoDataRecordingOutput notexist in assetWriterStart")
                return
            }
            
            var videoSettings:[String : Any]?
            
            guard let currentTake = CameraTakeService.shared.getCurrentTake() else {
                Logger.shared.error("no currentTake.")
                return
            }
            
            self.outputFileName = URL(fileURLWithPath: currentTake.localTakeDirectory)
                .appending(component: currentTake.uuid, directoryHint: .notDirectory)
                .appendingPathExtension(for: .quickTimeMovie)
            
            if currentMode.settings.colorspace == .appleLog {
                switch currentMode.settings.codec {
                case .proRes422HQ:
                    if currentMode.settings.recordToDisk, let url = makeAndReturnStorageDirectory() {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422HQ, assetWriterOutputFileType: .mov, outputFileURL: url)
                        self.outputFileName = url
                    } else {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422HQ, assetWriterOutputFileType: .mov)
                    }
                case .proRes422:
                    if currentMode.settings.recordToDisk, let url = makeAndReturnStorageDirectory() {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422, assetWriterOutputFileType: .mov, outputFileURL: url)
                        self.outputFileName = url
                    } else {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422, assetWriterOutputFileType: .mov)
                    }
                case .proRes422LT:
                    if currentMode.settings.recordToDisk, let url = makeAndReturnStorageDirectory() {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422LT, assetWriterOutputFileType: .mov, outputFileURL: url)
                        self.outputFileName = url
                    } else {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422LT, assetWriterOutputFileType: .mov)
                    }
                case .proRes422Proxy:
                    if currentMode.settings.recordToDisk, let url = makeAndReturnStorageDirectory() {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422Proxy, assetWriterOutputFileType: .mov, outputFileURL: url)
                        self.outputFileName = url
                    } else {
                        videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .proRes422Proxy, assetWriterOutputFileType: .mov)
                    }
                }
            } else {
                videoSettings = videoDataRecordingOutput.recommendedVideoSettings(forVideoCodecType: .hevc, assetWriterOutputFileType: .mov)
            }
            
            if outputFileName == nil {
                return //can't write
            }
            
            let writer = try! AVAssetWriter(outputURL: outputFileName!, fileType: .mov)
            
            
            guard let videoSettings else {
                Logger.shared.error("videoDataRecordingOutput no settings.")
                return
            }
            
            let avInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            
            if (UIDevice.current.orientation == .landscapeLeft) ||
                (UIDevice.current.orientation == .landscapeRight) ||
                (UIDevice.current.orientation == .portrait) ||
                (UIDevice.current.orientation == .portraitUpsideDown) {
                lastOrientation = UIDevice.current.orientation
            }
            
            guard let _ = videoDataRecordingOutput.connection(with: .video) else {
                Logger.shared.error("no connection for rotation in assetwriter begin")
                return
            }
            
            avInput.expectsMediaDataInRealTime = true
            
            var audioSettings:[String:Any]?
            if let audioOutput {
                audioSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .m4a)
                
                audioSettings?[AVNumberOfChannelsKey] = 2  // Force stereo
            }
            let avAudioPinut = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            avAudioPinut.expectsMediaDataInRealTime = true
            
            let pixelAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: avInput, sourcePixelBufferAttributes: nil)
            
            
            
            if writer.canAdd(avInput) {
                Logger.shared.info("Addding input with transform")
                if lastOrientation == .landscapeRight {
                    Logger.shared.info("Rotating 180")
                    avInput.transform = avInput.transform.rotated(by: -.pi)
                } else if lastOrientation == .portrait {
                    Logger.shared.info("Rotating 180")
                    avInput.transform = avInput.transform.rotated(by: .pi / 2.0)
                } else if lastOrientation == .portraitUpsideDown {
                    Logger.shared.info("Rotating 180")
                    avInput.transform = avInput.transform.rotated(by: -.pi / 2.0)
                }
                
                writer.add(avInput)
            }
            
            if writer.canAdd(avAudioPinut) {
                writer.add(avAudioPinut)
                Logger.shared.info("Assetwriter Audio input added")
            }
            assetWriter = writer
            assetWriterVideoInput = avInput
            assetWriterAudioInput = avAudioPinut
            pixelBufferAdaptor = pixelAdapter
            
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { return }
                if let assetWriter {
                    assetWriter.startWriting()
                }
            }
            
        case .assetWriterStartWait:
            if timestamp >= startTime {
                if let assetWriter {
                    if assetWriter.status == .writing {
                        
                        startTime = timestamp
                        Logger.shared.info("Start Time:\(self.startTime.value) - \(self.startTime.timescale)")
                        
                        assetWriter.startSession(atSourceTime: startTime)
                        recordingState = .assetWriterCapturing
                        addLocationMetadataToVideo(assetWriter: assetWriter)
                        
                        if let o = outputFileName { StatusService.shared.startFileMonitor(url: o) }
                    }
                }
            }
        case .assetWriterCapturing:
            if let assetWriterVideoInput {
                if assetWriterVideoInput.isReadyForMoreMediaData == true {
                    //  let t = timestamp - startTime
                    
                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        pixelBufferAdaptor?.append(imageBuffer, withPresentationTime:timestamp)
                    }
                }
            }
            
            break
        case .assetWriterEnding:
            
            if assetWriter == nil {
                Logger.shared.error("assetwriter nil at .assetWriterEnding: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
                return
            }
            
            if assetWriterVideoInput == nil {
                Logger.shared.error("assetwriterinput nil at .assetWriterEnding: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
                return
            }
            
            
            if assetWriter?.status == .writing {
                assetWriterVideoInput?.markAsFinished()
                assetWriterAudioInput?.markAsFinished()
            }
            
            recordingState = .idle
            assetWriter?.finishWriting { [weak self] in
                guard let self else { return }
                Logger.shared.info("assetWriter finishing")
                recordingState = .idle
                assetWriter = nil
                assetWriterVideoInput = nil
                assetWriterAudioInput = nil
                isCurrentlyRecording = false
                
                if let outputFileName {
                    if !LibraryController.makeThumbnailFor(url: outputFileName) {
                        Logger.shared.error("Unable to create thumbnail for: \(outputFileName.path)")
                    }
                    
                }
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
                return
            }
            
            if assetWriter?.error != nil {
                Logger.shared.error("assetwriter failed: \(String(describing: self.assetWriter?.outputURL.path(percentEncoded: true))) error:\(String(describing: self.assetWriter?.error?.localizedDescription))")
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
            }
            CameraTakeService.shared.endTake()
        default:
            break
        }
    }
    
    private func makeAndReturnStorageDirectory() -> URL? {
        for storage in ExternalStorageService.storageList() {
            if let mediaURL = ExternalStorageManager.loadExernalStorage(media: storage) {
                if mediaURL.startAccessingSecurityScopedResource() {
                    if let take = CameraTakeService.shared.getCurrentTake() {
                        let d = mediaURL
                            .appending(path: take.projectUUID, directoryHint: .isDirectory)
                            .appending(path: take.uuid, directoryHint: .isDirectory)
                        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
                        return d.appending(path: "\(take.uuid).mov", directoryHint: .notDirectory)
                    }
                }
            }
        }
        return nil
    }
    
    private func processVideo(sampleBuffer: CMSampleBuffer) {
        if !renderingEnabled {
            return
        }
        
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let _ = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }
        
        if let p = CamTool.shared.getPreviewView() {
            p.pixelBuffer = videoPixelBuffer
        } else if getCameraTech() != .movie {
            Logger.shared.info("No getPreviewView yet; dropping pixelBuffer")
        }
    }
    
    func transitionToSize(size:CGSize, orientation:UIInterfaceOrientation) {
        self.sessionQueue.async { [weak self] in
            guard let self else { return }
            if let photoOrientation = AVCaptureVideoOrientation(interfaceOrientation: orientation) {
                if let c = self.photoOutput.connection(with: .video) {
                    Logger.shared.info("getting a bail message here. need to switch to angle.")
                    c.videoOrientation = photoOrientation
                }
            }
            
            if let c = CamTool.shared.getPreviewLayer()?.connection {
                if let rotationCoordinator {
                    c.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
                }
            }
            
            if let videoDataPreviewOutput, let c = videoDataPreviewOutput.connection(with: .video) {
                if let rotation = PreviewMetalView.Rotation(with: orientation,
                                                            videoOrientation: c.videoOrientation,
                                                            cameraPosition: self.videoInput.device.position) {
                    if let p = CamTool.shared.getPreviewView() {
                        p.rotation = rotation
                    }
                }
            }
        }
        
    }
    
    var beepTool = BeepTool()
    
    func beginRecording() {
        if self.isRecording() {
            return
        }
        beepTool.playBeepSound()
        switch(getCameraTech()) {
        case .movie:
            CameraTakeService.shared.startTake()
            sessionQueue.async { [weak self] in
                guard let self else {
                    return
                }
                
                if (self.movieFileOutput == nil) {
                    
                    self.movieFileOutput = AVCaptureMovieFileOutput()
                    
                    guard let movieFileOutput else {
                        Logger.shared.error("moviefileoutput in beginrecording - unable to create")
                        return
                    }
                    
                    if let currentTake = CameraTakeService.shared.getCurrentTake() {
                        self.outputFileName = URL(fileURLWithPath: currentTake.localTakeDirectory)
                            .appending(component: currentTake.uuid, directoryHint: .notDirectory)
                            .appendingPathExtension(for: .quickTimeMovie)
                    }
                    
                    guard let _ = outputFileName else {
                        Logger.shared.error("moviefileoutput unable to create a filename")
                        return
                    }
                    
                    
                    if session.canAddOutput(movieFileOutput) {
                        session.beginConfiguration()
                        session.addOutput(movieFileOutput)
                        session.commitConfiguration()
                    } else {
                        Logger.shared.error("Unable to add moviefileoutput")
                        return
                    }
                    
                    guard let movieFileOutputConnection = movieFileOutput.connection(with: .video) else {
                        Logger.shared.error("moviefileoutput unable to connect to connection")
                        return
                    }
                    
                    if movieFileOutput.availableVideoCodecTypes.contains(.hevc) {
                        movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection)
                    }
                }
                
                if let outputFileName {
                    Logger.shared.info("Starting movie file \(outputFileName)")
                    movieFileOutput?.startRecording(to: outputFileName, recordingDelegate: self)
                    recordingState = .movieFileCapturing
                    isCurrentlyRecording = true
                    StatusService.shared.startFileMonitor(url: outputFileName)
                } else {
                    Logger.shared.info("Unable to start recording. no outputFileName.")
                }
            }
        case .photo:
            CameraTakeService.shared.startTake()
            
            sessionQueue.async { [weak self] in
                guard let self else { return }
                let photoSettings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
                photoSettings.isDepthDataDeliveryEnabled = false
                photoSettings.flashMode = photoFlashRequest
                photoOutput.capturePhoto(with: photoSettings, delegate: photoDelegate)
            }
        case .cifilter:
            recordingState = .assetWriterStart
            isCurrentlyRecording = true
        }
    }
    
    func endRecording() {
        if !self.isRecording() {
            return
        }
        
        StatusService.shared.stopFileMonitor()
        
        switch (getCameraTech()) {
        case .movie:
            sessionQueue.async { [weak self] in
                guard let self else { return }
                if let movieFileOutput {
                    if !movieFileOutput.isRecording { Logger.shared.error("Attempt to endRecording while not recording (moviefile)"); return }
                    movieFileOutput.stopRecording()
                    CameraTakeService.shared.endTake()
                }
            }
        case .photo:
            CameraTakeService.shared.endTake()
            break
        case .cifilter:
            if recordingState == .assetWriterCapturing {
                recordingState = .assetWriterEnding
                isCurrentlyRecording = false
            }
        }
    }
    
    private func setupEventSubscriptions() {
        subscriptions.removeAll()
        self.subscriptions.append(PubCentral.shared.pubThermalStateChanged.receive(on: DispatchQueue.main).sink { value in
            //            if let userInfoValue = value.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            //                let reasonIntegerValue = userInfoValue.integerValue,
            //                let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            //                Logger.shared.error("Capture session was interrupted with reason \(reason)")
            //
            //                if reason == .videoDeviceInUseByAnotherClient {
            //
            //                } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
            //
            //                }
            //            }
        })
        
        self.subscriptions.append(PubCentral.shared.pubSessionRuntimeError.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            
            if isRecording() {
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
            }
            
            guard let errorValue = value.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
                return
            }
            
            let error = AVError(_nsError: errorValue)
            Logger.shared.error("Capture session runtime error: \(error)")
            
            if error.code == .mediaServicesWereReset {
                sessionQueue.async {
                    
                }
            } else {
                
            }
        })
        
        self.subscriptions.append(PubCentral.shared.pubSessionWasInterrupted.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            
            if isRecording() {
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil) }
            }
            
            guard let errorValue = value.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
                return
            }
            
            let error = AVError(_nsError: errorValue)
            Logger.shared.info("Capture session was interrupted: \(error)")
            
            if error.code == .mediaServicesWereReset {
                sessionQueue.async {
                    
                }
            } else {
                
            }
            
        })
        
        self.subscriptions.append(PubCentral.shared.pubSessionInterruptionEnded.receive(on: DispatchQueue.main).sink { value in
            Logger.shared.info("Capture session interuption ended")
        })
        
        self.subscriptions.append(PubCentral.shared.pubExternalDisplayChanged.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            if let v = getPreviewView() {
                externalDisplay(allowSecondary: true, preview: v)
            }
        })
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isRecording() {
            Logger.shared.error("Dropped Frame while recording!")
        }
        if recordingState == .assetWriterCapturing {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name.CameraOperations.droppedFrame, object: nil)
            }
        }
    }
}

extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}

extension PreviewMetalView.Rotation {
    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevice.Position) {
        /*
         Calculate the rotation between the videoOrientation and the interfaceOrientation.
         The direction of the rotation depends upon the camera position.
         */
        switch videoOrientation {
        case .portrait:
            switch interfaceOrientation {
            case .landscapeRight:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .landscapeLeft:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .portrait:
                self = .rotate0Degrees
                
            case .portraitUpsideDown:
                self = .rotate180Degrees
                
            default: return nil
            }
        case .portraitUpsideDown:
            switch interfaceOrientation {
            case .landscapeRight:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .landscapeLeft:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .portrait:
                self = .rotate180Degrees
                
            case .portraitUpsideDown:
                self = .rotate0Degrees
                
            default: return nil
            }
            
        case .landscapeRight:
            switch interfaceOrientation {
            case .landscapeRight:
                self = .rotate0Degrees
                
            case .landscapeLeft:
                self = .rotate180Degrees
                
            case .portrait:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .portraitUpsideDown:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            default: return nil
            }
            
        case .landscapeLeft:
            switch interfaceOrientation {
            case .landscapeLeft:
                self = .rotate0Degrees
                
            case .landscapeRight:
                self = .rotate180Degrees
                
            case .portrait:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .portraitUpsideDown:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            default: return nil
            }
        @unknown default:
            fatalError("Unknown orientation.")
        }
    }
}
