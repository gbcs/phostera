//
//  DirectorProjectCodec.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/13/23.
//

import Foundation
public enum DirectorProjectProresCodec:Int, Codable, CaseIterable, Equatable {
    case proRes422HQ = 0
    case proRes422
    case proRes422LT
    case proRes422Proxy

    public enum CodingKeys: Int, CodingKey {
        case proRes422HQ = 0
        case proRes422
        case proRes422LT
        case proRes422Proxy
    }
}
