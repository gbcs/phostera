//
//  CommandMessageType.swift
//  Phostera
//
//  Created by Gary Barnett on 7/22/23.
//

import Foundation

public enum CommandMessageType: UInt32, Codable {
    case invalid = 0
    case authentication
    case preview
    case status
    case transfer
    case mode
    case camera
    case script
    case footage
    case screenshot
    case project
    case standbyMode
    case standbyModeOps
    
    enum CodingKeys: Int, CodingKey {
        case invalid = 0
        case authentication
        case preview
        case status
        case transfer
        case mode
        case camera
        case script
        case footage
        case screenshot
        case project
        case standbyMode
        case standbyModeOps
    }
    
}
