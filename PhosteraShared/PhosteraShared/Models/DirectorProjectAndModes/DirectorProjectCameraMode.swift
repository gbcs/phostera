//
//  DirectorProjectCameraMode.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation

public class DirectorProjectCameraMode: NSObject, Identifiable, Codable, ObservableObject {
    @Published public var uuid:String
    @Published public var cameraType:DirectorProjectCameraType
    @Published public var techType:DirectorProjectCameraTechType
    @Published public var enabled: Bool = true
    @Published public var includeDepthData: Bool = false
    @Published public var allowLowSpecCapture: Bool = false
    @Published public var title:String
    @Published public var desc:String
    @Published public var settings:CurrentModeMetadata
    @Published public var aspectRatio:CGSize
    @Published public var provider:String
    @Published public var version:Int
    @Published public var frontCamera:Bool
    @Published public var photoMode:Bool
    @Published public var projectUUID:String

    public init(type:DirectorProjectCameraType, title:String, desc:String, settings:CurrentModeMetadata, aspectRatio:CGSize, version:Int, provider:String, frontCamera:Bool, photoMode:Bool, techType:DirectorProjectCameraTechType, projectUUID:String) {
        self.uuid = UUID().uuidString.lowercased()
        self.cameraType = type
        self.title = title
        self.desc = desc
        self.settings = settings
        self.aspectRatio = aspectRatio
        self.version = version
        self.provider = provider
        self.frontCamera = frontCamera
        self.photoMode = photoMode
        self.techType = techType
        self.projectUUID = projectUUID
    }
    
    public enum CodingKeys: Int, CodingKey {
        case uuid = 0
        case cameraType
        case enabled
        case includeDepthData
        case allowLowSpecCapture
        case title
        case desc
        case settings
        case aspectRatio
        case version
        case provider
        case frontCamera
        case photoMode
        case techType
        case projectUUID
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        cameraType = try container.decode(DirectorProjectCameraType.self, forKey: .cameraType)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        includeDepthData = try container.decode(Bool.self, forKey: .includeDepthData)
        allowLowSpecCapture = try container.decode(Bool.self, forKey: .allowLowSpecCapture)
        title = try container.decode(String.self, forKey: .title)
        desc = try container.decode(String.self, forKey: .desc)
        settings = try container.decode(CurrentModeMetadata.self, forKey: .settings)
        aspectRatio = try container.decode(CGSize.self, forKey: .aspectRatio)
        version = try container.decode(Int.self, forKey: .version)
        provider = try container.decode(String.self, forKey: .provider)
        frontCamera = try container.decode(Bool.self, forKey: .frontCamera)
        photoMode = try container.decode(Bool.self, forKey: .photoMode)
        techType = try container.decode(DirectorProjectCameraTechType.self, forKey: .techType)
        projectUUID = try container.decode(String.self, forKey: .projectUUID)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(cameraType, forKey: .cameraType)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(includeDepthData, forKey: .includeDepthData)
        try container.encode(allowLowSpecCapture, forKey: .allowLowSpecCapture)
        try container.encode(title, forKey: .title)
        try container.encode(desc, forKey: .desc)
        try container.encode(settings, forKey: .settings)
        try container.encode(aspectRatio, forKey: .aspectRatio)
        try container.encode(version, forKey: .version)
        try container.encode(provider, forKey:.provider)
        try container.encode(frontCamera, forKey: .frontCamera)
        try container.encode(photoMode, forKey: .photoMode)
        try container.encode(techType, forKey: .techType)
        try container.encode(projectUUID, forKey: .projectUUID)
    }
    
    func titleLine() -> String {
        return "\(self.title) - \(self.desc)"
    }
}
