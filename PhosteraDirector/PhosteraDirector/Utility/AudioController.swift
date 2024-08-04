//
//  AudioController.swift
//  PhosteraDirector
//
//  Created by Gary Barnett on 9/1/23.
//

import Foundation
import AVFAudio
import zlib

//Setup and play samples as given
class AudioController {
    static var shared = AudioController()
    let audioEngine = AVAudioEngine()
    var node1:AVAudioPlayerNode?
    var formatConverter:AVAudioConverter?
    
    func decompressData(_ compressedData: Data, frameCount: Int) -> [Float32]? {
        // Initialize zlib stream
        var zStream = z_stream()
        inflateInit_(&zStream, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        
        var decompressedBuffer = [Float32](repeating: 0, count: frameCount)
        var resultBuffer: [Float32]?

        compressedData.withUnsafeBytes { compressedBytes -> Void in
            var localBuffer = Array<Float32>(repeating: 0, count: frameCount)
            
            localBuffer.withUnsafeMutableBytes { localBytes in
                // Set up z_stream
                zStream.next_in = UnsafeMutablePointer(mutating: compressedBytes.bindMemory(to: UInt8.self).baseAddress!)
                zStream.avail_in = uInt(compressedData.count)
                zStream.next_out = localBytes.bindMemory(to: UInt8.self).baseAddress!
                zStream.avail_out = uInt(frameCount * MemoryLayout<Float32>.size)
                
                // Decompress
                if inflate(&zStream, Z_SYNC_FLUSH) != Z_OK {
                    // Handle decompression error
                    resultBuffer = nil
                    return
                }
            }
            
            resultBuffer = localBuffer
        }
        
        // Clean up
        inflateEnd(&zStream)
        
        if let result = resultBuffer {
            decompressedBuffer = result
            return decompressedBuffer
        }
        
        return nil
    }
    
    static func hasPermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }
    
    static func hasPermissionDenied() -> Bool {
        return AVAudioApplication.shared.recordPermission == .denied
    }
    
    static func requestPermission() {
        if (!AudioController.hasPermission()) && (!AudioController.hasPermissionDenied()) {
            AVAudioApplication.requestRecordPermission() {_ in
                DispatchQueue.main.async { NotificationCenter.default.post(name: .audioAccessChanged, object: nil) }
            }
        }
    }
    
    func start() {
        node1 = AVAudioPlayerNode()
        guard let node1 else { return }
        audioEngine.attach(node1)

        // Add your source format
        guard let formatIn = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate:48000 , channels: 2, interleaved: false) else {
            Logger.shared.error("Failed to create format")
            return
        }
        
        guard let formatOut = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false) else { Logger.shared.error("bleh"); return }
       
        
        audioEngine.connect(node1, to: audioEngine.mainMixerNode, format: formatIn)
        audioEngine.mainMixerNode.outputVolume = 1.0
        node1.volume = 1.0
        audioEngine.inputNode.volume = 1.0
        
       formatConverter = AVAudioConverter(from: formatIn, to:formatOut)
        
        do {
            
            try audioEngine.start()
        } catch {
            Logger.shared.error("Audio format didn't start: \(error.localizedDescription)")
        }
        node1.play()
    }
    
    var interval = 0

    func addAudioBuffer(uuid:String, data:Data) {
        
        guard var floatArray = decompressData(data, frameCount: 1024) else { return }
        guard let formatIn = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false) else { Logger.shared.error("bleh"); return }
        guard let bufferIn = AVAudioPCMBuffer(pcmFormat: formatIn, frameCapacity: AVAudioFrameCount(1024)) else {  return }
        bufferIn.frameLength = 1024
        
        floatArray.withUnsafeMutableBufferPointer { pointer in
            let bytePointer = UnsafeMutableRawPointer(pointer.baseAddress!).bindMemory(to: Float32.self, capacity: 1024)
            
            let chan1 = bufferIn.floatChannelData?[0]
            let chan2 = bufferIn.floatChannelData?[1]
            
            guard let chan1, let chan2 else { return }
            
            var odd:Bool = true
            var offset:Int = 0
            for x in 0..<1024 {
                if odd {
                    chan1[x] = bytePointer[x]
                } else {
                    chan2[x] = bytePointer[x]
                    offset += 1
                }
                odd = !odd
            }
        }

////        let err:NSErrorPointer = .none
////        
////        formatConverter?.convert(to: bufferOut, error: err, withInputFrom: inputBlock)
//        
        if let node = node1 {
            interval += 1
            if interval > 30 {
                interval = 0
                Logger.shared.info("engine (running:\(audioEngine.isRunning):\(audioEngine.debugDescription)")
                Logger.shared.info("node1: \(node1.debugDescription) - \(String(describing: node1?.volume))")
            }

            node.scheduleBuffer(bufferIn)
        }
   }
}


