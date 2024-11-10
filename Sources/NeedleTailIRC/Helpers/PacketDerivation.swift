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
import NeedleTailStructures


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
    
    private var packets = [[MultipartPacket]]()
    
    public init() {}
    
    public enum ProcessedResult: Sendable {
        case message(String)
        case data(Data)
        case none
    }
    
    public func processPacket(_ packet: MultipartPacket) -> ProcessedResult {
        var packet = packet
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
            print("PART_NUMBER:", groupPackets.count)
            print("TOTAL_PARTS:", groupPackets.first?.totalParts)
            let sortedParts = groupPackets.sorted { $0.partNumber < $1.partNumber }
            var builtData = Data()
            var joinedMessage = ""

            for packet in sortedParts {
                if let message = packet.message {
                    joinedMessage += message
                } else if let data = packet.data {
                    builtData.append(data)
                }
            }

            // Return either the joined message or the built data
            if !joinedMessage.isEmpty {
                return .message(joinedMessage)
            } else if !builtData.isEmpty {
                return .data(builtData)
            }
        }
        return .none
    }
}


public struct IRCMessageGenerator: Sendable {
    
    private let packetBuilder = PacketBuilder()
    
    public init() {}
    
    public func createMessages(
        origin: String,
        command: IRCCommand,
        tags: [IRCTag]? = nil,
        logger: NeedleTailLogger
    ) async -> AsyncStream<IRCMessage> {
        
        var streamContinuation: AsyncStream<IRCMessage>.Continuation?
        let stream = AsyncStream<IRCMessage>(bufferingPolicy: .unbounded) { continuation in
            streamContinuation = continuation
        }
        
        let packetDeriver = PacketDerivation()
        
        // Helper function to create an IRCMessage
        func createIRCMessage(for
                              command: IRCCommand,
                              currentPacket: MultipartPacket
        ) async {
            var mutableTags = tags ?? []
            var modifiedCommand = command
            guard let packetMessage = currentPacket.message else { return }
            switch command {
            case .privMsg(let recipients, _), .notice(let recipients, _):
                modifiedCommand = .privMsg(recipients, packetMessage)
            case .quit(_):
                modifiedCommand = .quit(currentPacket.message)
            case .otherCommand(let otherCommand, _):
                modifiedCommand = .otherCommand(otherCommand, [packetMessage])
            case .otherNumeric(let otherNumeric, _):
                modifiedCommand = .otherNumeric(otherNumeric, [packetMessage])
            default:
                break
            }
            
            var modifiedPacket = currentPacket
            modifiedPacket.message = ""
            
            do {
                let packetMetadata = try BSONEncoder().encodeString(currentPacket)
                mutableTags.append(IRCTag(key: "packetMetadata", value: packetMetadata))
            } catch {
                logger.log(level: .error, message: "Failed to encode IRCTag for packet metadata: \(error)")
            }
            
            let message = IRCMessage(
                origin: origin,
                command: modifiedCommand,
                tags: mutableTags)
            streamContinuation?.yield(message)
            
            if modifiedPacket.partNumber == modifiedPacket.totalParts {
                streamContinuation?.finish()
            }
        }
        
        // Helper function to handle empty messages
        func handleEmptyMessage(for command: IRCCommand) async {
            let packet = await createEmptyPacket()
            await createIRCMessage(for: command, currentPacket: packet)
        }
        
        // Helper function to process packets and create IRC messages
        func processPackets(
            packets: AsyncStream<MultipartPacket>,
            command: IRCCommand
        ) async {
            for await currentPacket in packets {
                await createIRCMessage(for: command, currentPacket: currentPacket)
            }
        }
        
        // Function to handle message processing
        func handleMessage(for command: IRCCommand, message: String) async  {
            if message.isEmpty {
                await handleEmptyMessage(for: command)
            } else {
                let packets = try await packetDeriver.calculateAndDispense(text: message)
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
            let message = messageArray.joined(separator: Constants.comma.rawValue)
            await handleMessage(for: .otherCommand(otherCommand, [message]), message: message)
            
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
    
    public func messageReassembler(ircMessage: IRCMessage) async throws -> IRCMessage? {
        
        var packet: MultipartPacket?
        var ircMessage = ircMessage

        for tag in ircMessage.tags ?? [] {
            if tag.key == "packetMetadata" {
                packet = try BSONDecoder().decodeString(MultipartPacket.self, from: tag.value)
            }
        }

        switch ircMessage.command {
        case .privMsg(let recipients, let message):
            packet?.message = message
            guard let packet = packet else { return nil }
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                guard !processedMessage.isEmpty else { return nil }
                ircMessage.command = .privMsg(recipients, processedMessage)
            default:
                return nil
            }
        case .notice(let recipients, let message):
            packet?.message = message
            guard let packet = packet else { return nil }
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                guard !processedMessage.isEmpty else { return nil }
                ircMessage.command = .notice(recipients, processedMessage)
            default:
                return nil
            }
        case .quit(let message):
            if let message = message {
                packet?.message = message
            }
            guard let packet = packet else { return nil }
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                guard !processedMessage.isEmpty else { return nil }
                ircMessage.command = .quit(processedMessage)
            default:
                return nil
            }
        case .otherCommand(let command, let messageArray):
            guard let message = messageArray.first else { return nil }
            packet?.message = message
            guard let packet = packet else { return nil }
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                guard !processedMessage.isEmpty else { return nil }
                let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
                ircMessage.command = .otherCommand(command, rebuiltArray)
            default:
                return nil
            }
        case .otherNumeric(let command, let messageArray):
            guard let message = messageArray.first else { return nil }
            packet?.message = message
            guard let packet = packet else { return nil }
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                guard !processedMessage.isEmpty else { return nil }
                let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
                ircMessage.command = .otherNumeric(command, rebuiltArray)
            default:
                return nil
            }
        default:
            return ircMessage
        }
        return ircMessage
    }
}
