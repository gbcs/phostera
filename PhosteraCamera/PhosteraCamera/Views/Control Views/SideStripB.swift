//
//  TopStrip.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//

import Foundation
import UIKit
import Combine

class SideStripB: UIView {
    private var torchUI:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.off.circle"))
    private var upZoom:UIImageView = UIImageView(image: UIImage(systemName: "plus.magnifyingglass"))
    private var downZoom:UIImageView = UIImageView(image: UIImage(systemName: "minus.magnifyingglass"))
    private var overlays:UIImageView = UIImageView(image: UIImage(systemName: "bed.double"))
    private var library:UIImageView = UIImageView(image: UIImage(systemName: "list.and.film"))
    private var settings:UIImageView = UIImageView(image: UIImage(systemName: "gear"))
    
    private var firstRun:Bool = true
    
    private var subRecordingState:AnyCancellable?
    
    func getTorchButtonPosition() -> CGPoint {
        precondition(Thread.isMainThread)
        return torchUI.frame.origin
    }
    
    @objc private func userTappedZoomUp(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            do {
                try d.lockForConfiguration()
                var m = d.maxAvailableVideoZoomFactor
                if d.activeFormat.videoZoomFactorUpscaleThreshold < m { m = d.activeFormat.videoZoomFactorUpscaleThreshold}
                d.ramp(toVideoZoomFactor: m, withRate: 1.0)
                d.unlockForConfiguration()
            } catch {
                Logger.shared.error("Unable to lock cameraDevice for configuration.")
            }
        }
    }
    
    @objc private func userTappedZoomDown(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            do {
                try d.lockForConfiguration()
                let m = d.minAvailableVideoZoomFactor
                d.ramp(toVideoZoomFactor: m, withRate: 1.0)
                d.unlockForConfiguration()
            } catch {
                Logger.shared.error("Unable to lock cameraDevice for configuration.")
            }
        }
    }
    
    @objc private func userTappedtorchUI(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.showtorchUI, object: nil) }
    }
    
    @objc private func userTappedOverlays(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
      //  DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.showviztoolsui, object: nil) }
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.standby, object: nil) }
    }
    
    @objc private func userTappedLibrary(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.UtilityPages.library, object: nil) }
    }
    
    @objc private func userTappedSettings(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.UtilityPages.settings, object: nil) }
    }
    
    
    func setup() {
        precondition(Thread.isMainThread)
        if firstRun {
            for component in [torchUI, upZoom, downZoom, overlays, library, settings] {
                component.contentMode = .scaleAspectFit
                component.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
                component.isUserInteractionEnabled = true
                component.tintColor = .white
                
                addSubview(component)
            }
            
            let upZoomG = UITapGestureRecognizer(target: self, action: #selector(userTappedZoomUp(_:)))
            upZoom.addGestureRecognizer(upZoomG)
            
            let downZoomG = UITapGestureRecognizer(target: self, action: #selector(userTappedZoomDown(_:)))
            downZoom.addGestureRecognizer(downZoomG)
            
            let torchUIG = UITapGestureRecognizer(target: self, action: #selector(userTappedtorchUI(_:)))
            torchUI.addGestureRecognizer(torchUIG)
            
            let overlaysG = UITapGestureRecognizer(target: self, action: #selector(userTappedOverlays(_:)))
            overlays.addGestureRecognizer(overlaysG)
            
            let libraryG = UITapGestureRecognizer(target: self, action: #selector(userTappedLibrary(_:)))
            library.addGestureRecognizer(libraryG)
            
            let settingsG = UITapGestureRecognizer(target: self, action: #selector(userTappedSettings(_:)))
            settings.addGestureRecognizer(settingsG)
            
            firstRun = false
        }
        
        let width = 30.0
        let height = frame.size.height
        let insetY = 40.0
        if height > 450 {
            let h = height / 2 - 155
            torchUI.frame = CGRectMake(5, h, width, 60)
            upZoom.frame = CGRectMake(5, h + 60, width, 60)
            downZoom.frame = CGRectMake(5, h + 120, width, 60)
            overlays.frame = CGRectMake(5, h + 180 , width, 60)
            library.frame = CGRectMake(5, h + 240 , width, 60)
            settings.frame = CGRectMake(5, h + 300 , width, 60)
        } else {
            torchUI.frame = CGRectMake(5, insetY, width, 60)
            upZoom.frame = CGRectMake(5, insetY + 60, width, 60)
            downZoom.frame = CGRectMake(5, insetY + 120, width, 60)
            overlays.frame = CGRectMake(5, insetY + 180, width, 60)
            library.frame = CGRectMake(5, insetY + 240, width, 60)
            settings.frame = CGRectMake(5, insetY + 300, width, 60)
        }
        
        subRecordingState = PubCentral.shared.pubRecordingState?.receive(on: DispatchQueue.main).sink { [weak self] isRecording in
            guard let self else { return }
            for item in [library, settings, overlays] {
                item.isUserInteractionEnabled = !isRecording
                item.alpha = isRecording ? 0.1 : 1.0
            }
        }
    }
    
    init(frame:CGRect, zoomEnabled:Bool) {
        precondition(Thread.isMainThread)
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        precondition(Thread.isMainThread)
        super.init(coder: coder)
    }
}
