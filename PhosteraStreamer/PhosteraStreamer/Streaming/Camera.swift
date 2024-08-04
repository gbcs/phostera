//
//  Camera.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 9/16/23.
//

import UIKit
import AVFoundation
import Combine
import PhosteraShared

class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    static func hasPermission() -> Bool {  return AVCaptureDevice.authorizationStatus(for: .video) == .authorized  }
    static func hasPermissionDenied() -> Bool {  return AVCaptureDevice.authorizationStatus(for: .video) == .denied }
    
    static func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .cameraAccessChanged, object: nil) }
        })
    }
    
    private var session:AVCaptureMultiCamSession?
    private var cameraDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var cameraDevice2: AVCaptureDevice?
    private var videoInput2: AVCaptureDeviceInput?
    private var videoDataOutput2: AVCaptureVideoDataOutput?
    private var cameraConnection:AVCaptureConnection?
    private var camera2Connection:AVCaptureConnection?
    private var disconnectPublisher:Publishers.Throttle<NSObject.KeyValueObservingPublisher<AVCaptureDevice, Bool>, DispatchQueue>?
    private var disconnectSubscriber:AnyCancellable?
    
    func getVideoDataOutput() -> AVCaptureVideoDataOutput? {
        return videoDataOutput
    }
    
    private var cancellable:AnyCancellable?
    
    private let cameraQueue = DispatchQueue(label: "cameraQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
  
    var hostCamera:StreamUserCameraSelection = .off
    var subjectCamera:StreamSubjectCameraSelection = .off
    
    func stopRear() {
        if subjectCamera == .off { return }
 
        subjectCamera = .off

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
            MetalTool.shared.useCameraBuffer(rear: nil)
            Task {
                let project = await ProjectService.shared.currentProject()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    start(withHost: hostCamera,
                          withSubject: subjectCamera,
                          rearExternal: project.ipadExternal == .replacesRear, rearLens: project.rearCameraLens)
                }
            }
        })
    }
    
    func stop() {
        cameraQueue.async { [weak self] in
            guard let self else { return }
            session?.stopRunning()
            session = nil
            cameraDevice = nil
            videoInput = nil
            videoDataOutput = nil
            cameraDevice2 = nil
            videoInput2 = nil
            videoDataOutput2 = nil
            cancellable = nil
            cameraConnection = nil
            camera2Connection = nil
            disconnectPublisher = nil
            disconnectSubscriber = nil
            Dispatch.DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.localCameraChanged, object: nil) }
            Task {
                MetalTool.shared.useCameraBuffer(front: nil)
                MetalTool.shared.useCameraBuffer(rear: nil)
            }
        }
    }

    var lastOrientation:CGFloat = 0
    
    func updateRotationAngle() {
        func updateOutputFront(o:AVCaptureVideoDataOutput) {
            if let c = o.connections.first {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    var newOrientation = lastOrientation
                    
                    switch windowScene.interfaceOrientation {
                    case .portraitUpsideDown:
                        newOrientation = 270
                        if o == videoDataOutput {
                            if c.isVideoMirroringSupported {
                                c.isVideoMirrored = true
                            }
                        }
                    case .portrait:
                        newOrientation = 90
                        if o == videoDataOutput {
                            if c.isVideoMirroringSupported {
                                c.isVideoMirrored = true
                            }
                        }
                    case .landscapeRight: //camera on left
                        newOrientation = 180
                        if o == videoDataOutput {
                            if c.isVideoMirroringSupported {
                                c.isVideoMirrored = true
                            }
                        }
                    case .landscapeLeft: //camera on right
                        newOrientation = 0
                        if o == videoDataOutput {
                            if c.isVideoMirroringSupported {
                                c.isVideoMirrored = true
                            }
                        }
                    default:
                        break
                    }
                    
                    if lastOrientation != newOrientation {
                        c.videoRotationAngle = newOrientation
                        lastOrientation = newOrientation
                    }
                }
            }
        }
        
        func updateOutputRear(o:AVCaptureVideoDataOutput) {
            if let c = o.connections.first {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    var newOrientation = lastOrientation
                    
                    switch windowScene.interfaceOrientation {
                    case .portraitUpsideDown:
                        newOrientation = 270
                       
                    case .portrait:
                        newOrientation = 90
                      
                    case .landscapeRight: //camera on left
                        newOrientation = 0
                     
                    case .landscapeLeft: //camera on right
                        newOrientation = 180
                    default:
                        break
                    }
                    
                    if lastOrientation != newOrientation {
                        c.videoRotationAngle = newOrientation
                        lastOrientation = newOrientation
                    }
                }
            }
        }
        
        if let videoDataOutput {
            updateOutputFront(o: videoDataOutput)
        }
        
        if let videoDataOutput2 {
            updateOutputRear(o: videoDataOutput2)
        }
    }

    func start(withHost:StreamUserCameraSelection, withSubject:StreamSubjectCameraSelection, rearExternal:Bool, rearLens:StreamRearCameraLens) {
        lastOrientation = -1
        cancellable = PubCentral.shared.orientationChanged.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
                updateRotationAngle()
        }

        hostCamera = withHost
        subjectCamera = withSubject

        session = AVCaptureMultiCamSession()
        guard let session else {
            Logger.shared.error("Could not create capture session")
            return
        }
       
        cameraDevice = nil
        cameraDevice2 = nil
        disconnectSubscriber = nil
        disconnectPublisher = nil 
        
        MetalTool.shared.useCameraBuffer(front: nil)
        MetalTool.shared.useCameraBuffer(rear: nil)
        
        if hostCamera == .frontOn {
            if !rearExternal {
                let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [ .external,], mediaType: .video, position:  .unspecified )
                cameraDevice = videoDeviceDiscoverySession.devices.first
            }
            
            if cameraDevice == nil {
                let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [ .builtInWideAngleCamera,], mediaType: .video, position:  .front )
                cameraDevice = videoDeviceDiscoverySession.devices.first
            }
            
            if cameraDevice == nil {
                Logger.shared.error("No front/external camera found.")
                hostCamera = .off
            } else {
                guard let cameraDevice else { return }
                do {
                    videoInput = try AVCaptureDeviceInput(device: cameraDevice)
                } catch {
                    Logger.shared.error("Could not create front video device input: \(error)")
                    hostCamera = .off
                }
            }
        }
        
        if subjectCamera == .rearOn {
            if rearExternal {
                let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [ .external], mediaType: .video, position:  .unspecified )
                cameraDevice2 = videoDeviceDiscoverySession.devices.first
            }
            
            if cameraDevice2 == nil {
                var deviceList:[AVCaptureDevice.DeviceType] = []
                switch rearLens {
                case .telephoto:
                    deviceList.append(.builtInTelephotoCamera)
                case .ultrawide:
                    deviceList.append(.builtInUltraWideCamera)
                case .wide:
                    deviceList.append(.builtInWideAngleCamera)
                }
                
                let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceList, mediaType: .video, position:  .back )
                if videoDeviceDiscoverySession.devices.count < 1 {
                    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [ .builtInWideAngleCamera], mediaType: .video, position:  .back )
                    cameraDevice2 = videoDeviceDiscoverySession.devices.first
                } else {
                    cameraDevice2 = videoDeviceDiscoverySession.devices.first
                }
            }
            
            if cameraDevice2 == nil {
                Logger.shared.error("No rear/external camera found.")
                subjectCamera = .off
            } else {
                guard let cameraDevice2 else { return }
                do {
                    videoInput2 = try AVCaptureDeviceInput(device: cameraDevice2)
                } catch {
                    Logger.shared.error("Could not create rear video device input: \(error)")
                    subjectCamera = .off
                }
            }
        }
        
        if (subjectCamera == .off) && (hostCamera == .off) {
            Logger.shared.info("All cameras off.")
            return
        }

        session.beginConfiguration()
        
        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }
      
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            Logger.shared.error("MultiCam not supported on this device")
            return
        }
        
        if let videoInput {
            guard session.canAddInput(videoInput) else {
                Logger.shared.error("Could not add video device input to the session")
                session.commitConfiguration()
                return
            }
            session.addInputWithNoConnections(videoInput)
        }
        
        if let videoInput2 {
            guard session.canAddInput(videoInput2) else {
                Logger.shared.error("Could not add video device input to the session")
                session.commitConfiguration()
                return
            }
            session.addInputWithNoConnections(videoInput2)
        }

        if let cameraDevice {
            videoDataOutput = AVCaptureVideoDataOutput()
            
            guard let videoDataOutput else {
                Logger.shared.error("Could not create videoDataOutput")
                session.commitConfiguration()
                return
            }
            
            if session.canAddOutput(videoDataOutput) {
                session.addOutputWithNoConnections(videoDataOutput)
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                videoDataOutput.setSampleBufferDelegate(self, queue: cameraQueue)
            } else {
                Logger.shared.error("Could not add video data output to the session")
                session.commitConfiguration()
                return
            }
      
            if let videoInput {
                guard let videoInputPort = videoInput.ports(for: .video,
                                                            sourceDeviceType: cameraDevice.deviceType,
                                                            sourceDevicePosition: cameraDevice.position).first else {
                    Logger.shared.error("Could not find the front camera device input's video port")
                    return
                }
                
                cameraConnection = AVCaptureConnection(inputPorts: [videoInputPort], output: videoDataOutput)
                if let cameraConnection {
                    guard session.canAddConnection(cameraConnection) else {
                        Logger.shared.error("Could not add a connection to the camera video data output")
                        return
                    }
                    session.addConnection(cameraConnection)
                }
            }
        }
        
        if let cameraDevice2 {
            videoDataOutput2 = AVCaptureVideoDataOutput()
            
            guard let videoDataOutput2 else {
                Logger.shared.error("Could not create videoDataOutput")
                session.commitConfiguration()
                return
            }
            
            if session.canAddOutput(videoDataOutput2) {
                session.addOutputWithNoConnections(videoDataOutput2)
                videoDataOutput2.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                videoDataOutput2.setSampleBufferDelegate(self, queue: cameraQueue)
            } else {
                Logger.shared.error("Could not add video data output to the session")
                session.commitConfiguration()
                return
            }
            
            if let videoInput2 {
                guard let videoInputPort2 = videoInput2.ports(for: .video,
                                                              sourceDeviceType: cameraDevice2.deviceType,
                                                              sourceDevicePosition: cameraDevice2.position).first else {
                    Logger.shared.error("Could not find the front camera device input's video port")
                    return
                }
                
                camera2Connection = AVCaptureConnection(inputPorts: [videoInputPort2], output: videoDataOutput2)
                if let camera2Connection {
                    guard session.canAddConnection(camera2Connection) else {
                        Logger.shared.error("Could not add a connection to the camera video data output")
                        return
                    }
                    session.addConnection(camera2Connection)
                }
            }
        }
        
        updateRotationAngle()
        session.commitConfiguration()
       
        Logger.shared.info("SessionCommit: pressureCost: \(session.systemPressureCost) - hardwareCost: \(session.hardwareCost)")
        
        cameraQueue.async { [weak self] in
            guard let self else { return }
            session.startRunning()
            Task { [weak self] in
                guard let self else { return }
                let project = await ProjectService.shared.currentProject()
                cameraQueue.async { [weak self] in
                    guard let self else { return }
                    
                    do {
                        var fr:CMTimeScale = 24
                        if project.streamFrameRate == .fr25 {
                            fr = 25
                        } else if project.streamFrameRate == .fr30 {
                            fr = 30
                        }
                        if let cameraDevice {
                            try cameraDevice.lockForConfiguration()
                            for range in cameraDevice.activeFormat.videoSupportedFrameRateRanges {
                                if (Int32(range.minFrameRate) >= fr) && (Int32(range.maxFrameRate) <= fr) {
                                    cameraDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fr)
                                    cameraDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fr)
                                    break
                                }
                            }
                            cameraDevice.unlockForConfiguration()
                        }
                        
                        if let cameraDevice2 {
                            try cameraDevice2.lockForConfiguration()
                            for range in cameraDevice2.activeFormat.videoSupportedFrameRateRanges {
                                if (Int32(range.minFrameRate) >= fr) && (Int32(range.maxFrameRate) <= fr) {
                                    cameraDevice2.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fr)
                                    cameraDevice2.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fr)
                                    break
                                }
                            }
                            cameraDevice2.unlockForConfiguration()
                        }
                    } catch {
                        Logger.shared.error("Unable to set camera frame rate to \(project.streamFrameRate) - \(error.localizedDescription)")
                    }
                }
            }
            
            if cameraDevice == nil {
                StreamBuffer.shared.clear(uuid: "front")
            }
            
            if cameraDevice2 == nil {
                StreamBuffer.shared.clear(uuid: "rear")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                Dispatch.DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.localCameraChanged, object: nil) }
            })
        }
    }
   
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDesc:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            Logger.shared.error("captureOutput formatDesc nil")
            return
        }
        
        let mediaType = CMFormatDescriptionGetMediaType(formatDesc)
        
        if mediaType == kCMMediaType_Video {
            if connection == cameraConnection {
                MetalTool.shared.useCameraBuffer(front: sampleBuffer)
            } else if connection == camera2Connection {
                MetalTool.shared.useCameraBuffer(rear: sampleBuffer)
            } else {
                Logger.shared.error("Unmatched connection")
            }
            return
        }

        Logger.shared.error("Unhandled media type in captureOutput")
    }
}
