//
//  ProjectRequest.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public class ProjectRequest: Codable {
    public var command:ProjectRequestCommand
    public var uuid:String
    public var sessionKey:String
    public var dataUUID:String

    public init(command:ProjectRequestCommand, uuid:String, sesionKey:String, dataUUID:String) {
        self.command = command
        self.uuid = uuid
        self.sessionKey = sesionKey
        self.dataUUID = dataUUID
    }
    
    enum CodingKeys: Int, CodingKey {
        case command = 1
        case uuid
        case sessionKey
        case dataUUID
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        command = try container.decode(ProjectRequestCommand.self, forKey: .command)
        uuid = try container.decode(String.self, forKey: .uuid)
        sessionKey = try container.decode(String.self, forKey: .sessionKey)
        dataUUID = try container.decode(String.self, forKey: .dataUUID)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(command, forKey: .command)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(sessionKey, forKey: .sessionKey)
        try container.encode(dataUUID, forKey: .dataUUID)
    }
}
