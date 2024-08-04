//
//  TopStrip.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//


import Foundation
import UIKit
import Combine

class TorchUI: UIView {
    private var torchUp:UIImageView = UIImageView(image: UIImage(systemName: "plus"))
    private var torchDn:UIImageView = UIImageView(image: UIImage(systemName: "minus"))
    private var torchOn:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.on.circle.fill"))
    private var torchAuto:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.on.circle"))
    private var torchOff:UIImageView = UIImageView(image: UIImage(systemName: "flashlight.slash.circle"))
    
    private var firstRun:Bool = true
    
    @objc private func userTappedTorchUp(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            if !d.isTorchAvailable {
                Logger.shared.info("Torch is not available right now.")
                return
            }
            
            if !d.isTorchModeSupported(.on) {
                Logger.shared.info("Torch is not supported right now.")
                return
            }
            
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
                return
            }
            
            var l = 1.0 - d.torchLevel
            if l < 0.1 { return }
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
            }
            
            l = d.torchLevel + 0.1
            
            do {
                try d.setTorchModeOn(level: l)
            } catch {
                Logger.shared.info("Unable to set torch level to: \(l): \(error.localizedDescription)")
            }
            
            d.unlockForConfiguration()
        }
    }
    
    @objc private func userTappedTorchDn(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            if !d.isTorchAvailable {
                Logger.shared.info("Torch is not available right now.")
                return
            }
            
            if !d.isTorchModeSupported(.on) {
                Logger.shared.info("Torch On is not supported right now.")
                return
            }
            
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
                return
            }
            
            var l = d.torchLevel
            
            if l < 0.2 { return }
            
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
            }
            
            l = d.torchLevel - 0.1
            
            do {
                try d.setTorchModeOn(level: l)
            } catch {
                Logger.shared.info("Unable to set torch level to: \(l): \(error.localizedDescription)")
            }
            
            d.unlockForConfiguration()
        }
    }
    
    @objc private func userTappedTorchOn(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            if !d.isTorchAvailable {
                Logger.shared.info("Torch is not available right now.")
                return
            }
            
            if !d.isTorchModeSupported(.on) {
                Logger.shared.info("Torch On is not supported right now.")
                return
            }
            
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
                return
            }
            
            do {
                try d.setTorchModeOn(level: 0.5)
            } catch {
                Logger.shared.info("Unable to set torch level to: \(0.5): \(error.localizedDescription)")
            }
            
            d.unlockForConfiguration()
        }
    }
    
    @objc private func userTappedTorchAuto(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            if !d.isTorchAvailable {
                Logger.shared.info("Torch is not available right now.")
                return
            }
            
            if !d.isTorchModeSupported(.auto) {
                Logger.shared.info("Torch auto is not supported right now.")
                return
            }
            
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
                return
            }
            
            d.torchMode = .auto
            d.unlockForConfiguration()
        }
    }
    
    @objc private func userTappedTorchOff(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if let d = CamTool.shared.getCameraDevice() {
            do {
                try d.lockForConfiguration()
            } catch {
                Logger.shared.info("Unable to lock cameraDevice for configuration: \(error.localizedDescription)")
                return
            }
            
            d.torchMode = .off
            d.unlockForConfiguration()
        }
    }
    
    private func setup() {
        precondition(Thread.isMainThread)
        if firstRun {
            torchUp.contentMode = .scaleAspectFit
            torchDn.contentMode = .scaleAspectFit
            torchOn.contentMode = .scaleAspectFit
            torchAuto.contentMode = .scaleAspectFit
            torchOff.contentMode = .scaleAspectFit
            
            torchUp.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
            torchDn.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
            torchOn.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
            torchAuto.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
            torchOff.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1)
            
            torchUp.isUserInteractionEnabled = true
            torchDn.isUserInteractionEnabled = true
            torchOn.isUserInteractionEnabled = true
            torchAuto.isUserInteractionEnabled = true
            torchOff.isUserInteractionEnabled = true
            
            let torchUpG = UITapGestureRecognizer(target: self, action: #selector(userTappedTorchUp(_:)))
            torchUp.addGestureRecognizer(torchUpG)
            
            let torchDnG = UITapGestureRecognizer(target: self, action: #selector(userTappedTorchDn(_:)))
            torchDn.addGestureRecognizer(torchDnG)
            
            let torchOnG = UITapGestureRecognizer(target: self, action: #selector(userTappedTorchOn(_:)))
            torchOn.addGestureRecognizer(torchOnG)
            
            let torchAutoG = UITapGestureRecognizer(target: self, action: #selector(userTappedTorchAuto(_:)))
            torchAuto.addGestureRecognizer(torchAutoG)
            
            let torchOffG = UITapGestureRecognizer(target: self, action: #selector(userTappedTorchOff(_:)))
            torchOff.addGestureRecognizer(torchOffG)
            
            addSubview(torchUp)
            addSubview(torchDn)
            addSubview(torchOn)
            addSubview(torchAuto)
            addSubview(torchOff)
            
            firstRun = false
        }
        
        let width = 240.0
        let colWidth = width / 5
        
        torchUp.frame = CGRectMake(0 + colWidth * 0, 0, 40, 40)
        torchDn.frame = CGRectMake(0 + colWidth * 1, 0, 40, 40)
        torchOn.frame = CGRectMake(0 + colWidth * 2, 0, 40, 40)
        torchAuto.frame = CGRectMake(0 + colWidth * 3, 0, 40, 40)
        torchOff.frame = CGRectMake(0 + colWidth * 4, 0, 40, 40)
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
