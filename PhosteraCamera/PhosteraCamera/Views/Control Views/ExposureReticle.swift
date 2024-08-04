//
//  FocusReticle.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 8/1/23.
//

import Foundation
import Foundation
import UIKit
import AVFoundation
import Combine

extension ExposureReticle: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

class ExposureReticle: UIView {
    private var exposureMode:AnyCancellable?
    private var locked:Bool = false
    private var dragOffset = CGPoint.zero
    
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
        exposureMode = (PubCentral.shared.pubExposureMode?.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            switch(value) {
            case .autoExpose:
                locked = false
            case .continuousAutoExposure:
                locked = false
            case .locked:
                locked = true
            case .custom:
                locked = true
            @unknown default:
                Logger.shared.error("Unknown case in exposureMode")
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
                    CamTool.shared.getCameraDeviceExposure().userUpdatedPOI(poi: point)
            }
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        precondition(Thread.isMainThread)
        CamTool.shared.getCameraDeviceExposure().userToggledExposure()
    }
    
    override func draw(_ rect: CGRect) {
        precondition(Thread.isMainThread)
        if let context = UIGraphicsGetCurrentContext() {
            context.setLineWidth(3.0)
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let radius: CGFloat = bounds.width / 2.0
            
            if locked {
                context.setStrokeColor(UIColor.systemRed.cgColor)
                context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                context.strokePath()
                return
            }
            
            context.setStrokeColor(UIColor.white.cgColor)
            
            let totalArcLength: CGFloat = 360.0
            let numSegments: CGFloat = 4
            let segmentAngle = totalArcLength / numSegments
            
            let emptyStart = segmentAngle * 0.7
            
            for x in 0..<4 {
                let startAngle = (CGFloat(x) * segmentAngle)
                let endAngle = (CGFloat(x) * segmentAngle) + emptyStart
                
                let startAngleInRadians = startAngle * .pi / 180.0 + 0.27
                let endAngleInRadians = endAngle * .pi / 180.0 + 0.27
                
                let startPoint = CGPoint(x: center.x + radius * cos(startAngleInRadians), y: center.y + radius * sin(startAngleInRadians))
                
                context.move(to: startPoint)
                context.addArc(center: center, radius: radius, startAngle: startAngleInRadians, endAngle: endAngleInRadians, clockwise: false)
            }
            
            context.strokePath()
        }
    }
}

