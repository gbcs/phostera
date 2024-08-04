//
//  TopStrip.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//

import Foundation
import UIKit
import AVFoundation
import Combine

enum TopStripPresentationMode {
    case iPad
    case iPhonePortrait
    case iPhoneLandscape
}

enum MasterCautionStatus: Int {
    case normal
    case fair
    case serious
    case critical
}

class TopStrip: UIView {
    private var isAdjustingWhitebalance:AnyCancellable?
    private var whiteBalanceMode:AnyCancellable?
    private var deviceWhiteBalanceGains:AnyCancellable?
 
    private var isAdjustingExposure:AnyCancellable?
    private var exposureMode:AnyCancellable?
    private var exposureISO:Cancellable?
    private var exposureShutter:AnyCancellable?

    private var focusMode:AnyCancellable?
    private var isAdjustingFocus:AnyCancellable?
    private var lensPosition:AnyCancellable?
    private var pressureState:AnyCancellable?
    private var batteryLevel:AnyCancellable?
    private var batteryState:AnyCancellable?
    private var diskFree:AnyCancellable?
    private var fileSize:AnyCancellable?
    private var beganRecording:AnyCancellable?
    private var endedRecording:AnyCancellable?
    private var outputFramerate:AnyCancellable?
    
    private var insets = CGSizeMake(80,0)
  
    private var isoLabel: UILabel?
    private var isoValue: UILabel?
    
    private var shutterLabel: UILabel?
    private var shutterValue: UILabel?
  
    private var wbLabel: UILabel?
    private var wbValue: UILabel?
    
    private var focusLabel: UILabel?
    private var focusValue: UILabel?
    
    private var masterCautionButton:UIImageView?
    private var batDiskFileStatus:UILabel?
    private var recordingFileStatus:UILabel?
    
    private var exposureLocked:Bool = false
    private var whiteBalanceLocked:Bool = false
    private var focusLocked:Bool = false
    
    //Only show left and right in portrait mode on iPhone
    
    private var masterCautionStatus:AVCaptureDevice.SystemPressureState.Level = .nominal
    
    private var columns:[CGFloat] = [100, 160, 248, 360]
    
    private var currentBatteryLevel:Float = UIDevice.current.batteryLevel
    private var currentDiskFree:Int64 = StatusService.shared.diskSpaceMonitor.getFreeDiskSpace() ?? 0
    private var currentFileSize:Int64 = 0
    private var currentBatteryState:UIDevice.BatteryState = UIDevice.current.batteryState

    private let numberFormatter: NumberFormatter = {
           let formatter = NumberFormatter()
           formatter.numberStyle = .decimal
           formatter.minimumFractionDigits = 2
           formatter.maximumFractionDigits = 2
           return formatter
       }()
    
    override init(frame: CGRect) {
        precondition(Thread.isMainThread)
        isoLabel = UILabel(frame: CGRectZero   )
        isoValue = UILabel(frame: CGRectZero)
        
        shutterLabel = UILabel(frame: CGRectZero)
        shutterValue = UILabel(frame: CGRectZero)
        
        wbLabel = UILabel(frame: CGRectZero)
        wbValue = UILabel(frame: CGRectZero)
        
        focusLabel = UILabel(frame: CGRectZero)
        focusValue = UILabel(frame: CGRectZero)
        
        isoLabel?.text = "ISO"
        shutterLabel?.text = "SHU"
        wbLabel?.text = "WB"
        focusLabel?.text = "FOC"
        
        //Right
        masterCautionButton = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        batDiskFileStatus = UILabel(frame: CGRectMake(columns[2] + 40, insets.height, 40, 20))
        recordingFileStatus = UILabel(frame: CGRectMake(columns[2] + 40, insets.height, 40, 20))

        masterCautionButton?.tintColor = UIColor.white
       
        super.init(frame: frame)
        if let i = masterCautionButton { i.backgroundColor = UIColor.clear; addSubview(i) }
        
        for i in [batDiskFileStatus, recordingFileStatus, isoLabel, isoValue, shutterLabel, shutterValue, wbLabel, wbValue, focusLabel, focusValue] {
            guard let i else { continue }
            i.backgroundColor = UIColor.clear
            addSubview(i)
            addTapGesture(toView: i)
            i.isUserInteractionEnabled = true
            i.textColor = UIColor.white
        }
    }
    
