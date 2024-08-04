//
//  FlashUI.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/20/23.
//

import Foundation

import Foundation
import UIKit
import Combine

class FlashUI: UIView {
    private var flashOn:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.on.circle.fill"))
    private var flashAuto:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.on.circle"))
    private var flashOff:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.slash.circle"))
    
    private var firstRun:Bool = true
    
    @objc private func userTappedFlashOn(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            if !d.isFlashAvailable {
                Logger.shared.info("Flash is not available right now.")
                return
            }
            
            let o = CamTool.shared.getPhotoOutput()
            if !o.supportedFlashModes.contains(.on) {
                Logger.shared.info("Flash On is not supported right now.")
                return
            }
            
            CamTool.shared.photoFlashRequest = .on
        }
    }
    
    @objc private func userTappedFlashAuto(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            if !d.isFlashAvailable {
                Logger.shared.info("Flash is not available right now.")
                return
            }
            
            let o = CamTool.shared.getPhotoOutput()
            if !o.supportedFlashModes.contains(.auto) {
                Logger.shared.info("Flash Auto is not supported right now.")
                return
            }
            
            CamTool.shared.photoFlashRequest = .auto
        }
    }
    
    @objc private func userTappedFlashOff(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        CamTool.shared.photoFlashRequest = .off
    }
    
    private func setup() {
        precondition(Thread.isMainThread)
        if firstRun {
            for item in [flashOn, flashOff, flashAuto] {
                item.contentMode = .scaleAspectFit
                item.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
                item.isUserInteractionEnabled = true
                addSubview(item)
            }
            
            let flashOnG = UITapGestureRecognizer(target: self, action: #selector(userTappedFlashOn(_:)))
            flashOn.addGestureRecognizer(flashOnG)
            
            let flashAutoG = UITapGestureRecognizer(target: self, action: #selector(userTappedFlashAuto(_:)))
            flashAuto.addGestureRecognizer(flashAutoG)
            
            let flashOffG = UITapGestureRecognizer(target: self, action: #selector(userTappedFlashOff(_:)))
            flashOff.addGestureRecognizer(flashOffG)
            
            firstRun = false
        }
        
        let width = 240.0
        let colWidth = width / 5
        
        flashOn.frame = CGRectMake(0 + colWidth * 2, 0, 40, 40)
        flashAuto.frame = CGRectMake(0 + colWidth * 3, 0, 40, 40)
        flashOff.frame = CGRectMake(0 + colWidth * 4, 0, 40, 40)
    }
    
    override init(frame:CGRect) {
        precondition(Thread.isMainThread)
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        precondition(Thread.isMainThread)
        super.init(coder: coder)
    }
}
