//
//  PacketDerivation.swift
//
//
//  Created by Cole M on 6/19/24.
//

import Foundation
import NIOCore
import Algorithms
import BSON
import DequeModule
import NeedleTailAsyncSequence
import AsyncAlgorithms
import NeedleTailLogger

public struct AuthPacket: Codable, Sendable {
    public let jwt: String?
    public let nick: String?
    
    public init(
        jwt: String,
        nick: String
    ) {
        self.jwt = jwt
        self.nick = nick
    }
}

public struct MultipartPacket: Sendable, Codable, Hashable {
    public let groupId: String
    public var date: Date
    public var partNumber: Int
    public let totalParts: Int
    public var message: String?
    public var data: Data?
    
    public init(
        groupId: String,
        date: Date = Date(),
        partNumber: Int = 0,
        totalParts: Int,
        message: String? = nil,
        data: Data? = nil
    ) {
        self.groupId = groupId
        self.date = date
        self.partNumber = partNumber
        self.totalParts = totalParts
        self.message = message
        self.data = data
    }
}

public struct PacketDerivation: Sendable {
    
    public init() {}
    
    //IRC Requirement is a count of 512
    public func calculateAndDispense(
        text: String? = nil,
        data: Data? = nil,
        chunkCount: Int = 512,
        bufferingPolicy: AsyncStream<MultipartPacket>.Continuation.BufferingPolicy = .unbounded
    ) async -> AsyncStream<MultipartPacket> {
        var streamContinuation: AsyncStream<MultipartPacket>.Continuation?
        let stream = AsyncStream<MultipartPacket>(bufferingPolicy: bufferingPolicy) { continuation in
            streamContinuation = continuation
        }
        let groupId = UUID().uuidString
        let packetDate = Date()
        
        if let text {
            let chunks = text.chunks(ofCount: chunkCount)
            let totalParts = chunks.count
            var packets = [MultipartPacket]()
            packets.reserveCapacity(totalParts)
            for (index, chunk) in chunks.enumerated() {
                let packet = MultipartPacket(
                    groupId: groupId,
                    date: packetDate,
                    partNumber: index + 1, // Use index for part number
                    totalParts: totalParts,
                    message: String(chunk)
                )
                packets.append(packet)
            }
            
            for packet in packets.sorted(by: { $0.partNumber < $1.partNumber }) {
                streamContinuation?.yield(packet)
            }
            
            // Finish the stream if all packets have been yielded
            if totalParts > 0 {
                streamContinuation?.finish()
            }
            
        } else if let data {
            let chunks = data.chunks(ofCount: chunkCount)
            let totalParts = chunks.count
            var packets = [MultipartPacket]()
            packets.reserveCapacity(totalParts)
            
            for (index, chunk) in chunks.enumerated() {
                let packet = MultipartPacket(
                    groupId: groupId,
                    date: packetDate,
                    partNumber: index + 1, // Use index for part number
                    totalParts: totalParts,
                    data: chunk
                )
                packets.append(packet)
            }
            
            for packet in packets.sorted(by: { $0.partNumber < $1.partNumber }) {
                streamContinuation?.yield(packet)
            }
            
            // Finish the stream if all packets have been yielded
            if totalParts > 0 {
                streamContinuation?.finish()
            }
        }
        return stream
    }
}


