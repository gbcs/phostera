import AVFoundation
import HaishinKit
import Photos
import UIKit
import VideoToolbox
import PhosteraShared
import Combine

final class Streamer: NSObject {
    private static let maxRetryCount: Int = 5
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var sharedObject: RTMPSharedObject!
    private var currentEffect: VideoEffect?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    private var videoBitRate = 1920 * 1000
    private var preferedStereo = false
    private var streamURL:String = ""
    private var streamName:String = ""
    private var showBackgroundOnly:Bool = false
    private var recordStream:Bool = false
    private var bandwidthLimit:Double = 6800000
    
    @Published var streamState:StreamConnectionState = .offline
    
    func getBitrate() -> Int {
        return rtmpStream.videoSettings.bitRate
    }
    
    func update(bitrate:Int) {
        let rate = max(bitrate, 640000)
        Logger.shared.info("update bit rate to: \(rate)")
        rtmpStream.videoSettings.bitRate = rate
    }
    
    func play(media:FootageModel) {
        DispatchQueue.main.async { NotificationCenter.default.post(name: Notification.Name.resetMedia, object: nil) }
        let p = media.url.lastPathComponent
        let url = FootageService.footageDirectory.appending(path: p)
        if FileManager.default.fileExists(atPath: url.path) {
            MetalTool.shared.mediaPlayer.stop()
            MediaAudioPlayer.shared.stop()
            MetalTool.shared.useMediaPlayerBuffer(video: nil)
            let urlAudio = url.appendingPathExtension("caf")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                try? MediaAudioPlayer.shared.loadAudioFile(with: urlAudio)
                MetalTool.shared.startMediaBuffer()
                MetalTool.shared.mediaPlayer.playMedia(url: url, videoUUID: "video1", startTime: .zero)
            })
        }
    }
    
    func update(orientation:UIInterfaceOrientation) {
        if let o = DeviceUtil.videoOrientation(by: orientation) {
            Logger.shared.info("videoOrientation:\(o)")
            rtmpStream.videoOrientation = o
        }
    }
    
    func removeLocalMedia() {
        MetalTool.shared.mediaPlayer.stop()
        MediaAudioPlayer.shared.stop()
        MetalTool.shared.useMediaPlayerBuffer(video: nil)
    }
    
    func handleStateChangeFromEvent(project:StreamProjectModel, newState:StreamConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if MetalTool.shared.mediaShown {
                MetalTool.shared.mediaShown = false
                MediaAudioPlayer.shared.stop()
                MetalTool.shared.mediaPlayer.stop()
                MetalTool.shared.stopMediaBuffer()
            }
            switch(newState) {
            case .offline:
                if streamState != .offline {
                    streamState = .offline
                    publish(beUp: false)
                    streamState = newState
                }
            case .connection:
                if streamState != .connection {
                    streamState = newState
                    MetalTool.shared.streamer.setup(project: project)
                    publish(beUp: true)
                }
                break
            case .preroll:
                if streamState != .preroll {
                    removeLocalMedia()
                    if let media = project.mediaPreroll {
                        self.play(media: media)
                        MetalTool.shared.mediaShown = true
                    }
                }
                streamState = newState
            case .intro:
                if streamState != .intro {
                    removeLocalMedia()
                    if let media = project.mediaIntro {
                        self.play(media: media)
                        MetalTool.shared.mediaShown = true
                    }
                }
                streamState = newState
            case .paused:
                if (streamState == .live) || (streamState == .paused) {
                    if let media = project.mediaInterstitial {
                        removeLocalMedia()
                        self.play(media: media)
                        MetalTool.shared.mediaShown = true
                    }
                    
                    //MetalTool.shared.streamer.showBackgroundInStream(only: true)
                    streamState = newState
                }
                streamState = newState
            case .outro:
                if streamState == .live {
                    if let media = project.mediaOutro {
                        removeLocalMedia()
                        self.play(media: media)
                        MetalTool.shared.mediaShown = true
                    }
                }
                streamState = newState
            case .failed:
                streamState = newState
            case .live:
                streamState = newState
                removeLocalMedia()
                MetalTool.shared.mediaShown = false
                MetalTool.shared.streamer.showBackgroundInStream(only: false)
            }
        }
    }
    
    func handleStateButtonPush(project:StreamProjectModel) {
        switch(streamState) {
        case .offline:
            handleStateChangeFromEvent(project: project, newState: .connection)
        case .connection:
            handleStateChangeFromEvent(project: project, newState: .offline)
        case .preroll:
            handleStateChangeFromEvent(project: project, newState: .intro)
        case .intro:
            handleStateChangeFromEvent(project: project, newState: .live)
        case .live:
            WatchEntryManager.shared.mediaQueue.removeAll()
            if MetalTool.shared.mediaShown {
                MetalTool.shared.mediaShown = false
                MetalTool.shared.mediaPlayer.stop()
                MediaAudioPlayer.shared.stop()
                MetalTool.shared.stopMediaBuffer()
            }
            handleStateChangeFromEvent(project: project, newState: .paused)
        case .paused:
            handleStateChangeFromEvent(project: project, newState: .live)
        case .outro:
            handleStateChangeFromEvent(project: project, newState: .offline)
        case .failed:
            handleStateChangeFromEvent(project: project, newState: .connection)
        }
    }

    func showBackgroundInStream(only:Bool) {
        showBackgroundOnly = only
    }
    
    func isOffline() -> Bool {
        return streamState == .offline
    }

    var setupComplete:Bool = false
    
    func setup(project:StreamProjectModel) {
        if !setupComplete {
            rtmpConnection.delegate = self
            rtmpStream = RTMPStream(connection: rtmpConnection)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                if let orientation = DeviceUtil.videoOrientation(by: windowScene.interfaceOrientation) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        rtmpStream.videoOrientation = orientation
                    }
                }
            }
            
            rtmpStream.isMonitoringEnabled = false
            Logger.shared.info("Audio monitoring at setup is: \(rtmpStream.isMonitoringEnabled ? "enabled" : "disabled")")
            
            NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(didInterruptionNotification(_:)), name: AVAudioSession.interruptionNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(didRouteChangeNotification(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
            setupComplete = true
        }
        
        streamURL = project.config.url
        streamName = project.config.name
        recordStream = project.recordStream
        bandwidthLimit = project.maxBandwidth
        videoBitRate = Int(bandwidthLimit)
        
        var size:CGSize = .zero
       
        var startingBandwidth = bandwidthLimit
        switch project.streamResolution {
        case .v1920x1080:
            size = CGSizeMake(1920, 1080)
            if startingBandwidth > 6800000 {
                startingBandwidth = 6800000
            }
        case .v1280x720:
            size = CGSizeMake(1280, 720)
            if startingBandwidth > 4000000 {
                startingBandwidth = 4000000
            }
        case .v720x480:
            size = CGSizeMake(720, 480)
            if startingBandwidth > 1500000 {
                startingBandwidth = 1500000
            }
        case .v640x360:
            size = CGSizeMake(640, 360)
            if startingBandwidth > 1200000 {
                startingBandwidth = 1200000
            }
        }

        rtmpStream.videoSettings = VideoCodecSettings(
            videoSize: size,
            bitRate: Int(startingBandwidth),
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
            scalingMode: .trim,
            bitRateMode: .average,
            maxKeyFrameIntervalDuration: 2,
            allowFrameReordering: nil,
            isHardwareEncoderEnabled: true
        )
        
        rtmpStream.audioSettings = AudioCodecSettings(
            bitRate: 64 * 10000
        )
        
        var framerate:Float64 = 24
        switch(project.streamFrameRate) {
        case .fr24:
            framerate = 24
        case .fr25:
            framerate = 25
        case .fr30:
            framerate = 30
        }
    
        rtmpStream.frameRate = framerate
    }

    func acceptVideoSampleBuffer(buffer:CMSampleBuffer) {
        if let rtmpStream {
            rtmpStream.append(buffer)
        }
    }
    
    func acceptAudioBuffer(buffer:AVAudioPCMBuffer, when:AVAudioTime) {
        if let rtmpStream {
            rtmpStream.append(buffer, when: when)
        }
    }
    
    func shutdown() {
        Logger.shared.info("shutdown")
       
        rtmpStream.close()
        streamURL = ""
        observerInstalled = false
        NotificationCenter.default.removeObserver(self)
        setupComplete = false
    }

    var lastFPS:UInt16 = 0
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if Thread.isMainThread {
            if abs(Int(lastFPS) - Int(rtmpStream.currentFPS)) > 2 {
                lastFPS = rtmpStream.currentFPS
                Logger.shared.info("stream fps changed: \(rtmpStream.currentFPS)")
            }
        }
    }

    func isConnected() -> Bool {
        if rtmpConnection.connected { return true }
        return false
    }

    private var observerInstalled:Bool = false
    
    func publish(beUp:Bool) {
        if beUp {
            streamState = .connection
            UIApplication.shared.isIdleTimerDisabled = true
   
            if !observerInstalled {
                rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
                rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
                rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
                observerInstalled = true
            }
            
            videoBitRate = Int(bandwidthLimit)
            
            rtmpConnection.connect(streamURL)
            
            if recordStream {
                MetalTool.shared.startRecording()
            }
        } else {
            streamState = .offline
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            
            if observerInstalled {
                observerInstalled = false
                rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
                rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
                rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
            }

            if recordStream {
                MetalTool.shared.endRecording()
            }
        }
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        Logger.shared.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream.publish(streamName)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                streamState = .live
                UIApplication.shared.isIdleTimerDisabled = true
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name.remoteStreamChanged, object: nil)
                }
            }
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= Streamer.maxRetryCount else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    streamState = .failed
                    UIApplication.shared.isIdleTimerDisabled = false
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name.remoteStreamChanged, object: nil)
                    }
                }
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(streamURL)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        Logger.shared.error(notification.debugDescription)
        rtmpConnection.connect(streamURL)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            streamState = .connection
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name.remoteStreamChanged, object: nil)
            }
        }
    }

    @objc
    private func didInterruptionNotification(_ notification: Notification) {
        Logger.shared.info(notification.debugDescription)
    }

    @objc
    private func didRouteChangeNotification(_ notification: Notification) {
        Logger.shared.info(notification.debugDescription)
        rtmpStream.isMonitoringEnabled = false
//        if DeviceUtil.isHeadphoneDisconnected(notification) {
//            rtmpStream.isMonitoringEnabled = false
//        } else {
//            rtmpStream.isMonitoringEnabled = DeviceUtil.isHeadphoneConnected()
//        }
        rtmpStream.isMonitoringEnabled = false
        Logger.shared.info("Audio monitoring after route change is: \(rtmpStream.isMonitoringEnabled ? "enabled" : "disabled")")
        
        if let portName = AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName {
            Logger.shared.info("Audio port name is: \(portName)")
        }
    }

    @objc
    private func on(_ notification: Notification) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let orientation = DeviceUtil.videoOrientation(by: windowScene.interfaceOrientation) {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    rtmpStream.videoOrientation = orientation
                }
            }
        }
    }
}

