//
//  DirectorProjectModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/17/23.
//

import Foundation
import Combine

public class DirectorProjectModel: NSObject, Identifiable, Codable, ObservableObject {
    @Published public var uuid:String
    @Published public var title:String
    @Published public var resolution:DirectorProjectResolution = .v1920x1080
    @Published public var frameRate:DirectorProjectFrameRate = .fr24
    @Published public var codec:DirectorProjectProresCodec = .proRes422HQ
    @Published public var colorspace:DirectorProjectColorspace = .rec709
    @Published public var backupFootageOnCameraStorage:Bool = false
    @Published public var recordFootageToCameraStorage:Bool = false
    @Published public var backupProxiesOnCameraStorage:Bool = false
    @Published public var collectProxies:Bool = true
    @Published public var proxyResolution:DirectorProjectResolution = .v1920x1080
    @Published public var fileNamingScheme:DirectorProjectFileNamingScheme = .scheme1
    @Published public var proxyNamingScheme:DirectorProjectFileNamingScheme = .scheme1
    @Published public var fileStorageLocation:DirectorProjectStorageLocation = .appStorage
    @Published public var proxyStorageLocation:DirectorProjectStorageLocation = .appStorage
    @Published public var modeList:[DirectorProjectCameraMode] = []
    @Published public var modeStandby:Bool = true
    @Published public var locationInformation:Bool = false
    @Published public var directorUUID:String
    @Published public var version:Int
    @Published public var signupMessage:String
    @Published public var allowStreamers:Bool = true
    
    public init(title: String, directorUUID:String) {
        self.signupMessage = "Help me film the world around us."
        self.version = 1
        self.uuid = UUID().uuidString.lowercased()
        self.title = title
        self.directorUUID = directorUUID
        self.modeList = []
    }
    
    public enum CodingKeys: Int, CodingKey {
        case uuid = 1
        case title
        case resolution
        case frameRate
        case codec
        case colorspace
        case backupFootageOnCameraStorage
        case backupProxiesOnCameraStorage
        case collectProxies
        case proxyResolution
        case fileNamingScheme
        case proxyNamingScheme
        case fileStorageLocation
        case proxyStorageLocation
        case modeStandby
        case locationInformation
        case directorUUID
        case version
        case signupMessage
        case modeList
        case recordFootageToCameraStorage
        case allowStreamers
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        directorUUID = try container.decode(String.self, forKey: .directorUUID)
        title = try container.decode(String.self, forKey: .title)
        resolution = try container.decode(DirectorProjectResolution.self, forKey: .resolution)
        frameRate = try container.decode(DirectorProjectFrameRate.self, forKey: .frameRate)
        codec = try container.decode(DirectorProjectProresCodec.self, forKey: .codec)
        colorspace = try container.decode(DirectorProjectColorspace.self, forKey: .colorspace)
        backupFootageOnCameraStorage = try container.decode(Bool.self, forKey: .backupFootageOnCameraStorage)
        backupProxiesOnCameraStorage = try container.decode(Bool.self, forKey: .backupProxiesOnCameraStorage)
        collectProxies = try container.decode(Bool.self, forKey: .collectProxies)
        proxyResolution = try container.decode(DirectorProjectResolution.self, forKey: .proxyResolution)
        fileNamingScheme = try container.decode(DirectorProjectFileNamingScheme.self, forKey: .fileNamingScheme)
        proxyNamingScheme = try container.decode(DirectorProjectFileNamingScheme.self, forKey: .proxyNamingScheme)
        fileStorageLocation = try container.decode(DirectorProjectStorageLocation.self, forKey: .fileStorageLocation)
        proxyStorageLocation = try container.decode(DirectorProjectStorageLocation.self, forKey: .proxyStorageLocation)
        modeList = try container.decode(Array.self, forKey: .modeList)
        modeStandby = try container.decode(Bool.self, forKey: .modeStandby)
        locationInformation = try container.decode(Bool.self, forKey: .locationInformation)
        version = try container.decode(Int.self, forKey: .version)
        signupMessage = try container.decode(String.self, forKey: .signupMessage)
        recordFootageToCameraStorage = try container.decode(Bool.self, forKey: .recordFootageToCameraStorage)
        allowStreamers = try container.decode(Bool.self, forKey: .allowStreamers)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(directorUUID, forKey: .directorUUID)
        try container.encode(title, forKey: .title)
        try container.encode(resolution, forKey: .resolution)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(codec, forKey: .codec)
        try container.encode(colorspace, forKey: .colorspace)
        try container.encode(backupFootageOnCameraStorage, forKey: .backupFootageOnCameraStorage)
        try container.encode(backupProxiesOnCameraStorage, forKey: .backupProxiesOnCameraStorage)
        try container.encode(collectProxies, forKey: .collectProxies)
        try container.encode(proxyResolution, forKey: .proxyResolution)
        try container.encode(fileNamingScheme, forKey: .fileNamingScheme)
        try container.encode(proxyNamingScheme, forKey: .proxyNamingScheme)
        try container.encode(fileStorageLocation, forKey: .fileStorageLocation)
        try container.encode(proxyStorageLocation, forKey: .proxyStorageLocation)
        try container.encode(modeList, forKey: .modeList)
        try container.encode(modeStandby, forKey: .modeStandby)
        try container.encode(locationInformation, forKey: .locationInformation)
        try container.encode(version, forKey: .version)
        try container.encode(signupMessage, forKey: .signupMessage)
        try container.encode(recordFootageToCameraStorage, forKey: .recordFootageToCameraStorage)
        try container.encode(allowStreamers, forKey: .allowStreamers)
    }
}

