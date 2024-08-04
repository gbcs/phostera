//
//  DiskFileItem.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 10/4/23.
//

import Foundation
public struct DiskFileItem: Identifiable, RandomAccessCollection, BidirectionalCollection {
    public  var id: Int32
    public var name: String
    public var children: [DiskFileItem]?
    public  var footageType: FootageType?
    public var fullPath:String
    
    public mutating func determineFootageType() {
        footageType = .video
    }
    
    public typealias Index = Array<DiskFileItem>.Index
    public typealias Element = DiskFileItem
    public typealias SubSequence = ArraySlice<DiskFileItem>
    
    public var startIndex: Index {
        return children?.startIndex ?? 0
    }
    
    public var endIndex: Index {
        return children?.endIndex ?? 0
    }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        guard let children = children else { return [] }
        return children[bounds]
    }
    
    public func index(before i: Index) -> Index {
        return i - 1
    }
    
    public func index(after i: Index) -> Index {
        return i + 1
    }
    
    public subscript(position: Array<DiskFileItem>.Index) -> DiskFileItem {
         _read {
             guard let children = children, position < children.endIndex else {
                 fatalError("Index out of range")
             }
             yield children[position]
         }
     }
    
    public init(id: Int32, name: String, children: [DiskFileItem]? = nil, footageType: FootageType? = nil, fullPath: String) {
        self.id = id
        self.name = name
        self.children = children
        self.footageType = footageType
        self.fullPath = fullPath
    }
}
