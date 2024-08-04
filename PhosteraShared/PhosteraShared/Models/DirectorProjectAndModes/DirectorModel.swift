//
//  DirectorModel.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/3/23.
//

import Foundation

public class DirectorModel:NSObject, Identifiable, Decodable, Encodable {
    public var title:String
    public var uuid:String
    public var publicKey:Data
    public var sessionkey:String
    public var authorized:Bool
    public var blocked:Bool
    public var sessionPublicKey:Data
    
    public init(title: String, uuid: String, publicKey: Data, authorized:Bool, sessionKey:String, blocked:Bool, sessionPublicKey:Data) {
        self.title = title
        self.uuid = uuid
        self.publicKey = publicKey
        self.authorized = authorized
        self.sessionkey = sessionKey
        self.blocked = blocked
        self.sessionPublicKey = sessionPublicKey
    }
}
