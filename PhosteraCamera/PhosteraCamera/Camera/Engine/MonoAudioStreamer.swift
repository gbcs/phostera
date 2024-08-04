import Foundation
import AudioToolbox
import AVFoundation

class AudioStreamerMono {
    private var sourceFormat = AudioStreamBasicDescription(
        mSampleRate: 48000.0,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 8,
        mFramesPerPacket: 1,
        mBytesPerFrame: 8,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 32,
        mReserved: 0
    )
    
    private var destinationFormat = AudioStreamBasicDescription(
        mSampleRate: 22050.0,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 32,
        mReserved: 0
    )
    
    private var audioConverter: AudioConverterRef?
    
    init() {
        var converter: AudioConverterRef?
        let status = AudioConverterNew(&sourceFormat, &destinationFormat, &converter)
        if status != noErr {
            Logger.shared.error("Error initializing Audio Converter: \(status)")
        } else if let converterUnwrapped = converter {
            self.audioConverter = converterUnwrapped
            Logger.shared.info("Audio Converter successfully initialized")
        }
    }

    func convertSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer),
              let audioConverter = self.audioConverter else {
            Logger.shared.error("Failed to get data buffer or audio converter is nil")
            return nil
        }
        
        if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee {
                Logger.shared.info("Sample Rate: \(asbd.mSampleRate)")
                Logger.shared.info("Format ID: \(asbd.mFormatID)")
                Logger.shared.info("Format Flags: \(asbd.mFormatFlags)")
                Logger.shared.info("Bytes Per Packet: \(asbd.mBytesPerPacket)")
                Logger.shared.info("Frames Per Packet: \(asbd.mFramesPerPacket)")
                Logger.shared.info("Bytes Per Frame: \(asbd.mBytesPerFrame)")
                Logger.shared.info("Channels Per Frame: \(asbd.mChannelsPerFrame)")
                Logger.shared.info("Bits Per Channel: \(asbd.mBitsPerChannel)")
                Logger.shared.info("Reserved: \(asbd.mReserved)")
            }
        }
        
        let originalBufferSize = CMBlockBufferGetDataLength(blockBuffer)
        let rateRatio = destinationFormat.mSampleRate / sourceFormat.mSampleRate
        let newBufferSize = Int(Double(originalBufferSize) * rateRatio) / 2
        
        guard let sourceDataPointer = malloc(originalBufferSize) else {
            Logger.shared.error("Failed to allocate memory for source data")
            return nil
        }
        defer { free(sourceDataPointer) }

        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: originalBufferSize, destination: sourceDataPointer)
        guard let convertedBufferPointer = malloc(newBufferSize) else {
            Logger.shared.error("Failed to allocate memory for converted buffer")
            return nil
        }
        defer { free(convertedBufferPointer) }

        var ioOutputDataPacketSize: UInt32 = UInt32(newBufferSize) / destinationFormat.mBytesPerPacket
        let outputAudioBuffer = AudioBuffer(mNumberChannels: destinationFormat.mChannelsPerFrame, mDataByteSize: UInt32(newBufferSize), mData: convertedBufferPointer)
        var outputBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: outputAudioBuffer)

        let status = AudioConverterFillComplexBuffer(
            audioConverter,
            globalInputProc,
            sourceDataPointer,
            &ioOutputDataPacketSize,
            &outputBufferList,
            nil
        )

        if status != noErr {
            Logger.shared.error("Error during conversion: \(status)")
            return nil
        }

        Logger.shared.info("Conversion successful, buffer size: \(newBufferSize)")
        return Data(bytes: convertedBufferPointer, count: newBufferSize)
    }
    
    deinit {
        if let converter = audioConverter {
            AudioConverterDispose(converter)
            Logger.shared.info("Audio Converter disposed")
        }
    }
}

func globalInputProc(_ inAudioConverter: AudioConverterRef,
                     _ ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
                     _ ioData: UnsafeMutablePointer<AudioBufferList>,
                     _ outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                     _ inUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let inUserData = inUserData else {
        Logger.shared.error("Input user data is nil")
        return -1
    }

    let sourcePointer = inUserData.assumingMemoryBound(to: UInt8.self)
    let packetSizeInBytes = 8 // Source packet size (32-bit float stereo)

    var audioBuffer = AudioBuffer()
    audioBuffer.mData = UnsafeMutableRawPointer(sourcePointer)
    audioBuffer.mDataByteSize = ioData.pointee.mBuffers.mDataByteSize
    audioBuffer.mNumberChannels = 2

    ioData.pointee.mBuffers = audioBuffer
    ioNumberDataPackets.pointee = UInt32(audioBuffer.mDataByteSize) / UInt32(packetSizeInBytes)

    //Logger.shared.info("Global input proc: Packet count set to \(ioNumberDataPackets.pointee)")
    return noErr
}

