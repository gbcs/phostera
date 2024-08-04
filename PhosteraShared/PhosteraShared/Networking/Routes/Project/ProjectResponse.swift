//
//  ProjectResponse.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public enum ProjectResponseCode:Int, Codable {
    case success = 1
    case failure = 2
    
    enum CodingKeys: Int, CodingKey {
        case success = 1
        case failure = 2
    }
}

public class ProjectResponse: Codable {
    public var status:ProjectResponseCode
    public var command:ProjectRequestCommand
    public var projectUUID:String
    public var data:Data
    
    enum CodingKeys: Int, CodingKey {
        case status = 1
        case command
        case data
        case projectUUID
    }
    
    public init(status: ProjectResponseCode, command:ProjectRequestCommand, data:Data, projectUUID:String) {
        self.status = status
        self.command = command
        self.data = data
        self.projectUUID = projectUUID
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try container.decode(ProjectResponseCode.self, forKey: .status)
        command = try container.decode(ProjectRequestCommand.self, forKey: .command)
        data = try container.decode(Data.self, forKey: .data)
        projectUUID = try container.decode(String.self, forKey: .projectUUID)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(command, forKey: .command)
        try container.encode(data, forKey: .data)
        try container.encode(projectUUID, forKey: .projectUUID)
    }
}
