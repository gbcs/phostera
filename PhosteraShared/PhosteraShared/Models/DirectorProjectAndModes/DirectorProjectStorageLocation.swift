//
//  DirectorProjectStorageLocation.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation

public enum DirectorProjectStorageLocation:Int, Codable, CaseIterable, Equatable {
    case appStorage = 0
    case photoLibrary
    case externalStorage
    
    public enum CodingKeys: Int, CodingKey {
        case appStorage = 0
        case photoLibrary
        case externalStorage
    }
}
