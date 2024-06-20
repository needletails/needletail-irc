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


struct IRCPacket: Sendable, Codable {
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
    
    private var packets = [IRCPacket]()
    private var ircString = ""
    
    public init() {}
    
    public func processPacket(_ buffer: ByteBuffer) throws -> String? {
        let packet = try BSONDecoder().decode(IRCPacket.self, from: Document(buffer: buffer))
        packets.append(packet)
        
        //We are the final packet. so build and process the message
        if packet.partNumber == packet.totalParts {
            ircString = ""
            for packet in packets {
                ircString += packet.message
            }
            
            packets.removeAll()
            return ircString
        }
        return nil
    }
    
}
