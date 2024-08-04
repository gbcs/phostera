//
//  TransferModel.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/27/23.
//

import Foundation
import Network
import Combine
import CoreMedia
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum CameraValueType: Int, Codable {
    case string = 1
    case int
    case uint
    case uint64
    case cgFloat
    case cgSize
    case cgRect
    case cmTime
    case bool
    case whiteBalanceMode
    case whiteBalanceGains
    case cgPoint
    case float
    case focusMode
    case pressureState
    case notification
    case exposureMode
    case batteryState
    case int64
}

public class CameraStatusElement: NSObject, Identifiable, Codable {
    public let element: CameraUpdateElement
    public var value: Any
    public let valueType: CameraValueType
    
    public init(element: CameraUpdateElement, value: Any) {
        self.element = element
        self.value = value
        
        switch(value.self) {
        case is String:
            valueType = .string
        case is Int:
            valueType = .int
        case is UInt:
            valueType = .uint
        case is UInt64:
            valueType = .uint64
        case is Int64:
            valueType = .int64
        case is CGFloat:
            valueType = .cgFloat
        case is Float:
            valueType = .float
        case is CGSize:
            valueType = .cgSize
        case is CGRect:
            valueType = .cgRect
        case is CMTime:
            valueType = .cmTime
        case is Bool:
            valueType = .bool
        case is AVCaptureDevice.WhiteBalanceMode:
            valueType = .whiteBalanceMode
        case is AVCaptureDevice.ExposureMode:
            valueType = .exposureMode
        case is CGPoint:
            valueType = .cgPoint
        case is AVCaptureDevice.FocusMode:
            valueType = .focusMode
        case is NotificationCenter.Publisher.Output.Name:
            valueType = .notification
        default:
#if os(macOS)
            valueType = .int
            #else
            if value is UIDevice.BatteryState {
                valueType = .batteryState
            } else if value is AVCaptureDevice.SystemPressureState.Level {
                valueType = .pressureState
            } else if value is AVCaptureDevice.WhiteBalanceGains {
                valueType = .whiteBalanceGains
            } else {
                fatalError("Unsupported type")
            }
#endif
            break
        }
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        element = try container.decode(CameraUpdateElement.self, forKey: .element)
        valueType = try container.decode(CameraValueType.self, forKey: .valueType)
        
        switch valueType {
        case .string:
            value = try container.decode(String.self, forKey: .value)
        case .int:
            value = try container.decode(Int.self, forKey: .value)
        case .uint:
            value = try container.decode(UInt.self, forKey: .value)
        case .uint64:
            value = try container.decode(UInt64.self, forKey: .value)
        case .int64:
            value = try container.decode(Int64.self, forKey: .value)
        case .cgFloat:
            value = try container.decode(CGFloat.self, forKey: .value)
        case .float:
            value = try container.decode(Float.self, forKey: .value)
        case .cgSize:
            let sizeStr = try container.decode(String.self, forKey: .value)
            let components = sizeStr.split(separator: ",").map { CGFloat(Double($0)!) }
            value = CGSize(width: components[0], height: components[1])
        case .cgRect:
            let rectStr = try container.decode(String.self, forKey: .value)
            let components = rectStr.split(separator: ",").map { CGFloat(Double($0)!) }
            value = CGRect(x: components[0], y: components[1], width: components[2], height: components[3])
        case .cmTime:
            let timeStr = try container.decode(String.self, forKey: .value)
            let timeSeconds = Double(timeStr)!
            value = CMTime(seconds: timeSeconds, preferredTimescale: 600)
        case .bool:
            value = try container.decode(Bool.self, forKey: .value)
        case .whiteBalanceMode:
            value = -1 //This won't decode
            if let v = try? container.decode(AVCaptureDevice.WhiteBalanceMode.self.RawValue, forKey: .value) {
                if let m = AVCaptureDevice.WhiteBalanceMode(rawValue: v) {
                    value = m
                }
            }
        case .exposureMode:
            value = -1 //This won't decode
            if let v = try? container.decode(AVCaptureDevice.ExposureMode.self.RawValue, forKey: .value) {
                if let m = AVCaptureDevice.ExposureMode(rawValue: v) {
                    value = m
                }
            }
        case .whiteBalanceGains:
            value = -1 //This won't decode
#if !os(macOS)
            if let list = try? container.decode([Float].self, forKey: .value) {
                value = AVCaptureDevice.WhiteBalanceGains(redGain: list[0], greenGain: list[1], blueGain: list[2])
            }
#endif
        case .cgPoint:
            let pointStr = try container.decode(String.self, forKey: .value)
            let components = pointStr.split(separator: ",").map { CGFloat(Double($0)!) }
            value = CGPoint(x: components[0], y: components[0])
        case .focusMode:
            value = -1 //This won't decode
            if let v = try? container.decode(AVCaptureDevice.FocusMode.self.RawValue, forKey: .value) {
                if let m = AVCaptureDevice.FocusMode(rawValue: v) {
                    value = m
                }
            }
        case .pressureState:
            value = -1 //This won't decode
#if !os(macOS)
            if let v = try? container.decode(AVCaptureDevice.SystemPressureState.Level.self.RawValue, forKey: .value) {
                value = AVCaptureDevice.SystemPressureState.Level(rawValue: v)
            }
#endif
        case .batteryState:
            value = -1 //This won't decode
#if !os(macOS)
            if let v = try? container.decode(UIDevice.BatteryState.self.RawValue, forKey: .value) {
                if let m = UIDevice.BatteryState(rawValue: v) {
                    value = m
                }
            }
#endif
        case .notification:
            value = "Unknown"
            if let v = try? container.decode(String.self, forKey: .value) {
                value = v
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(element, forKey: .element)
        try container.encode(valueType, forKey: .valueType)
        
        switch valueType {
        case .string:
            try container.encode(value as! String, forKey: .value)
        case .int:
            try container.encode(value as! Int, forKey: .value)
        case .uint:
            try container.encode(value as! UInt, forKey: .value)
        case .uint64:
            try container.encode(value as! UInt64, forKey: .value)
        case .int64:
            try container.encode(value as! Int64, forKey: .value)
        case .cgFloat:
            try container.encode(value as! CGFloat, forKey: .value)
        case .float:
            try container.encode(value as! Float, forKey: .value)
        case .cgSize:
            let size = value as! CGSize
            try container.encode("\(size.width),\(size.height)", forKey: .value)
        case .cgRect:
            let rect = value as! CGRect
            try container.encode("\(rect.origin.x),\(rect.origin.y),\(rect.size.width),\(rect.size.height)", forKey: .value)
        case .cmTime:
            let time = value as! CMTime
            try container.encode("\(CMTimeGetSeconds(time))", forKey: .value)
        case .bool:
            try container.encode(value as! Bool, forKey: .value)
        case .whiteBalanceMode:
            if let m = value as? AVCaptureDevice.WhiteBalanceMode {
                try container.encode(m.rawValue, forKey: .value)
            } else {
                try container.encode(-1, forKey: .value)
            }
        case .whiteBalanceGains:
#if !os(macOS)
            if let gains = value as? AVCaptureDevice.WhiteBalanceGains {
                let gainsArray: [Float] = [gains.redGain, gains.greenGain, gains.blueGain]
                try container.encode(gainsArray, forKey: .value)
            } else {
                try container.encode([-1, -1, -1], forKey: .value)
            }
#else
            try container.encode(-1, forKey: .value)
#endif
        case .cgPoint:
            if let p = value as? CGPoint {
                try container.encode("\(p.x),\(p.y)", forKey: .value)
            }
        case .focusMode:
            if let m = value as? AVCaptureDevice.FocusMode {
                try container.encode(m.rawValue, forKey: .value)
            } else {
                try container.encode(-1, forKey: .value)
            }
        case .pressureState:
#if !os(macOS)
            if let m = value as? AVCaptureDevice.SystemPressureState.Level {
                try container.encode(m.rawValue, forKey: .value)
            } else {
                try container.encode(-1, forKey: .value)
            }
#else
            try container.encode(-1, forKey: .value)
#endif
        case .notification:
            try container.encode(value as! String, forKey: .value)
            
        case .exposureMode:
            if let m = value as? AVCaptureDevice.ExposureMode {
                try container.encode(m.rawValue, forKey: .value)
            } else {
                try container.encode(-1, forKey: .value)
            }
        case .batteryState:
#if !os(macOS)
            if let m = value as? UIDevice.BatteryState {
                try container.encode(m.rawValue, forKey: .value)
            } else {
                try container.encode(-1, forKey: .value)
            }
#else
            try container.encode(-1, forKey: .value)
#endif
            
        }
    }
    
    enum CodingKeys: CodingKey {
        case element
        case value
        case valueType
    }
}

public enum CameraUpdateElement: Int, Codable {
    case adjustingWhiteBalance = 1
    case whiteBalanceMode
    case whiteBalanceTemperature
    case whiteBalanceTint
    case adjustingExposure
    case exposureMode
    case exposurePOI
    case exposureISO
    case exposureShutter
    case focusPOI
    case focusMode
    case adjustingFocus
    case lensPosition
    case recordingState
    case horizonPreviewAngle
    case sessionResolution
    case sessionFrameRate
    case modeName
    case modeOutputName
    case pressureState
    case cameraStart
    case cameraStop
    case beginRecording
    case endRecording
    case togglePreview
    case gotoSettings
    case gotoLibrary
    case orientationChange
    case appActive
    case newMode
    case showTorchUI
    case showVizToolsUI
    case appBackground
    case appForeground
    case thermalStateChange
    case sessionRuntimeError
    case sessionWasInterrupted
    case sessionInterruptionEnded
    case flashScreen
    case batteryLevel
    case batteryState
    case diskFree
    case frontPosition
}

