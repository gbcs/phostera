//
//  CameraRoute.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/13/23.
//

import Foundation

import Foundation
import PhosteraShared

public class CameraRoute {
    static var shared = CameraRoute()
    
    func handleRouting(content:Data?, command:CommandMessageType, connection:CameraCommandConnector, forCamera:String) {
        //Pull out the requested auth response
        Task(priority: .userInitiated, operation: {
            var cameraResponse:CameraResponse
            
            if (content == nil) || content!.isEmpty {
                Logger.shared.error("no data in handleRouting.\(command)")
                return
            }
            
            let decoder = JSONDecoder()
            do {
                cameraResponse = try decoder.decode(CameraResponse.self, from: content!)
            } catch {
                Logger.shared.error("decoder error:\(error)")
                return
            }
            
            if cameraResponse.status == .success {
                if cameraResponse.command == .aacCookie {
                    if let data = try? decoder.decode(Data.self, from: cameraResponse.data) {
                        DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.aacCookie, object: nil, userInfo: ["cookie" : data,
                                                                                                                                                       "uuid" : forCamera]) }
                    }
                }  else {
                    Logger.shared.info("unhandled camera response \(cameraResponse.command)")
                }
            }
        })
    }
}

