//
//  TopStrip.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/28/23.
//


import Foundation
import UIKit
import Combine

class SideStripA: UIView {
    private var subAudioLevels:AnyCancellable?
    private var isPortraitiPhone:Bool = false
    private var level1: CGFloat = 0.0
    private var level2: CGFloat = 0.0
    private var highWaterMark: CGFloat = 0.0
    
    func levelToMeterScale(dBValue: Float, minDecibels: Float, maxDecibels: Float, meterLength: Int) -> CGFloat {
        if dBValue < minDecibels {
            return 0
        }

        // Typically, the scale is logarithmic
        let decibelResolution = maxDecibels - minDecibels
        let normalizedValue = (dBValue - minDecibels) / decibelResolution
        let scaleFactor = pow(normalizedValue, 0.5) // Use an exponent to adjust the curve. 0.5 will create a sqrt curve.

        return CGFloat(max(0, min(meterLength, Int(Float(meterLength) * scaleFactor))))
    }
    
    func setupViews(isPortraitiPhone:Bool) {
        precondition(Thread.isMainThread)
        self.isPortraitiPhone = isPortraitiPhone
        setNeedsDisplay()
        
        subAudioLevels = StatusService.shared.$audioPowerLevelUpdated.receive(on: DispatchQueue.main).throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true).sink { [weak self] value in
            guard let self else { return }
            precondition(Thread.isMainThread)
            if StatusService.shared.audioPowerLevels.count < 2 { return } //Not setup yet
            
            
            let (l1, high1) = StatusService.shared.audioPowerLevels[0]
            let (l2, high2) = StatusService.shared.audioPowerLevels[1]
            let high = high1 > high2 ? high1 : high2
            
            level1 = levelToMeterScale(dBValue: Float(l1), minDecibels: -60.0, maxDecibels: 0.0, meterLength: 100)
            level2 = levelToMeterScale(dBValue: Float(l2), minDecibels: -60.0, maxDecibels: 0.0, meterLength: 100)
            highWaterMark = levelToMeterScale(dBValue: Float(high), minDecibels: -60.0, maxDecibels: 0.0, meterLength: 100)
 
            setNeedsDisplay()
        }
    }
    
    private func drawMeter(level: CGFloat, x: CGFloat, context:CGContext) {
        precondition(Thread.isMainThread)
        let segmentWidth: CGFloat = 5
        let segmentCount: Int = 100
        let segmentHeight: CGFloat = bounds.height / CGFloat(segmentCount + segmentCount - 1)
        let segmentGap: CGFloat = 0.5
        let highWaterMarkThickness: CGFloat = 1
        for segment in 0..<segmentCount {
            let isActive = CGFloat(segment) < level
            let y = bounds.height - CGFloat(segment) * (segmentHeight + segmentGap) - (!isPortraitiPhone ? 80.0 : 0.0)
            
            context.setFillColor(isActive ? UIColor.green.cgColor : UIColor(_colorLiteralRed: 0, green: 0.5, blue: 0, alpha: 0.4).cgColor)
            context.fill(CGRect(x: x, y: y, width: segmentWidth, height: segmentHeight - segmentGap))
        }
        
        let highWaterMarkY = bounds.height - CGFloat(highWaterMark) * (segmentHeight + segmentGap) - (!isPortraitiPhone ? 80.0 : 0.0)
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(highWaterMarkThickness)
        context.stroke(CGRect(x: x, y: highWaterMarkY, width: segmentWidth, height: highWaterMarkThickness))
    }

    override func draw(_ rect: CGRect) {
        precondition(Thread.isMainThread)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let leftMargin = UIDevice.current.userInterfaceIdiom == .pad ? 0.0 : (isPortraitiPhone ? 0.0 : 50.0)
        let segmentWidth: CGFloat = 5
        drawMeter(level: level1, x: leftMargin, context: context)
        drawMeter(level: level2, x: leftMargin + segmentWidth + 1, context: context)
    }
}
