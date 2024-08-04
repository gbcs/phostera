//
//  WatchEntryModel.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/22/23.
//

import Foundation

public class WatchEntryModel: NSObject, Identifiable {
    public var uuid:String
    public var online:Bool
    public var name:String
    public var size:CGSize
    
    public init(uuid: String, online: Bool, name: String, size: CGSize) {
        self.uuid = uuid
        self.online = online
        self.name = name
        self.size = size
    }
}
