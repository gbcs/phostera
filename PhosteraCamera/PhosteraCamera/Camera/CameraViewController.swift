

import UIKit
import AVFoundation
import Combine
import SwiftUI
import PhosteraShared

class CameraViewController: UIViewController {
    private let standbyViewTag = 42
    private var statusBarOrientation: UIInterfaceOrientation = .landscapeLeft
    private var supportedOrientations:UIInterfaceOrientationMask = .all
    
    @State private var libraryItems:[FootageFileItem] = []
    
    private var wrangler:CameraViewWrangler = CameraViewWrangler()
    private var subscriptions:[Cancellable] = [Cancellable]()
    private var mainControlView:MainControlView = MainControlView(frame: .zero, zoomEnabled: false)
    private var topStrip:TopStrip = TopStrip()
    private var sideStripA:SideStripA = SideStripA()
    private var sideStripB:SideStripB = SideStripB(frame: .zero, zoomEnabled: true)
    private var modeInfo:ModeInfo = ModeInfo()
    private var focusReticle:FocusReticle = FocusReticle(frame: .zero)
    private var exposureReticle:ExposureReticle = ExposureReticle(frame: .zero)
    lazy private var animator:UIDynamicAnimator = UIDynamicAnimator(referenceView: self.view)
    private var torchUI:TorchUI?
    private var flashUI:FlashUI?
    private var vizToolsUI:VizToolsUI?
    
    private var standbySubs:[AnyCancellable] = []
    
    private var switchingModes:Bool = false
    
    override var prefersStatusBarHidden: Bool {  return true  }
    override var prefersHomeIndicatorAutoHidden: Bool {  return true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return supportedOrientations }
    
