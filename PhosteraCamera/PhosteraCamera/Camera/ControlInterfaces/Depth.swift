//
//  Depth.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/7/23.
//

import Foundation
import AVFoundation
import UIKit

import Combine

class DeviceDepth: NSObject {
    private var device:AVCaptureDevice?
    func updateSupportedModes() {
        if (device != nil) {
        }
    }

    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
        self.updateSupportedModes()
    }
    
    
//    @IBAction private func toggleDepthVisualization() {
//        depthVisualizationOn = !depthVisualizationOn
//        var depthEnabled = depthVisualizationOn
//        
//        sessionQueue.async {
//            self.session.beginConfiguration()
//            
//            if self.photoOutput.isDepthDataDeliverySupported {
//                self.photoOutput.isDepthDataDeliveryEnabled = depthEnabled
//            } else {
//                depthEnabled = false
//            }
//            
//            if let unwrappedDepthConnection = self.depthDataOutput.connection(with: .depthData) {
//                unwrappedDepthConnection.isEnabled = depthEnabled
//            }
//            
//            if depthEnabled {
//                // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
//                // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
//                self.outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [self.videoDataOutput, self.depthDataOutput])
//                
//                if let unwrappedOutputSynchronizer = self.outputSynchronizer {
//                    unwrappedOutputSynchronizer.setDelegate(self, queue: self.dataOutputQueue)
//                }
//            } else {
//                self.outputSynchronizer = nil
//            }
//            
//            self.session.commitConfiguration()
//            
//            DispatchQueue.main.async {
//                self.updateDepthUIHidden()
//            }
//            
//            self.dataOutputQueue.async {
//                if !depthEnabled {
//                    self.videoDepthConverter.reset()
//                    self.videoDepthMixer.reset()
//                    self.currentDepthPixelBuffer = nil
//                }
//                self.depthVisualizationEnabled = depthEnabled
//            }
//            
//            self.processingQueue.async {
//                if !depthEnabled {
//                    self.photoDepthMixer.reset()
//                    self.photoDepthConverter.reset()
//                }
//            }
//        }
//    }
    
//    /// - Tag: SmoothDepthData
//    @IBAction private func toggleDepthSmoothing() {
//        
//        depthSmoothingOn = !depthSmoothingOn
//        let smoothingEnabled = depthSmoothingOn
//        
//      //  let stateImage = UIImage(named: smoothingEnabled ? "DepthSmoothOn" : "DepthSmoothOff")
//      //  self.depthSmoothingButton.setImage(stateImage, for: .normal)
//        
//        sessionQueue.async {
//            self.depthDataOutput.isFilteringEnabled = smoothingEnabled
//        }
//    }
    
//    /// - Tag: VaryFrameRate
//    @IBAction private func changeDepthDataMaxFrameRate(_ sender: UISlider) {
//        let depthDataMaxFrameRate = sender.value
//        let newMinDuration = Double(1) / Double(depthDataMaxFrameRate)
//        let duration = CMTimeMaximum(videoInput.device.activeVideoMinFrameDuration, CMTimeMakeWithSeconds(newMinDuration, preferredTimescale: 1000))
//        
//      //  self.depthDataMaxFrameRateValueLabel.text = String(format: "%.1f", depthDataMaxFrameRate)
//        
//        do {
//            try self.videoInput.device.lockForConfiguration()
//            self.videoInput.device.activeDepthDataMinFrameDuration = duration
//            self.videoInput.device.unlockForConfiguration()
//        } catch {
//            Logger.shared.error("Could not lock device for configuration: \(error)")
//        }
//    }
    
//    /// - Tag: VaryMixFactor
//    @IBAction private func changeMixFactor(_ sender: UISlider) {
//        let mixFactor = sender.value
//      //  self.mixFactorValueLabel.text = String(format: "%.1f", mixFactor)
//        dataOutputQueue.async {
//            self.videoDepthMixer.mixFactor = mixFactor
//        }
//        processingQueue.async {
//            self.photoDepthMixer.mixFactor = mixFactor
//        }
//    }
}
