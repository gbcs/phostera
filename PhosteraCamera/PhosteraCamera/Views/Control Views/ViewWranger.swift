//
//  CameraViewWrangler.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/29/23.
//

import UIKit
import AVFoundation


//Maintain a "view" on how views should be positioned.
//Gets orientation, size, 'flavor' and creates view positions that can be used in CameraViewController

//Base layout by orientation
enum DeviceSizeFlavor: Int {
    case iPad // Seperate preview and controls/visualizations - no overlay
    case iPhone //Base case
    case iPhoneSmall //SE - no usable sidebar
}

//Modified by user choice
enum DeviceScreenMode: Int {
    case previewUnderlayUI
    case previewBetweenUI //Not available on iPhoneSmall
}

//Modified by user choice
enum DevicePreferHand: Int {
    case right
    case left
}

enum WrangledViewList: Int, CaseIterable {
    case mainControls = 0 //Record button, etc
    case visualizer = 1 //Visualization View
    case topStrip = 2 //iso, shutter, wb, master caution, speed-guage, time-left, director status
    case sideStripA = 3 //Audio Controls
    case sideStripB = 4 //Zoom Controls
    case modeInfo = 5 //Mode name, 4k/30/hdr
    case preview = 6 //Frame for preview view
    case torchUI = 7
    case vizToolsUI = 8
}

class CameraViewWrangler: NSObject {
    private var currentScreenMode:DeviceScreenMode = .previewBetweenUI
    private var sizeFlavor:DeviceSizeFlavor = .iPhone
    private var whichHand:DevicePreferHand = .right
    private var screenSize:CGSize = .zero

    private var frames:[CGRect] = [CGRect]()
    private var heights:[CGFloat] = [ 50.0, 50.0, 50.0, 50, 50, 50.0, 50  ]
    
    
    private let mainControlViewWidth = 50.0
    
    func frameForView(whichOne:WrangledViewList) -> CGRect {
        precondition(Thread.isMainThread)
        let position = whichOne.rawValue
        if frames.count >  position {
            //Logger.shared.error("Returning frameForView for postion \(position) = \(self.frames[position].debugDescription)")
            return frames[position]
        }
        Logger.shared.error("Requested frameForView for postion \(position) which didn't exist. Returned .zero")
        return .zero
    }
    
    private func heightForView(whichOne:WrangledViewList) -> CGFloat {
        precondition(Thread.isMainThread)
        switch (whichOne) {
        case .mainControls:
            return 50
        case .visualizer:
            return 50
        case .topStrip:
            return screenSize.width > screenSize.height ? 30 : 80
        case .sideStripA:
            return 0
        case .sideStripB:
            return 0
        case .modeInfo:
            return 20
        case .preview:
            return 0
        case .torchUI:
            return 40
        case .vizToolsUI:
            return 40
        }
    }
    
    private func setupViewsforiPad() {
        precondition(Thread.isMainThread)
        let ipadSideStripWidth = 50.0
        let topMargin = self.heightForView(whichOne: .topStrip)
        let botMargin = self.heightForView(whichOne: .mainControls)
        let leftMargin = ipadSideStripWidth
        let rightMargin = ipadSideStripWidth
        
        let newSize = CGSizeMake(screenSize.width - (leftMargin + rightMargin), screenSize.height - (topMargin + botMargin))
        let previewFrame = figureSizeForGivenAspectRatioWindowInside(size:newSize, aspectRatio: CamTool.shared.getAspectRatio())
        
        var modeInfox = 440.0
        var modeInfoY = 0.0
        var modeInfoWidth = screenSize.width - (modeInfox + 150)
        var modeInfoHeight = self.heightForView(whichOne: .modeInfo)
        let isPortrait = screenSize.height > screenSize.width
        if isPortrait {
            modeInfox = 0
            modeInfoY = previewFrame.origin.y + previewFrame.size.height
            modeInfoWidth = (screenSize.width / 2.0) - 150
            modeInfoHeight = screenSize.height - modeInfoY
        }
        
        frames = [
            //MainControlView
            CGRectMake(screenSize.width - (mainControlViewWidth + leftMargin),
                       screenSize.height - self.heightForView(whichOne: .mainControls) - (isPortrait ? 0 : 10),
                       mainControlViewWidth, self.heightForView(whichOne: .mainControls) + 5),
            //visualizer
            CGRectMake((screenSize.width / 2.0) - 150,
                       screenSize.height - self.heightForView(whichOne: .visualizer) - (isPortrait ? 0 : 10),
                       300,
                       self.heightForView(whichOne: .visualizer)),
            //topStrip
            CGRectMake(0,
                       0,
                       screenSize.width,
                       self.heightForView(whichOne: .topStrip)),
            //sideStripA
            CGRectMake(0,
                       topMargin,
                       ipadSideStripWidth,
                       screenSize.height - (topMargin + botMargin)),
            //sideStripB
            CGRectMake(screenSize.width - ipadSideStripWidth,
                       topMargin,
                       ipadSideStripWidth,
                       screenSize.height - (topMargin + botMargin)),
            //modeInfo
            CGRectMake(modeInfox,
                       modeInfoY,
                       modeInfoWidth,
                       modeInfoHeight
                       ),
            //preview
            previewFrame,
            
            //torchUI
            CGRectMake(screenSize.width - ipadSideStripWidth - 240,
                       topMargin,
                       240,
                       self.heightForView(whichOne: .torchUI)),
            
            //vizToolsUI
            CGRectMake(screenSize.width - ipadSideStripWidth - 240,
                       topMargin + 100,
                       240,
                       self.heightForView(whichOne: .vizToolsUI)),
        ]
       // Logger.shared.info("frames_modeinfo \(self.frames[5].debugDescription)")
      //  Logger.shared.info("frames: \(self.frames.debugDescription)")
    }
    
 
        
