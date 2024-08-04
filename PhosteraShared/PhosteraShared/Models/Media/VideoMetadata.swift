//
//  VideoMetadata.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/5/23.
//

import Foundation
import AVFoundation

public class VideoMetadata: NSObject, Identifiable, Codable {
    public var duration: Float64
    public var resolution: CGSize
    public var frameRate:Float
    public var encoding: String
    
    public init(duration: Float64, resolution: CGSize, frameRate: Float, encoding: String) {
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.encoding = encoding
    }
    
    public static func videoMetadata(from url: URL) async -> VideoMetadata? {
        let asset = AVAsset(url: url)
        do {
            
            let length = CMTimeGetSeconds(try await asset.load(.duration))
            
            for format in try await asset.load(.availableMetadataFormats) {
                let metadata = try await asset.loadMetadata(for: format)
                print("meta:\(metadata.debugDescription)")
            }
            
            guard let videoTrack = try await asset.loadTracks(withMediaType:.video).first else {
                return nil
            }
            
            let resolution = try await videoTrack.load(.naturalSize)
            let frameRate = try await videoTrack.load(.nominalFrameRate)
            
            
            let descriptions = try await videoTrack.load(.formatDescriptions)
            
            guard let encoding = descriptions.first.flatMap({
                CMFormatDescriptionGetExtension($0 , extensionKey: kCMFormatDescriptionExtension_FormatName) as? String
            }) else {
                return nil
            }
            
            let metadata = VideoMetadata(duration: length, resolution: resolution, frameRate: frameRate, encoding: encoding)
            
            print("videoMetadata:\(length) - \(resolution) - \(frameRate) - \(encoding)")
            
            return metadata
        } catch {
            return nil
        }
    }
    
    public enum CodingKeys: Int, CodingKey {
        case duration = 0
        case resolution
        case frameRate
        case encoding
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        duration = try container.decode(Float64.self, forKey: .duration)
        resolution = try container.decode(CGSize.self, forKey: .resolution)
        frameRate = try container.decode(Float.self, forKey: .frameRate)
        encoding = try container.decode(String.self, forKey: .encoding)
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(duration, forKey: .duration)
        try container.encode(resolution, forKey: .resolution)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(encoding, forKey: .encoding)
    }
}
