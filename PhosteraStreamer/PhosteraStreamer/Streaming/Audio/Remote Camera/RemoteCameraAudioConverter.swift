//
//  RemoteCameraAudioConverter.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/16/23.
//

import Foundation
import AVFoundation
import AudioToolbox

class RemoteCameraAudioConverter {
    
    private let audioFormat: AVAudioFormat
    
    init?() {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: false) else {
            return nil
        }
        self.audioFormat = format
    }
    
    func createPCMBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let frameCapacity = UInt32(data.count) / 4
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCapacity) else {
            return nil
        }
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        
        let byteCount = data.count
        data.withUnsafeBytes { (bytes) in
            let floatData = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            memcpy(pcmBuffer.floatChannelData?[0], floatData, byteCount)
        }
        
        return pcmBuffer
    }
}



//class RemoteCameraAudioConverter {
//    private var sourceFormat: AudioStreamBasicDescription = AudioStreamBasicDescription(
//        mSampleRate: 22050.0,
//        mFormatID: kAudioFormatLinearPCM,
//        mFormatFlags: kAudioFormatFlagIsFloat,
//        mBytesPerPacket: 4,  // Single channel, 32-bit float
//        mFramesPerPacket: 1,
//        mBytesPerFrame: 4,   // Single channel, 32-bit float
//        mChannelsPerFrame: 1,
//        mBitsPerChannel: 32,
//        mReserved: 0
//    )
//    
//   
//    private var destinationFormat: AudioStreamBasicDescription = AudioStreamBasicDescription(
//        mSampleRate: 48000.0,
//        mFormatID: kAudioFormatLinearPCM,
//        mFormatFlags: kAudioFormatFlagIsFloat,
//        mBytesPerPacket: 8,  // Stereo, 32-bit float
//        mFramesPerPacket: 1,
//        mBytesPerFrame: 8,   // Stereo, 32-bit float
//        mChannelsPerFrame: 2,
//        mBitsPerChannel: 32,
//        mReserved: 0
//    )
//    private var audioConverter: AudioConverterRef?
//    
//    init() {
//        // Adjusting the formats: source is now mono and destination is stereo
//        var converter: AudioConverterRef?
//        let status = AudioConverterNew(&sourceFormat, &destinationFormat, &converter)
//        if status != noErr {
//            Logger.shared.error("Error initializing Audio Converter for revert: \(status)")
//        } else if let converterUnwrapped = converter {
//            self.audioConverter = converterUnwrapped
//            Logger.shared.error("Audio Converter successfully initialized for revert")
//        }
//    }
//    
//    func revertConvertedData(_ convertedData: Data) -> AVAudioPCMBuffer? {
//        var data = convertedData
//        
//  
//        return data.withUnsafeMutableBytes { rawDataPointer -> AVAudioPCMBuffer? in
//            guard let sourceDataPointer = rawDataPointer.baseAddress else {
//                Logger.shared.error("Failed to get base address of converted data")
//                return nil
//            }
//            
//            let convertedBufferSize = 2048 / Int(sourceFormat.mBytesPerFrame) * Int(destinationFormat.mBytesPerFrame)
//            guard let convertedBufferPointer = malloc(convertedBufferSize) else {
//                Logger.shared.error("Failed to allocate memory for converted buffer")
//                return nil
//            }
//            defer { free(convertedBufferPointer) }
//
//            var ioOutputDataPacketSize: UInt32 = UInt32(convertedBufferSize) / destinationFormat.mBytesPerPacket
//            var outputAudioBuffer = AudioBuffer()
//            outputAudioBuffer.mData = convertedBufferPointer
//            outputAudioBuffer.mDataByteSize = UInt32(convertedBufferSize)
//            outputAudioBuffer.mNumberChannels = destinationFormat.mChannelsPerFrame
//
//            var outputBufferList = AudioBufferList()
//            outputBufferList.mNumberBuffers = 1
//            outputBufferList.mBuffers = outputAudioBuffer
//
//            
//            
//            Logger.shared.info(
//"""
//inputdata count = \(convertedData.count)
//outputbuffersize = \(convertedBufferSize)
//ioOutputDataPacketSize = \(ioOutputDataPacketSize)
//sourceFormat.mBytesPerPacket = \(sourceFormat.mBytesPerPacket)
//"""
//            )
//            
//            
//            guard let audioConverter = self.audioConverter else {
//                Logger.shared.error("Audio converter is nil")
//                return nil
//            }
//
//            let status = AudioConverterFillComplexBuffer(
//                audioConverter,
//                globalInputProc,
//                sourceDataPointer,
//                &ioOutputDataPacketSize,
//                &outputBufferList,
//                nil
//            )
//            
//            if status != noErr {
//                Logger.shared.error("Error during reverse conversion: \(status)")
//                return nil
//            }
//            
//            Logger.shared.error("Reverse conversion successful, buffer size: \(convertedBufferSize)")
//            return createPCMBuffer(from: &outputBufferList, with: destinationFormat)
//        }
//    }
//
//    
//    private func calculateOutputBufferSize(from inputBufferSize: Int) -> Int {
//            return inputBufferSize * 2
//    }
//    
//    private func createPCMBuffer(from bufferList: inout AudioBufferList, with format: AudioStreamBasicDescription) -> AVAudioPCMBuffer? {
//        var formatIn = format
//        guard let pcmFormat = AVAudioFormat(streamDescription: &formatIn) else {
//            Logger.shared.error("Failed to create AVAudioFormat")
//            return nil
//        }
//        
//        
//        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: UInt32(bufferList.mBuffers.mDataByteSize) / format.mBytesPerFrame) else {
//            Logger.shared.error("Failed to create PCM buffer")
//            return nil
//        }
//        
//        pcmBuffer.frameLength = pcmBuffer.frameCapacity
//        let channelCount = Int(format.mChannelsPerFrame)
//        
//        for channel in 0..<channelCount {
//            guard let channelData = pcmBuffer.floatChannelData?[channel] else {
//                Logger.shared.error("Failed to get channel data")
//                return nil
//            }
//            memcpy(channelData, bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self), Int(pcmBuffer.frameLength * format.mBytesPerFrame))
//        }
//        
//        Logger.shared.error("PCM buffer created successfully")
//        return pcmBuffer
//    }
//    
//    deinit {
//        if let converter = audioConverter {
//            AudioConverterDispose(converter)
//            Logger.shared.error("Audio Converter disposed for revert")
//        }
//    }
//}
//
//
//
//func globalInputProc(_ inAudioConverter: AudioConverterRef,
//                     _ ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
//                     _ ioData: UnsafeMutablePointer<AudioBufferList>,
//                     _ outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
//                     _ inUserData: UnsafeMutableRawPointer?) -> OSStatus {
//    guard let inUserData = inUserData else {
//        Logger.shared.error("Input user data is nil")
//        return -1
//    }
//
//    let sourcePointer = inUserData.assumingMemoryBound(to: UInt8.self)
//
//    var audioBuffer = AudioBuffer()
//    audioBuffer.mData = UnsafeMutableRawPointer(sourcePointer)
//    audioBuffer.mDataByteSize = ioData.pointee.mBuffers.mDataByteSize
//    audioBuffer.mNumberChannels = 1
//
//    ioData.pointee.mBuffers = audioBuffer
//    let packetSizeInBytes = 4 // Source packet size (32-bit float stereo)
//    ioNumberDataPackets.pointee = UInt32(audioBuffer.mDataByteSize) / UInt32(packetSizeInBytes)
//
//    Logger.shared.error("Global input proc: Packet count set to \(ioNumberDataPackets.pointee)")
//    return noErr
//}
//
