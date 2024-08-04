//
//  BaseViewController.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/7/23.
//

import UIKit
import SwiftUI
import PhosteraShared
import Combine

class BaseViewController : UIHostingController<ContentView> {
    var lockedOrientationMask: UIInterfaceOrientationMask = .all
    var streamChangedSub:AnyCancellable?
    let displayViewTag = 142
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        
//        if self.view.viewWithTag(displayViewTag) == nil {
//            if let preview = MetalTool.shared.getDisplayView() {
//                preview.tag = displayViewTag
//                self.view.addSubview(preview)
//                Logger.shared.info("Added displayView")
//            }
//        }
//    
        streamChangedSub = MetalTool.shared.streamer.$streamState.sink {  _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if  MetalTool.shared.streamer.streamState != .offline {
                    enableOrientationLock()
                } else {
                    disableOrientationLock()
                }
            }
        }
    }
}

extension BaseViewController {
    func enableOrientationLock() {
        if let orientation = self.view.window?.windowScene?.interfaceOrientation {
            switch orientation {
            case .portrait:
                lockedOrientationMask = .portrait
            case .portraitUpsideDown:
                lockedOrientationMask = .portraitUpsideDown
            case .landscapeLeft:
                lockedOrientationMask = .landscapeLeft
            case .landscapeRight:
                lockedOrientationMask = .landscapeRight
            case .unknown:
                lockedOrientationMask = .all
            @unknown default:
                lockedOrientationMask = .all
            }
        } else {
            lockedOrientationMask = .all
        }
        
        setNeedsUpdateOfSupportedInterfaceOrientations()
        Logger.shared.info("Enabled orientation lock. \(lockedOrientationMask.rawValue)")
    }
    
    func disableOrientationLock() {
        lockedOrientationMask = .all
        setNeedsUpdateOfSupportedInterfaceOrientations()
        Logger.shared.info("Disabled orientation lock.")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return lockedOrientationMask
    }
    
}
