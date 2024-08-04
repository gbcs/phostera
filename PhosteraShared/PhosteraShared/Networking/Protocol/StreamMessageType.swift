//
//  StreamMessageType.swift
//  Phostera Director
//
//  Created by Gary Barnett on 7/24/23.
//

import Foundation

public enum StreamMessageType: UInt32, Codable {
    case invalid = 0
    case auth
    case preview
    case audio
    case metadata
    
    enum CodingKeys: Int, CodingKey {
        case invalid = 0
        case auth
        case preview
        case audio
        case metadata
    }
}
