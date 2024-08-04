//
//  SettingsService.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/3/23.
//

import UIKit
import PhosteraShared

//Would use userDefaults, but Apple is asking for privacy manifest for use. This is easy, so why not. We'll do our part to avoid device fingerprinting.
//variables backed by a plist

//The object initializes to the startup defaults for the app
class SettingsData: NSObject, Codable {
    var runServer:Bool = true
    var allowNewDirectorToConnect:Bool = true
    var leftHandOperation:Bool = false
    var showCameraWhenConnectedToExternalDisplay:Bool = false
    var showUIOnExternalDisplay:Bool = false
    var needsOnboarding:Bool = true
    var serverUUID:String = ""
    var serverPublicKey:Data = Data()
    var displayName:String = ""
    var allowNetworking:Bool = false
    var lastSuccessfulModeId:String = ""
    var currentModeId:String = ""
    var settingsDataVersion:Int = 1
    var currentProjectId:String = ""
}


class SettingsService {
    static var shared = SettingsService()
    var settings:SettingsData = SettingsData()
    private let serverUUIDDefaultsKey:String = "server.uuid"
    private let serverPublicKeyDefaultsKey:String = "server.public.key"
   
    var externalDisplayView:UIView?
    var currentStorageMedia:StorageMediaModel?

    func save() {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(settings) {
            try? data.write(to: self.settingsURL())
        }
    }
    
    
    
    private func settingsURL() -> URL {
        let url = URL.applicationSupportDirectory.appendingPathComponent("settings", conformingTo: .propertyList)
        try? FileManager.default.createDirectory(at:  URL.applicationSupportDirectory, withIntermediateDirectories: true)
        return url
    }
    
    private func load() {
        if let data = try? Data(contentsOf: self.settingsURL()) {
            let decoder = PropertyListDecoder()
            if let s = try? decoder.decode(SettingsData.self, from: data) {
                settings = s
            }
        }
    }
    
    init() {
        load()
    }
}
