//
//  AuthRequest.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public class AuthRequest: Codable {
    public var uuid:String
    public var title:String
    public var model:String
    public var userPublicKey:Data
    public var userSessionPublicKey:Data
    public var userMessageForSignup:String
    public var pairingCode:String
    
    public init(uuid: String, title: String, model: String, publicKey:Data, sessionPublicKey:Data, userMessage:String, pairingCode:String) {
        self.uuid = uuid
        self.title = title
        self.model = model
        self.userPublicKey = publicKey
        self.userSessionPublicKey = sessionPublicKey
        self.userMessageForSignup = userMessage
        self.pairingCode = pairingCode
    }
    
    enum CodingKeys: Int, CodingKey {
        case uuid = 1
        case title
        case model
        case userPublicKey
        case userSessionPublicKey
        case userMessageForSignup
        case pairingCode
    }
}
