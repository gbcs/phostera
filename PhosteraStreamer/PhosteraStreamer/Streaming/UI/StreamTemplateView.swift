//
//  StreamTemplateView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/6/23.
//

import UIKit

class StreamTemplateView: UIView {
    var streamPixelRef: String
    var aspectRatio: CGSize
    var label:UILabel = UILabel(frame: .zero)
    
    init(frame: CGRect, streamPixelRef: String, aspectRatio: CGSize) {
        self.streamPixelRef = streamPixelRef
        self.aspectRatio = aspectRatio
        super.init(frame: frame)
        self.addSubview(label)
        label.text = "Front Camera"
        label.textAlignment = .center
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

