//
//  AudioController.swift
//  Phostera Camera
//
//  Created by Gary Barnett on 7/6/23.
//

import AVFoundation
import Combine
import PhosteraShared

// The enumeration to normalize UIInterfaceOrientation and AVAudioSession.StereoOrientation.
enum Orientation: Int {
    case unknown = 0
    case portrait = 1
    case portraitUpsideDown = 2
    case landscapeLeft = 4
    case landscapeRight = 3
}

fileprivate extension Orientation {
    // The convenience property to retrieve the AVAudioSession.StereoOrientation.
    var inputOrientation: AVAudioSession.StereoOrientation {
        return AVAudioSession.StereoOrientation(rawValue: rawValue)!
    }
}

enum AudioControllerState {
    case stopped
    case playing
    case recording
}

struct RecordingOption: Comparable {
    let name: String
    fileprivate let dataSourceName: String
    static func < (lhs: RecordingOption, rhs: RecordingOption) -> Bool {
        lhs.name < rhs.name
    }
}

class AudioController: NSObject {
    static var shared = AudioController()
    var audioEngine = AVAudioEngine()
    
    var isStereoSupported = false
    
    static var recordingOptions: [RecordingOption] = {
        let front = AVAudioSession.Orientation.front
        let back = AVAudioSession.Orientation.back
        let bottom = AVAudioSession.Orientation.bottom
        
        let session = AVAudioSession.sharedInstance()
        guard let dataSources = session.preferredInput?.dataSources else { return [] }
        
        var options = [RecordingOption]()
        dataSources.forEach { dataSource in
            switch dataSource.orientation {
            case front:
                options.append(RecordingOption(name: "Front Stereo", dataSourceName: front.rawValue))
            case back:
                options.append(RecordingOption(name: "Back Stereo", dataSourceName: back.rawValue))
            case bottom:
                options.append(RecordingOption(name: "Mono", dataSourceName: bottom.rawValue))
            default: ()
            }
        }
        // Sort alphabetically.
        options.sort()
        return options
    }()
    
    var isDeviceSupported: Bool {
        return AudioController.recordingOptions.count >= 3
    }
    
    private(set) var state = AudioControllerState.stopped
    
    override init() {
        super.init()
       
        setupAudioSession()
        enableBuiltInMic()
        setupAudioEngine()
    }
    
    // MARK: - Audio Session Configuration
    func setupAudioSession() {
        Logger.shared.info("setupAudioSession")
        let session = AVAudioSession.sharedInstance()
        do {  try session.setCategory(.playAndRecord, options: [.allowBluetooth]) } catch { Logger.shared.info("setupAudioSession fail1"); return }
        do {  try session.setPreferredSampleRate(48000) } catch { Logger.shared.info("setupAudioSession fail2b"); return }
        do {  try session.setPreferredInputNumberOfChannels(session.maximumInputNumberOfChannels) } catch { Logger.shared.info("setupAudioSession fail2"); return }
        do {  try session.setPreferredOutputNumberOfChannels(session.maximumOutputNumberOfChannels) } catch { Logger.shared.info("setupAudioSession fail3"); return }
        do {  try session.setActive(true) } catch { Logger.shared.info("setupAudioSession fail4"); return }
        Logger.shared.info("setupAudioSession Complete")
    }
    
    private func enableBuiltInMic() {
        // Get the shared audio session.
        let session = AVAudioSession.sharedInstance()
        
        // Find the built-in microphone input.
        guard let availableInputs = session.availableInputs,
              let builtInMicInput = availableInputs.first(where: { $0.portType == .builtInMic }) else {
            Logger.shared.error("The device must have a built-in microphone.")
            return
        }
        
        // Make the built-in microphone input the preferred input.
        do {
            try session.setPreferredInput(builtInMicInput)
        } catch {
            Logger.shared.error("Unable to set the built-in mic as the preferred input.")
        }
    }
    
    func startup() {
    }
    
    func stop() {
  
    }
    
    static func hasPermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }
    
    static func hasPermissionDenied() -> Bool {
        return AVAudioApplication.shared.recordPermission == .denied
    }
    
    static func requestPermission() {
        if (!hasPermission()) && (!hasPermissionDenied()) {
            AVAudioApplication.requestRecordPermission() {_ in
                DispatchQueue.main.async { NotificationCenter.default.post(name: .audioAccessChanged, object: nil) }
            }
        }
    }
    
    private var publishers:[AnyCancellable?] = [AnyCancellable?]()
    
    func setupPublishers() {
        self.publishers.removeAll()
    }

    func selectRecordingOption(_ option: RecordingOption, orientation: Orientation, completion: (StereoLayout) -> Void) {
        
        // Get the shared audio session.
        let session = AVAudioSession.sharedInstance()
        
        // Find the built-in microphone input's data sources,
        // and select the one that matches the specified name.
        guard let preferredInput = session.preferredInput,
              let dataSources = preferredInput.dataSources,
              let newDataSource = dataSources.first(where: { $0.dataSourceName == option.dataSourceName }),
              let supportedPolarPatterns = newDataSource.supportedPolarPatterns else {
            completion(.none)
            return
        }
        
        do {
            isStereoSupported = supportedPolarPatterns.contains(.stereo)
            // If the data source supports stereo, set it as the preferred polar pattern.
            if isStereoSupported {
                // Set the preferred polar pattern to stereo.
                try newDataSource.setPreferredPolarPattern(.stereo)
            }
            
            // Set the preferred data source and polar pattern.
            try preferredInput.setPreferredDataSource(newDataSource)
            
            // Update the input orientation to match the current user interface orientation.
            try session.setPreferredInputOrientation(orientation.inputOrientation)
            
        } catch {
            fatalError("Unable to select the \(option.dataSourceName) data source.")
        }
        
        // Call the completion handler with the updated stereo layout.
        completion(StereoLayout(orientation: newDataSource.orientation!,
                                stereoOrientation: session.inputOrientation))
    }
    
    
    func setupAudioEngine() {
//        let mixer = audioEngine.inputNode
//        let format = mixer.outputFormat(forBus: 0)
//    
//        do {
//            try audioEngine.start()
//        } catch {
//            Logger.shared.error("Couldn't start the audio engine.")
//        }
    }
    
    
    
}

