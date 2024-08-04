//
//  CollectionCell.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 8/22/23.
//

import UIKit
import AVFoundation
import Combine
import PhosteraShared

class RedXView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(2.0)
        
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: rect.width, y: rect.height))
        
        context.move(to: CGPoint(x: rect.width, y: 0))
        context.addLine(to: CGPoint(x: 0, y: rect.height))
        
        context.strokePath()
    }
}

class CollectionCell: UICollectionViewCell {
    static let identifer = "kPhosteraCollectionViewCell"
    private var currentScale: CGFloat = 1
    private var basicSubs:[AnyCancellable] = []
    private var onlineSubs:[AnyCancellable] = []
    private var cameraSubs:[AnyCancellable] = []
    
    private var streamSub:AnyCancellable?
    
    private var uuid: String = ""
    private var sampleBufLayer:AVSampleBufferDisplayLayer?

    private var recordingImage:UIImageView = UIImageView(image: UIImage(systemName: "record.circle"))
    private var histoLayer:CALayer?
    
    private let selectionView = UIView()
    private let infoLabel = UILabel()
    private let disconnectedView = RedXView(frame: .zero)
    
    private var standbyMode:Bool = false
    private var standbyModeOps:Bool = false
    
    private var videoTransform:CGAffineTransform = .identity
    
    private var frontCamera:Bool = false
    
    func getUUID() -> String { return uuid }
    
    override var isSelected: Bool {
        didSet {
            selectionView.isHidden = !isSelected
            infoLabel.textColor = isSelected ? UIColor.black : UIColor.white
        }
    }
    
