//
//  AuthResponse.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/21/23.
//

import Foundation

public enum AuthResponseCode:Int, Codable {
    case success = 1
    case failure = 2
    
    enum CodingKeys: Int, CodingKey {
        case success = 1
        case failure = 2
    }
}

public class AuthResponse: Codable {
    public var status:AuthResponseCode
    public var uuid:String
    public var sessionKey:Data
    public var name:String
    public var model:String
    public var publicKey:Data
    public var streamTCP:UInt16
    public var streamQUIC:UInt16
    public var audioStreamTCP:UInt16
    public var audioStreamQUIC:UInt16
    public var blocked:Bool
    public var serverSessionPublicKey:Data
    public var sessionSignature:Data
    public var serverSessionAgreementKey:Data
    public var version:Int
    
    enum CodingKeys: Int, CodingKey {
        case status = 1
        case uuid = 2
        case sessionKey = 3
        case name = 4
        case model = 5
        case publicKey = 6
        case streamTCP = 7
        case streamQUIC = 8
        case audioStreamTCP = 9
        case audioStreamQUIC = 10
        case blocked = 11
        case serverSessionPublicKey = 12
        case sessionSignature = 13
        case serverSessionAgreementKey = 14
        case version = 15
    }
    
    public init(status: AuthResponseCode, uuid: String, sessionKey: Data, name: String, model: String, publicKey: Data, streamTCP: UInt16, streamQUIC: UInt16, audioStreamTCP: UInt16, audioStreamQUIC: UInt16, blocked: Bool, serverSessionPublicKey:Data, sessionSignature:Data, serverAgreementPublicKey:Data, version:Int) {
        self.status = status
        self.uuid = uuid
        self.sessionKey = sessionKey
        self.name = name
        self.model = model
        self.publicKey = publicKey
        self.streamTCP = streamTCP
        self.streamQUIC = streamQUIC
        self.audioStreamTCP = audioStreamTCP
        self.audioStreamQUIC = audioStreamQUIC
        self.blocked = blocked
        self.serverSessionPublicKey = serverSessionPublicKey
        self.sessionSignature = sessionSignature
        self.serverSessionAgreementKey = serverAgreementPublicKey
        self.version = version
    }
}
