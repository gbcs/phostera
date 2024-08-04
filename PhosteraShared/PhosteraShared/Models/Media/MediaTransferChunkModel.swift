//
//  MediaTransferChunkModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/22/23.
//

import Foundation

public var mediaTransferChunkModelSegmentSize:Int = 2000000

public class MediaTransferChunkModel: NSObject, Identifiable, Codable {
    public var projectUUID:String
    public var takeUUID:String
    public var file:String
    public var index:Int
    
    public init(projectUUID:String, takeUUID:String, file:String, index:Int) {
        self.projectUUID = projectUUID
        self.takeUUID = takeUUID
        self.file = file
        self.index = index
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectUUID =  try container.decode(String.self, forKey: .projectUUID)
        takeUUID = try container.decode(String.self, forKey: .takeUUID)
        file = try container.decode(String.self, forKey: .file)
        index = try container.decode(Int.self, forKey: .index)
    }
    
    public enum CodingKeys: Int, CodingKey {
        case projectUUID = 1
        case takeUUID
        case index
        case file
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(projectUUID, forKey: .projectUUID)
        try container.encode(takeUUID, forKey: .takeUUID)
        try container.encode(index, forKey: .index)
        try container.encode(file, forKey: .file)
    }
}
