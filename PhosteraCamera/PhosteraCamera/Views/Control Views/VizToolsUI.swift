//
//  VizToolsUI.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 8/14/23.
//

import Foundation
import UIKit
import Combine

// WIP

class VizToolsUI: UIView {
    private var torchUp:UIImageView = UIImageView(image: UIImage(systemName: "mountain.2.circle"))
    private var torchDn:UIImageView = UIImageView(image: UIImage(systemName: "gearshift.layout.sixspeed"))
    private var torchOn:UIImageView = UIImageView(image: UIImage(systemName: "gearshift.layout.sixspeed"))
    private var torchAuto:UIImageView = UIImageView(image: UIImage(systemName: "gearshift.layout.sixspeed"))
    private var torchOff:UIImageView = UIImageView(image: UIImage(systemName: "gearshift.layout.sixspeed"))
    
    private var firstRun:Bool = true
    
    
    @objc private func userTappedTorchUp(_ gesture: UITapGestureRecognizer) {
        
    }
    
    @objc private func userTappedTorchDn(_ gesture: UITapGestureRecognizer) {
        
    }
    
    @objc private func userTappedTorchOn(_ gesture: UITapGestureRecognizer) {
        
    }
    
    @objc private func userTappedTorchAuto(_ gesture: UITapGestureRecognizer) {
        
    }
    
    @objc private func userTappedTorchOff(_ gesture: UITapGestureRecognizer) {
        
    }
    
    private func setup() {
        precondition(Thread.isMainThread)
        if firstRun {
            addSubview(torchUp)
            addSubview(torchDn)
            addSubview(torchOn)
            addSubview(torchAuto)
            addSubview(torchOff)
            
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
            
            let torchUpG = UILongPressGestureRecognizer(target: self, action: #selector(userTappedTorchUp(_:)))
            torchUpG.minimumPressDuration = 0.05
            torchUp.addGestureRecognizer(torchUpG)
            
            let torchDnG = UILongPressGestureRecognizer(target: self, action: #selector(userTappedTorchUp(_:)))
            torchDnG.minimumPressDuration = 0.05
            torchDn.addGestureRecognizer(torchDnG)
            
            let torchOnG = UILongPressGestureRecognizer(target: self, action: #selector(userTappedTorchUp(_:)))
            torchOnG.minimumPressDuration = 0.05
            torchOn.addGestureRecognizer(torchOnG)
            
            let torchAutoG = UILongPressGestureRecognizer(target: self, action: #selector(userTappedTorchUp(_:)))
            torchAutoG.minimumPressDuration = 0.05
            torchAuto.addGestureRecognizer(torchAutoG)
            
            let torchOffG = UILongPressGestureRecognizer(target: self, action: #selector(userTappedTorchUp(_:)))
            torchOffG.minimumPressDuration = 0.05
            torchOff.addGestureRecognizer(torchOffG)
            
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
