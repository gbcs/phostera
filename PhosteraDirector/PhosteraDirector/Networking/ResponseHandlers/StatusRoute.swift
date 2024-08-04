//
//  StatusRoute.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/27/23.
//

import Foundation
import UIKit
import AVFoundation
import PhosteraShared

//Incoming only. We just get status information from camera publishers here

public class StatusRoute {
    static var shared = StatusRoute()
    
    func handleRouting(content:Data?, command:CommandMessageType, connection:CameraCommandConnector, forCamera:String) {
        
        if (content == nil) || content!.isEmpty {
            Logger.shared.error("no data in handleRouting.\(command)")
            return
        }
        
        let decoder = JSONDecoder()
        do {
            let status:[CameraStatusElement] = try decoder.decode([CameraStatusElement].self, from: content!)
            for item in status {
                switch(item.element) {
                case .adjustingWhiteBalance:
                    if let value = item.value as? Bool {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.adjustingWhiteBalance = value
                        })
                    }
                case .whiteBalanceMode:
                    if let value = item.value as? AVCaptureDevice.WhiteBalanceMode {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.whiteBalanceMode = value
                        })
                    }
                case .whiteBalanceTemperature:
                    if let value = item.value as? Float {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.whiteBalanceTemperature  = value
                        })
                    }
                case .whiteBalanceTint:
                    if let value = item.value as? Float {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.whiteBalanceTint  = value
                        })
                    }
                case .adjustingExposure:
                    if let value = item.value as? Bool {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.adjustingExposure  = value
                        })
                    }
                case .exposureMode:
                    if let value = item.value as? AVCaptureDevice.ExposureMode {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.exposureMode  = value
                        })
                    }
                case .exposurePOI:
                    if let value = item.value as? CGPoint {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.exposurePOI  = value
                        })
                    }
                case .exposureISO:
                    if let value = item.value as? Float {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.exposureISO  = value
                        })
                    }
                case .exposureShutter:
                    if let value = item.value as? CMTime {
                        Task(priority: .userInitiated, operation: {
                            await  connection.status.exposureShutter  = value
                        })
                    }
                case .focusPOI:
                    if let value = item.value as? CGPoint {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.focusPOI  = value
                        })
                    }
                case .focusMode:
                    if let value = item.value as? AVCaptureDevice.FocusMode {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.focusMode  = value
                        })
                    }
                case .adjustingFocus:
                    if let value = item.value as? Bool {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.adjustingFocus  = value
                        })
                    }
                case .lensPosition:
                    if let value = item.value as? Float {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.lensPosition  = value
                        })
                    }
                case .recordingState:
                    if let value = item.value as? Bool {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.recordingState  = value
                        })
                    }
                case .horizonPreviewAngle:
                    if let value = item.value as? CGFloat {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.horizonPreviewAngle  = value
                        })
                    }
                case .sessionResolution:
                    if let value = item.value as? CGSize {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.sessionResolution  = value
                        })
                    }
                case .sessionFrameRate:
                    if let value = item.value as? CMTime {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.sessionFrameRate  = value
                        })
                    }
                case .modeName:
                    if let value = item.value as? String {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.modeName  = value
                        })
                    }
                case .modeOutputName:
                    if let value = item.value as? String {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.modeOutputName  = value
                        })
                    }
                case .pressureState:
                    if let value = item.value as? AVCaptureDevice.SystemPressureState.Level {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.pressureState  = value
                        })
                    }
                case .cameraStart:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.cameraStart = !connection.status.cameraStart
                    })
                case .cameraStop:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.cameraStop = !connection.status.cameraStop
                    })
                case .beginRecording:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.beginRecording = !connection.status.beginRecording
                    })
                case .endRecording:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.endRecording = !connection.status.endRecording
                    })
                case .togglePreview:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.togglePreview = !connection.status.togglePreview
                    })
                case .gotoSettings:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.gotoSettings = !connection.status.gotoSettings
                    })
                case .gotoLibrary:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.gotoLibrary = !connection.status.gotoLibrary
                    })
                case .orientationChange:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.orientationChange = !connection.status.orientationChange
                    })
                case .appActive:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.appActive = !connection.status.appActive
                    })
                case .newMode:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.newMode = !connection.status.newMode
                    })
                case .showTorchUI:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.showTorchUI = !connection.status.showTorchUI
                    })
                case .showVizToolsUI:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.showVizToolsUI = !connection.status.showVizToolsUI
                    })
                case .appBackground:
                    Task(priority: .userInitiated, operation: {
                        await   connection.status.appBackground = !connection.status.appBackground
                    })
                case .appForeground:
                    Task(priority: .userInitiated, operation: {
                        await    connection.status.appForeground = !connection.status.appForeground
                    })
                case .thermalStateChange:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.thermalStateChange = !connection.status.thermalStateChange
                    })
                case .sessionRuntimeError:
                    Task(priority: .userInitiated, operation: {
                        await connection.status.sessionRuntimeError = !connection.status.sessionRuntimeError
                    })
                   
                case .sessionWasInterrupted:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.sessionWasInterrupted = !connection.status.sessionWasInterrupted
                    })
                case .sessionInterruptionEnded:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.sessionWasInterrupted = !connection.status.sessionWasInterrupted
                    })
                case .flashScreen:
                    Task(priority: .userInitiated, operation: {
                        await  connection.status.flashScreen = !connection.status.flashScreen
                    })
                case .batteryLevel:
                    if let value = item.value as? Float {
                        Task(priority: .userInitiated, operation: {
                            await   connection.status.batteryLevel = value
                        })
                    }
                case .batteryState:
                    if let value = item.value as? UIDevice.BatteryState {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.batteryState = value
                        })
                    }
                case .diskFree:
                    if let value = item.value as? Int64 {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.diskFree = value
                        })
                    }
                case .frontPosition:
                    if let value = item.value as? Bool {
                        Task(priority: .userInitiated, operation: {
                            await connection.status.frontCamera = value
                        })
                    }
                }
            }
        } catch {
            Logger.shared.error("decoder error:\(error)")
            return
        }
    }
}


