//
//  UserMessagingService.swift
//  PhosteraCamera
//
//  Created by Gary Barnett on 9/10/23.
//

import Foundation
import Combine
import PhosteraShared

enum UserMessageRequestType {
    case newUserAuth
    case message
}

class UserMessageRequest: Equatable {
    var id:String = UUID().uuidString.lowercased()
    var requestType:UserMessageRequestType
    var text:String
    var director:DirectorModel
    
    init(requestType: UserMessageRequestType, text: String, director: DirectorModel) {
        self.requestType = requestType
        self.text = text
        self.director = director
    }
    
    static func == (lhs: UserMessageRequest, rhs: UserMessageRequest) -> Bool {
        lhs.id == rhs.id
    }
}

actor UserMessagingService {
    static var shared = UserMessagingService()
    
    private var messageQueue:[UserMessageRequest] = []

    func add(message:UserMessageRequest) {
        messageQueue.append(message)
        DispatchQueue.main.async {
            PubCentral.shared.userMessageIndex += 1
        }
    }
    
    func delete(message:UserMessageRequest) {
        messageQueue.removeAll(where: { $0 == message })
    }
    
    func pull() -> UserMessageRequest? {
        if let message = messageQueue.first {
            messageQueue.removeFirst()
            return message
        }
        return nil
    }
}
