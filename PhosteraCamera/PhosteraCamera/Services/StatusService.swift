//
//  StatusService.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/2/23.
//

//Drive the Master caution, recording time remaining, battery and disk/recording-file-size status indicators.
//Also Audio interruption, silence, 

import Foundation
import Combine
import UIKit


class FileSizeMonitor {
    private var url: URL?
    private var previousSize: UInt64 = 0
    private var timer:Timer?
    @Published var currentSize:UInt64 = 0
    
    private var keepRunning:Bool = false
    
    @objc private func updateFileSize() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let size = getFileSize()
            if size != currentSize {
                currentSize = size
            }
        }
    }
    
    func start(fileURL:URL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            keepRunning = true
            url = fileURL
            previousSize = 1
            currentSize = 0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: { [weak self] in
                guard let self else { return }
                if !keepRunning { return }
                timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector:#selector(updateFileSize) , userInfo: nil, repeats: true)
            })
        }
    }
  
    func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            keepRunning = false
            if let timer {
                timer.invalidate()
            }
            currentSize = 0
            previousSize = 1
        }
    }
    
    private func getFileSize() -> UInt64 {
        guard let url else { return 0 }
        var fileSize: UInt64 = 0
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
        } catch {
            Logger.shared.error("Error getting file size: \(error)")
        }
        
        if fileSize == previousSize {
            Logger.shared.error("File has stopped growing.")
        }
        
        previousSize = fileSize
        return fileSize
    }
}

class DiskSpaceMonitor {
    var timer: Timer?
    let threshold: Int64 // threshold in bytes
    @Published var freeSpace:Int64 = 0
    var monitoredURL:URL = URL.documentsDirectory
    
    init(threshold: Int64) {
        self.threshold = threshold
        checkDiskSpace()
    }

    func startMonitoring(url:URL) {
        monitoredURL = url
        timer = Timer.scheduledTimer(
            timeInterval: 60.0,
            target: self,
            selector: #selector(checkDiskSpace),
            userInfo: nil,
            repeats: true
        )
        
        if let f = getFreeDiskSpace() {
            freeSpace = f
        }
    }
    
    func stopMonitoring() {
        //monitoredURL = URL.documentsDirectory
        if let f = getFreeDiskSpace() {
            freeSpace = f
        }
        timer?.invalidate()
        timer = nil
    }

    @objc func checkDiskSpace() {
        if let space = getFreeDiskSpace() {
            freeSpace = space
            if space < threshold {
                Logger.shared.info("Disk space is below threshold")
            }
        }
    }

    func getFreeDiskSpace() -> Int64? {
        do {
            let fileSystemAttributes = try FileManager.default.attributesOfFileSystem(forPath: monitoredURL.path())
            let freeSpace = (fileSystemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
            return freeSpace
        } catch {
            Logger.shared.error("Error retrieving free disk space: \(error)")
            return nil
        }
    }
}

class StatusService {
    static var shared = StatusService()

    let diskSpaceMonitor:DiskSpaceMonitor = DiskSpaceMonitor(threshold: 1000000000) //Warn at 1gb
    var fileSizeMonitor:FileSizeMonitor = FileSizeMonitor()
    
    var pubBatteryStateChange:NotificationCenter.Publisher?
    var pubBatteryLevelChange:NotificationCenter.Publisher?
    
    var audioPowerLevels:[(CGFloat, CGFloat)] = [ (0.0,0.0), (0.0,0.0) ]
    
    @Published var audioPowerLevelUpdated:Int = 0
    
    func pushPowerLevel(level:CGFloat, peak:CGFloat, left:Bool) {
        audioPowerLevels[left ? 0 : 1] = (level, peak)
        audioPowerLevelUpdated = left ? 0 : 1
    }
    
    init() {
        setupPublishers()
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    deinit {
        diskSpaceMonitor.stopMonitoring()
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
    
    private func setupPublishers() {
       pubBatteryLevelChange = NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
       pubBatteryStateChange = NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
    }

    func stopFileMonitor() {
        Logger.shared.info("stopFileMonitor")
        fileSizeMonitor.stop()
        diskSpaceMonitor.stopMonitoring()
    }
    
    func startFileMonitor(url:URL) {
        fileSizeMonitor.start(fileURL: url)
        Logger.shared.info("startMonitoringFile:\(url.path)")
        diskSpaceMonitor.startMonitoring(url: url)
    }
}

