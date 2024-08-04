//
//  CameraUserModeInfo.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/15/23.
//

import Foundation

public class CurrentModeMetadata: NSObject, Identifiable, Codable, ObservableObject {
    @Published public var resolution:DirectorProjectResolution = .v1920x1080
    @Published public var frameRate:DirectorProjectFrameRate = .fr24
    @Published public var codec:DirectorProjectProresCodec = .proRes422HQ
    @Published public var colorspace:DirectorProjectColorspace = .rec709
    @Published public var fileNamingScheme:DirectorProjectFileNamingScheme = .scheme1
    @Published public var fileStorageLocation:DirectorProjectStorageLocation = .appStorage
    @Published public var recordToDisk:Bool = false
    
    public init(resolution: DirectorProjectResolution, frameRate: DirectorProjectFrameRate, codec: DirectorProjectProresCodec, colorspace: DirectorProjectColorspace, fileNamingScheme: DirectorProjectFileNamingScheme, fileStorageLocation: DirectorProjectStorageLocation, recordToDisk:Bool) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.colorspace = colorspace
        self.fileNamingScheme = fileNamingScheme
        self.fileStorageLocation = fileStorageLocation
        self.recordToDisk = recordToDisk
    }
    
    public enum CodingKeys: String, CodingKey {
        case resolution 
        case frameRate
        case codec
        case colorspace
        case fileNamingScheme
        case fileStorageLocation
        case recordToDisk
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try container.decode(DirectorProjectResolution.self, forKey: .resolution)
        frameRate = try container.decode(DirectorProjectFrameRate.self, forKey: .frameRate)
        codec = try container.decode(DirectorProjectProresCodec.self, forKey: .codec)
        colorspace = try container.decode(DirectorProjectColorspace.self, forKey: .colorspace)
        fileNamingScheme = try container.decode(DirectorProjectFileNamingScheme.self, forKey: .fileNamingScheme)
        fileStorageLocation = try container.decode(DirectorProjectStorageLocation.self, forKey: .fileStorageLocation)
        recordToDisk = try container.decode(Bool.self, forKey: .recordToDisk)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resolution, forKey: .resolution)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(codec, forKey: .codec)
        try container.encode(colorspace, forKey: .colorspace)
        try container.encode(fileNamingScheme, forKey: .fileNamingScheme)
        try container.encode(fileStorageLocation, forKey: .fileStorageLocation)
        try container.encode(recordToDisk, forKey: .recordToDisk)
    }
}
