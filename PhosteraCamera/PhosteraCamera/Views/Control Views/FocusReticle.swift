//
//  FocusReticle.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/1/23.
//

import Foundation
import UIKit
import AVFoundation
import Combine
import PhosteraShared

extension FocusReticle: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

class FocusReticle: UIView {
    private var dragOffset = CGPoint.zero
    private var locked:Bool = false
    private var focusMode:AnyCancellable?
    
    override init(frame: CGRect) {
        precondition(Thread.isMainThread)
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        precondition(Thread.isMainThread)
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        precondition(Thread.isMainThread)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
     
        tapGesture.require(toFail: panGesture)
     
        panGesture.delegate = self
        tapGesture.delegate = self
    }
    
    func setupSubscribers() {
        precondition(Thread.isMainThread)
        Logger.shared.info("Registering Focus Reticle subscriber")
        focusMode = (PubCentral.shared.pubFocusMode?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            switch(value) {
            case .autoFocus:
                locked = true
            case .continuousAutoFocus:
                locked = false
            case .locked:
                locked = true
            @unknown default:
                Logger.shared.error("Unknown case in focusMode")
            }
            setNeedsDisplay()
        })
    }
    
    public static func videoOrientation(by orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }
    
    func convertToPointOfInterest(fromViewCoordinates point: CGPoint, inFrame frame: CGRect, orientation: AVCaptureVideoOrientation) -> CGPoint {
        var pointOfInterest = CGPoint(x: 0.5, y: 0.5) // Default point of interest
        let frameSize = frame.size

        switch orientation {
        case .portrait:
            pointOfInterest = CGPoint(x: point.y / frameSize.height, y: 1.0 - point.x / frameSize.width)
        case .portraitUpsideDown:
            pointOfInterest = CGPoint(x: 1.0 - point.y / frameSize.height, y: point.x / frameSize.width)
        case .landscapeRight:
            pointOfInterest = CGPoint(x: point.x / frameSize.width, y: point.y / frameSize.height)
        case .landscapeLeft:
            pointOfInterest = CGPoint(x: 1.0 - point.x / frameSize.width, y: 1.0 - point.y / frameSize.height)
        @unknown default:
            break
        }

        // Clamp the point of interest to be within [0,1] for both x and y
        pointOfInterest.x = min(max(pointOfInterest.x, 0), 1)
        pointOfInterest.y = min(max(pointOfInterest.y, 0), 1)

        return pointOfInterest
    }
    
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        precondition(Thread.isMainThread)
        let translation = gesture.translation(in: superview)
        switch gesture.state {
        case .began:
            dragOffset = center
        case .changed:
            let newPosition = CGPoint(x: dragOffset.x + translation.x, y: dragOffset.y + translation.y)
            center = newPosition
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let point = convertToPointOfInterest(fromViewCoordinates: newPosition,
                                                     inFrame: CamTool.shared.getPreviewView()?.bounds ?? .zero,
                                                     orientation: AVCaptureVideoOrientation(interfaceOrientation: windowScene.interfaceOrientation) ?? .portrait )
                    CamTool.shared.getCameraDeviceFocus().userUpdatedPOI(poi: point)
            }
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        CamTool.shared.getCameraDeviceFocus().userToggledFocus()
    }
    
    override func draw(_ rect: CGRect) {
        precondition(Thread.isMainThread)
        if let context = UIGraphicsGetCurrentContext() {
            let rectRect = bounds
            context.setLineWidth(4.0)
            
            if locked {
                context.setStrokeColor(UIColor.systemRed.cgColor)
                context.stroke(rectRect)
            } else {
                let cornerRadius: CGFloat = 20.0
                context.setStrokeColor(UIColor.white.cgColor)
                context.move(to: CGPoint(x: rectRect.minX + cornerRadius, y: rectRect.minY))
                context.addLine(to: CGPoint(x: rectRect.minX, y: rectRect.minY))
                context.addLine(to: CGPoint(x: rectRect.minX, y: rectRect.minY + cornerRadius))
                
                context.move(to: CGPoint(x: rectRect.maxX - cornerRadius, y: rectRect.minY))
                context.addLine(to: CGPoint(x: rectRect.maxX, y: rectRect.minY))
                context.addLine(to: CGPoint(x: rectRect.maxX, y: rectRect.minY + cornerRadius))
                
                context.move(to: CGPoint(x: rectRect.maxX - cornerRadius, y: rectRect.maxY))
                context.addLine(to: CGPoint(x: rectRect.maxX, y: rectRect.maxY))
                context.addLine(to: CGPoint(x: rectRect.maxX, y: rectRect.maxY - cornerRadius))
                
                context.move(to: CGPoint(x: rectRect.minX + cornerRadius, y: rectRect.maxY))
                context.addLine(to: CGPoint(x: rectRect.minX, y: rectRect.maxY))
                context.addLine(to: CGPoint(x: rectRect.minX, y: rectRect.maxY - cornerRadius))
                context.strokePath()
            }
        }
    }
}
