//
//  FootageFileItem.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/5/23.
//

import Foundation

public class FootageFileItem: NSObject, Identifiable, Codable {
    public var url: String
    public var size: UInt64
    public var creationDate:Date
    public var thumbnailURL: Bool
    public var videoMetadata: VideoMetadata?
    public var photoMetadata: PhotoMetadata?
    
    public init(url: String, size: UInt64, creationDate: Date, thumbnailURL: Bool) {
        self.url = url
        self.size = size
        self.creationDate = creationDate
        self.thumbnailURL = thumbnailURL
    }
    
    public enum CodingKeys: Int, CodingKey {
        case url = 0
        case size
        case creationDate
        case thumbnailURL
        case videoMetadata
        case  photoMetadata
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        url = try container.decode(String.self, forKey: .url)
        size = try container.decode(UInt64.self, forKey: .size)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        thumbnailURL = try container.decode(Bool.self, forKey: .thumbnailURL)
        videoMetadata = try container.decode(VideoMetadata.self, forKey: .videoMetadata)
        photoMetadata = try container.decode(PhotoMetadata.self, forKey: .photoMetadata)
       
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(url, forKey: .url)
        try container.encode(size, forKey: .size)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(videoMetadata, forKey: .videoMetadata)
        try container.encode(photoMetadata, forKey: .photoMetadata)
    }
}
