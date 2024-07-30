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


struct IRCPacket: Sendable, Codable, Hashable {
    let id: String
    let groupId: String
    let date: Date
    let partNumber: Int
    let totalParts: Int
    let message: String
}

public struct PacketDerivation: Sendable {
    
    public init() {}
    
    public func calculateAndDispense(ircMessage: String) async throws -> [ByteBuffer] {
        var packets = [ByteBuffer]()
        let groupId = UUID().uuidString
        let date = Date()
        
        if ircMessage.count > 512 {
            let chunks = ircMessage.chunks(ofCount: 512)
            for (chunkId, chunk) in chunks.enumerated() {
                let packet = IRCPacket(
                    id: UUID().uuidString,
                    groupId: groupId,
                    date: date,
                    partNumber: chunkId + 1,
                    totalParts: chunks.count,
                    message: String(chunk))
                packets.append(ByteBuffer(data: try BSONEncoder().encodeData(packet)))
            }
        } else {
            let packet = IRCPacket(
                id: UUID().uuidString,
                groupId: groupId,
                date: date,
                partNumber: 1,
                totalParts: 1,
                message: ircMessage)
            packets.append(ByteBuffer(data: try BSONEncoder().encodeData(packet)))
        }
        
        return packets
    }
}

public actor PacketBuilder {
    
    var deque = Deque<[IRCPacket]>()
    
    public init() {}
    
    public func processPacket(_ buffer: ByteBuffer) async -> String? {
        do {
            let packet = try BSONDecoder().decode(IRCPacket.self, from: Document(buffer: buffer))
            findAndCreate(packet: packet)
            return findCompletePacket()
        } catch {
            deque.removeAll()
            return nil
        }
    }
    
    func findCompletePacket() -> String? {
        var completePacket: [IRCPacket]? = nil
        var oldestDate: Date? = nil
        
        for array in deque {
            guard let firstElement = array.first else { continue }
            if array.count == firstElement.totalParts {
                if completePacket == nil || firstElement.date < oldestDate! {
                    completePacket = array
                    oldestDate = firstElement.date
                }
            }
        }
        
        // Create the IRC string if a complete packet was found
        let ircString = completePacket.map { packet in
            packet.sorted(by: { $0.partNumber < $1.partNumber })
                .compactMap { $0.message }
                .joined()
        }
        deque.removeAll(where: { $0.contains(where: { $0.groupId == completePacket?.first?.groupId }) })
        return ircString
    }
    
    func findAndCreate(packet: IRCPacket) {
        if let index = deque.firstIndex(where: { $0.contains(where: { $0.groupId == packet.groupId }) }) {
            deque[index].append(packet)
        } else {
            deque.append([packet])
        }
    }
}
