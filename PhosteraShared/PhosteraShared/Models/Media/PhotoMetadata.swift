//
//  PhotoMetadata.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/5/23.
//

import Foundation
import AVFoundation

public class PhotoMetadata: NSObject, Identifiable, Codable {
    public var resolution: CGSize
    public var encoding: String
    
    public init(resolution: CGSize, encoding: String) {
        self.resolution = resolution
        self.encoding = encoding
    }
    
    public static func photoMetadata(from url: URL) async -> PhotoMetadata? {
        if
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
            let exifData = imageProperties[kCGImagePropertyExifDictionary as String] as? [String: Any],
            let width = imageProperties[kCGImagePropertyPixelWidth as String] as? CGFloat,
            let height = imageProperties[kCGImagePropertyPixelHeight as String] as? CGFloat {
            
            let metadata = PhotoMetadata(resolution: .zero, encoding: "")
            metadata.resolution = CGSizeMake(width, height)
            metadata.encoding = url.pathExtension.lowercased()
            print(exifData) // Outputs the EXIF data
            return metadata
        }
        
        return nil
    }
    
    public enum CodingKeys: Int, CodingKey {
        case resolution = 0
        case encoding
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        resolution = try container.decode(CGSize.self, forKey: .resolution)
        encoding = try container.decode(String.self, forKey: .encoding)
        
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(resolution, forKey: .resolution)
        try container.encode(encoding, forKey: .encoding)
    }
}
