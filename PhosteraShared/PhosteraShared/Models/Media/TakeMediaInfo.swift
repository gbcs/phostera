//
//  TakeMediaInfo.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/22/23.
//

import Foundation

public class TakeMediaInfo: NSObject, Identifiable, Codable {
    public var uuid:String
    public var thumbnail:Data
    public var mediaSegments:[String]
    public var mediaSegmentSizes:[UInt64]
    public var mediaDuration:Float64
    public var mediaResolution:CGSize
    public var mediaFramerate:DirectorProjectFrameRate
    public var proxyExists:Bool
    public var proxySize:UInt64
    
    public init(thumbnail:Data,
                mediaSegments:[String],
                mediaSegmentSizes:[UInt64],
                mediaResolution:CGSize,
                proxyExists:Bool,
                proxySize:UInt64,
                mediaDuration:Float64,
                mediaFramerate:DirectorProjectFrameRate) {
        self.uuid = UUID().uuidString.lowercased()
        self.thumbnail = thumbnail
        self.mediaSegments = mediaSegments
        self.mediaSegmentSizes = mediaSegmentSizes
        self.mediaResolution = mediaResolution
        self.proxyExists = proxyExists
        self.proxySize = proxySize
        self.mediaDuration = mediaDuration
        self.mediaFramerate = mediaFramerate
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        uuid = try container.decode(String.self, forKey: .uuid)
        thumbnail = try container.decode(Data.self, forKey: .thumbnail)
        mediaSegments = try container.decode(Array<String>.self, forKey: .mediaSegments)
        mediaSegmentSizes = try container.decode(Array<UInt64>.self, forKey: .mediaSegmentSizes)
        mediaDuration = try container.decode(Float64.self, forKey: .mediaDuration)
        mediaResolution = try container.decode(CGSize.self, forKey: .mediaResolution)
        proxyExists = try container.decode(Bool.self, forKey: .proxyExists)
        proxySize = try container.decode(UInt64.self, forKey: .proxySize)
        mediaFramerate = try container.decode(DirectorProjectFrameRate.self, forKey: .mediaFramerate)
    }
    
    public enum CodingKeys: Int, CodingKey {
        case uuid = 0
        case thumbnail
        case mediaSegments
        case mediaSegmentSizes
        case mediaDuration
        case mediaResolution
        case proxyExists
        case proxySize
        case mediaFramerate
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(mediaSegments, forKey: .mediaSegments)
        try container.encode(mediaSegmentSizes, forKey: .mediaSegmentSizes)
        try container.encode(mediaDuration, forKey: .mediaDuration)
        try container.encode(mediaResolution, forKey: .mediaResolution)
        try container.encode(proxyExists, forKey: .proxyExists)
        try container.encode(proxySize, forKey: .proxySize)
        try container.encode(mediaFramerate, forKey: .mediaFramerate)
    }
}
