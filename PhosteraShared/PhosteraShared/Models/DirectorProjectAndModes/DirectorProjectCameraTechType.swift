//
//  DirectorProjectCameraTechType.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/15/23.
//

import Foundation

public enum DirectorProjectCameraTechType:Int, Codable, CaseIterable, Equatable {
    case movie = 0
    case cifilter
    case photo

    public enum CodingKeys: Int, CodingKey {
        case movie = 0
        case cifilter
        case photo
    }
}
