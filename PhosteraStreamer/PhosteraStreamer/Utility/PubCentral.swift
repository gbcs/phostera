//
//  PubCentral.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 8/21/23.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Combine

extension NSNotification.Name {
    
    static let cameraAccessChanged = Notification.Name("cameraAccessChanged")
    static let audioAccessChanged = Notification.Name("audioAccessChanged")
    static let networkAccessChanged = Notification.Name("networkAccessChanged")
    static let projectListChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.projectListChanged")
    static let mediaFailed = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.mediaFailed")
    static let mediaCompleted = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.mediaCompleted")
    static let mediaStarted = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.mediaStarted")
    static let restarted = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.restarted")
    static let remoteStreamChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.remoteStreamChanged")
    static let localCameraChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.localCameraChanged")
    static let documentPicked = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.documentPicked")
    static let presetChosen = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.presetChosen")
    static let presetReset = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.presetReset")
    static let mediaPicked = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.mediaPicked")
    static let mediaRemoved = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.camera.mediaRemoved")
    static let screenshotReceived = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.screenshotReceived")
    static let bandwidthReport = NSNotification.Name(rawValue: "com.gb-cs.phosteradir.bandwidthReport")
    
    class Camera {
        static let updated = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.updated")
        static let online = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.online")
        static let streamChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.streamchanged")
        static let selectedChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.selectedchanged")
        static let cameraListChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.cameralistchanged")
        static let aacCookie = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.camera.aacCookie")
       
    }
    
    class Project {
        static let directorsUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.directors.updated")
        static let projectsUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.updated")
        static let takeListUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.takeListUpdated")
        static let takeMediaInfoUpdated = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.takeMediaInfoUpdated")
        static let proxyCreationStatus = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.proxyCreationStatus")
        static let proxyMediaChunk = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.projects.proxyMediaChunk")
    }
    
    class Onboarding {
        static let complete = NSNotification.Name(rawValue: "com.gb-cs.phostera.onboarding.complete")
    }
    static let externalScreenChanged = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.exrternalscreenchanged")
    static let resetMedia = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.resetMedia")
    static let reloadFootage = NSNotification.Name(rawValue: "com.gb-cs.phosterastr.reloadFootage")
}

class PubCentral {
    static var shared = PubCentral()
    let cameraUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.updated).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let onlineUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.online).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let streamChanged = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.streamChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let selectedChanged = NotificationCenter.default.publisher(for: NSNotification.Name.Camera.selectedChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let onboardingComplete = NotificationCenter.default.publisher(for: Notification.Name.Onboarding.complete).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let networkingAccessChanged = NotificationCenter.default.publisher(for: Notification.Name.networkAccessChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let cameraListChanged = NotificationCenter.default.publisher(for: Notification.Name.Camera.cameraListChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let projectListChanged = NotificationCenter.default.publisher(for: Notification.Name.projectListChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let mediaFailed = NotificationCenter.default.publisher(for: Notification.Name.mediaFailed).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let mediaCompleted = NotificationCenter.default.publisher(for: Notification.Name.mediaCompleted).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let mediaStarted = NotificationCenter.default.publisher(for: Notification.Name.mediaStarted).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let orientationChanged = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
#if os(macOS)
    let pubEnterBackground = NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let pubWillEnterForeground = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
#else
    let pubEnterBackground = NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let pubWillEnterForeground = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
#endif
    let pubRestarted = NotificationCenter.default.publisher(for: Notification.Name.restarted).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
  
    let pubRemoteStreamChanged = NotificationCenter.default.publisher(for: NSNotification.Name.remoteStreamChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    
    let localCameraChanged = NotificationCenter.default.publisher(for: Notification.Name.localCameraChanged).throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
    let documentPicked = NotificationCenter.default.publisher(for: NSNotification.Name.documentPicked)
    let pubPresetChosen = NotificationCenter.default.publisher(for: NSNotification.Name.presetChosen)
    let pubPresetReset = NotificationCenter.default.publisher(for: NSNotification.Name.presetReset)
    let pubMediaPicked = NotificationCenter.default.publisher(for: NSNotification.Name.mediaPicked)
    let pubMediaRemoved = NotificationCenter.default.publisher(for: NSNotification.Name.mediaRemoved)
   
    let pubScreenshotReceived = NotificationCenter.default.publisher(for: NSNotification.Name.screenshotReceived)
    
    let pubDirectorsUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Project.directorsUpdated)
    let pubProjectsUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Project.projectsUpdated)
    let pubTakeListUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Project.takeListUpdated)
    let pubTakeMediaInfoUpdated = NotificationCenter.default.publisher(for: NSNotification.Name.Project.takeMediaInfoUpdated)
    let pubProxyCreationStatus = NotificationCenter.default.publisher(for: NSNotification.Name.Project.proxyCreationStatus)
    let pubProxyMediaChunk = NotificationCenter.default.publisher(for: NSNotification.Name.Project.proxyMediaChunk)
    var pubExternalDisplayChanged = NotificationCenter.default.publisher(for: NSNotification.Name.externalScreenChanged)
    var pubResetMedia = NotificationCenter.default.publisher(for: NSNotification.Name.resetMedia)
    var pubReloadFootage = NotificationCenter.default.publisher(for: NSNotification.Name.reloadFootage)
    var pubBandwidthReport = NotificationCenter.default.publisher(for: NSNotification.Name.bandwidthReport)
}