    private func setupViewsforiPhone() {
        precondition(Thread.isMainThread)
        let previewFrame = figureSizeForGivenAspectRatioWindowInside(size:screenSize, aspectRatio: CamTool.shared.getAspectRatio())
        let defaultSidePanelWidth = 50.0
        var sidePanel = defaultSidePanelWidth
        if previewFrame.origin.x > sidePanel { sidePanel = previewFrame.origin.x }
        
        var modeInfoY = screenSize.height - self.heightForView(whichOne: .modeInfo)
        if screenSize.height > previewFrame.origin.y + previewFrame.size.height {
            modeInfoY = previewFrame.origin.y + previewFrame.size.height
        }
        
        var modeInfoWidth = screenSize.width
        
        var modeInfox = 0.0
        if screenSize.width > screenSize.height {
            modeInfox = 500.0
            modeInfoY = 0.0
            modeInfoWidth = 240.0
        }
        
        var mainControlX = screenSize.width - (mainControlViewWidth + 35 + defaultSidePanelWidth)
        

        if CameraViewController.currentWindowInterfaceOrientation().isPortrait {
            mainControlX = screenSize.width - (mainControlViewWidth + 25)
        }
        frames = [
            //Maincontrolview
            CGRectMake(mainControlX,
                       screenSize.height - self.heightForView(whichOne: .mainControls),
                       mainControlViewWidth,
                       self.heightForView(whichOne: .mainControls)),
            //Visualizer
            CGRectMake(40,
                       screenSize.height - self.heightForView(whichOne: .visualizer),
                       150,
                       self.heightForView(whichOne: .visualizer)),
            //TopStrip
            CGRectMake(0,
                       0,
                       screenSize.width,
                       self.heightForView(whichOne: .topStrip)),
            //SideA
            CGRectMake(0,
                       previewFrame.origin.y,
                       sidePanel,
                       screenSize.height - (previewFrame.origin.y * 2)),
            //SideB
            CGRectMake(screenSize.width - sidePanel,
                       previewFrame.origin.y,
                       sidePanel,
                       screenSize.height - (previewFrame.origin.y * 2)),
            //Modeinfo
            CGRectMake(modeInfox,
                       modeInfoY,
                       modeInfoWidth,
                       self.heightForView(whichOne: .modeInfo)),
            //Preview
            previewFrame
        ]
        //Logger.shared.info("frames_modeinfo \(self.frames[5].debugDescription)")
       // Logger.shared.info("frames: \(self.frames.debugDescription)")
        
        Logger.shared.info("frames_preview \(self.frames[WrangledViewList.modeInfo.rawValue].debugDescription)")
        
    }
    

    func setupViewsFor(useFlavor:DeviceSizeFlavor, screenMode:DeviceScreenMode, forSize:CGSize, forHand:DevicePreferHand) {
        precondition(Thread.isMainThread)
        if (forSize.width < 100) || (forSize.height < 100) {
            Logger.shared.info("attempt to setupViewsFor with frame: \(self.frames.debugDescription)")
            return
        }
        screenSize = forSize
        currentScreenMode = screenMode
        sizeFlavor = useFlavor
        whichHand = forHand
        
        frames.removeAll()
        
        if sizeFlavor == .iPad {
            self.setupViewsforiPad()
        } else {
            self.setupViewsforiPhone()
        }
    }
    
    //Figure largest arbitrary included rectangle.
    //whichever size has space left over, halve it and return 0 for the other side
    private func figureSizeForGivenAspectRatioWindowInside(size: CGSize, aspectRatio:CGSize) -> CGRect {
        precondition(Thread.isMainThread)
        var r = CGRectZero
        if size.height > size.width {
            r = AVMakeRect(aspectRatio: CGSizeMake(aspectRatio.height, aspectRatio.width), insideRect:CGRectMake(0,0,size.width, size.height))
        } else {
            r = AVMakeRect(aspectRatio: CGSizeMake(aspectRatio.width, aspectRatio.height), insideRect:CGRectMake(0,0,size.width, size.height))
        }
        return CGRectMake((screenSize.width - r.size.width) / 2, (screenSize.height - r.size.height) / 2, r.size.width, r.size.height)
    }
}
