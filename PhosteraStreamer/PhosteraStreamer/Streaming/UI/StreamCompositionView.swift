//
//  StreamCompositionView.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/6/23.
//

import UIKit
import SwiftUI

class StreamCompositionUIView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
   
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2)
    }

    func add(streamPixelRef:String, frame:CGRect, aspectRatio: CGSize) {
        let subView = StreamTemplateView(frame: frame, streamPixelRef: streamPixelRef, aspectRatio: aspectRatio)
        subView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.2)
        addGestureRecognizers(to: subView)
        addSubview(subView)
        subView.layer.setValue((subviews.count - 1), forKey: "zOrder")
    }
    
    func remove(streamPixelRef: String) {
        let viewsToRemove = subviews.compactMap { $0 as? StreamTemplateView }.filter { $0.streamPixelRef == streamPixelRef }
        for view in viewsToRemove {
            view.removeFromSuperview()
        }
    }
    
    func removeAll() {
        let viewsToRemove = subviews
        for view in viewsToRemove {
            view.removeFromSuperview()
        }
    }
    
    private func addGestureRecognizers(to view: StreamTemplateView) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: self)
        view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
        gesture.setTranslation(.zero, in: self)
        if gesture.state == .ended {
            if view.frame.origin.x < 0 { view.frame.origin.x = 0 }
            if view.frame.origin.y < 0 { view.frame.origin.y = 0 }
            if view.frame.origin.x + view.frame.size.width > self.bounds.size.width { view.frame.origin.x = frame.size.width - view.frame.size.width }
            if view.frame.origin.y + view.frame.size.height > self.bounds.size.height { view.frame.origin.y = frame.size.height - view.frame.size.height }
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view = gesture.view as? StreamTemplateView else { return }
        let scale = gesture.scale
        
        let newWidth = view.frame.width * scale
        let newHeight = newWidth / (view.aspectRatio.width / view.aspectRatio.height)
        
        let deltaX = (newWidth - view.frame.width) / 2
        let deltaY = (newHeight - view.frame.height) / 2
        
        view.frame = CGRect(
            x: view.frame.origin.x - deltaX,
            y: view.frame.origin.y - deltaY,
            width: newWidth,
            height: newHeight
        )
        gesture.scale = 1
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            guard let _ = gesture.view else { return }
            // Handle long press, perhaps by changing a value related to the view's visibility
            Logger.shared.error("lp")
        }
    }
}