public actor PacketBuilder {
    
    private let executor: any AnyExecutor
    private var packets = [[MultipartPacket]]()
    private var builtData: Data?
    private var joinedMessage: String?
    
    public init(executor: any AnyExecutor) {
        self.executor = executor
    }
    
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    public enum ProcessedResult: Sendable {
        case message(String)
        case data(Data)
        case none
    }
    
    public func processPacket(_ packet: MultipartPacket) -> ProcessedResult {
        // Find the index of the group that contains the packet
        if let groupIndex = packets.firstIndex(where: { $0.first?.groupId == packet.groupId }) {
            // Append the packet to the existing group
            
            if var message = packet.message {
                if message.first == ":" {
                    message = String(message.dropFirst())
                }
            }
            packets[groupIndex].append(packet)
            return finishProcess(groupIndex: groupIndex)
        } else {
            if var message = packet.message {
                if message.first == ":" {
                    message = String(message.dropFirst())
                }
            }
            // Create a new group with the packet
            packets.append([packet])
            return finishProcess(groupIndex: packets.count - 1)
        }
    }
    
    private func finishProcess(groupIndex: Int) -> ProcessedResult {
        let groupPackets = packets[groupIndex]
        // Check if we have all parts
        if groupPackets.count == groupPackets.first?.totalParts {
            let sortedParts = groupPackets.sorted { $0.partNumber < $1.partNumber }
            
            for packet in sortedParts {
                if let message = packet.message {
                    if joinedMessage == nil {
                        joinedMessage = ""
                    }
                    
                    if let currentJoinedMessage = joinedMessage {
                        joinedMessage = currentJoinedMessage + message
                    }
                    
                } else if let data = packet.data {
                    // Initialize builtData if it's nil
                    if builtData == nil {
                        builtData = Data()
                    }
                    
                    // Safely append the data to builtData
                    if var currentBuiltData = builtData {
                        currentBuiltData.append(data)
                        builtData = currentBuiltData // Update the instance variable
                    }
                }
            }
            
            defer {
                joinedMessage = nil
                builtData = nil
            }
            // Return either the joined message or the built data
            if let joinedMessage {
                return .message(joinedMessage)
            } else if let builtData {
                return .data(builtData)
            }
            return .none
        }
        return .none
    }
}


