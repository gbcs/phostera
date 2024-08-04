//
//  StreamProjectModel.swift
//  PhosteraShared
//
//  Created by Gary Barnett on 9/11/23.
//

import Foundation
import Combine

public enum StreamAudioSampleRate: Int {
    case sr44100 = 1
  //  case sr48000
}

public class StreamAudioConfigurationModel: NSObject, Identifiable, Codable, ObservableObject {
    @Published public var id:String
    @Published public var sampleRate:StreamAudioSampleRate
    @Published public var hostMicrophone:String
    @Published public var subjectMicrophone:String
    @Published public var interviewMicrophone:String
    
    required public init(sampleRate:StreamAudioSampleRate) {
        self.id = UUID().uuidString.lowercased()
        self.sampleRate = sampleRate
        hostMicrophone = ""
        subjectMicrophone = ""
        interviewMicrophone = ""
    }
    
    public enum CodingKeys: Int, CodingKey {
        case id = 1
        case sampleRate
        case hostMicrophone
        case subjectMicrophone
        case interviewMicrophone
    }
   
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let sampleRateRaw = try container.decode(Int.self, forKey: .sampleRate)
        sampleRate = StreamAudioSampleRate(rawValue: sampleRateRaw) ?? StreamAudioSampleRate.sr44100
        hostMicrophone = try container.decode(String.self, forKey: .hostMicrophone)
        subjectMicrophone = try container.decode(String.self, forKey: .subjectMicrophone)
        interviewMicrophone = try container.decode(String.self, forKey: .interviewMicrophone)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sampleRate.rawValue, forKey: .sampleRate)
        try container.encode(hostMicrophone, forKey: .hostMicrophone)
        try container.encode(subjectMicrophone, forKey: .subjectMicrophone)
        try container.encode(interviewMicrophone, forKey: .interviewMicrophone)
    }
}

public enum StreamResolution:Int, Codable, CaseIterable, Equatable {
    case v1920x1080 = 1
    case v1280x720
    case v720x480
    case v640x360
    
    public enum CodingKeys: Int, CodingKey {
        case v1920x1080 = 1
        case v1280x720
        case v720x480
        case v640x360
    }
}

public enum StreamFrameRate:Int, Codable, CaseIterable, Equatable {
    case fr24 = 1
    case fr25
    case fr30
    
    public enum CodingKeys: Int, CodingKey {
        case fr24 = 1
        case fr25
        case fr30
    }
    
    public static func toInt(streamRate:StreamFrameRate) -> Int {
        switch(streamRate) {
        case .fr24:
            return 24
        case .fr25:
            return 25
        case .fr30:
            return 30
        }
    }
}

public enum StreamProjectMediaType: Int, Codable {
    case preroll = 1
    case intro
    case interstitial
    case outro
    case backgroundImage
}

public enum StreamServiceType:Int, Codable, CaseIterable, Equatable {
    case unknown = 1
    case rtmp
//    case srt
    
    public enum CodingKeys: Int, CodingKey {
        case unknown = 1
        case rtmp
//        case srt
    }
}

public class StreamConfigurationModel: NSObject, Identifiable, Codable, ObservableObject {
    @Published public var id:String
    @Published public var service:StreamServiceType
    @Published public var url:String
    @Published public var name:String
    
    override public init() {
        self.id = UUID().uuidString.lowercased()
        self.service = .unknown
        self.url = ""
        self.name = ""
    }
    
    public enum CodingKeys: Int, CodingKey {
        case id = 1
        case service
        case url
        case name
    }
   
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let serviceType = try container.decode(Int.self, forKey: .service)
        service = StreamServiceType(rawValue: serviceType) ?? StreamServiceType.unknown
        url = try container.decode(String.self, forKey: .url)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(service.rawValue, forKey: .service)

    }
}

public enum StreamExternalCamera: Int, Codable, CaseIterable, Equatable {
    case replacesFront = 1
    case replacesRear
    
    public enum CodingKeys: Int, CodingKey {
        case replacesFront = 1
        case replacesRear
    }
}

public enum StreamRearCameraLens: Int, Codable, CaseIterable, Equatable {
    case ultrawide = 1
    case wide
    case telephoto
    
    public enum CodingKeys: Int, CodingKey {
        case ultrawide = 1
        case wide
        case telephoto
    }
}

