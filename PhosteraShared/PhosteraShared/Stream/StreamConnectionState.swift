//
//  StreamConnectionState.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/7/23.
//

import Foundation

public enum StreamConnectionState: Int {
    case offline = 1
    case connection
    case preroll
    case intro
    case live
    case paused
    case outro
    case failed
}
