//
//  CameraModel.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/20/23.
//

import Foundation
import Symbols


public class CameraModel: NSObject, Identifiable, Codable {
    public var uuid:String
    public var name:String
    public var model:String
    public var authorized:Bool = false
    public var blocked:Bool = false
    
    public init(uuid: String, name: String, model: String, blocked: Bool) {
        self.uuid = uuid
        self.name = name
        self.model = model
        self.blocked = blocked
    }
    
    public func isKnown() -> Bool {
        if self.model.compare("Unknown") == .orderedSame {
            return false
        }
        return true
    }
}