    func addTapGesture(toView:UIView) {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(userTapped(_:)))
        toView.addGestureRecognizer(recognizer)
    }
    
    required init?(coder: NSCoder) {
        precondition(Thread.isMainThread)
        super.init(coder: coder)
    }
    
    func setupViews(isPortraitiPhone:Bool) {
        precondition(Thread.isMainThread)
        if let i = masterCautionButton { i.frame =  CGRectMake(30, 10, 30, 30) }
        
        if let i = batDiskFileStatus { i.frame = CGRectMake(frame.size.width - 105, insets.height, 100, 20) }
        if let i = recordingFileStatus { i.frame = CGRectMake(frame.size.width - 80, insets.height + 25, 80, 20) }

        if let i = isoLabel { i.frame = CGRectMake(insets.width, insets.height, 30, 20) }
        if let i = isoValue { i.frame = CGRectMake(insets.width + 30, insets.height, 50, 20) }
        
        if let i = shutterLabel { i.frame = CGRectMake(columns[1], insets.height, 40, 20) }
        if let i = shutterValue { i.frame = CGRectMake(columns[1] + 40, insets.height, 48, 20) }
        
        if let i = wbLabel { i.frame = CGRectMake(columns[2], insets.height, 30, 20) }
        if let i = wbValue { i.frame = CGRectMake(columns[2] + 30, insets.height, 85, 20)}
        
        if let i = focusLabel { i.frame = CGRectMake(columns[3], insets.height, 40, 20) }
        if let i = focusValue { i.frame = CGRectMake(columns[3] + 40, insets.height, 60, 20) }
        
        //timeRemainingAmount?.text = "999:59"
        
        recordingFileStatus?.isHidden = true
        updateMasterCaution()
        
        if isPortraitiPhone {
            let offset:CGSize = CGSizeMake(-70, 50)
            if let i = isoLabel { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            if let i = isoValue { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            
            if let i = shutterLabel { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            if let i = shutterValue { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            
            if let i = wbLabel { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            if let i = wbValue { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            
            if let i = focusLabel { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            if let i = focusValue { i.frame.origin.y += offset.height; i.frame.origin.x += offset.width }
            
            if let i = batDiskFileStatus { i.frame.origin.y += 10; i.frame.origin.x += 5 }
            
            if let i = recordingFileStatus { i.frame.origin.y += 5; i.frame.origin.x += 5 }
      
        }
    
        updateBatDiskFileStatusLabel()
    }
    
    @objc private func userTapped(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        if (gesture.state != .recognized)  {
            return
        }

        switch(gesture.view) {
        case isoLabel:
            fallthrough
        case isoValue:
            fallthrough
        case shutterLabel:
            fallthrough
        case shutterValue:
            CamTool.shared.getCameraDeviceExposure().userToggledExposure()
        case wbLabel:
            fallthrough
        case wbValue:
            CamTool.shared.getCameraDeviceWhitebalance().userToggledWhitebalance()
        case focusLabel:
            fallthrough
        case focusValue:
            CamTool.shared.getCameraDeviceFocus().userToggledFocus()
        default:
            break
        }
    }
    
    func updateLockedStatus() {
        guard let isoLabel,
              let isoValue,
              let shutterLabel,
              let shutterValue,
              let wbLabel,
              let wbValue,
              let focusLabel,
              let focusValue
        else {
            return
        }
        
        isoLabel.backgroundColor = exposureLocked ? .accent.withAlphaComponent(0.2) : .clear
        isoValue.backgroundColor = exposureLocked ? .accent.withAlphaComponent(0.2) : .clear
        shutterLabel.backgroundColor = exposureLocked ? .accent.withAlphaComponent(0.2) : .clear
        shutterValue.backgroundColor = exposureLocked ? .accent.withAlphaComponent(0.2) : .clear
        
        wbLabel.backgroundColor = whiteBalanceLocked ? .accent.withAlphaComponent(0.2) : .clear
        wbValue.backgroundColor = whiteBalanceLocked ? .accent.withAlphaComponent(0.2) : .clear
        
        focusLabel.backgroundColor = focusLocked ? .accent.withAlphaComponent(0.2) : .clear
        focusValue.backgroundColor = focusLocked ? .accent.withAlphaComponent(0.2) : .clear
        
    }
          
    func setupSubscriptions() {
        precondition(Thread.isMainThread)
        isAdjustingExposure = (PubCentral.shared.pubIsAdjustingExposure?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            let color = value == true ? UIColor.green : UIColor.white
            isoLabel?.textColor = color
            setNeedsDisplay()
        })
        
        exposureMode = (PubCentral.shared.pubExposureMode?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            switch(value) {
            case .autoExpose:
                exposureLocked = false
            case .continuousAutoExposure:
                exposureLocked = false
            case .locked:
                exposureLocked = true
            case .custom:
                exposureLocked = true
            @unknown default:
                Logger.shared.error("Unknown case in exposureMode")
            }
            updateLockedStatus()
            setNeedsDisplay()
        })
    
        exposureISO = (PubCentral.shared.pubExposureISO?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            isoValue?.text = String(Int(value))
            setNeedsDisplay()
        })

        exposureShutter = (PubCentral.shared.pubExposureShutter?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            let frameRate = Double(value.timescale) / Double(value.value)
            shutterValue?.text = String(format: "1/%.0f", frameRate)
        })
        
        isAdjustingWhitebalance = (PubCentral.shared.pubIsAdjustingWhitebalance?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            let color = value == true ? UIColor.green : UIColor.white
            wbLabel?.textColor = color
        })
        
        whiteBalanceMode = (PubCentral.shared.pubWhiteBalanceMode?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            switch(value) {
            case .autoWhiteBalance:
                whiteBalanceLocked = true
            case.continuousAutoWhiteBalance:
                whiteBalanceLocked = false
            case .locked:
                whiteBalanceLocked = true
            @unknown default:
                Logger.shared.error("Unknown case in whiteBalanceMode")
            }
            updateLockedStatus()
            setNeedsDisplay()
        })
        
        deviceWhiteBalanceGains = (PubCentral.shared.pubDeviceWhiteBalanceGains?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            if (value.blueGain < 1.0) || (value.redGain < 1.0) || (value.greenGain < 1.0) { return }
            if let c = CamTool.shared.getCameraDevice() {
                let m = c.maxWhiteBalanceGain
                if (value.blueGain > m) || (value.redGain > m) || (value.greenGain > m) { return }
                let v = c.temperatureAndTintValues(for: value)
                wbValue?.text = String(Int(v.temperature)) + "K"
            }
        })

        focusMode = (PubCentral.shared.pubFocusMode?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            switch(value) {
            case .autoFocus:
                focusLocked = true
            case .continuousAutoFocus:
                focusLocked = false
            case .locked:
                focusLocked = true
            @unknown default:
                Logger.shared.error("Unknown case in focusMode")
            }
            updateLockedStatus()
            setNeedsDisplay()
        })
        
        isAdjustingFocus = (PubCentral.shared.pubisAdjustingFocus?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            let color = value == true ? UIColor.green : UIColor.white
            focusLabel?.textColor = color
        })
        
        lensPosition = (PubCentral.shared.publensPosition?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            focusValue?.text = String(Int(value * 100))
        })
        
        pressureState = (PubCentral.shared.pubPressureState?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            Logger.shared.info("Pressure State:\(value.debugDescription)")
            masterCautionStatus = value.level
            updateMasterCaution()
        })
        
        batteryLevel = (StatusService.shared.pubBatteryStateChange)?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            currentBatteryLevel = UIDevice.current.batteryLevel
            currentBatteryState = UIDevice.current.batteryState
            updateBatDiskFileStatusLabel()
            
            Logger.shared.info("Battery State:\(currentBatteryState.rawValue)")
        }
        
        batteryState = (StatusService.shared.pubBatteryLevelChange)?.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            currentBatteryLevel = UIDevice.current.batteryLevel
            currentBatteryState = UIDevice.current.batteryState
            updateBatDiskFileStatusLabel()
            Logger.shared.info("Battery level:\(currentBatteryLevel)")
        }
        
        diskFree = (StatusService.shared.diskSpaceMonitor.$freeSpace).receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            if value == 0 { return }
            currentDiskFree = value
            updateBatDiskFileStatusLabel()
            Logger.shared.info("Free disk space:\(value)")
        }
        
        beganRecording = (PubCentral.shared.pubCameraOperationsBeginRecording.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            if CamTool.shared.getCameraTech() != .photo  {
                //Start caring about file size monitoring.. but give time for the file to get monitored.
                currentFileSize = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: { [weak self] in
                    guard let self else { return }
                    recordingFileStatus?.isHidden = false
                    monitorFileSize()
                })
            }
        })
        
        endedRecording = (PubCentral.shared.pubCameraOperationsEndRecording.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            if CamTool.shared.getCameraTech() != .photo  {
                recordingFileStatus?.isHidden = true
            }
        })
        
        
        
    //    subModeOutputEncoder = PubCentral.shared.pubModeOutputName?.receive(on: DispatchQueue.main).sink {  [weak self] value in
    //        guard let self else { return }
    //        encoder = value
    //        updateLabels()
    //    }
    //
    //    subModeOutputSize = PubCentral.shared.pubSessionResolution?.receive(on: DispatchQueue.main).sink {  [weak self] value in
    //        guard let self else { return }
    //        frameSize = "\(Int(value.height))"
    //        updateLabels()
    //    }
    //
       
        
