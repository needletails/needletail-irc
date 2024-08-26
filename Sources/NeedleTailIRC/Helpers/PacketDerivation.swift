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


public struct IRCPacket: Sendable, Codable, Hashable {
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
    
    public var streamContinuation: AsyncStream<IRCPacket>.Continuation?
    
    public func calculateAndDispense(
        ircMessage: String,
        bufferingPolicy: AsyncStream<IRCPacket>.Continuation.BufferingPolicy
    ) async throws -> AsyncStream<IRCPacket> {
        
        let stream = AsyncStream<IRCPacket>(bufferingPolicy: bufferingPolicy) { continuation in
            streamContinuation = continuation
        }
        
        let groupId = UUID().uuidString
        let chunks = ircMessage.chunks(ofCount: 512)
        let totalParts = chunks.count
        let packetDate = Date() // Create the date once
        
        // Pre-allocate an array for packets
        var packets = [IRCPacket]()
        packets.reserveCapacity(totalParts) // Reserve capacity to avoid reallocations
        
        for (index, chunk) in chunks.enumerated() {
            let packet = IRCPacket(
                groupId: groupId,
                date: packetDate,
                partNumber: index + 1, // Use index for part number
                totalParts: totalParts,
                message: String(chunk)
            )
            packets.append(packet)
        }
        
        // Yield all packets at once
        for packet in packets {
            await streamContinuation?.yield(packet)
        }
        
        // Finish the stream if all packets have been yielded
        if totalParts > 0 {
            streamContinuation?.finish()
        }
        
        return stream
    }
}


public actor PacketBuilder {
    
    var groupIdToPacketsMap = [String: Deque<IRCPacket>]()
    
    public init() {}
    
    public func processPacket(_ buffer: ByteBuffer) async -> String? {
        do {
            let packet = try BSONDecoder().decode(IRCPacket.self, from: Document(buffer: buffer))
            findAndCreate(packet: packet)
            return findCompletePacket()
        } catch {
            groupIdToPacketsMap.removeAll()
            return nil
        }
    }
    
    func findCompletePacket() -> String? {
        var completePacket = [IRCPacket]()
        var oldestDate: Date? = nil
        
        for (groupId, packets) in groupIdToPacketsMap {
            guard let firstPacket = packets.first, packets.count == firstPacket.totalParts else { continue }
            if completePacket.isEmpty || firstPacket.date < oldestDate! {
                completePacket.append(contentsOf: packets)
                oldestDate = firstPacket.date
            }
        }
        
        // Create the IRC string if a complete packet was found
        let ircString = completePacket.sorted(by: { $0.partNumber < $1.partNumber })
                .compactMap { $0.message }
                .joined()
        if let groupId = completePacket.first?.groupId {
            groupIdToPacketsMap.removeValue(forKey: groupId)
        }
        
        return ircString
    }
    
    func findAndCreate(packet: IRCPacket) {
        // Check if there are already packets for the given groupId
        if var packets = groupIdToPacketsMap[packet.groupId] {
            // Append the new packet to the existing array
            packets.append(packet)
            // Update the dictionary with the modified array
            groupIdToPacketsMap[packet.groupId] = packets
        } else {
            // If no packets exist for the groupId, create a new array and add the packet
            groupIdToPacketsMap[packet.groupId] = [packet]
        }
    }
}
