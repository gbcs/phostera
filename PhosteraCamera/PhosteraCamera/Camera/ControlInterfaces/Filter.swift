//
//  DeviceFilter.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/7/23.
//

import Foundation
import AVFoundation
import UIKit

import Combine

class DeviceFilter: NSObject {
    private var device:AVCaptureDevice?
  
    
    func updateSupportedModes() {
        if (device != nil) {
        }
    }
    
  
    
    func useDevice(currentDevice:AVCaptureDevice) {
        device = currentDevice
        self.updateSupportedModes()
    }
    
    
//      
//      @IBAction private func toggleFiltering() {
//          
//          videoFilterOn = !videoFilterOn
//          let filteringEnabled = videoFilterOn
//          
//        //  let stateImage = UIImage(named: filteringEnabled ? "ColorFilterOn" : "ColorFilterOff")
//         // self.videoFilterButton.setImage(stateImage, for: .normal)
//          
//          let index = filterIndex
//          
//          if filteringEnabled {
//              let filterDescription = filterRenderers[index].description
//              updateFilterLabel(description: filterDescription)
//          }
//          
//          // Enable/disable the video filter.
//          dataOutputQueue.async {
//              if filteringEnabled {
//                  self.videoFilter = self.filterRenderers[index]
//              } else {
//                  if let filter = self.videoFilter {
//                      filter.reset()
//                  }
//                  self.videoFilter = nil
//              }
//          }
//          
//          // Enable/disable the photo filter.
//          processingQueue.async {
//              if filteringEnabled {
//                  self.photoFilter = self.photoRenderers[index]
//              } else {
//                  if let filter = self.photoFilter {
//                      filter.reset()
//                  }
//                  self.photoFilter = nil
//              }
//          }
//      }
    // MARK: - UI Utility Functions
    
    func updateDepthUIHidden() {
//        self.depthVisualizationButton.isHidden = !self.photoOutput.isDepthDataDeliverySupported
//        self.depthVisualizationButton.setImage(UIImage(named: depthVisualizationOn ? "DepthVisualOn" : "DepthVisualOff"),
//                                               for: .normal)
//        self.depthSmoothingOn = depthVisualizationOn
//        self.depthSmoothingButton.isHidden = !self.depthSmoothingOn
//        self.depthSmoothingButton.setImage(UIImage(named: depthVisualizationOn ? "DepthSmoothOn" : "DepthSmoothOff"),
//                                           for: .normal)
//        self.mixFactorNameLabel.isHidden = !depthVisualizationOn
//        self.mixFactorValueLabel.isHidden = !depthVisualizationOn
//        self.mixFactorSlider.isHidden = !depthVisualizationOn
//        self.depthDataMaxFrameRateNameLabel.isHidden = !depthVisualizationOn
//        self.depthDataMaxFrameRateValueLabel.isHidden = !depthVisualizationOn
//        self.depthDataMaxFrameRateSlider.isHidden = !depthVisualizationOn
    }
    
    func updateFilterLabel(description: String) {
//        filterLabel.text = description
//        filterLabel.alpha = 0.0
//        filterLabel.isHidden = false
//
//        UIView.animate(withDuration: 0.25, animations: {
//            self.filterLabel.alpha = 1.0
//        }) { _ in
//            UIView.animate(withDuration: 0.25, delay: 1.0, options: [], animations: {
//                self.filterLabel.alpha = 0.0
//            }, completion: { _ in })
//        }
    }
    
//    
//    @IBAction private func changeFilterSwipe(_ gesture: UISwipeGestureRecognizer) {
//        let filteringEnabled = videoFilterOn
//        if filteringEnabled {
//            if gesture.direction == .left {
//                filterIndex = (filterIndex + 1) % filterRenderers.count
//            } else if gesture.direction == .right {
//                filterIndex = (filterIndex + filterRenderers.count - 1) % filterRenderers.count
//            }
//            
//            let newIndex = filterIndex
//            let filterDescription = filterRenderers[newIndex].description
//           // updateFilterLabel(description: filterDescription)
//            
//            // Switch renderers
//            dataOutputQueue.async {
//                if let filter = self.videoFilter {
//                    filter.reset()
//                }
//                self.videoFilter = self.filterRenderers[newIndex]
//            }
//            
//            processingQueue.async {
//                if let filter = self.photoFilter {
//                    filter.reset()
//                }
//                self.photoFilter = self.photoRenderers[newIndex]
//            }
//        }
//    }
//    
    
}
