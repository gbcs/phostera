//
//  CommandProtocol.swift
//  Phostera Director
//
//  Created by Gary Barnett on 7/20/23.
//

import Foundation
import Network

public class CommandProtocol: NWProtocolFramerImplementation {
    public static let definition = NWProtocolFramer.Definition(implementation: CommandProtocol.self)
    public static var label: String { return "Phostera" }

    required public init(framer: NWProtocolFramer.Instance) { }
    public func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { return .ready }
    public func wakeup(framer: NWProtocolFramer.Instance) { }
    public func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    public func cleanup(framer: NWProtocolFramer.Instance) { }

    public func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        let type = message.commandMessageType

        let header = CommandProtocolHeader(type: type.rawValue, length: UInt32(messageLength))
        framer.writeOutput(data: header.encodedData)
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            //Logger.shared.log.error("CommandProtocol Framing error: \(error.localizedDescription)")
        }
    }

    public func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var tempHeader: CommandProtocolHeader? = nil
            let headerSize = CommandProtocolHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                           maximumLength: headerSize) { (buffer, isComplete) -> Int in
                guard let buffer = buffer else {
                    return 0
                }
                if buffer.count < headerSize {
                    return 0
                }
                tempHeader = CommandProtocolHeader(buffer)
                return headerSize
            }
            
            guard parsed, let header = tempHeader else {
                return headerSize
            }

            var messageType = CommandMessageType.invalid
            if let parsedMessageType = CommandMessageType(rawValue: header.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(commandMessageType: messageType)

            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

public extension NWProtocolFramer.Message {
    convenience init(commandMessageType: CommandMessageType) {
        self.init(definition: CommandProtocol.definition)
        self["CommandMessageType"] = commandMessageType
    }

    var commandMessageType: CommandMessageType {
        if let type = self["CommandMessageType"] as? CommandMessageType {
            return type
        } else {
            return .invalid
        }
    }
}

public struct CommandProtocolHeader: Codable {
    public let type: UInt32
    public let length: UInt32

    public init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }

    public init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        withUnsafeMutableBytes(of: &tempType) { typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
                                                            count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
            lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                                                              count: MemoryLayout<UInt32>.size))
        }
        type = tempType
        length = tempLength
    }

    public var encodedData: Data {
        var tempType = type
        var tempLength = length
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        return data
    }

    public static var encodedSize: Int {
        return MemoryLayout<UInt32>.size * 2
    }
}
