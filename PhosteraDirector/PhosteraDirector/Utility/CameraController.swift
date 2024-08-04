//
//  CameraController.swift
//  Phostera Director
//
//  Created by Gary Barnett on 7/5/23.
//

import Foundation
import AVFoundation

class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static var shared = CameraController()
    var histogramCalculator:HistogramCalculator = HistogramCalculator()
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let sessionQueue = DispatchQueue(label: "session queue")
    private let outputQueue = DispatchQueue(label: "com.gb-cs.capture.director.camera")
    
    private let captureSession = AVCaptureSession()
    
    var videoOutput: AVCaptureVideoDataOutput!
    var cameraInput: AVCaptureDeviceInput!
    var cameraDevice: AVCaptureDevice!
    
    func isSessionRunning() -> Bool {
        return captureSession.isRunning
    }
    
    static func hasPermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    static func hasPermissionDenied() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .denied
    }
    
    static func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .cameraAccessChanged, object: nil) }
        })
    }
    
    func start() {
        if SettingsService.shared.settings.needsOnboarding { return }
        if !isSessionRunning() {
            captureSession.sessionPreset = .iFrame960x540
            captureSession.automaticallyConfiguresApplicationAudioSession = false
            guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                Logger.shared.error("Unable to access back camera!")
                return
            }
            do {
                cameraInput = try AVCaptureDeviceInput(device: backCamera)
                
                videoOutput = AVCaptureVideoDataOutput()
                
                if captureSession.canAddInput(cameraInput) {
                    captureSession.addInput(cameraInput)
                }
                
                if captureSession.canAddOutput(videoOutput) {
                    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                    captureSession.addOutput(videoOutput)
                    videoOutput.setSampleBufferDelegate(self, queue: outputQueue )
                }
                
            } catch let error  {
                Logger.shared.error("Error Unable to initialize back camera:  \(error.localizedDescription)")
            }
            
            cameraDevice = backCamera
            
            sessionQueue.async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        if isSessionRunning() {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        histogramCalculator.calculate(for: sampleBuffer)
    }

}
