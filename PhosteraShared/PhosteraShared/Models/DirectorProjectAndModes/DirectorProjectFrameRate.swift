//
//  DirectorProjectFrameRate.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation

public enum DirectorProjectFrameRate:Int, Codable, CaseIterable, Equatable {
    case fr24 = 0
    case fr25
    case fr30
//    case fr48
//    case fr50
//    case fr60
    
    public enum CodingKeys: Int, CodingKey {
        case fr24 = 0
        case fr25
        case fr30
//        case fr48
//        case fr50
//        case fr60
    }
}
