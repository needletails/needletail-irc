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
    public var message: String
    
    public init(
        groupId: String,
        date: Date = Date(),
        partNumber: Int = 0,
        totalParts: Int,
        message: String = ""
    ) {
        self.groupId = groupId
        self.date = date
        self.partNumber = partNumber
        self.totalParts = totalParts
        self.message = message
    }
}

public actor PacketDerivation {
    
    public init() {}
    
    public var streamContinuation: AsyncStream<MultipartPacket>.Continuation?
    
    public func calculateAndDispense(
        ircMessage: String,
        bufferingPolicy: AsyncStream<MultipartPacket>.Continuation.BufferingPolicy = .unbounded
    ) async -> AsyncStream<MultipartPacket> {
        
        let stream = AsyncStream<MultipartPacket>(bufferingPolicy: bufferingPolicy) { continuation in
            streamContinuation = continuation
        }
        
        let groupId = UUID().uuidString
        let chunks = ircMessage.chunks(ofCount: 512)
        let totalParts = chunks.count
        let packetDate = Date() // Create the date once
        
        // Pre-allocate an array for packets
        var packets = [MultipartPacket]()
        packets.reserveCapacity(totalParts) // Reserve capacity to avoid reallocations
        
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
        // Yield all packets at once
        for packet in packets.sorted(by: { $0.partNumber < $1.partNumber }) {
            streamContinuation?.yield(packet)
        }
        
        // Finish the stream if all packets have been yielded
        if totalParts > 0 {
            streamContinuation?.finish()
        }
        
        return stream
    }
}


public actor PacketBuilder {
    
    private var packets = [[MultipartPacket]]()
    
    public init() {}
    
    public func processPacket(_ packet: MultipartPacket) -> String? {
        
        // Find the index of the group that contains the packet
        if let groupIndex = packets.firstIndex(where: { $0.first?.groupId == packet.groupId }) {
            // Append the packet to the existing group
            packets[groupIndex].append(packet)
            return finishProcess(groupIndex: groupIndex)
        } else {
            // Create a new group with the packet
            packets.append([packet])
            return finishProcess(groupIndex: packets.count - 1)
        }
    }
    
    private func finishProcess(groupIndex: Int) -> String? {
        let groupPackets = packets[groupIndex]
        
        // Check if we have all parts
        if groupPackets.count == groupPackets.first?.totalParts {
            let sortedParts = groupPackets.sorted { $0.partNumber < $1.partNumber }
            packets.remove(at: groupIndex) // Remove the completed group
            return sortedParts.compactMap { $0.message }.joined()
        }
        
        return nil
    }
}


public actor IRCMessageGenerator: Sendable {
    
    private let packetBuilder = PacketBuilder()
    
    public init() {}
    
    public func createMessages(
        origin: String,
        command: IRCCommand,
        tags: [IRCTags]? = nil,
        logger: NeedleTailLogger
    ) async throws -> AsyncStream<IRCMessage> {
        
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
            
            switch command {
            case .PRIVMSG(let recipients, _), .NOTICE(let recipients, _):
                modifiedCommand = .PRIVMSG(recipients, currentPacket.message)
            case .QUIT(_):
                modifiedCommand = .QUIT(currentPacket.message)
            case .otherCommand(let otherCommand, _):
                modifiedCommand = .otherCommand(otherCommand, [currentPacket.message])
            case .otherNumeric(let otherNumeric, _):
                modifiedCommand = .otherNumeric(otherNumeric, [currentPacket.message])
            default:
                break
            }
            
            var modifiedPacket = currentPacket
            modifiedPacket.message = ""
            
            do {
                let packetMetadata = try BSONEncoder().encodeString(currentPacket)
                mutableTags.append(IRCTags(key: "packetMetadata", value: packetMetadata))
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
            await createIRCMessage(for: command, currentPacket: createEmptyPacket())
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
                let packets = try await packetDeriver.calculateAndDispense(ircMessage: message)
                await processPackets(packets: packets, command: command)
            }
        }
        
        switch command {
        case .PRIVMSG(_, let message), .NOTICE(_, let message):
            await handleMessage(for: command, message: message)
            
        case .QUIT(let message):
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
        //        print("SENDING MESSAGES FOR MESSAGE \(command.commandAsString)'n MESSAGE COUNT: ", ircMessages.count)
        return stream
    }

    private func createEmptyPacket() -> MultipartPacket {
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
        case .PRIVMSG(let recipients, let message):
            packet?.message = message
            guard let packet = packet else { return nil }
            guard let processedMessage = await packetBuilder.processPacket(packet) else { return nil }
            guard !processedMessage.isEmpty else { return nil }
            ircMessage.command = .PRIVMSG(recipients, processedMessage)
        case .NOTICE(let recipients, let message):
            packet?.message = message
            guard let packet = packet else { return nil }
            guard let processedMessage = await packetBuilder.processPacket(packet) else { return nil }
            guard !processedMessage.isEmpty else { return nil }
            ircMessage.command = .NOTICE(recipients, processedMessage)
        case .QUIT(let message):
            if let message = message {
                packet?.message = message
            }
            guard let packet = packet else { return nil }
            guard let processedMessage = await packetBuilder.processPacket(packet) else { return nil }
            guard !processedMessage.isEmpty else { return nil }
            ircMessage.command = .QUIT(processedMessage)
        case .otherCommand(let command, let messageArray):
            guard let message = messageArray.first else { return nil }
            packet?.message = message
            guard let packet = packet else { return nil }
            guard let processedMessage = await packetBuilder.processPacket(packet) else { return nil }
            guard !processedMessage.isEmpty else { return nil }
            let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
            ircMessage.command = .otherCommand(command, rebuiltArray)
        case .otherNumeric(let command, let messageArray):
            guard let message = messageArray.first else { return nil }
            packet?.message = message
            guard let packet = packet else { return nil }
            guard let processedMessage = await packetBuilder.processPacket(packet) else { return nil }
            guard !processedMessage.isEmpty else { return nil }
            let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
            ircMessage.command = .otherNumeric(command, rebuiltArray)
        default:
            return ircMessage
        }
        return ircMessage
    }
}
