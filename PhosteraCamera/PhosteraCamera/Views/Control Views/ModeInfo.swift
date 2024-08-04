//
//  Modeinfo.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//

import Foundation
import UIKit
import Combine

class ModeInfo: UIView {
    private var modeLabel:UILabel?
    private var cautionMessage:String = ""
    private var modeName:String = ""
    private var pressureStateCritical:Bool = false
    
    private var subModeName:AnyCancellable?
    private var subPressureState:AnyCancellable?
    private var subDroppedFrames:AnyCancellable?
    private var subRecordMode:AnyCancellable?
    
    func setup(multiLine:Bool) {
        precondition(Thread.isMainThread)
        if modeLabel == nil {
            modeLabel = UILabel(frame: CGRectMake(0, 0, frame.size.width, frame.size.height))
            if let i = modeLabel { addSubview(i)}
        }
        
        if multiLine {
            modeLabel?.lineBreakMode = .byWordWrapping
            modeLabel?.numberOfLines = 2
        } else {
            modeLabel?.lineBreakMode = .byTruncatingMiddle
            modeLabel?.numberOfLines = 1
        }
        
        modeLabel?.frame = CGRectMake(0, 0, frame.size.width, frame.size.height)
        
        modeLabel?.textColor = UIColor.white
        updateLabels()
    }
    
    private func updateLabels() {
        precondition(Thread.isMainThread)
        if cautionMessage.isEmpty {
            modeLabel?.text = modeName
        } else {
            modeLabel?.text = cautionMessage
            modeLabel?.textColor = pressureStateCritical ? UIColor.systemRed : UIColor.systemYellow
        }
    }
    
    func setupSubscribers() {
        precondition(Thread.isMainThread)
        subModeName = PubCentral.shared.pubModeName?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            modeName = value
            updateLabels()
        }
        
        subDroppedFrames = PubCentral.shared.pubDroppedFrame.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            cautionMessage = "DROPFRAME"
            updateLabels()
        }
        
        subRecordMode = PubCentral.shared.pubCameraOperationsEndRecording.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            cautionMessage = ""
            updateLabels()
        }

        subPressureState = (PubCentral.shared.pubPressureState?.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            var reason = ""
            if value.factors.contains(.systemTemperature) {
                if (value.level != .nominal) && (value.level != .fair) {
                    reason.append("SYSHOT ")
                }
                //                    else {
                //                    reason.append("SYSWARM ")
                //                }
            }
            if value.factors.contains(.depthModuleTemperature) { reason.append("DEPTHOT ") } //This is degrading depth output, so worth noting at all pressures
            if value.factors.contains(.peakPower) { reason.append("WEAKBAT") } //Plug it in to an external battery like you should already be doing.
            
            pressureStateCritical = value.level == .critical ? true : false
            
            if value.level == .shutdown {
                reason = "SYS SHUTDOWN"
            }
            
            if (value.level == .serious) || (value.level == .critical) || (value.level == .shutdown) || (value.level == .fair) {
                cautionMessage = reason
            } else {
                cautionMessage = ""
            }
            updateLabels()
            Logger.shared.info("System Pressure: \(value.level.rawValue) - \(reason)")
        })
    }
}
