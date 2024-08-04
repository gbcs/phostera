//
//  VideoEncoderSharedData.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/14/23.
//

import Foundation
import UIKit

public class VideoEncoderSharedData: NSObject, Codable {
    public var sourceOrientation:UIInterfaceOrientation
    
    public init(sourceOrientation: UIInterfaceOrientation) {
        self.sourceOrientation = sourceOrientation
    }
    
    public enum CodingKeys: Int, CodingKey {
        case sourceOrientation = 1
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceOrientation = UIInterfaceOrientation(rawValue: try container.decode(Int.self, forKey: .sourceOrientation)) ?? .landscapeLeft
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceOrientation.rawValue, forKey: .sourceOrientation)
    }
}
