//
//  DirectorProjectCameraType.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation
public enum DirectorProjectCameraType:Int, Codable, CaseIterable, Equatable {
//    case external = 0
    case wide = 0
    case telephoto
    case ultrawide
    case dual
    case dualWide
    case triple
//    case trueDepth
//    case lidarDepth

    public enum CodingKeys: Int, CodingKey {
  //      case external = 0
        case wide = 0
        case telephoto
        case ultrawide
        case dual
        case dualWide
        case triple
//        case trueDepth
//        case lidarDepth
    }
}
