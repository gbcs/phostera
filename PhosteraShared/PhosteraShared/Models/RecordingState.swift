//
//  RecordingState.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 11/1/23.
//

import Foundation

public enum RecordingState: Int {
    case idle = 0
    case assetWriterStart
    case assetWriterStartWait
    case assetWriterCapturing
    case assetWriterEnding
    case movieFileCapturing
}
