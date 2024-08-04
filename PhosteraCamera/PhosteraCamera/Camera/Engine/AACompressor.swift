////
////  AACompressor.swift
////  PhosteraCamera
////
////  Created by Gary Barnett on 9/21/23.
////
//
//import Foundation
//import AudioToolbox
//
//import AudioToolbox
//
//class BufferManager {
//    var pcmData: Data
//    init(pcmBuffer: [Float]) {
//        self.pcmData = Data(bytes: pcmBuffer, count: pcmBuffer.count * MemoryLayout<Float>.size)
//    }
//}
//
//func audioConverterComplexInputDataProc(
//    _ audioConverter: AudioConverterRef,
//    _ ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
//    _ ioData: UnsafeMutablePointer<AudioBufferList>,
//    _ outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
//    _ inUserData: UnsafeMutableRawPointer?
//) -> OSStatus {
//    guard let inUserData = inUserData else { return -1 }
//    let bufferManager = Unmanaged<BufferManager>.fromOpaque(inUserData).takeUnretainedValue()
//    bufferManager.pcmData.withUnsafeBytes { rawBufferPointer in
//        ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: rawBufferPointer.baseAddress!)
//        ioData.pointee.mBuffers.mDataByteSize = UInt32(bufferManager.pcmData.count)
//    }
//    return noErr
//}
//
//class AACAudioStreamer {
//    private var audioConverter: AudioConverterRef?
//    private var aacFormat = AudioStreamBasicDescription()
//    private var pcmFormat = AudioStreamBasicDescription()
//
//    init(pcmFormat: AudioStreamBasicDescription, aacFormat: AudioStreamBasicDescription) {
//        self.pcmFormat = pcmFormat
//        self.aacFormat = aacFormat
//        let result = AudioConverterNew(&self.pcmFormat, &self.aacFormat, &self.audioConverter)
//        if result != noErr {
//            Logger.shared.error("Error initializing AudioConverter")
//        }
//    }
//    
//    func getMagicCookie() -> Data? {
//        guard let audioConverter else { return nil }
//        var cookieSize: UInt32 = 0
//        var status = AudioConverterGetPropertyInfo(audioConverter, kAudioConverterCompressionMagicCookie, &cookieSize, nil)
//        
//        if status != noErr {
//            Logger.shared.error("Error getting magic cookie size.")
//            return nil
//        }
//        
//        if cookieSize == 0 {
//            return nil
//        }
//        
//        let cookie = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(cookieSize))
//        defer {
//            cookie.deallocate()
//        }
//
//        status = AudioConverterGetProperty(audioConverter, kAudioConverterCompressionMagicCookie, &cookieSize, cookie)
//        
//        if status != noErr {
//            Logger.shared.error("Error getting magic cookie.")
//            return nil
//        }
//        
//        return Data(bytes: cookie, count: Int(cookieSize))
//    }
//
//    func convertPCMBufferToAAC(pcmBuffer: [Float], completion: @escaping (Data?) -> Void) {
//        let outputBufferSize = 4096
//        let outputBuffer = UnsafeMutableRawPointer.allocate(byteCount: outputBufferSize, alignment: 1)
//        
//        let outputAudioBuffer = AudioBuffer(
//            mNumberChannels: aacFormat.mChannelsPerFrame,
//            mDataByteSize: UInt32(outputBufferSize),
//            mData: outputBuffer
//        )
//        
//        var outputBufferList = AudioBufferList(
//            mNumberBuffers: 1,
//            mBuffers: outputAudioBuffer
//        )
//        
//        var ioOutputDataPackets: UInt32 = 1
//
//        let bufferManager = BufferManager(pcmBuffer: pcmBuffer)
//        let userData = Unmanaged.passUnretained(bufferManager).toOpaque()
//        
//        let outputStatus = AudioConverterFillComplexBuffer(
//            audioConverter!,
//            audioConverterComplexInputDataProc,
//            userData,
//            &ioOutputDataPackets,
//            &outputBufferList,
//            nil
//        )
//        
//        if outputStatus == noErr {
//            let outputData = Data(bytes: outputBuffer, count: Int(outputBufferList.mBuffers.mDataByteSize))
//            completion(outputData)
//        } else {
//            Logger.shared.error("Failed to convert audio")
//            completion(nil)
//        }
//        
//        outputBuffer.deallocate()
//    }
//
//}
//
//
//
//
//
//
//
