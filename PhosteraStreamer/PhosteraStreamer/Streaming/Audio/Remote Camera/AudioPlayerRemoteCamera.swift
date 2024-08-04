//
//  AudioRemoteCamera.swift
//  PhosteraStreamer
//
//  Created by Gary Barnett on 11/9/23.
//
import AVFoundation
import AudioToolbox


enum SimpleAudioFileWriterError: Error {
    case badSetup
}

class SimpleAudioFileWriter {
    private var audioFile: AVAudioFile?

    func setupAudioFile(outputURL: URL) throws {
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22050, channels: 1, interleaved: false)
        guard let audioFormat else {
            throw SimpleAudioFileWriterError.badSetup
        }
        audioFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat.settings)
    }

    func write(buffer: AVAudioPCMBuffer) throws {
        guard let audioFile = audioFile else {
            throw NSError(domain: "SimpleAudioFileWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio file is not set up."])
        }
        try audioFile.write(from: buffer)
        Logger.shared.info("SimpleAudioFileWriter: wrote: \(buffer.frameLength)")
    }

    func finishWriting() {
        audioFile = nil // Closing the file
    }
}

class AudioPlayerRemoteCamera {
    
    //Will be more than one of these at a time in the future
    //Manage a converter instance
    //Manage an audio queue
    //Play audio
    
    static var shared = AudioPlayerRemoteCamera()
    
    var audioConverter:RemoteCameraAudioConverter? = RemoteCameraAudioConverter()
    var audioQueue:RemoteCameraAudioQueue = RemoteCameraAudioQueue(sampleRate: 48000, samplesPerInterval: 8192)
    
    var writer:SimpleAudioFileWriter? = SimpleAudioFileWriter()
    
    var count = 0
    
    func getAndPlayBuffer() {
        guard let audioConverter else { return }
        if let buffer = audioQueue.sampleQueue.first {
            audioQueue.sampleQueue.removeFirst()
            if let pcmBuffer = audioConverter.createPCMBuffer(from: buffer) {
                AudioTool.shared.play(camera: pcmBuffer)
                count += 1
                try? writer?.write(buffer: pcmBuffer)
                if count > 100 {
                    writer = nil
                    Logger.shared.info("Done.....")
                }
            }
        }
    }
    
    func ingest(string:String, data:Data) {
        audioQueue.ingest(sample: data)
    }
    
    init() {
        let url = URL.documentsDirectory.appending(component: "c.caf", directoryHint: .notDirectory)
        let fileURl = URL(fileURLWithPath: url.path)
        try? writer?.setupAudioFile(outputURL: fileURl)
        start()
    }
    
    func start() {
        audioQueue.startTimer { [weak self] in
            guard let self else { return }
            getAndPlayBuffer()
        }
    }
    
    func stop() {
        audioQueue.stopTimer()
    }
    
}
