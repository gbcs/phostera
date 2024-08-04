//
//  CameraRequestCommand.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public enum CameraRequestCommand: Codable {
    case startTake
    case endTake
    case zoomIn
    case zoomOut
    case requestStatusSubscription
    case toggleExposureLock
    case toggleWhiteBalanceLock
    case toggleFocusLock
    case directorMode
    case screenshot
    case changeMode
    case directorAndProjectList
    case takeList
    case takeMediaInfo
    case takeMediaChunk
    case makeProxy
    case makeProxyStatus
    case aacCookie

    enum CodingKeys: Int, CodingKey {
        case startTake = 1
        case endTake
        case zoomIn
        case zoomOut
        case requestStatusSubscription
        case toggleExposureLock
        case toggleWhiteBalanceLock
        case toggleFocusLock
        case directorMode
        case screenshot
        case changeMode
        case directorAndProjectList
        case takeList
        case takeMediaInfo
        case takeMediaChunk
        case makeProxy
        case makeProxyStatus
        case aacCookie
    }
}
