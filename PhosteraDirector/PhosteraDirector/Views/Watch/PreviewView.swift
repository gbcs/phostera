//
//  PreviewView.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/24/23.
//

import Foundation
#if os(macOS)
import Cocoa
import AVFoundation
import PhosteraShared

class PreviewView: NSView {
    var camera:CameraModel
    var avlayer = AVSampleBufferDisplayLayer()
    
    func updateCameraLayer() {
        self.avlayer.videoGravity = .resizeAspect
        let x = self.frame.origin.x;
        let y = self.frame.origin.y;
        let w = self.frame.size.width;
        let h = self.frame.size.height;
        var transform = CATransform3DIdentity
        self.avlayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)
//        self.avlayer.frame = CGRectMake(x, y, h, w);
//        transform = CATransform3DTranslate(transform, (w - h) / 2, (h - w) / 2, 0);
//        transform = CATransform3DRotate(transform, -Double.pi/2, 0, 0, 1);
//        self.avlayer.transform = transform
    }
    init(camera: CameraModel) {
        self.camera = camera
        super.init(frame: .zero)
        avlayer.frame = self.frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute:{
            self.layer?.addSublayer(self.avlayer)
            self.updateCameraLayer()
            NetworkHandler.shared.connectCameraStreamChannel(uuid: camera.uuid, avlayer: self.avlayer)
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#else
import UIKit
import SwiftUI
import AVFoundation
import PhosteraShared

class PreviewView: UIView {
    var camera:CameraModel
    var avlayer = AVSampleBufferDisplayLayer()
    
    func updateCameraLayer() {
        self.avlayer.videoGravity = .resizeAspect
        let x = self.frame.origin.x;
        let y = self.frame.origin.y;
        let w = self.frame.size.width;
        let h = self.frame.size.height;
        self.avlayer.frame = self.frame
                                        
 
        var transform = CATransform3DIdentity
        if UIDevice.current.orientation == .landscapeLeft {
        
//            transform = CATransform3DTranslate(transform, (w - h) / 2, (h - w) / 2, 0);
//            transform = CATransform3DRotate(transform, -Double.pi/2, 0, 0, 1);
        } else if UIDevice.current.orientation == .landscapeRight {
            self.avlayer.frame = CGRectMake(x, y, h, w);
            transform = CATransform3DTranslate(transform, (w - h) / 2, (h - w) / 2, 0);
            transform = CATransform3DRotate(transform, Double.pi/2, 0, 0, 1);
        } else if UIDevice.current.orientation == .portraitUpsideDown {
            self.avlayer.frame = CGRectMake(x, y, h, w);
            transform = CATransform3DTranslate(transform, (w - h) / 2, (h - w) / 2, 0);
            transform = CATransform3DRotate(transform, Double.pi/2, 0, 0, 1);
        } else {
            self.avlayer.frame = self.bounds
        }
        self.avlayer.transform = transform
 
       
    }
    init(camera: CameraModel) {
        self.camera = camera
        super.init(frame: .zero)
        self.backgroundColor = UIColor.purple
        avlayer.frame = self.frame
        avlayer.videoGravity = .resizeAspect
        avlayer.backgroundColor = UIColor.green.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute:{
            self.layer.addSublayer(self.avlayer)
            self.updateCameraLayer()
            Task {
               await NetworkHandler.shared.connectCameraVideoStreamChannel(uuid: camera.uuid)
            }
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
