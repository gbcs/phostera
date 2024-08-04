//
//  CameraResponse.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public enum CameraResponseCode:Int, Codable {
    case success = 1
    case failure = 2
    
    enum CodingKeys: Int, CodingKey {
        case success = 1
        case failure = 2
    }
}

public class CameraResponse: Codable {
    public var status:CameraResponseCode
    public var command:CameraRequestCommand
    public var data:Data
    
    enum CodingKeys: Int, CodingKey {
        case status = 1
        case command
        case data
    }
    
    public init(status: CameraResponseCode, command:CameraRequestCommand, data:Data) {
        self.status = status
        self.command = command
        self.data = data
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        status = try container.decode(CameraResponseCode.self, forKey: .status)
        command = try container.decode(CameraRequestCommand.self, forKey: .command)
        data = try container.decode(Data.self, forKey: .data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(command, forKey: .command)
        try container.encode(data, forKey: .data)
    }
}
