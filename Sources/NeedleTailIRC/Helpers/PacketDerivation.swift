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
    let partNumber: Int
    let totalParts: Int
    let message: String
}

public struct PacketDerivation: Sendable {
    
    public init() {}
    
    public func calculateAndDispense(ircMessage: String) async throws -> [ByteBuffer] {
        var packets = [ByteBuffer]()
        var chunkId = 0
        if ircMessage.count > 512 {
            let chunks = ircMessage.chunks(ofCount: 512)
            for chunk in chunks {
                chunkId += 1
                let packet = IRCPacket(
                    id: UUID().uuidString,
                    partNumber: chunkId,
                    totalParts: chunks.count,
                    message: String(chunk))
                packets.append(
                    ByteBuffer(data: try BSONEncoder().encodeData(packet))
                )
            }
        } else {
            let packet = IRCPacket(
                id: UUID().uuidString,
                partNumber: 1,
                totalParts: 1,
                message: ircMessage)
            packets.append(
                ByteBuffer(data: try BSONEncoder().encodeData(packet))
            )
        }
        
        return packets
    }
}

public actor PacketBuilder {
    
    var deque = Deque<IRCPacket>()
    private var ircString = ""
    
    public init() {}
    
    public func processPacket(_ buffer: ByteBuffer) async throws -> String? {
        let packet = try BSONDecoder().decode(IRCPacket.self, from: Document(buffer: buffer))
        deque.append(packet)
        guard deque.count == packet.totalParts else { return nil }
        let sorted = deque.sorted(by: { $0.partNumber < $1.partNumber })
        var ircString = ""
        ircString.append(contentsOf: sorted.compactMap({ $0.message }).joined())
        deque.removeAll()
        return ircString.isEmpty ? nil : ircString
    }
}
