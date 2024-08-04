//
//  Documents.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/19/23.
//

import Foundation

public enum StreamerDocumentType: Int {
   case pdf = 0
}

public class StreamerDocumentModel: NSObject, Identifiable, Codable, ObservableObject {
    public var id:String
    public var url:URL
    public var title:String
    public var type:StreamerDocumentType
    
    public init(url: URL, title: String, type: StreamerDocumentType) {
        self.id = UUID().uuidString.lowercased()
        self.url = url
        self.title = title
        self.type = type
    }
    
    public enum CodingKeys: Int, CodingKey {
        case id = 0
        case url
        case title
        case type
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        type = try StreamerDocumentType(rawValue: container.decode(Int.self, forKey: .type)) ?? .pdf
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
        try container.encode(type.rawValue, forKey: .type)
    }
    
}

