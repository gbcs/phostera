//
//  PubCentral.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/21/23.
//

import UIKit
import Combine

extension NSNotification.Name {
    class Camera {
        static let updated = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.updated")
        static let online = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.online")
        static let streamChanged = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.streamchanged")
        static let selectedChanged = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.selectedchanged")
        static let cameraListChanged = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.cameraListChanged")
        static let cameraInfoViewToggle = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.cameraInfoViewToggle")
        static let onboardingComplete = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.onboardingcomplete")
        static let standbyUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.standby")
        static let standbyOpsUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.standbyops")
    }
    
    class Project {
        static let proxyMediaChunk = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.proxyMediaChunk")
        static let takeListUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.takeListUpdated")
    }
    
    static let projectListChanged = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.projectListChanged")
    static let documentPicked = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.documentPicked")
    static let screenshotReceived = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.screenshotReceived")
    
}

class PubCentral {
    static var shared = PubCentral()
    let cameraUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.updated)
    let cameraListChanged = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.cameraListChanged)
    let onlineUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.online)
    let streamChanged = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.streamChanged)
    let selectedChanged = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.selectedChanged)
    let toggleCameraInfoView = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.cameraInfoViewToggle)
    let onboardingComplete = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.onboardingComplete)
    let networkingAllowed = NotificationCenter.default.publisher(for: NSNotification.Name.networkAccessChanged)
    let pubEnterBackground = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
    let pubWillEnterForeground = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
    let projectListChanged = NotificationCenter.default.publisher(for: NSNotification.Name.projectListChanged)
    let documentPicked = NotificationCenter.default.publisher(for: NSNotification.Name.documentPicked)
    let pubScreenshotReceived = NotificationCenter.default.publisher(for: NSNotification.Name.screenshotReceived)
    let pubProxyMediaChunk = NotificationCenter.default.publisher(for: NSNotification.Name.Project.proxyMediaChunk)
    let standbyUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.standbyUpdated)
    let standbyOpsUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.standbyOpsUpdated)
    let takeListUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Project.takeListUpdated)

}
