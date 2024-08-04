//
//  DirectorProjectResolution.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation
public enum DirectorProjectResolution:Int, Codable, CaseIterable, Equatable {
 //   case v1280x720 = 0
    case v1920x1080 = 1
    case v3840x2160 = 2
    
    public enum CodingKeys: Int, CodingKey {
 //       case v1280x720 = 0
        case v1920x1080 = 1
        case v3840x2160 = 2
    }
}