    override func viewDidLoad() {
        precondition(Thread.isMainThread)
        super.viewDidLoad()
        focusReticle.frame = CGRectMake(view.frame.size.width * 0.33 - 30, view.frame.size.height * 0.50 - 30, 60, 60)
        exposureReticle.frame = CGRectMake(view.frame.size.width * 0.66 - 30, view.frame.size.height * 0.50 - 30, 60, 60)
        focusReticle.isHidden = true
        exposureReticle.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        precondition(Thread.isMainThread)
        super.viewWillDisappear(animated)
        torchUI?.removeFromSuperview()
        flashUI?.removeFromSuperview()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        precondition(Thread.isMainThread)
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            guard let self else { return }
            
            if let orientation = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .compactMap({$0 as? UIWindowScene})
                .first?.interfaceOrientation {
                updateOrientation(interfaceOrientation: orientation)
            }
            setupSubscribers()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            if SettingsService.shared.settings.needsOnboarding {
                let newpage = UIHostingController(rootView: WelcomePageView())
                newpage.modalPresentationStyle = .fullScreen
                present(newpage, animated: false, completion:{ })
            } else if (!CamTool.shared.hasPermission()) {
                @State var pathOnboard:[OnboardingRoute] = [OnboardingRoute]()
                let newpage = UIHostingController(rootView: PermissionsPageView(path: $pathOnboard))
                newpage.modalPresentationStyle = .fullScreen
                present(newpage, animated: false, completion:{ })
            } else {
                startup()
            }
        })
         
        if !SettingsService.shared.settings.needsOnboarding {
            if SettingsService.shared.settings.runServer {
                Task {
                    if await CommandServer.shared.listenerState() != .ready {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            ServerKeys.startServer()
                        })
                    }
                }
            }
            positionViewsInVC(size: view.frame.size)
            displayAnyUserMessage()
           
        }
    }

    private func switchToMode(uuid:String) {
        precondition(Thread.isMainThread)
        Logger.shared.info("Switching to mode: \(uuid)")
        if switchingModes {
            Logger.shared.error("Mode switch attempt while already switching. bailing.")
            return
        }
        
        switchingModes = true
        
        if CamTool.shared.isSessionRunning() {
            CamTool.shared.stopSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
                guard let self else { return }
                Logger.shared.info("Stopping running mode. Will start mode shortly. \(uuid)")
                startMode(uuid: uuid)
            })
            return
        }
       
        startMode(uuid: uuid)
    }
    
    private func startMode(uuid:String) {
        precondition(Thread.isMainThread)
        Logger.shared.info("Starting mode \(uuid)")
        Logger.shared.info("-----------------------------------------------------------------------------------")
        CamTool.shared.useMode(uuid: uuid, completion: { [weak self] value in
            guard let self else {
                return
            }
            precondition(Thread.isMainThread)
            if CamTool.shared.isSessionRunning() {
                if let orientation = UIApplication.shared.connectedScenes
                    .filter({$0.activationState == .foregroundActive})
                    .compactMap({$0 as? UIWindowScene})
                    .first?.interfaceOrientation {
                    updateOrientation(interfaceOrientation: orientation)
                }
                setupPreview()
                setupControlViews()
                setupControlSubscriptions()
                moveSubViews(forSize: view.frame.size)
                focusReticle.isHidden = false
                exposureReticle.isHidden = false
                positionViews(hidden: false, forSize: view.frame.size)
                CamTool.shared.transitionToSize(size: view.frame.size, orientation: statusBarOrientation)
                if let p = CamTool.shared.getPreviewView() {
                    CamTool.shared.externalDisplay(allowSecondary: true, preview: p)
                }
                SettingsService.shared.settings.lastSuccessfulModeId = SettingsService.shared.settings.currentModeId
                SettingsService.shared.save()
            } else {
                SettingsService.shared.settings.currentModeId = SettingsService.shared.settings.lastSuccessfulModeId
                SettingsService.shared.save()
                switchingModes = false
                CamTool.shared.useMode(uuid: SettingsService.shared.settings.currentModeId, completion: { _ in })
            }
            if let p = CamTool.shared.getPreviewView() {
                p.alpha = 1.0
            }
            switchingModes = false
        })
    }
    
    private var standbyTakeCount:Int = 0
    private var standbyCopyCompleted:Int = 0
    private var standbyProxyCompleted:Int = 0
    
    @objc func removeStandby(_ gesture: UITapGestureRecognizer) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            NotificationCenter.default.post(name: Notification.Name.CameraOperations.modeSwitch, object: nil)
        })
    }

    let sleepImageTag = 422
    func showStandby() {
        if let v = self.view.viewWithTag(standbyViewTag) {
            v.removeFromSuperview()
        }
        
        let x = UIView(frame: CGRectMake(0, 0, view.bounds.size.width, view.bounds.size.height))
        x.tag = standbyViewTag
        x.backgroundColor = UIColor.black
        
        let tapG = UITapGestureRecognizer(target: self, action: #selector(removeStandby(_:)))
        x.addGestureRecognizer(tapG)
        x.isUserInteractionEnabled = true
        
        let midX = x.bounds.size.width / 2.0
        let midY = x.bounds.size.height / 2.0
    
        let i = UIImageView(image: UIImage(systemName: "sleep.circle"))
        i.tag = sleepImageTag
        i.contentMode = .scaleAspectFit
        i.frame = CGRectMake(midX - 30, midY - 100, 60, 60)
        x.addSubview(i)
        
        let l1 = UILabel(title: "Phostera Camera")
        l1.frame = CGRectMake(0, midY - 40, x.bounds.size.width, 40)
        l1.textAlignment = .center
        l1.font = .boldSystemFont(ofSize: 24)
        l1.textColor = .white
        x.addSubview(l1)
        
        let l2 = UILabel(title: "Waiting for the action.")
        l2.frame = CGRectMake(0, midY + 40, x.bounds.size.width, 40)
        l2.textAlignment = .center
        l2.font = .systemFont(ofSize: 18)
        l2.numberOfLines = 0
        l2.lineBreakMode = .byWordWrapping
        l2.textColor = .white
        l2.tag = 111
        x.addSubview(l2)
        
        
        let l3 = UILabel(title: SettingsService.shared.settings.serverUUID)
        l3.frame = CGRectMake(0, x.bounds.size.height - 80, x.bounds.size.width / 2.0, 40)
        l3.textAlignment = .left
        l3.font = .systemFont(ofSize: 18)
        l3.numberOfLines = 0
        l3.lineBreakMode = .byWordWrapping
        l3.textColor = .white
        l3.tag = 112
        x.addSubview(l3)
        
        let l4 = UILabel(title: "\(VersionInfo.productVersion).\(VersionInfo.buildNumber)")
        l4.frame = CGRectMake(x.bounds.size.width / 2.0, x.bounds.size.height - 80, x.bounds.size.width / 2.0, 40)
        l4.textAlignment = .right
        l4.font = .systemFont(ofSize: 18)
        l4.numberOfLines = 0
        l4.lineBreakMode = .byWordWrapping
        l4.textColor = .white
        l4.tag = 113
        x.addSubview(l4)
        
        view.addSubview(x)
        
        self.standbySubs.append(StandbyModeService.shared.$isRunning.sink  { [weak self] running in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !running {
                    updateStandbyMessage(message: "Waiting for the action.")
                    if let x = view.viewWithTag(standbyViewTag) {
                        if let v = x.viewWithTag(sleepImageTag) {
                            v.layer.removeAllAnimations()
                        }
                    }
                } else {
                    if let x = view.viewWithTag(standbyViewTag) {
                        if let v = x.viewWithTag(sleepImageTag) {
                            UIView.animate(withDuration: 2.0,
                                           delay: 0,
                                           options: [.autoreverse, .repeat],
                                           animations: {
                                v.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                            }, completion: nil)
                        }
                    }
                }
            }
        })
        
        self.standbySubs.append(StandbyModeService.shared.$standbyMessage.sink  { [weak self] message in
            guard let self else { return }
            updateStandbyMessage(message: message)
        })
    }
    
    func updateStandbyMessage(message:String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let v = self.view.viewWithTag(standbyViewTag) {
                if let v2 = v.viewWithTag(111) as? UILabel {
                    v2.text = message
                }
            }
        }
    }
    
    func positionViewsInVC(size:CGSize) {
        if let orientation = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.interfaceOrientation {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                updateOrientation(interfaceOrientation: orientation)
                CamTool.shared.transitionToSize(size: size, orientation: orientation)
                positionViews(hidden: false, forSize: size)
                moveSubViews(forSize: size)
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        precondition(Thread.isMainThread)
        super.viewWillTransition(to: size, with: coordinator)
      
 
        torchUI?.removeFromSuperview()
        flashUI?.removeFromSuperview()
        
        if let p = CamTool.shared.getPreviewView() {
            p.frame = CGRectMake(0, 0, size.width, size.height)
        }
        
        if let p = CamTool.shared.getPreviewLayer() {
            p.frame = CGRectMake(0, 0, size.width, size.height)
        }
        
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                guard let self else { return }
                if let orientation = UIApplication.shared.connectedScenes
                    .filter({$0.activationState == .foregroundActive})
                    .compactMap({$0 as? UIWindowScene})
                    .first?.interfaceOrientation {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        updateOrientation(interfaceOrientation: orientation)
                        CamTool.shared.transitionToSize(size: size, orientation: orientation)
                        positionViews(hidden: false, forSize: size)
                        moveSubViews(forSize: size)
                        if self.view.viewWithTag(standbyViewTag) != nil {
                            showStandby()
                        }
                        focusReticle.frame = CGRectMake(view.frame.size.width * 0.33 - 30, view.frame.size.height * 0.50 - 30, 60, 60)
                        exposureReticle.frame = CGRectMake(view.frame.size.width * 0.66 - 30, view.frame.size.height * 0.50 - 30, 60, 60)
                        CamTool.shared.getCameraDeviceFocus().userUpdatedPOI(poi: CGPointMake(0.33, 0.5))
                        CamTool.shared.getCameraDeviceExposure().userUpdatedPOI(poi: CGPointMake(0.66, 0.5))
                    }
                }
            }, completion: nil
        )
    }
    
    func updateOrientation(interfaceOrientation:UIInterfaceOrientation) {
        precondition(Thread.isMainThread)
        statusBarOrientation = interfaceOrientation
        let encoderData = VideoEncoderSharedData(sourceOrientation: interfaceOrientation)
        Task {
            await VideoStreamServer.shared.update(transformData: encoderData)
        }
    }
    
    private func orientationMask(from orientation: UIInterfaceOrientation) -> UIInterfaceOrientationMask {
        precondition(Thread.isMainThread)
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .all
        }
    }
    
    private func lockCurrentOrientation(lock:Bool) {
        precondition(Thread.isMainThread)
        var updatedOrientation:UIInterfaceOrientationMask = .landscapeLeft
        if lock {
            updatedOrientation = orientationMask(from: statusBarOrientation)
        } else {
            updatedOrientation = .all
        }
        supportedOrientations = updatedOrientation
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    private func lockOrientationTo(mask:UIInterfaceOrientationMask) {
        precondition(Thread.isMainThread)
        supportedOrientations = mask
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    private func stopAndRemoveStandby() {
        if StandbyModeService.shared.isRunning {
            StandbyModeService.shared.stop()
            Task {
                await CommandServer.shared.standbyModeOps(isRunning: false)
            }
        }
        
        if let v = self.view.viewWithTag(standbyViewTag) {
            v.removeFromSuperview()
            Task {
                await CommandServer.shared.standbyMode(isOn: false)
            }
        }
    }
    
    private func displayAnyUserMessage() {
        precondition(Thread.isMainThread)
        if animator.items(in: self.view.bounds).count < 1 {
            Task {
                if let message = await UserMessagingService.shared.pull() {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        if animator.items(in: self.view.bounds).count > 0 {
                            return //Already animating
                        }
                        let animatedView = NewUserRequestView(frame: CGRectMake(100, -200, 300, 300),
                                                              directorIn: message.director,
                                                              message: message.text)
                        self.view.addSubview(animatedView)
                        self.view.bringSubviewToFront(animatedView)
                        
                        let gravity = UIGravityBehavior(items: [animatedView])
                        gravity.gravityDirection = .init(dx: 0, dy: 1)
                        gravity.magnitude = 1.0
                        let collision = UICollisionBehavior(items: [animatedView])
                        collision.addBoundary(withIdentifier: "collisionLine" as NSCopying,
                                              from: CGPoint(x: 0, y: 360),
                                              to: CGPoint(x: view.bounds.width, y: 360))
                        
                        animator.addBehavior(collision)
                        animator.addBehavior(gravity)
                    }
                }
            }
        }
    }
    
    private func startup() {
        Logger.shared.info("viewDidAppear main path.")
        UIApplication.shared.isIdleTimerDisabled = true
        var modeId = SettingsService.shared.settings.currentModeId
        if modeId == "" {
            modeId = ModeHandler.shared.defaultModes.updateSettingsWithDefaultMode() ?? ""
            Logger.shared.info("Creating initial modes.")
            if modeId == "" {
                Logger.shared.error("Attempt to load a mode without asetting a currentModeId first.")
            }
        }
        Logger.shared.info("Will enter foreground with pubWillEnterForeground event.")
        if SettingsService.shared.settings.needsOnboarding { return }
        if SettingsService.shared.settings.runServer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
                ServerKeys.startServer()
            })
        }
        self.view.layoutSubviews()
        if let p = CamTool.shared.getPreviewView() {
            p.alpha = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            guard let self else { return }
            if let orientation = UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .compactMap({$0 as? UIWindowScene})
                .first?.interfaceOrientation {
                updateOrientation(interfaceOrientation: orientation)
            }
            positionViewsInVC(size: view.frame.size)
     
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: { [weak self] in
            guard let self else { return }
            if let p = CamTool.shared.getPreviewView() {
                p.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)
            }
            
            if let p = CamTool.shared.getPreviewLayer() {
                p.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)
            }
            switchToMode(uuid: SettingsService.shared.settings.currentModeId)
        })
    }
    
    private func releaseAnyUserMessage() {
        if let messageView = self.view.viewWithTag(newUserRequestViewTag) {
            animator.removeAllBehaviors()
            let gravity = UIGravityBehavior(items: [messageView])
            gravity.gravityDirection = .init(dx: 0, dy: 1)
            gravity.magnitude = 1.0
            animator.addBehavior(gravity)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: { [weak self] in
                guard let self else { return }
                precondition(Thread.isMainThread)
                animator.removeAllBehaviors()
                messageView.removeFromSuperview()
                displayAnyUserMessage()
            })
        }
    }
                                          
    private func setupSubscribers() {
        precondition(Thread.isMainThread)
        subscriptions.removeAll()

        subscriptions.append(PubCentral.shared.$releaseUserMessageView.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            releaseAnyUserMessage()
        })
        
        subscriptions.append(PubCentral.shared.$userMessageIndex.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            displayAnyUserMessage()
        })
        
        subscriptions.append(PubCentral.shared.pubOrientationLockToMask.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            guard let mask = value.userInfo?["orientation"] as? UIInterfaceOrientationMask else {
                Logger.shared.error("Invalid orientation in pubOrientationLockToMask")
                return
            }
            lockOrientationTo(mask: mask)
        })
        
        subscriptions.append(PubCentral.shared.pubOrientationLockToCurrent.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            guard let locked = value.userInfo?["orientation"] as? Bool else {
                return
            }
            lockCurrentOrientation(lock:locked)
        })
        
        subscriptions.append(PubCentral.shared.pubOnboardingComplete.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            SettingsService.shared.settings.needsOnboarding = false
            SettingsService.shared.save()
            presentedViewController?.dismiss(animated: true, completion: { })
        })
        
        subscriptions.append(PubCentral.shared.pubHandleNewMode.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            presentedViewController?.dismiss(animated: true, completion: { })
        })
        
        subscriptions.append(PubCentral.shared.pubModeSwitch.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            UIApplication.shared.isIdleTimerDisabled = true
            let modeId = SettingsService.shared.settings.currentModeId
            if modeId == "" {
               Logger.shared.error("Attempt to load a mode without asetting a currentModeId first.")
            }
            stopAndRemoveStandby()
            Logger.shared.info("pubModeSwitch:\(modeId)")
            switchToMode(uuid: SettingsService.shared.settings.currentModeId)
        })

        subscriptions.append(PubCentral.shared.pubCameraOperationsStop.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            if CamTool.shared.isSessionRunning() { CamTool.shared.stopSession() }
            mainControlView.recordingStatus(isRecording: false)
        })
        
        subscriptions.append(PubCentral.shared.pubCameraOperationsStart.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            stopAndRemoveStandby()
            if !CamTool.shared.isSessionRunning() {
                let m = SettingsService.shared.settings.currentModeId
                if let mode = ModeHandler.shared.mainBundleModeWithUUID(uuid: m) {
                    switchToMode(uuid: mode.uuid)
                } else {
                    Logger.shared.error("Unable to find mode: \(m)")
                }
            }
        })
        
        subscriptions.append(PubCentral.shared.pubCameraOperationsBeginRecording.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            if CamTool.shared.getCameraTech() != .photo  {
                lockCurrentOrientation(lock:true)
            }
 
            CamTool.shared.beginRecording()
        })
        
        subscriptions.append(PubCentral.shared.pubCameraOperationsEndRecording.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            if CamTool.shared.getCameraTech() != .photo  {
                lockCurrentOrientation(lock:false)
            }
            CamTool.shared.endRecording()
            mainControlView.recordingStatus(isRecording: false)
        })
        
        subscriptions.append(PubCentral.shared.pubUtilityPagesSettings.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            let newpage = UIHostingController(rootView: SettingsPageView())
            newpage.modalPresentationStyle = .fullScreen
            newpage.isModalInPresentation = true
            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
            present(newpage, animated: true, completion:{
            })
        })
        
        subscriptions.append(PubCentral.shared.pubUtilityPagesLibrary.receive(on: DispatchQueue.main).sink {  [weak self] value in
            guard let self else { return }
            DispatchQueue.main.async {  [weak self] in
                guard let self else { return }
                let newpage = UIHostingController(rootView: LibraryPageView())
                newpage.modalPresentationStyle = .fullScreen
                newpage.isModalInPresentation = true
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
                present(newpage, animated: true, completion:{
                })
            }
        })
        
        subscriptions.append(PubCentral.shared.pubDidActivateNotification.receive(on: DispatchQueue.main).sink { value in
            
        })
        
        subscriptions.append(PubCentral.shared.pubOrientationDidChangeNotification.receive(on: DispatchQueue.main).sink { value in
            
        })
        
        subscriptions.append(PubCentral.shared.pubShowtorchUI.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            
            if let torchUI {
                torchUI.removeFromSuperview()
                self.torchUI = nil
            } else if let flashUI {
                flashUI.removeFromSuperview()
                self.flashUI = nil
            } else {
                let torchSize = CGSizeMake(240,60)
                if let f = CamTool.shared.getPreviewView()?.frame {
                    let torchButtonPos = sideStripB.getTorchButtonPosition()
                    let isLandscape = view.frame.size.width > view.frame.size.height
                    if CamTool.shared.getCameraTech() == .photo {
                        flashUI = FlashUI(frame: CGRectMake(f.size.width + f.origin.x - torchSize.width - (isLandscape ? 0 : 50), f.origin.y + torchButtonPos.y + 10, torchSize.width, torchSize.height))
                        if let flashUI {
                            view.addSubview(flashUI)
                            view.bringSubviewToFront(flashUI)
                        }
                    } else {
                        torchUI = TorchUI(frame: CGRectMake(f.size.width + f.origin.x - torchSize.width - (isLandscape ? 0 : 50), f.origin.y + torchButtonPos.y + 10, torchSize.width, torchSize.height))
                        if let torchUI {
                            view.addSubview(torchUI)
                            view.bringSubviewToFront(torchUI)
                        }
                    }
                }
            }
        })
        
        subscriptions.append(PubCentral.shared.pubShowVizToolsUI.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            if let vizToolsUI {
                vizToolsUI.removeFromSuperview()
                self.vizToolsUI = nil
            } else {
                vizToolsUI = VizToolsUI(frame: CGRectMake(200, 100, 240, 40))
                if let vizToolsUI {
                    view.addSubview(vizToolsUI)
                    view.bringSubviewToFront(vizToolsUI)
                }
            }
        })
        
        subscriptions.append(PubCentral.shared.pubEnterBackground.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            if SettingsService.shared.settings.runServer {
                ServerKeys.stopServer()
            }
            if CamTool.shared.isCurrentlyRecording {
                NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
                })
            } else {
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
            }
            stopAndRemoveStandby()
            Logger.shared.info("Entered background with pubEnterBackground event.")
        })
        
        subscriptions.append(PubCentral.shared.pubWillEnterForeground.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            startup()
        })
        
        subscriptions.append(PubCentral.shared.pubFlashScreen.receive(on: DispatchQueue.main).sink { [weak self] _ in
            guard let self else { return }
            flashScreen()
        })
        
        subscriptions.append(PubCentral.shared.pubSessionWasInterrupted.receive(on: DispatchQueue.main).sink { _ in
            Logger.shared.info("Interrupted with pubSessionWasInterrupted event.")
            if CamTool.shared.isCurrentlyRecording {
                Logger.shared.info("Recording was interrupted with this pubSessionWasInterrupted event.")
                NotificationCenter.default.post(name: Notification.Name.CameraOperations.endRecording, object: nil)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: { [weak self] in
                    guard let self else { return }
                    DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
                    mainControlView.recordingStatus(isRecording: false)
                })
            } else {
                DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
            }
        })
        
        subscriptions.append(PubCentral.shared.pubStandby.receive(on: DispatchQueue.main).sink { [weak self] value in
            guard let self else { return }
            UIApplication.shared.isIdleTimerDisabled = true
            DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.CameraOperations.stop, object: nil) }
            showStandby()
            Task {
                await CommandServer.shared.standbyMode(isOn: true)
                await CommandServer.shared.standbyModeOps(isRunning: true)
            }
            StandbyModeService.shared.start()
        })
        
        subscriptions.append(PubCentral.shared.pubStandbyOpsComplete.receive(on: DispatchQueue.main).sink { _ in
            Task {
                await CommandServer.shared.standbyModeOps(isRunning: false)
            }
        })
        
        subscriptions.append(PubCentral.shared.pubDroppedFrame.receive(on: DispatchQueue.main).sink { _ in
           
        })
    
    }
    
    private func flashScreen() {
        precondition(Thread.isMainThread)
        let flashView = UIView(frame: view.frame)
        view.addSubview(flashView)
        flashView.backgroundColor = .black
        flashView.layer.opacity = 1
        UIView.animate(withDuration: 0.25, animations: {
            flashView.layer.opacity = 0
        }, completion: { _ in
            flashView.removeFromSuperview()
        })
    }
    
    private func positionViews(hidden:Bool, forSize:CGSize) {
        precondition(Thread.isMainThread)
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        wrangler.setupViewsFor(useFlavor: isIpad ? .iPad : .iPhone, screenMode: .previewUnderlayUI, forSize: forSize , forHand: .right)
        if hidden {
            for v in [CamTool.shared.getVisualizer(), topStrip, sideStripA, sideStripB, modeInfo, mainControlView] {
                v.frame = CGRectZero
            }
            torchUI?.frame = .zero
            flashUI?.frame = .zero
            vizToolsUI?.frame = .zero
        } else {
            mainControlView.frame = wrangler.frameForView(whichOne: .mainControls)
            CamTool.shared.getVisualizer().frame = wrangler.frameForView(whichOne: .visualizer)
            topStrip.frame = wrangler.frameForView(whichOne: .topStrip)
            sideStripA.frame = wrangler.frameForView(whichOne: .sideStripA)
            sideStripB.frame = wrangler.frameForView(whichOne: .sideStripB)
            modeInfo.frame = wrangler.frameForView(whichOne: .modeInfo)
            torchUI?.frame = wrangler.frameForView(whichOne: .torchUI)
            flashUI?.frame = wrangler.frameForView(whichOne: .torchUI)
            vizToolsUI?.frame = wrangler.frameForView(whichOne: .vizToolsUI)
            modeInfo.setup(multiLine: isIpad)
        }
        
        if let p = CamTool.shared.getPreviewView() { view.bringSubviewToFront(p) }
        
        for v in [CamTool.shared.getVisualizer(), topStrip, sideStripA, sideStripB, modeInfo, mainControlView] {
            view.bringSubviewToFront(v)
        }
        
        if let v = CamTool.shared.getPreviewView() {
            v.frame = wrangler.frameForView(whichOne: .preview)
            view.sendSubviewToBack(v)
            Logger.shared.info("Using preview view.")
        }
        
        if let v = CamTool.shared.getPreviewLayer() {
            v.frame = wrangler.frameForView(whichOne: .preview)
            Logger.shared.info("Using preview layer.")
        }
        
        if SettingsService.shared.settings.leftHandOperation {
            let f = sideStripB.frame
            sideStripB.frame = sideStripA.frame
            sideStripA.frame = f
        }
        
    }
    
    private func setupPreview() {
        precondition(Thread.isMainThread)
        if CamTool.shared.getCameraTech() == .movie {
            if let p = CamTool.shared.getPreviewLayer() {
                p.frame = view.frame
                view.layer.addSublayer(p)
            }
        } else {
            if let p = CamTool.shared.getPreviewLayer() {
                p.removeFromSuperlayer()
            }
        }
        
        if (CamTool.shared.getCameraTech() == .cifilter) || (CamTool.shared.getCameraTech() == .photo) {
            if let p = CamTool.shared.makePreviewView(frame: view.frame) {
                view.addSubview(p)
            }
        } else {
            if let p = CamTool.shared.getPreviewView() {
                p.removeFromSuperview()
            }
        }
    }
    
    private func setupControlSubscriptions() {
        precondition(Thread.isMainThread)
        topStrip.setupSubscriptions()
        focusReticle.setupSubscribers()
        exposureReticle.setupSubscribers()
        modeInfo.setupSubscribers()
    }
    
    private func setupControlViews() {
        precondition(Thread.isMainThread)
        for v in [CamTool.shared.getVisualizer(), topStrip, sideStripA, sideStripB, mainControlView, exposureReticle, focusReticle, modeInfo] {
            view.addSubview(v)
            view.bringSubviewToFront(v)
            v.backgroundColor = UIColor.clear
        }
    }
    
    private func moveSubViews(forSize:CGSize) {
        precondition(Thread.isMainThread)
        let isLandscape = forSize.width > forSize.height
        let isIpad = UIDevice.current.userInterfaceIdiom == .pad
        let isPortraitiPhone = (!isIpad) && (!isLandscape)
        topStrip.setupViews(isPortraitiPhone: isPortraitiPhone)
        sideStripA.setupViews(isPortraitiPhone: isPortraitiPhone)
        sideStripB.setup()
        modeInfo.setup( multiLine: (!isLandscape) && isIpad ) //Portrait mode iphone gets modeInfo in bottom left
        mainControlView.setup()
    }
    
    static func currentWindowInterfaceOrientation() -> UIInterfaceOrientation {
        precondition(Thread.isMainThread)
        if let scene = UIApplication.shared.connectedScenes.first {
            if let windowScene = scene.inputView?.window?.windowScene {
                return windowScene.interfaceOrientation
            }
        }
        return UIInterfaceOrientation.unknown
    }
}