public class StreamProjectModel: NSObject, Identifiable, Codable, ObservableObject {
    @Published public var id:String
    @Published public var title:String
    @Published public var streamResolution:StreamResolution
    @Published public var config:StreamConfigurationModel
    @Published public var streamFrameRate:StreamFrameRate
    @Published public var mediaPreroll:FootageModel?
    @Published public var mediaIntro:FootageModel?
    @Published public var mediaInterstitial:FootageModel?
    @Published public var mediaOutro:FootageModel?
    @Published public var mediaBackgroundImage:FootageModel?
    @Published public var recordStream: Bool
    @Published public var defaultUserMessage:String
    @Published public var wifiSSID:String
    @Published public var wifiPassword:String
    @Published public var audioConfiguration:StreamAudioConfigurationModel
    @Published public var currentPreset:Int
    @Published public var presets:[[StreamPane]]
    @Published public var ipadExternal:StreamExternalCamera
    @Published public var rearCameraLens:StreamRearCameraLens
    @Published public var provideWifi:Bool
    @Published public var maxBandwidth:Double
    
    
    public init(id: String, title: String, streamResolution: StreamResolution, streamFrameRate: StreamFrameRate) {
        self.presets = [ [], [], [], [], [] ]
        self.currentPreset = 0
        self.defaultUserMessage = "Let me in!"
        self.wifiSSID = ""
        self.wifiPassword = ""
        self.rearCameraLens = .ultrawide
        self.ipadExternal = .replacesRear
        self.config = StreamConfigurationModel()
        self.id = id
        self.title = title
        self.streamResolution = streamResolution
        self.streamFrameRate = streamFrameRate
        self.audioConfiguration = StreamAudioConfigurationModel(sampleRate: .sr44100)
        self.recordStream = true
        self.provideWifi = false
        self.maxBandwidth = 6800000
    }
    
    public enum CodingKeys: Int, CodingKey {
        case id = 1
        case title
        case streamResolution
        case streamFrameRate
        case mediaPreroll
        case mediaIntro
        case mediaInterstitial
        case mediaOutro
        case mediaBackgroundImage
        case recordStream
        case config
        case defaultUserMessage
        case wifiSSID
        case wifiPassword
        case audioConfiguration
        case currentPreset
        case presets
        case ipadExternal
        case rearCameraLens
        case provideWifi
        case maxBandwidth
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        streamResolution = try container.decode(StreamResolution.self, forKey: .streamResolution)
        streamFrameRate = try container.decode(StreamFrameRate.self, forKey: .streamFrameRate)
        mediaPreroll = try? container.decode(FootageModel.self, forKey: .mediaPreroll)
        mediaIntro = try? container.decode(FootageModel.self, forKey: .mediaIntro)
        mediaInterstitial = try? container.decode(FootageModel.self, forKey: .mediaInterstitial)
        mediaOutro = try? container.decode(FootageModel.self, forKey: .mediaOutro)
        mediaBackgroundImage = try? container.decode(FootageModel.self, forKey: .mediaBackgroundImage)
        recordStream = try container.decode(Bool.self, forKey: .recordStream)
        config = try container.decode(StreamConfigurationModel.self, forKey: .config)
        defaultUserMessage = try container.decode(String.self, forKey: .defaultUserMessage)
        wifiSSID = try container.decode(String.self, forKey: .wifiSSID)
        wifiPassword = try container.decode(String.self, forKey: .wifiPassword)
        audioConfiguration = try container.decode(StreamAudioConfigurationModel.self, forKey: .audioConfiguration)
        currentPreset = try container.decode(Int.self, forKey: .currentPreset)
        presets = try container.decode(Array.self, forKey: .presets)
        ipadExternal = try container.decode(StreamExternalCamera.self, forKey: .ipadExternal)
        rearCameraLens = try container.decode(StreamRearCameraLens.self, forKey: .rearCameraLens)
        provideWifi = try container.decode(Bool.self, forKey: .provideWifi)
        maxBandwidth = try container.decode(Double.self, forKey: .maxBandwidth)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(streamResolution, forKey: .streamResolution)
        try container.encode(streamFrameRate, forKey: .streamFrameRate)
        try? container.encode(mediaPreroll, forKey: .mediaPreroll)
        try? container.encode(mediaIntro, forKey: .mediaIntro)
        try? container.encode(mediaInterstitial, forKey: .mediaInterstitial)
        try? container.encode(mediaOutro, forKey: .mediaOutro)
        try? container.encode(mediaBackgroundImage, forKey: .mediaBackgroundImage)
        try? container.encode(recordStream, forKey: .recordStream)
        try? container.encode(config, forKey: .config)
        try? container.encode(defaultUserMessage, forKey: .defaultUserMessage)
        try? container.encode(wifiSSID, forKey: .wifiSSID)
        try? container.encode(wifiPassword, forKey: .wifiPassword)
        try? container.encode(audioConfiguration, forKey: .audioConfiguration)
        try? container.encode(currentPreset, forKey: .currentPreset)
        try? container.encode(presets, forKey: .presets)
        try? container.encode(ipadExternal, forKey: .ipadExternal)
        try? container.encode(rearCameraLens, forKey: .rearCameraLens)
        try? container.encode(provideWifi, forKey: .provideWifi)
        try? container.encode(maxBandwidth, forKey: .maxBandwidth)
    }
}

