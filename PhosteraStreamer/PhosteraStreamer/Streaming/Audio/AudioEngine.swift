//
//  AudioTool.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/8/23.
//

import Foundation
import AVFoundation

class AudioTool {
    static var shared = AudioTool()
    
    var audioEngine:AVAudioEngine?
    var inputNode: AVAudioInputNode?
    var mixerNode:AVAudioMixerNode?
    var mediaNode:AVAudioPlayerNode = AVAudioPlayerNode()
    //var cameraNode:AVAudioPlayerNode = AVAudioPlayerNode()
//var cameraMixer:AVAudioMixerNode = AVAudioMixerNode()
    
    private var audioWriter:AudioWriter?
    
    func play(media:AVAudioPCMBuffer) {
        mediaNode.scheduleBuffer(media)
    }
    
    
    func play(camera:AVAudioPCMBuffer) {
      //  cameraNode.scheduleBuffer(camera)
    }
    
    func listAvailableInputs() -> [AVAudioSessionPortDescription]? {
        return AVAudioSession.sharedInstance().availableInputs
    }
    
    func chooseInput(with portDescription: AVAudioSessionPortDescription) {
        do {
            try AVAudioSession.sharedInstance().setPreferredInput(portDescription)
        } catch {
            print("Unable to set preferred input: \(error.localizedDescription)")
        }
    }
  
    func chooseFirstInput() {
        if let list = listAvailableInputs() {
            if let f = list.first {
                chooseInput(with: f)
            }
        }
    }
    
    var dCount = 10000
    
    func startEngine() {
        audioEngine = AVAudioEngine()
        mixerNode = AVAudioMixerNode()
        
        guard let audioEngine else { return }
        guard let mixerNode else { return }
        
        audioEngine.attach(mediaNode)
        audioEngine.attach(mixerNode)
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        let mainMixerNode = audioEngine.mainMixerNode
        let mixerFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)
        
        guard let mixerFormat else { return }
        
        audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
        audioEngine.connect(mediaNode, to: mixerNode, format: mixerFormat)
        
        audioEngine.connect(mixerNode, to: mainMixerNode, format: mixerFormat)
        mixerNode.volume = 1.0
        mainMixerNode.volume = 1.0
        inputNode.volume = 1.0
        mainMixerNode.outputVolume = 1.0
        mixerNode.outputVolume = 1.0
        mixerNode.installTap(onBus: 0, bufferSize: 4096, format: mixerFormat) { [weak self] (buffer, time) in
            guard let self else { return }
            audioWriter?.write(buffer: buffer, time: time)
            //let t = FrameTimer.shared.nextAudioTimestamp(samples: 4096)
            MetalTool.shared.streamer.acceptAudioBuffer(buffer: buffer, when: time)
            dCount += 1
            
            if dCount > 9999 {
                printAudioFormat(format: mixerFormat, title: "mixerFormat")
                printAudioFormat(format: inputNode.inputFormat(forBus: 0), title: "inputNode.input")
                printAudioFormat(format: inputNode.outputFormat(forBus: 0), title: "inputNode.output")
                printAudioFormat(format: mediaNode.outputFormat(forBus: 0), title: "mediaNode.output")
                dCount = 0
            }
        }
      
        do {
            try audioEngine.start()
        } catch {
            print("Could not start the audio engine: \(error.localizedDescription)")
        }
        
        mediaNode.play()
       // cameraNode.play()
    }
    
    func printAudioFormat(format:AVAudioFormat, title:String) {
        let channelCount = format.channelCount
        let sampleRate = format.sampleRate
        let commonFormat = format.commonFormat
        let interleaved = format.isInterleaved
        let settings = format.settings
        let formatSettings = format.settings
        let asbd = formatSettings[AVLinearPCMBitDepthKey] as? Int ?? 0
        Logger.shared.info("Audio Format:\(title) - Channel Count: \(channelCount), Sample Rate: \(sampleRate), Common Format: \(commonFormat), Is Interleaved: \(interleaved), All Settings: \(settings), PCM Bit Depth: \(asbd)")
    }
    
    func stopEngine() {
        guard let audioEngine else { return }
        mediaNode.stop()
     //   cameraNode.stop()
        audioEngine.stop()
    }
    
    func adjustInputVolume(level:Float) {
        Logger.shared.info("Adjust input volume: \(level)")
        audioEngine?.inputNode.volume = level
    }
    
    func adjustMediaVolume(level:Float) {
        Logger.shared.info("Adjust media volume: \(level)")
        mediaNode.volume = level
    }
    
    func startWriter(url:URL) {
        guard let audioEngine else { return }
        let mainMixerNode = audioEngine.mainMixerNode
        let format = mainMixerNode.outputFormat(forBus: 0)
        audioWriter = nil
        if let writer = AudioWriter(outputURL: url, format: format) {
            writer.startWriting()
            audioWriter = writer
        }
    }
    
    func write(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        audioWriter?.write(buffer: buffer, time: time)
    }
    
    func stopWriting() {
        audioWriter?.stopWriting()
        audioWriter = nil
    }
}