//        outputFramerate = PubCentral.shared.pubSessionFrameRate?.receive(on: DispatchQueue.main).sink {  [weak self] value in
//            guard let self else { return }
////            frameRate = "\(value.timescale)"
////            updateLabels()
//        }
        
    }
    
    private func monitorFileSize() {
        fileSize = StatusService.shared.fileSizeMonitor.$currentSize.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            Logger.shared.info("Recording file size: \(value)")
            let s:Float = Float(value) / Float(1000000000)
            let s2 = numberFormatter.string(from: NSNumber(value: s)) ?? "0"
            recordingFileStatus?.text = "\(s2)G"
        }
    }
    
    private func updateBatDiskFileStatusLabel() {
        precondition(Thread.isMainThread)
        currentBatteryLevel = UIDevice.current.batteryLevel
        currentBatteryState = UIDevice.current.batteryState
        
        let state = currentBatteryState == .charging ? "+" : ""
        var disk = Int(currentDiskFree / 1000000000)
        let bat = Int(currentBatteryLevel * 100)
        
        if disk > 999 { disk = 999 } //screen space limit
        
        batDiskFileStatus?.text = "\(state)\(bat) \(disk)G"
    }
    
    private func updateMasterCaution() {
        precondition(Thread.isMainThread)
        switch(masterCautionStatus) {
        case .nominal:
            masterCautionButton?.image = UIImage(systemName: "exclamationmark.triangle")
            masterCautionButton?.tintColor = UIColor.green
            masterCautionButton?.alpha = 0.2
        case .fair:
            masterCautionButton?.image = UIImage(systemName: "exclamationmark.triangle")
            masterCautionButton?.tintColor = UIColor.label
            masterCautionButton?.alpha = 0.3
        case .serious:
            masterCautionButton?.image = UIImage(systemName: "exclamationmark.triangle")
            masterCautionButton?.tintColor = UIColor.systemYellow
            masterCautionButton?.alpha = 1.0
        case .critical:
            masterCautionButton?.image = UIImage(systemName: "exclamationmark.triangle")
            masterCautionButton?.tintColor = UIColor.systemRed
            masterCautionButton?.alpha = 1.0
            masterCautionButton?.addSymbolEffect(.pulse, options: .repeating, animated: true, completion: { context in })
        case .shutdown:
            masterCautionButton?.image = UIImage(systemName: "exclamationmark.triangle")
            masterCautionButton?.tintColor = UIColor.systemRed
            masterCautionButton?.alpha = 1.0
        default:
            break
        }
    }
    