extension Streamer: RTMPConnectionDelegate {
    func connection(_ connection: RTMPConnection, publishInsufficientBWOccured stream: RTMPStream) {
        videoBitRate -= 64 * 10000
        
        if videoBitRate < 640000 {
            videoBitRate = 640000
        }
    
        stream.videoSettings.bitRate = videoBitRate
        Logger.shared.info("Decreasing stream bandwidth to: \(videoBitRate)")
        let bitrate = stream.videoSettings.bitRate
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name.bandwidthReport, object: ["videoBitRate" : bitrate])
        }
    }

    func connection(_ connection: RTMPConnection, publishSufficientBWOccured stream: RTMPStream) {
//        videoBitRate += 32 * 1000
//   
//        if videoBitRate > maxBandwidth {
//            videoBitRate = Int(maxBandwidth)
//        } else {
//            Logger.shared.info("Increasing stream bandwidth to: \(videoBitRate)")
//            stream.videoSettings.bitRate = min(videoBitRate, VideoCodecSettings.default.bitRate)
//        }
//        let bitrate = stream.videoSettings.bitRate
//        DispatchQueue.main.async {
//            NotificationCenter.default.post(name: NSNotification.Name.bandwidthReport, object: ["videoBitRate" : bitrate])
//        }
    }

    func connection(_ connection: RTMPConnection, updateStats stream: RTMPStream) {
        let bitrate = stream.videoSettings.bitRate
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name.bandwidthReport, object: ["videoBitRate" : bitrate])
        }
    }

    func connection(_ connection: RTMPConnection, didClear stream: RTMPStream) {
        Logger.shared.info("clear: \(stream.debugDescription)")
    }
}

extension Streamer: IORecorderDelegate {
    func recorder(_ recorder: IORecorder, errorOccured error: IORecorder.Error) {
        Logger.shared.error(error.localizedDescription)
    }

    func recorder(_ recorder: IORecorder, finishWriting writer: AVAssetWriter) {
        Logger.shared.info("Finished writing: \(writer.outputURL)")
    }
}

