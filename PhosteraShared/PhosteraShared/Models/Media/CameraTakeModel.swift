//
//  TakeModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/17/23.
//

import Foundation

public class CameraTakeModel: NSObject, Identifiable, Codable {
    public var uuid:String
    public var cameraUUID:String
    public var startTime:Date
    public var endTime:Date
    public var projectUUID:String
    public var localTakeDirectory:String
    public var marked:Bool
    
    public init(projectUUID:String,
                cameraUUID: String,
                startTime: Date) {
        self.uuid = UUID().uuidString.lowercased()
        self.cameraUUID = cameraUUID
        self.startTime = startTime
        self.endTime = startTime
        self.projectUUID = projectUUID
        self.localTakeDirectory = ""
        self.marked = false
    }
    
    public enum CodingKeys: Int, CodingKey {
        case uuid = 0
        case cameraUUID
        case startTime
        case endTime
        case projectUUID
        case localTakeDirectory
        case marked
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        cameraUUID = try container.decode(String.self, forKey: .cameraUUID)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        projectUUID = try container.decode(String.self, forKey: .projectUUID)
        localTakeDirectory = try container.decode(String.self, forKey: .localTakeDirectory)
        marked = try container.decode(Bool.self, forKey: .marked)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(uuid, forKey: .uuid)
        try container.encode(cameraUUID, forKey: .cameraUUID)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(projectUUID, forKey: .projectUUID)
        try container.encode(localTakeDirectory, forKey: .localTakeDirectory)
        try container.encode(marked, forKey: .marked)
    }

}

