//
//  StreamCompositionViewController.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 10/2/23.
//

import SwiftUI
import AVFoundation
import PhosteraShared
import Combine
import DeviceKit


struct StreamCompositionView: UIViewControllerRepresentable {
    typealias UIViewControllerType = StreamCompositionViewController
    
    func makeUIViewController(context: Context) -> StreamCompositionViewController {
        return StreamCompositionViewController()
    }
    
    func updateUIViewController(_ uiViewController: StreamCompositionViewController, context: Context) {}
}

class StreamCompositionViewController: UIViewController {
    var compositionView: StreamCompositionUIView!
    var presetView: StreamPresetView!
    var cancellables:[AnyCancellable] = []
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        savePreset()
        super.viewWillTransition(to: size, with: coordinator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
            guard let self else { return }
            loadCurrentPreset()
        })

    }

    override func viewDidLoad() {
        title = "Position Camera"
        super.viewDidLoad()
        compositionView = StreamCompositionUIView(frame: view.bounds)
        view.addSubview(compositionView)
        presetView = StreamPresetView(frame: .zero)
        view.addSubview(presetView)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDeviceOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
      
        cancellables.append(PubCentral.shared.pubPresetChosen.sink { [weak self] notification in
            guard let self else { return }
            let outputData = output()
            if let userInfo = notification.userInfo {
                if let index = userInfo["index"] as? Int {
                    Task {
                        let project = await ProjectService.shared.currentProject()
                        project.presets[project.currentPreset] = outputData
                        project.currentPreset = index
                        _ = await ProjectService.shared.save(project: project)
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            loadCurrentPreset()
                        }
                    }
                }
            }
        })
        
        cancellables.append(PubCentral.shared.pubPresetReset.sink { notification in
            Task {
                let project = await ProjectService.shared.currentProject()
                let currentPreset = project.currentPreset
                project.presets[currentPreset] = []
                _ = await ProjectService.shared.save(project: project)
                DispatchQueue.main.async { [weak self] in
                       guard let self else { return }
                       presetSetup()
                }
            }
        })
    }
    
    @objc func handleDeviceOrientationChange() {
        view.setNeedsLayout()
    }

    func loadCurrentPreset() {
        Task {
            let project = await ProjectService.shared.currentProject()
            let currentPreset = project.currentPreset
            let presetInfo = project.presets[currentPreset]
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                restoreState(streamPanes: presetInfo)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(presetView)
        
        var previewRect = AVMakeRect(aspectRatio: CGSizeMake(16, 9), insideRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height))
        var presetRect:CGRect = .zero
        if self.view.frame.size.height > self.view.frame.size.width {
            previewRect.origin.y = (self.view.frame.size.height / 2.0) - (previewRect.size.height / 2.0)
            previewRect.origin.x = 0
            presetRect = CGRectMake(0, 0, self.view.frame.size.width, 44)
        } else {
            previewRect.origin.x = (self.view.frame.size.width / 2.0) - (previewRect.size.width / 2.0)
            previewRect.origin.y = (self.view.frame.size.height / 2.0) - (previewRect.size.height / 2.0)
            presetRect = CGRectMake(0, 15, 44, self.view.frame.size.height - 25)
        }
        
        compositionView.frame = previewRect
        presetView.frame = presetRect
        
        compositionView.setNeedsLayout()
        compositionView.layoutIfNeeded()
        
        presetView.setNeedsLayout()
        presetView.layoutIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadCurrentPreset()
    }
    
    func isiPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    func isPreUSBCiPad() -> Bool {
        let device = Device.current
        let preUSBCModels: [String] = [
            "iPad (5th generation)", "iPad (6th generation)",
            "iPad Air", "iPad Air 2",
            "iPad mini", "iPad mini 2", "iPad mini 3", "iPad mini 4",
            "iPad Pro (9.7-inch)", "iPad Pro (10.5-inch)",
            "iPad Pro (12.9-inch)", "iPad Pro (12.9-inch) (2nd generation)"
        ]
        
        return preUSBCModels.contains(device.description)
    }
    
    func presetSetup() {
        var panes:[StreamPane] = []
        
        //Enumerate everything we know about, online or not.
//        
//        //Always have a media player
//        panes.append(StreamPane(zOrder: 2, streamPixelRef: "video1", frame: CGRectMake(350, 100, 400, 400 / (16/9)), aspectRatio: CGSizeMake(16, 9)))
//       
        //Always have a front camera
        panes.append(StreamPane(zOrder: 99, streamPixelRef: "front", frame: CGRectMake(0, 762, 565, 317), aspectRatio: CGSizeMake(16, 9)))
//
//        //Always have a rear camera
//        panes.append(StreamPane(zOrder: 1, streamPixelRef: "rear", frame: CGRectMake(350, 100, 400, 400 / (16/9)), aspectRatio: CGSizeMake(16, 9)))
//       
//        //Might have an external camera
//        if isiPad() && (!isPreUSBCiPad()) {
//            panes.append(StreamPane(zOrder: 3, streamPixelRef: "external", frame: CGRectMake(700, 100, 400, 400 / (16/9)), aspectRatio: CGSizeMake(16, 9)))
//        }
//        
//        //Grab all the remote cameras
//        var zIndex:Int = 4
//        for camera in CameraManager.shared.cameraList {
//            if !camera.isKnown() { continue }
//            panes.append(StreamPane(zOrder: zIndex, streamPixelRef: camera.uuid, frame: CGRectMake(CGFloat(100 + (zIndex * 50)), 100, 200, 200 / (16/9)), aspectRatio: CGSizeMake(16, 9)))
//            zIndex += 1
//        }
 
        Task {
            let project = await ProjectService.shared.currentProject()
            project.presets[project.currentPreset] = panes
            _ = await ProjectService.shared.save(project: project)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                loadCurrentPreset()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        savePreset()
    
        super .viewWillDisappear(animated)
    }

    func reset() {
        compositionView.removeAll()
        presetSetup()
    }
    
    func savePreset() {
        let outputData = output()
        Task {
            let project = await ProjectService.shared.currentProject()
            project.presets[project.currentPreset] = outputData
            if await ProjectService.shared.save(project: project) != true {
                Logger.shared.error("Unable to save project preset")
            }
            MetalTool.shared.updatePreset()
        }
    }
    
    func output() -> [StreamPane] {
        let standardWidth: CGFloat = 1920
        let standardHeight: CGFloat = 1080
        let scaleX = standardWidth / compositionView.bounds.width
        let scaleY = standardHeight / compositionView.bounds.height
        
        return compositionView.subviews.enumerated().compactMap { index, subview in
            guard let streamView = subview as? StreamTemplateView else { return nil }
            var frame = streamView.frame
            frame.origin.x *= scaleX
            frame.origin.y *= scaleY
            frame.size.width *= scaleX
            frame.size.height *= scaleY
            let streamPixelRef = streamView.streamPixelRef
            let zOrder = index
            return StreamPane(zOrder: zOrder, streamPixelRef: streamPixelRef, frame: frame, aspectRatio: streamView.aspectRatio)
        }.sorted(by: { $0.zOrder < $1.zOrder })
    }

    func restoreState(streamPanes:[StreamPane]) {
        compositionView.removeAll()
        
        let standardWidth: CGFloat = 1920
        let standardHeight: CGFloat = 1080
        let scaleX = compositionView.bounds.width / standardWidth
        let scaleY = compositionView.bounds.height / standardHeight
        
        for pane in streamPanes.sorted(by: { $0.zOrder < $1.zOrder }) {
            var frame = pane.frame
            frame.origin.x *= scaleX
            frame.origin.y *= scaleY
            frame.size.width *= scaleX
            frame.size.height *= scaleY
            compositionView.add(streamPixelRef: pane.streamPixelRef, frame: frame, aspectRatio: pane.aspectRatio)
        }
        
        if streamPanes.count == 0 {
            presetSetup()
        }
        
        presetView.selectButton()
    }
}
