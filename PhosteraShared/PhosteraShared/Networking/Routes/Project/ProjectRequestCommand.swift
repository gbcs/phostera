//
//  ProjectRequestCommand.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public enum ProjectRequestCommand: Codable {
    case directorList
    case projectList
    case takeList
    case takeMediaInfo
    case takeMediaChunk
    case makeProxyStatus
    
    enum CodingKeys: Int, CodingKey {
        case directorList
        case projectList
        case takeList
        case takeMediaInfo
        case takeMediaChunk
        case makeProxyStatus
    }
}
