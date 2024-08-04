//
//  CameraStreamConnector.swift
//  Phostera Director Director
//
//  Created by Gary Barnett on 7/24/23.
//

import Foundation
import Network
import CoreMedia
import PhosteraShared
import AVFAudio
import AVFoundation
import VideoToolbox

enum VideoStreamServerErrors: Error {
    case tlsSetup
}

class CameraStreamConnector: NSObject {
    var connection: NWConnection?
    var endpoint: NWEndpoint?
    var uuid:String = ""
    private let naluParser = NALUParser()
    private let h264Converter = H264Converter()
    var useQUIC:Bool = false
    var sessionKey:String = ""
    private var videoDecoder:VideoDecoder?
    @Published var transform:Data?
    
    func setupDecompressor(description:CMVideoFormatDescription) {
        if videoDecoder != nil { videoDecoder = nil }
        
        videoDecoder = VideoDecoder(videoFormatDescription: description, callback: { [weak self] imageBuffer in
            guard let self else { return }
            guard let imageBuffer else { return }
            //            let width = CVPixelBufferGetWidth(imageBuffer)
            //            let height = CVPixelBufferGetHeight(imageBuffer)
            //Logger.shared.info("Width: \(width), Height: \(height)")
            
            StreamBuffer.shared.ingest(uuid: uuid, image: imageBuffer)
        })
    }
    
    func setPreviewLayerCallback(_ callback: @escaping (CMSampleBuffer) -> Void) {
        h264Converter.sampleBufferCallback = callback
    }
    
    func stop() {
        connection?.cancel()
        h264Converter.sampleBufferCallback = nil
        connection = nil
        endpoint = nil
    }
    
    static func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolTLS.Options()
        do {
            let secIdentity = try ServerKeys.keysForServer()
            guard let identity = sec_identity_create(secIdentity) else { return NWParameters(tls: options) }
            sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
            sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)
            sec_protocol_options_append_tls_ciphersuite( options.securityProtocolOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_AES_128_GCM_SHA256))! )
        } catch {
            return NWParameters(tls: options)
        }
        
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            sec_protocol_verify_complete(true)
        }, queue)
        return NWParameters(tls: options)
    }
    
    deinit {
        StreamBuffer.shared.clear(uuid: uuid)
        connection = nil
        endpoint = nil
    }
    
    static func createQUICParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
        let options = NWProtocolQUIC.Options(alpn: ["phostera"])
        //options.isDatagram = true
       // options.maxDatagramFrameSize = 65535
        options.idleTimeout = 120000
        options.direction = .bidirectional
        
        do {
            let secIdentity = try ServerKeys.keysForServer()
            guard let identity = sec_identity_create(secIdentity) else { return NWParameters(quic: options) }
            sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
            sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)
            sec_protocol_options_append_tls_ciphersuite( options.securityProtocolOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_AES_128_GCM_SHA256))! )
        } catch {
            return NWParameters(quic: options)
        }
        
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            sec_protocol_verify_complete(true)
        }, queue)
        return NWParameters(quic: options)
    }
    
    
    func setEndpoint(ep:NWEndpoint, useQUIC:Bool) {
        self.endpoint = ep
        self.useQUIC = useQUIC
        
        let tcpOpts = NWProtocolTCP.Options()
        tcpOpts.disableECN         = true    // Explicit Congestion Notification
        tcpOpts.enableKeepalive    = false   // Send Keep-Alive packets
        tcpOpts.connectionTimeout  = 5       // Connection handshake timeout (seconds)
        tcpOpts.connectionDropTime = 5       // Seconds TCP will do packet retransmission

        let params:NWParameters?
        
        if useQUIC {
            params = CameraStreamConnector.createQUICParameters(allowInsecure: true, queue: .global(qos: .userInitiated))
        } else {
           params = CameraStreamConnector.createTLSParameters(allowInsecure: true, queue: .global(qos: .userInitiated))
        }
       
        guard let params else {
            return
        }
        
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        let streamptions = NWProtocolFramer.Options(definition: StreamProtocol.definition)
        params.defaultProtocolStack.applicationProtocols.insert(streamptions, at: 0)
        
        let connection = NWConnection(to: ep, using: params)
        self.connection = connection
    }

