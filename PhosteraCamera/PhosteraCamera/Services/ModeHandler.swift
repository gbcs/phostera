//
//  ModeHandler.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/3/23.
//

import UIKit
import PhosteraShared
import AVFoundation

//Load up a JSON for a given mode, supply data for requestors during session setup, etc.
//Inform preview type, capture mode, etc

class DefaultModes {
    var modeListFrontPhoto:[DirectorProjectCameraMode] = []
    var modeListFrontVideo:[DirectorProjectCameraMode] = []
    var modeListBackPhoto:[DirectorProjectCameraMode] = []
    var modeListBackVideo:[DirectorProjectCameraMode] = []
    
    static func saveMode(mode:DirectorProjectCameraMode) {
        let url = DefaultModes.getURLforDefaultMode(modeId: mode.uuid)
        do {
            let data = try JSONEncoder().encode(mode)
            try data.write(to: url)
        } catch {
            Logger.shared.error("Unable to save default mode: \(error.localizedDescription)")
        }
    }
    
    func loadMode(modeUUID:String) -> DirectorProjectCameraMode? {
        let url = DefaultModes.getURLforDefaultMode(modeId: modeUUID)
        if let data = FileManager.default.contents(atPath: url.path) {
            let decoder = JSONDecoder()
            if let mode = try? decoder.decode(DirectorProjectCameraMode.self, from: data) {
                return mode
            }
        }
        Logger.shared.error("Mode loading error. Unable to load main bundle mode: \(modeUUID)")
        return nil
    }
    
    static func defaultModeURL() -> URL {
        let appSupport = URL.applicationSupportDirectory
        let keyURL = appSupport.appending(path: "defaultModes", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: keyURL, withIntermediateDirectories: true, attributes: nil)
        
        if !FileManager.default.fileExists(atPath: keyURL.path) {
            Logger.shared.error("Unable to create defaultModes support directory.")
        }
        return keyURL
    }

    public static func getURLforDefaultMode(modeId:String) -> URL {
        return DefaultModes.defaultModeURL().appending(component: modeId, directoryHint: .notDirectory)
    }
    
