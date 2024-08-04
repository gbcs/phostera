//
//  DirectorProjectFileNamingScheme.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation

public enum DirectorProjectFileNamingScheme:Int, Codable, CaseIterable, Equatable {
    case scheme1 = 0
    case scheme2
    
    public enum CodingKeys: Int, CodingKey {
        case scheme1 = 0
        case scheme2
    }
}
