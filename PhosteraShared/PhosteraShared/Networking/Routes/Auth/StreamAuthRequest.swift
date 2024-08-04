//
//  StreamAuthRequest.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public class StreamAuthRequest: Codable {
    public var sessionKey:String

    public init(sessionKey: String) {
        self.sessionKey = sessionKey
    }
    
    enum CodingKeys: Int, CodingKey {
        case sessionKey = 1
    }
}