    func update(uuid:String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            recordingImage.frame.size = CGSizeMake(15, 15)
            recordingImage.tintColor = UIColor.white
            if recordingImage.superview == nil { addSubview(recordingImage) }
            
            selectionView.backgroundColor = UIColor.systemYellow
            selectionView.frame = CGRectMake(0, 0, frame.size.width - recordingImage.frame.size.width , WatchEntryManager.shared.cameraInfoBarHeight + 5)
            selectionView.isHidden = true
            if selectionView.superview == nil { addSubview(selectionView) }
            
            infoLabel.backgroundColor = UIColor.clear
            infoLabel.font = UIFont.systemFont(ofSize: 12)
            infoLabel.textColor = UIColor.white
            if infoLabel.superview == nil { addSubview(infoLabel) }
            
            clipsToBounds = true
            autoresizesSubviews = true
            backgroundColor = UIColor(white: 1, alpha: 0.1)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(gesture:)))
            addGestureRecognizer(pinchGesture)
            
            resize()
            basicSubs.removeAll()
            
            Logger.shared.info("cellupdate - \(uuid)")
            self.uuid = uuid
            if let model = CameraManager.shared.getCamera(uuid: uuid) {
                infoLabel.text = model.name
            }
            streamSub = PubCentral.shared.streamChanged.receive(on: DispatchQueue.main).sink() { [weak self] value in
                guard let self else { return }
                setupSampleLayer()
            }
            
            if uuid == lightMeterUUID {
                histoLayer = CALayer()
                if let histoLayer {
                    layer.addSublayer(histoLayer)
                    histoLayer.frame.size = self.frame.size
                    CameraController.shared.histogramCalculator.updateLayer(visualLayer: histoLayer)
                }
                recordingImage.removeFromSuperview()
            } else {
                basicSubs.append(PubCentral.shared.cameraUpdated.receive(on: DispatchQueue.main).sink() { _ in
                    if CameraManager.shared.onlineUUIDs.contains(uuid) {
                        Task {
                            if let connection = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self else { return }
                                    addCameraSubs(conn:connection)
                                }
                            }
                            if let _ = await NetworkHandler.shared.cameraVideoStreamConnections[uuid] {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self else { return }
                                    setupSampleLayer()
                                }
                            }
                        }
                    }
                })
                
            }
            
            setupSampleLayer()
            updateDisconnectedView()
            if CameraManager.shared.onlineUUIDs.contains(uuid) {
                Task {
                    if let connection = await NetworkHandler.shared.cameraCommandConnections[uuid] {
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            addCameraSubs(conn:connection)
                        }
                    }
                    if let _ = await NetworkHandler.shared.cameraVideoStreamConnections[uuid] {
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            setupSampleLayer()
                        }
                    }
                }
            }
            
            updateStandbyView()
        }
    }
    
    var sampleCount:UInt64 = 0
    
    func setupSampleLayer() {
        Task {
            if let stream = await NetworkHandler.shared.cameraVideoStreamConnections[uuid] {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if sampleBufLayer == nil {
                        sampleBufLayer = AVSampleBufferDisplayLayer()
                    }
                    guard let sampleBufLayer else { return }
                    if sampleBufLayer.superlayer == nil {
                        self.layer.insertSublayer(sampleBufLayer, at:0)
                        sampleBufLayer.backgroundColor = UIColor.clear.cgColor
                    }
                    sampleBufLayer.frame = CGRectMake(0, WatchEntryManager.shared.cameraInfoBarHeight, layer.bounds.size.width, layer.bounds.size.height).insetBy(dx: 2, dy: 2)
                    stream.setPreviewLayerCallback { [weak self] sampleBuffer, sampleUUID in
                        guard let self else { return }
                        if sampleUUID != uuid {
                            Logger.shared.error("sample uuid mismatch: \(uuid) (ours) != \(sampleUUID) (buffer)")
                           
                            return
                        }
                       
                        sampleCount += 1
                        //Logger.shared.error("sample = \(sampleCount)")
                       
                       
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            guard let layer = self.sampleBufLayer  else { return }
                            layer.sampleBufferRenderer.flush(removingDisplayedImage: false)
                            layer.sampleBufferRenderer.enqueue(sampleBuffer)
                            //layer.enqueue(sampleBuffer)
                            

                        }
                    }
                    onlineSubs.removeAll()
                    onlineSubs.append(stream.$transform.sink { [weak self] value in
                        guard let self else { return }
                        guard let value else { return }
                        if let t = try? JSONDecoder().decode(VideoEncoderSharedData.self, from: value) {
                            Logger.shared.info("got vesd: \(t.sourceOrientation) - \(value.bytes.count)")
                            
                            var layertransform:CATransform3D = CATransform3DMakeAffineTransform(.identity)
                            
                            if frontCamera {
                                switch(t.sourceOrientation) {
                                case .landscapeRight:
                                    layertransform = CATransform3DMakeRotation(-Double.pi, 0, 0, 1)
                                    Logger.shared.info("Using landscapeRight")
                                case .portrait:
                                    layertransform = CATransform3DMakeRotation(Double.pi/2, 0, 0, 1)
                                    Logger.shared.info("Using portrait")
                                case .portraitUpsideDown:
                                    layertransform = CATransform3DMakeRotation(-Double.pi/2, 0, 0, 1)
                                    Logger.shared.info("Using portraitUpsideDown")
                                case .landscapeLeft:
                                    layertransform = CATransform3DMakeRotation(0, 0, 0, 1)
                                    Logger.shared.info("Using landscapeLeft")
                                    break
                                default:
                                    break
                                }
                            } else {
                                switch(t.sourceOrientation) {
                                case .landscapeRight:
                                    //layertransform = CATransform3DTranslate(layertransform, (w - h) / 2, (h - w) / 2, 0);
                                    layertransform = CATransform3DMakeRotation(0, 0, 0, 1)
                                    Logger.shared.info("Using landscapeRight")
                                case .portrait:
                                    layertransform = CATransform3DMakeRotation(Double.pi/2, 0, 0, 1)
                                    Logger.shared.info("Using portrait")
                                case .portraitUpsideDown:
                                    layertransform = CATransform3DMakeRotation(-Double.pi/2, 0, 0, 1)
                                    Logger.shared.info("Using portraitUpsideDown")
                                case .landscapeLeft:
                                    layertransform = CATransform3DMakeRotation(-Double.pi, 0, 0, 1)
                                    Logger.shared.info("Using landscapeLeft")
                                    break
                                default:
                                    break
                                }
                            }
                            
                          
                            DispatchQueue.main.async {
                                sampleBufLayer.transform = layertransform
                            }
                           
                        }
                     
                    })
                    
                }
               
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    sampleBufLayer?.removeFromSuperlayer()
                    sampleBufLayer = nil
                }
            }
        }
    }
    
    func addCameraSubs(conn:CameraCommandConnector) {
        Task(priority: .userInitiated, operation: {
            cameraSubs.removeAll()
            let uuid = await conn.getUUID()
            Logger.shared.info("addCameraSubs \(uuid)")
            await cameraSubs.append(conn.status.$adjustingExposure.receive(on: DispatchQueue.main).sink() { value in
               // Logger.shared.error("adjustingexposure:\(value)")
            })
            
            await cameraSubs.append(conn.status.$recordingState.receive(on: DispatchQueue.main).sink() { value in
                if value {
                    self.recordingImage.image = UIImage(systemName: "record.circle.fill")
                    self.recordingImage.tintColor = UIColor.systemRed
                } else {
                    self.recordingImage.image = UIImage(systemName: "record.circle")
                    self.recordingImage.tintColor = UIColor.white
                }
            })
            
            await cameraSubs.append(conn.status.$modeName .receive(on: DispatchQueue.main).sink() { [weak self] value in
                guard let self else { return }
                if let model = CameraManager.shared.getCamera(uuid: uuid) {
                    infoLabel.text = model.name + " - " + value
                }
                
                updateStandbyView()
            })
            
            cameraSubs.append(CameraManager.shared.$onlineUUIDs.receive(on: DispatchQueue.main).sink() { [weak self] value in
                guard let self else { return }
                updateDisconnectedView()
            })
            
            cameraSubs.append(PubCentral.shared.standbyUpdated.receive(on: DispatchQueue.main).sink() {  [weak self] _ in
                guard let self else { return }
                updateStandbyView()
            })
            
            cameraSubs.append(PubCentral.shared.standbyOpsUpdated.receive(on: DispatchQueue.main).sink() {  [weak self] _ in
                guard let self else { return }
                updateStandbyView()
            })
        
            await cameraSubs.append(conn.status.$frontCamera .receive(on: DispatchQueue.main).sink() { [weak self] value in
                guard let self else { return }
                frontCamera = value
            })
        })
    }
    
    let standbyViewTag = 42
    
    func updateStandbyView() {
        Logger.shared.info("updateStandbyView: \(CameraManager.shared.standbyUUIDs.contains(uuid)) - \(CameraManager.shared.standbyOpsUUIDS.contains(uuid))")
   
        let standbyOpsViewtag = 43
        var standbyView:UILabel? = self.viewWithTag(standbyViewTag) as? UILabel
        var standbyOpsView:UIActivityIndicatorView? = self.viewWithTag(standbyOpsViewtag) as? UIActivityIndicatorView
        
        if CameraManager.shared.standbyUUIDs.contains(uuid) {
            if standbyView == nil {
                standbyView = UILabel(frame: CGRectMake(10, 20, 100, 40))
                if let standbyView {
                    standbyView.backgroundColor = .accent
                    standbyView.tag = standbyViewTag
                    standbyView.text = "Standby"
                    standbyView.textAlignment = .center
                    self.addSubview(standbyView)
                }
            }
            
            if CameraManager.shared.standbyOpsUUIDS.contains(uuid) {
                if standbyOpsView == nil {
                    standbyOpsView = UIActivityIndicatorView(frame: CGRectMake(120, 20, 40, 40))
                    if let standbyOpsView {
                        standbyOpsView.tag = standbyOpsViewtag
                        standbyOpsView.backgroundColor = .accent
                        self.addSubview(standbyOpsView)
                        standbyOpsView.startAnimating()
                    }
                }
            } else {
                standbyOpsView?.removeFromSuperview()
                standbyOpsView = nil
            }
         
        } else {
            standbyView?.removeFromSuperview()
            standbyView = nil
            standbyOpsView?.stopAnimating()
            standbyOpsView?.removeFromSuperview()
            standbyOpsView = nil
        }
    }
    
    func updateDisconnectedView() {
        if CameraManager.shared.isUUIDOnline(uuid: uuid) {
            disconnectedView.removeFromSuperview()
        } else {
            disconnectedView.frame = CGRectMake(0,WatchEntryManager.shared.cameraInfoBarHeight + 5, frame.size.width, frame.size.height -  (WatchEntryManager.shared.cameraInfoBarHeight + 5))
            addSubview(disconnectedView)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        resize()
      
    }

    func resize() {
        recordingImage.frame.origin.x = frame.size.width - recordingImage.frame.size.width
        infoLabel.frame = CGRectMake(0, 2, frame.size.width - recordingImage.frame.size.width, WatchEntryManager.shared.cameraInfoBarHeight)
        selectionView.frame = CGRectMake(0, 0, frame.size.width - recordingImage.frame.size.width , WatchEntryManager.shared.cameraInfoBarHeight + 5)
        histoLayer?.frame = CGRectMake(0, WatchEntryManager.shared.cameraInfoBarHeight + 5, frame.size.width, frame.size.height - selectionView.frame.origin.y)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        update(uuid: uuid)
    }

    @objc func handlePinch(gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            currentScale = gesture.scale
        case .changed:
            let newScale = 1 + (gesture.scale - currentScale)
            self.transform = self.transform.scaledBy(x: newScale, y: newScale)
            currentScale = gesture.scale
        case .ended, .cancelled, .failed:
            self.transform = .identity
            
            var x = self.frame.size.width * currentScale
            let minX = WatchEntryManager.shared.initialCameraSize.width
            if x < minX {
                x = minX
            }
            if x > UIScreen.main.bounds.size.width {
                x = UIScreen.main.bounds.size.width
            }
            let size = CGSizeMake(x, x/(16/9) + WatchEntryManager.shared.cameraInfoBarHeight)
         
            Logger.shared.info("Set model size to \(size)")
            sampleBufLayer?.frame = CGRectMake(0, WatchEntryManager.shared.cameraInfoBarHeight, size.width, size.height)
            NotificationCenter.default.post(name: .itemInvalidated, object: nil, userInfo: ["uuid": uuid, "size": size])
            currentScale = 1
        default:
            break
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        Logger.shared.info("prepareforReuse - \(uuid)")
        
        let taskUUID = uuid
        Task { [taskUUID] in
            if let stream = await NetworkHandler.shared.cameraVideoStreamConnections[taskUUID] {
                stream.sampleBufferCallback = nil
            }
        }
        
        super.prepareForReuse()
     
        
        uuid = ""
        infoLabel.text = ""
        currentScale = 1
        histoLayer?.removeFromSuperlayer()
        histoLayer = nil
        onlineSubs.removeAll()
        basicSubs.removeAll()
        cameraSubs.removeAll()
        sampleBufLayer?.removeFromSuperlayer()
        sampleBufLayer = nil
        
    }
}
