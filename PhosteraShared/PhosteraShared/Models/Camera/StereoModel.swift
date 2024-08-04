//
//  StereoModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/5/23.
//

import Foundation
//
//  StereoModel.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/30/23.
//

import Foundation
import AVFoundation

public enum StereoLayout: String {
    case none                    = "none"
    case mono                    = "Mono"
    case frontLandscapeLeft      = "Front LandscapeLeft"
    case frontLandscapeRight     = "Front LandscapeRight"
    case frontPortrait           = "Front Portrait"
    case frontPortraitUpsideDown = "Front PortraitUpsideDown"
    case backLandscapeLeft       = "Back LandscapeLeft"
    case backLandscapeRight      = "Back LandscapeRight"
    case backPortrait            = "Back Portrait"
    case backPortraitUpsideDown  = "Back PortraitUpsideDown"
    
    public init(orientation: AVAudioSession.Orientation, stereoOrientation: AVAudioSession.StereoOrientation) {
        
        let front: AVAudioSession.Orientation = .front
        let back: AVAudioSession.Orientation = .back
        
        switch (orientation, stereoOrientation) {
            
            // Front
            case (front, .none):
                self.init(rawValue: StereoLayout.mono.rawValue)!
                
            case (front, .landscapeLeft):
                self.init(rawValue: StereoLayout.frontLandscapeLeft.rawValue)!
                
            case (front, .landscapeRight):
                self.init(rawValue: StereoLayout.frontLandscapeRight.rawValue)!
                
            case (front, .portrait):
                self.init(rawValue: StereoLayout.frontPortrait.rawValue)!
                
            case (front, .portraitUpsideDown):
                self.init(rawValue: StereoLayout.frontPortraitUpsideDown.rawValue)!
                
            // Back
            case (back, .none):
                self.init(rawValue: StereoLayout.mono.rawValue)!
                
            case (back, .landscapeLeft):
                self.init(rawValue: StereoLayout.backLandscapeLeft.rawValue)!
                
            case (back, .landscapeRight):
                self.init(rawValue: StereoLayout.backLandscapeRight.rawValue)!
                
            case (back, .portrait):
                self.init(rawValue: StereoLayout.backPortrait.rawValue)!
                
            case (back, .portraitUpsideDown):
                self.init(rawValue: StereoLayout.backPortraitUpsideDown.rawValue)!
                
            default:
                self.init(rawValue: StereoLayout.none.rawValue)!
        }
    }
}