    func loadInitialDefaultList() {
        
        let defaultUserMetadata = CurrentModeMetadata(resolution: .v1920x1080, frameRate: .fr24, codec: .proRes422HQ, colorspace: .rec709, fileNamingScheme: .scheme1, fileStorageLocation: .appStorage, recordToDisk: false)
 
        modeListFrontPhoto = [DirectorProjectCameraMode(type: .wide,
                                                        title: "Wide",
                                                        desc: "Front Camera Photo",
                                                        settings: defaultUserMetadata,
                                                        aspectRatio: CGSizeMake(4, 3),
                                                        version: 1,
                                                        provider: "",
                                                        frontCamera: true,
                                                        photoMode: true,
                                                        techType: .photo,
                                                       projectUUID: "")
        ]
        
        modeListFrontVideo = [DirectorProjectCameraMode(type: .wide,
                                                        title: "Wide Lens",
                                                        desc: "Front Camera Video",
                                                        settings: defaultUserMetadata,
                                                        aspectRatio: CGSizeMake(16, 9),
                                                        version: 1,
                                                        provider: "",
                                                        frontCamera: true,
                                                        photoMode: false,
                                                        techType: .cifilter,
                                                        projectUUID: "")
        ]
        
        modeListBackPhoto = [DirectorProjectCameraMode(type: .wide,
                                                       title: "Wide Lens",
                                                       desc: "Back Camera Photo",
                                                       settings: defaultUserMetadata,
                                                       aspectRatio: CGSizeMake(4, 3),
                                                       version: 1,
                                                       provider: "",
                                                       frontCamera: false,
                                                       photoMode: true,
                                                       techType: .photo,
                                                       projectUUID: ""),
        ]
        
        modeListBackPhoto.append(DirectorProjectCameraMode(type: .ultrawide,
                                                           title: "Ultrawide Lens",
                                                           desc: "Back Camera Photo",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(4, 3),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: true,
                                                           techType: .photo,
                                                           projectUUID: ""))
        
        modeListBackPhoto.append(DirectorProjectCameraMode(type: .telephoto,
                                                           title: "Telephoto Lens",
                                                           desc: "Back Camera Photo",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(4, 3),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: true,
                                                           techType: .photo,
                                                           projectUUID: ""))
        
        modeListBackPhoto.append(DirectorProjectCameraMode(type: .dual,
                                                           title: "Dual lens",
                                                           desc: "Back Camera Photo",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(4, 3),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: true,
                                                           techType: .photo,
                                                           projectUUID: ""))
        
        modeListBackPhoto.append(DirectorProjectCameraMode(type: .dualWide,
                                                           title: "Dual Wide lens",
                                                           desc: "Back Camera Photo",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(4, 3),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: true,
                                                           techType: .photo,
                                                           projectUUID: ""))
        
        modeListBackPhoto.append(DirectorProjectCameraMode(type: .triple,
                                                           title: "Triple Lens",
                                                           desc: "Back Camera Photo",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(4, 3),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: true,
                                                           techType: .photo,
                                                           projectUUID: ""))

        modeListBackVideo = [DirectorProjectCameraMode(type: .wide,
                                                       title: "Wide Lens",
                                                       desc: "Back Camera Video",
                                                       settings: defaultUserMetadata,
                                                       aspectRatio: CGSizeMake(16, 9),
                                                       version: 1,
                                                       provider: "",
                                                       frontCamera: false,
                                                       photoMode: false,
                                                       techType: .cifilter,
                                                       projectUUID: "")
        ]
       
        modeListBackVideo.append(DirectorProjectCameraMode(type: .ultrawide,
                                                           title: "Ultrawide Lens",
                                                           desc: "Back Camera Video",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(16, 9),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: false,
                                                           techType: .cifilter,
                                                           projectUUID: ""))
        
        modeListBackVideo.append(DirectorProjectCameraMode(type: .telephoto,
                                                           title: "Telephoto Lens",
                                                           desc: "Back Camera Video",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(16, 9),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: false,
                                                           techType: .cifilter,
                                                           projectUUID: ""))
        
        modeListBackVideo.append(DirectorProjectCameraMode(type: .dual,
                                                           title: "Dual lens",
                                                           desc: "Back Camera Video",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(16, 9),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: false,
                                                           techType: .cifilter,
                                                           projectUUID: ""))
        
        modeListBackVideo.append(DirectorProjectCameraMode(type: .dualWide,
                                                           title: "Dual Wide lens",
                                                           desc: "Back Camera Video",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(16, 9),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: false,
                                                           techType: .cifilter,
                                                           projectUUID: ""))
        
        modeListBackVideo.append(DirectorProjectCameraMode(type: .triple,
                                                           title: "Triple Lens",
                                                           desc: "Back Camera Video",
                                                           settings: defaultUserMetadata,
                                                           aspectRatio: CGSizeMake(16, 9),
                                                           version: 1,
                                                           provider: "",
                                                           frontCamera: false,
                                                           photoMode: false,
                                                           techType: .cifilter,
                                                           projectUUID: ""))
        
        let encoder = JSONEncoder()
        
       
        
        var tmpList = modeListFrontPhoto
        modeListFrontPhoto.removeAll()
        for item in tmpList {
            if ModeHandler.testMode(testMode: item) {
                modeListFrontPhoto.append(item)
            }
        }
        
        tmpList = modeListFrontVideo
        modeListFrontVideo.removeAll()
        for item in tmpList {
            if ModeHandler.testMode(testMode: item) {
                modeListFrontVideo.append(item)
            }
        }
        
        tmpList = modeListBackPhoto
        modeListBackPhoto.removeAll()
        for item in tmpList {
            if ModeHandler.testMode(testMode: item) {
                modeListBackPhoto.append(item)
            }
        }
        
        tmpList = modeListBackVideo
        modeListBackVideo.removeAll()
        for item in tmpList {
            if ModeHandler.testMode(testMode: item) {
                modeListBackVideo.append(item)
            }
        }
        
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            modeListBackVideo.append(DirectorProjectCameraMode(type: .external,
//                                                               title: "iPad External",
//                                                               desc: "Back Camera Video",
//                                                               settings: defaultUserMetadata,
//                                                               aspectRatio: CGSizeMake(16, 9),
//                                                               version: 1,
//                                                               provider: "",
//                                                               frontCamera: false,
//                                                               photoMode: false,
//                                                               techType: .cifilter,
//                                                               projectUUID: ""))
//            
//            modeListBackPhoto.append(DirectorProjectCameraMode(type: .external,
//                                                               title: "iPad External",
//                                                               desc: "Back Camera Photo",
//                                                               settings: defaultUserMetadata,
//                                                               aspectRatio: CGSizeMake(4, 3),
//                                                               version: 1,
//                                                               provider: "",
//                                                               frontCamera: false,
//                                                               photoMode: true,
//                                                               techType: .photo,
//                                                               projectUUID: ""))
//         
//        }

        for list in [modeListFrontPhoto, modeListBackPhoto, modeListFrontVideo, modeListBackVideo] {
            for mode in list {
                let url = DefaultModes.getURLforDefaultMode(modeId: mode.uuid)
                do {
                    let data = try encoder.encode(mode)
                    try data.write(to: url)
                    let f = FileManager.default.fileExists(atPath: url.path())
                    Logger.shared.info("\(url) exists: \(f)")
                } catch {
                    Logger.shared.error("Unable to handle default mode: \(error.localizedDescription)")
                }
            }
        }
        
        SettingsService.shared.settings.currentModeId = modeListBackVideo[0].uuid
        SettingsService.shared.save()
    }
    
    func loadDefaultModes() -> Int {
        let fileManager = FileManager.default
        let modesURL = DefaultModes.defaultModeURL()
        let files = try? fileManager.contentsOfDirectory(at: modesURL, includingPropertiesForKeys: nil)
        
        guard let files else { return 0 }
       
        for f in files {
            let filename = f.lastPathComponent
            if let mode = loadMode(modeUUID: filename) {
                switch(mode.frontCamera) {
                case true:
                    switch(mode.photoMode) {
                    case true:
                        modeListFrontPhoto.append(mode)
                    case false:
                        modeListFrontVideo.append(mode)
                    }
                case false:
                    switch(mode.photoMode) {
                    case true:
                        modeListBackPhoto.append(mode)
                    case false:
                        modeListBackVideo.append(mode)
                    }
                }
            }
        }
        
        return files.count
    }
    
    func updateSettingsWithDefaultMode() -> String? {
        if modeListBackVideo.count > 0 {
            let mode = modeListBackVideo[0]
            SettingsService.shared.settings.currentModeId = mode.uuid
            SettingsService.shared.save()
            return mode.uuid
        }
        return nil
    }

    init() {
        _ = DefaultModes.defaultModeURL()
        if loadDefaultModes() < 1 {
            loadInitialDefaultList()
        }
    }
}

class DirectorModes {
    var modeListFrontPhoto:[DirectorProjectCameraMode] = []
    var modeListFrontVideo:[DirectorProjectCameraMode] = []
    var modeListBackPhoto:[DirectorProjectCameraMode] = []
    var modeListBackVideo:[DirectorProjectCameraMode] = []
    
    init() {
        loadDirectorModes()
    }
    
    func cleanDirectorModes() {
        modeListFrontPhoto.removeAll()
        modeListBackVideo.removeAll()
        modeListBackPhoto.removeAll()
        modeListFrontVideo.removeAll()
    }
    
    func loadDirectorModes() {
        cleanDirectorModes()

        let directorList = DirectorService.shared.directorList()
        for director in directorList {
            let projects = DirectorProjectService.shared.projectListByDirector(director: director)
            
            for project in projects {
                let settings = CurrentModeMetadata(resolution: project.resolution,
                                                   frameRate: project.frameRate,
                                                   codec: project.codec,
                                                   colorspace: project.colorspace,
                                                   fileNamingScheme: project.fileNamingScheme,
                                                   fileStorageLocation: project.fileStorageLocation,
                                                   recordToDisk: project.recordFootageToCameraStorage)
                for mode in project.modeList {
                    mode.settings = settings
                    if !ModeHandler.testMode(testMode: mode) { continue }
                    if mode.photoMode && mode.frontCamera {
                        modeListFrontPhoto.append(mode)
                    } else if (!mode.photoMode) && (!mode.frontCamera) {
                        modeListBackVideo.append(mode)
                    } else if mode.photoMode && (!mode.frontCamera) {
                        modeListBackPhoto.append(mode)
                    } else {
                        modeListFrontVideo.append(mode)
                    }
                }
            }
        }
    }
    
}

enum ModeHandlerError: Error {
    case generallyBadMode
}

class ModeHandler {
    var directorModes:DirectorModes = DirectorModes()
    var defaultModes:DefaultModes = DefaultModes()
    
    static var shared = ModeHandler()
    
    init() {
        
    }
    
    func defaultCameraMode() -> DirectorProjectCameraMode {
        return defaultModes.modeListBackVideo[0]
    }
    
    func updateDefaultMode(mode:DirectorProjectCameraMode) {
        DefaultModes.saveMode(mode: mode)
 
        for (index, m) in defaultModes.modeListFrontPhoto.enumerated() {
            if mode.uuid == m.uuid {
                defaultModes.modeListFrontPhoto[index] = mode
                return
            }
        }
        
        for (index, m) in defaultModes.modeListFrontVideo.enumerated() {
            if mode.uuid == m.uuid {
                defaultModes.modeListFrontVideo[index] = mode
                return
            }
        }
        
        for (index, m) in defaultModes.modeListBackPhoto.enumerated() {
            if mode.uuid == m.uuid {
                defaultModes.modeListBackPhoto[index] = mode
                return
            }
        }
        
        for (index, m) in defaultModes.modeListBackVideo.enumerated() {
            if mode.uuid == m.uuid {
                defaultModes.modeListBackVideo[index] = mode
                return
            }
        }
        
        Logger.shared.error("Unable to update default mode with: \(mode.uuid)")
    }
    
    static func defaultDirectorMode(uuid:String) throws -> DirectorProjectCameraMode {
        let decoder = JSONDecoder()
        guard let filename = Bundle.main.path(forResource: uuid, ofType: "json") else {
            Logger.shared.error("Unable to find mode in main bundle: \(uuid)")
            throw ModeHandlerError.generallyBadMode
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: filename) {
            if let json = fm.contents(atPath: filename) {
                do {
                    let x = try decoder.decode(DirectorProjectCameraMode.self, from: json)
                    return x
                } catch {
                    Logger.shared.error("Unable to decode mode in main bundle: \(uuid)")
                }
            } else {
                Logger.shared.error("Unable to read mode from main bundle: \(uuid)")
            }
        }
        throw ModeHandlerError.generallyBadMode
    }
    
    func mainBundleModeWithUUID(uuid:String) -> DirectorProjectCameraMode? {
        for mode in defaultModes.modeListBackPhoto {
            if mode.uuid.compare(uuid) == .orderedSame { return mode }
        }
        for mode in defaultModes.modeListBackVideo {
            if mode.uuid.compare(uuid) == .orderedSame { return mode }
        }
        for mode in defaultModes.modeListFrontPhoto {
            if mode.uuid.compare(uuid) == .orderedSame { return mode }
        }
        for mode in defaultModes.modeListFrontVideo {
            if mode.uuid.compare(uuid) == .orderedSame { return mode }
        }
        
       return nil
    }
    
    func directorModeWithUUID(modeUUID:String) -> DirectorProjectCameraMode? {
        for mode in directorModes.modeListBackPhoto {
            if mode.uuid.compare(modeUUID) == .orderedSame { return mode }
        }
        for mode in directorModes.modeListBackVideo {
            if mode.uuid.compare(modeUUID) == .orderedSame { return mode }
        }
        for mode in directorModes.modeListFrontPhoto {
            if mode.uuid.compare(modeUUID) == .orderedSame { return mode }
        }
        for mode in directorModes.modeListFrontVideo {
            if mode.uuid.compare(modeUUID) == .orderedSame { return mode }
        }
        
        return nil
    }
    
    static func testMode(testMode:DirectorProjectCameraMode) -> Bool {
        var discovery:AVCaptureDevice.DiscoverySession?
      
        switch testMode.cameraType {
//        case .external:
//            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.external],
//                                                         mediaType: .video,
//                                                         position: .unspecified)
        case .wide:
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                         mediaType: .video,
                                                         position: testMode.frontCamera ? .front : .back)
        case .telephoto:
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTelephotoCamera],
                                                         mediaType: .video,
                                                         position: testMode.frontCamera ? .front : .back)
        case .ultrawide:
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera],
                                                         mediaType: .video,
                                                         position: testMode.frontCamera ? .front : .back)
        case .dual:
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
                                                         mediaType: .video,
                                                         position: testMode.frontCamera ? .front : .back)
        case .dualWide:
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
                                                         mediaType: .video,
                                                         position: testMode.frontCamera ? .front : .back)
        case .triple:
            discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera],
                                                         mediaType: .video,
                                                         position: testMode.frontCamera ? .front : .back)
//        case .trueDepth:
//            return false
//        case .lidarDepth:
//            return false
        }
        
        guard let discovery else { return false}
        
        return discovery.devices.count > 0 ? true : false
    }
    
    func findMode(withUUID:String) -> DirectorProjectCameraMode? {
        if let mode = directorModeWithUUID(modeUUID: withUUID) {
            return mode
        }
        
        if let mode = mainBundleModeWithUUID(uuid: withUUID) {
            return mode
        }
        return nil
    }
    
}