//    func hostportForEndpoint(_ endpoint: NWEndpoint) -> (NWEndpoint.Host?, NWEndpoint.Port?) {
//        switch endpoint {
//        case .hostPort(let host, let port):
//            return (host, port)
//        default:
//            return (nil, nil)
//        }
//    }
    
    func cancel() {
        if let connection = self.connection {
            connection.cancel()
            self.connection = nil
        }
    }
    
    func connectionReady() -> Bool {
        return self.connection?.state == .ready
    }

    func requestAuth() {
        Logger.shared.info("Requesting auth using sessionKey \(sessionKey)")
        guard let connection = connection else {
            return
        }

        let message = NWProtocolFramer.Message(StreamMessageType: .auth)
        let context = NWConnection.ContentContext(identifier: "message",  metadata: [message])
        
        let content = StreamAuthRequest(sessionKey: sessionKey)
  
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(content)
            Logger.shared.info("Sending \(data.count) bytes to camera")
            
            connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
        } catch {
            Logger.shared.error("request auth encoder error \(error)")
        }
    }

    func startConnection(uuid:String) {
        Logger.shared.info("Connecting stream channel for \(uuid)")
        self.uuid = uuid
        guard let connection = connection else {
            return
        }
        
        naluParser.h264UnitHandling = { [h264Converter] h264Unit in
                h264Converter.convert(h264Unit)
        }
        
        h264Converter.sampleBufferCallback = { [weak self] sampleBuffer in
            guard let self else { return }
            guard let videoFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                //Logger.shared.error("NOVIDDESC")
                //No video frames; normal at startup. should probably put a hook to complain about them after one good one has passed
                return
            }
            
            if videoDecoder == nil {
                setupDecompressor(description: videoFormatDescription)
            }
            
            guard let videoDecoder else { return }
            
            videoDecoder.processSampleBuffer(sampleBuffer)
        }
        
        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                Logger.shared.info("\(connection) established")
                self?.receiveNextMessage()
                self?.requestAuth()
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.streamChanged, object: nil) }
            case .failed(let error):
                Logger.shared.error("\(connection) failed with \(error)")
                connection.cancel()
                self?.connectionFailed()
                DispatchQueue.main.async { NotificationCenter.default.post(name: NSNotification.Name.Camera.streamChanged, object: nil) }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }
    
    func receiveNextMessage() {
        guard let connection = connection else {
            return
        }

        connection.receiveMessage { (content, context, isComplete, error) in
            if let StreamMessage = context?.protocolMetadata(definition: StreamProtocol.definition) as? NWProtocolFramer.Message {
                self.receivedMessage(content: content, message: StreamMessage)
            }
            if error == nil {
                self.receiveNextMessage()
            }
        }
    }

    func receivedMessage(content: Data?, message: NWProtocolFramer.Message) {
        guard let content else { return }
        switch(message.StreamMessageType) {
        case .preview:
            //Logger.shared.error("content = \(content.bytes.count)")
            naluParser.enqueue(content)
        case .audio:
            Logger.shared.error("audio content = \(content.bytes.count)")
          //  AudioRemoteCamera.shared.playAudioBufferData(uuid: uuid, data: content)
            AudioPlayerRemoteCamera.shared.ingest(string: uuid, data: content)
            break
        case .metadata:
            if let t = try? JSONDecoder().decode(VideoEncoderSharedData.self, from: content) {
                Logger.shared.info("got vesd: \(t.sourceOrientation) - \(content.bytes.count)")
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    MetalTool.shared.updateSource(orientation: t.sourceOrientation, uuid: uuid)
                }
            }
            Logger.shared.info("received transform data.  content = \(content.bytes.count)")
            transform = content
        default:
            Logger.shared.error("receivedMessage fallthrough")
        }
    }
    
    func connectionFailed() {
        
    }
    
}

