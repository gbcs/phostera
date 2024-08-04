//
//  ProxyCreationStatus.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/22/23.
//

import Foundation

public class ProxyCreationStatus:NSObject, Identifiable, Decodable, Encodable {
    public var uuid:String
    public var status:Bool
    public var progress:Float
    
    public init(status:Bool, progress:Float) {
        self.uuid = UUID().uuidString.lowercased()
        self.status = status
        self.progress = progress
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(String.self, forKey: .uuid)
        status = try container.decode(Bool.self, forKey: .status)
        progress = try container.decode(Float.self, forKey: .progress)
    }
    
    public enum CodingKeys: Int, CodingKey {
        case uuid = 0
        case status
        case progress
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(status, forKey: .status)
        try container.encode(progress, forKey: .progress)
    }
}
