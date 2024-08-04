//
//  StorageMediaModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/4/23.
//

import Foundation

public class StorageMediaModel: NSObject, Codable {
    public var storageId:String = UUID().uuidString.lowercased()
    public var currentURL:URL
    public var bookmark:Data?
    public var volumeDescription:String = ""
    public var storageLocation:String = ""
    public var physicalLabel:String = ""
    public var owningUUID:String = ""
    public var readOnly:Bool
    public let volumeName:String
    public let totalCapacity:Int
    public let availableCapacity:Int
    
    public init(currentURL: URL, owningUUID: String, readOnly: Bool, volumeName: String, totalCapacity: Int, availableCapacity: Int, bookmark:Data) {
        self.currentURL = currentURL
        self.owningUUID = owningUUID
        self.readOnly = readOnly
        self.volumeName = volumeName
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.bookmark = bookmark
    }
    
    public enum CodingKeys: Int, CodingKey {
        case storageId = 1
        case currentURL
        case bookmark
        case volumeDescription
        case storageLocation
        case physicalLabel
        case owningUUID
        case readOnly
        case volumeName
        case totalCapacity
        case availableCapacity
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        storageId = try container.decode(String.self, forKey: .storageId)
        currentURL = try container.decode(URL.self, forKey: .currentURL)
        bookmark = try container.decode(Data.self, forKey: .bookmark)
        volumeDescription = try container.decode(String.self, forKey: .volumeDescription)
        storageLocation = try container.decode(String.self, forKey: .storageLocation)
        physicalLabel = try container.decode(String.self, forKey: .physicalLabel)
        owningUUID = try container.decode(String.self, forKey: .owningUUID)
        readOnly = try container.decode(Bool.self, forKey: .readOnly)
        volumeName = try container.decode(String.self, forKey: .volumeName)
        totalCapacity = try container.decode(Int.self, forKey: .totalCapacity)
        availableCapacity = try container.decode(Int.self, forKey: .availableCapacity)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(storageId, forKey: .storageId)
        try container.encode(currentURL, forKey: .currentURL)
        try container.encode(bookmark, forKey: .bookmark)
        try container.encode(volumeDescription , forKey: .volumeDescription)
        try container.encode(storageLocation, forKey: .storageLocation)
        try container.encode(physicalLabel, forKey: .physicalLabel)
        try container.encode(owningUUID, forKey: .owningUUID)
        try container.encode(readOnly, forKey: .readOnly)
        try container.encode(volumeName, forKey: .volumeName)
        try container.encode(totalCapacity , forKey: .totalCapacity)
        try container.encode(availableCapacity , forKey: .availableCapacity)
    }
}
