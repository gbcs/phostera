//
//  DirectorTakeModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/19/23.
//

import Foundation

public class DirectorTakeModel: NSObject, Identifiable, Codable {
    public var uuid:String
    public var cameraUUIDs:[String]
    public var startTime:Date
    public var endTime:Date
    public var cameraTakeUUIDs:[String:String]
    public var directorFootageReference:[String:String]
    public var projectUUID:String

    public init(projectUUID:String,
                cameraUUIDs: [String],
                startTime: Date) {
        self.uuid = UUID().uuidString.lowercased()
        self.projectUUID = projectUUID
        self.cameraUUIDs = cameraUUIDs
        self.startTime = startTime
        
        self.endTime = startTime
        self.cameraTakeUUIDs = [:]
        self.directorFootageReference = [:]
    }
    
    public enum CodingKeys: Int, CodingKey {
        case uuid = 0
        case cameraUUIDs
        case startTime
        case endTime
        case cameraTakeUUIDs
        case directorFootageReference
        case projectUUID
        case localTakeDirectory
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        uuid = try container.decode(String.self, forKey: .uuid)
        cameraUUIDs = try container.decode(Array.self, forKey: .cameraUUIDs)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        cameraTakeUUIDs = try container.decode(Dictionary.self, forKey: .cameraTakeUUIDs)
        directorFootageReference = try container.decode(Dictionary.self, forKey: .directorFootageReference)
        projectUUID = try container.decode(String.self, forKey: .projectUUID)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(uuid, forKey: .uuid)
        try container.encode(cameraUUIDs, forKey: .cameraUUIDs)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(cameraTakeUUIDs, forKey: .cameraTakeUUIDs)
        try container.encode(directorFootageReference, forKey: .directorFootageReference)
        try container.encode(projectUUID, forKey: .projectUUID)
    }

}

