//
//  Footage.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/12/23.
//

import Foundation
import UniformTypeIdentifiers

public enum FootageServiceError: Error {
    case assetLoadFailed
}

public enum FootageType: Int, Codable {
    case photo
    case video
    case other
    
    public var description: String {
        get {
            switch self {
            case .photo:
                return "Photo"
            case .video:
                return "Video"
            case .other:
                return "Other"
            }
        }
    }
}

public class FootageModel: NSObject, Codable, ObservableObject, Identifiable{
    @Published public var url:URL
    @Published public var type:FootageType
    @Published public var name:String
    
    public func getName() -> String {
        if name.lengthOfBytes(using: .utf8) > 0 {
            return name
        }
        return url.lastPathComponent
    }
    
    public init(url: URL, type: FootageType, name:String) {
        self.url = url
        self.type = type
        self.name = name
    }
    
    public enum CodingKeys: Int, CodingKey {
        case url = 1
        case type
        case name
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(URL.self, forKey: .url)
        type = try container.decode(FootageType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
    }

}