//    override func draw(_ rect: CGRect) {
//        precondition(Thread.isMainThread)
//        super.draw(rect)
//        if let context = UIGraphicsGetCurrentContext() {
//            var exposureRect:CGRect = .zero
//            var focusRect:CGRect = .zero
//            var whiteBalanceRect:CGRect = .zero
//            context.setStrokeColor(UIColor.systemRed.cgColor)
//            let offset:CGFloat = 2.0
//            context.setLineWidth(1.0)
//            if let i = isoLabel, let s = shutterValue {
//                 exposureRect = CGRectMake(i.frame.origin.x - offset,
//                                            i.frame.origin.y - offset,
//                                           s.frame.origin.x + s.frame.size.width + offset * 2.0 - i.frame.origin.x,
//                                            i.frame.size.height + offset * 2.0
//                                            )
//            }
//            
//            if let l = wbLabel, let v = wbValue {
//                whiteBalanceRect = CGRectMake(l.frame.origin.x - offset,
//                                          l.frame.origin.y - offset,
//                                          v.frame.size.width + offset * 2.0,
//                                          l.frame.size.height + offset * 2.0
//                )
//            }
//            
//            if let l = focusLabel, let v = focusValue {
//                focusRect = CGRectMake(l.frame.origin.x - offset,
//                                          l.frame.origin.y - offset,
//                                          v.frame.size.width + offset * 2.0,
//                                          l.frame.size.height + offset * 2.0
//                )
//            }
//            
//            if exposureLocked { context.stroke(exposureRect) }
//            if whiteBalanceLocked { context.stroke(whiteBalanceRect) }
//            if focusLocked {  context.stroke(focusRect) }
//        }
//    }
}
