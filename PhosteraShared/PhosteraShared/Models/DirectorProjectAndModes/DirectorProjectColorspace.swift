//
//  DirectorProjectColorspace.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation

public enum DirectorProjectColorspace:Int, Codable, CaseIterable, Equatable {
    case rec709 = 0
    case appleLog
   // case p3d65
    
    public enum CodingKeys: Int, CodingKey {
        case rec709 = 0
        case appleLog
       // case p3d65
    }
}