public actor IRCMessageGenerator: Sendable {
    
    let executor: any AnyExecutor
    
    private let packetBuilder: PacketBuilder
    
    public init(executor: any AnyExecutor) {
        self.executor = executor
        self.packetBuilder = PacketBuilder(executor: executor)
    }
    
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    
    
    // Helper function to create an IRCMessage
    func createIRCMessage(
        for command: IRCCommand,
        origin: String,
        tags: [IRCTag]? = nil,
        authPacket: AuthPacket? = nil,
        logger: NeedleTailLogger,
        currentPacket: MultipartPacket,
        continuation: AsyncStream<IRCMessage>.Continuation
    ) async {
        var mutableTags = [IRCTag]()
        
        if let authPacket {
            do {
                let value = try BSONEncoder().encode(authPacket).makeData().base64EncodedString()
                mutableTags.append(IRCTag(key: "irc-protected", value: value))
            } catch {
                logger.log(level: .error, message: "Error Encoding Auth Packet, \(error)")
            }
        }
        if let tags {
            mutableTags.append(contentsOf: tags)
        }
        
        var modifiedCommand = command
        guard let packetMessage = currentPacket.message else { return }
        switch command {
        case .privMsg(let recipients, _), .notice(let recipients, _):
            modifiedCommand = .privMsg(recipients, "")
        case .quit(_):
            modifiedCommand = .quit(packetMessage)
        case .otherCommand(let otherCommand, _):
            modifiedCommand = .otherCommand(otherCommand, [])
        case .otherNumeric(let otherNumeric, _):
            modifiedCommand = .otherNumeric(otherNumeric, [])
        default:
            break
        }
        
        var modifiedPacket = currentPacket
        modifiedPacket.message = ""
        
        do {
            let packetMetadata = try BSONEncoder().encode(currentPacket).makeData().base64EncodedString()
            mutableTags.append(IRCTag(key: "packet-metadata", value: packetMetadata))
        } catch {
            logger.log(level: .error, message: "Failed to encode IRCTag for packet metadata: \(error)")
        }
        
        let message = IRCMessage(
            origin: origin,
            command: modifiedCommand,
            tags: mutableTags)
        //Yields a message but the message mutable tags are empty.
        continuation.yield(message)
        if modifiedPacket.partNumber == modifiedPacket.totalParts {
            continuation.finish()
        }
    }
    
    public func createMessages(
        origin: String,
        command: IRCCommand,
        tags: [IRCTag]? = nil,
        authPacket: AuthPacket? = nil,
        logger: NeedleTailLogger
    ) async -> AsyncStream<IRCMessage> {
        let packetDeriver = PacketDerivation()
        var streamContinuation: AsyncStream<IRCMessage>.Continuation?
        let stream = AsyncStream<IRCMessage>(bufferingPolicy: .unbounded) { continuation in
            streamContinuation = continuation
        }
        
        // Helper function to handle empty messages
        func handleEmptyMessage(for command: IRCCommand) async {
            let packet = await createEmptyPacket()
            guard let continuation = streamContinuation else { return }
            await createIRCMessage(
                for: command,
                origin: origin,
                tags: tags,
                authPacket: authPacket,
                logger: logger,
                currentPacket: packet,
                continuation: continuation)
        }
        
        // Helper function to process packets and create IRC messages
        func processPackets(
            packets: AsyncStream<MultipartPacket>,
            command: IRCCommand
        ) async {
            guard let continuation = streamContinuation else { return }
            for await packet in packets {
                //Packets from the stream are properly fed here, but when we create messages the next stream that the CreateMessages method calls contains the next continuation items but the items are empty. Yields a message but the message mutable tags are empty.
                await createIRCMessage(
                    for: command,
                    origin: origin,
                    tags: tags,
                    authPacket: authPacket,
                    logger: logger,
                    currentPacket: packet,
                    continuation: continuation)
            }
        }
        
        // Function to handle message processing
        func handleMessage(for command: IRCCommand, message: String, chunkCount: Int = 512) async {
            if message.isEmpty {
                await handleEmptyMessage(for: command)
            } else {
                let packets = await packetDeriver.calculateAndDispense(text: message, chunkCount: chunkCount)
                await processPackets(packets: packets, command: command)
            }
        }
        
        switch command {
        case .privMsg(_, let message), .notice(_, let message):
            await handleMessage(for: command, message: message)
            
        case .quit(let message):
            if let message = message {
                await handleMessage(for: command, message: message)
            } else {
                await handleEmptyMessage(for: command)
            }
            
        case .otherCommand(let otherCommand, let messageArray):
            //5mb chunk size
            let chunkSize = 5 * 1024 * 1024
            let message = messageArray.joined(separator: Constants.comma.rawValue)
            await handleMessage(for: .otherCommand(otherCommand, [message]),
                                message: message,
                                chunkCount: (otherCommand == Constants.multipartMediaUpload.rawValue || otherCommand == Constants.multipartMediaDownload.rawValue) ? chunkSize : 512)
        case .otherNumeric(let otherNumeric, let messageArray):
            let message = messageArray.joined(separator: Constants.comma.rawValue)
            await handleMessage(for: .otherNumeric(otherNumeric, [message]), message: message)
            
        default:
            await handleEmptyMessage(for: command)
        }
        return stream
    }
    
    private func createEmptyPacket() async -> MultipartPacket {
        return MultipartPacket(
            groupId: UUID().uuidString,
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: ""
        )
    }
    
    /// Reassembles a chunked IRCMessage. A chunked IRCMessage is a wrapper arround an IRCMessage that contains basic IRCMessage information. The wrapper message contains an IRCTag containin the chuncked packetMetadata for reassembly.
    /// - Parameter ircMessage: Wrapper IRCMessage with the chunked metasata
    /// - Returns: A Reassembled IRCMessage
    public func messageReassembler(ircMessage: IRCMessage) async throws -> IRCMessage? {
        var ircMessage = ircMessage
        
        guard let packetTag = ircMessage.tags?.first(where: { $0.key == "packet-metadata" }) else { return nil }
        guard let data = Data(base64Encoded: packetTag.value) else { return nil }
        let packet = try BSONDecoder().decode(MultipartPacket.self, from: Document(data: data))
        
        switch ircMessage.command {
        case .privMsg(let recipients, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    ircMessage.command = .privMsg(recipients, processedMessage)
                } else {
                    ircMessage.command = .privMsg(recipients, "")
                }
            default:
                return nil
            }
        case .notice(let recipients, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    ircMessage.command = .notice(recipients, processedMessage)
                } else {
                    ircMessage.command = .notice(recipients, "")
                }
            default:
                return nil
            }
        case .quit(_):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    ircMessage.command = .quit(processedMessage)
                } else {
                    ircMessage.command = .quit("")
                }
            default:
                return nil
            }
        case .otherCommand(let command, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
                    ircMessage.command = .otherCommand(command, rebuiltArray)
                } else {
                    ircMessage.command = .otherCommand(command, [""])
                }
            default:
                return nil
            }
        case .otherNumeric(let command, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
                    ircMessage.command = .otherNumeric(command, rebuiltArray)
                } else {
                    ircMessage.command = .otherNumeric(command, [""])
                }
            default:
                return nil
            }
        default:
            return ircMessage
        }
        return ircMessage
    }
}
