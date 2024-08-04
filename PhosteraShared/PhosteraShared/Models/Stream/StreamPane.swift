//
//  StreamPane.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/7/23.
//

import Foundation

public class StreamPane: NSObject, Codable {
    public var id:UUID = UUID()
    public var zOrder:Int
    public var frame:CGRect
    public var streamPixelRef:String
    public var aspectRatio:CGSize
    
    public init(zOrder: Int, streamPixelRef: String, frame:CGRect, aspectRatio:CGSize) {
        self.zOrder = zOrder
        self.streamPixelRef = streamPixelRef
        self.frame = frame
        self.aspectRatio = aspectRatio
    }
    
    public static func == (lhs: StreamPane, rhs: StreamPane) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func vend(z:Int, uuid:String, frame:CGRect, aspectRatio:CGSize) -> StreamPane {
        return StreamPane(zOrder: z, streamPixelRef: uuid, frame:frame, aspectRatio: aspectRatio)
    }
}
