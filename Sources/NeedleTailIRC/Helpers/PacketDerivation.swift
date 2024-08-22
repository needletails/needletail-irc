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
    public var id: String
    public let groupId: String
    public var date: Date
    public var partNumber: Int
    public let totalParts: Int
    public var message: String
    
    public init(id: String = "", groupId: String, date: Date = Date(), partNumber: Int = 0, totalParts: Int, message: String = "") {
        self.id = id
        self.groupId = groupId
        self.date = date
        self.partNumber = partNumber
        self.totalParts = totalParts
        self.message = message
    }
}

public actor PacketDerivation {
    
    public init() {}

    private var partNumber = 0
    public var streamContinuation: AsyncStream<IRCPacket>.Continuation?
    
    public func calculateAndDispense(ircMessage: String, bufferingPolicy: AsyncStream<IRCPacket>.Continuation.BufferingPolicy) async throws -> AsyncStream<IRCPacket> {
        
        let stream = AsyncStream<IRCPacket>(bufferingPolicy: bufferingPolicy) { continuation in
            streamContinuation = continuation
            continuation.onTermination = { status in
                print("Monitor Stream Terminated with status: \(status)")
            }
        }
        
        let groupId = UUID().uuidString
        if #available(iOS 17, macOS 14, *) {
            let chunkCount = (ircMessage.count / 512)
            let chunks = ircMessage.chunks(ofCount: 512)
            partNumber = 0
            for chunk in chunks {
                partNumber += 1
                let packet = IRCPacket(
                    id: UUID().uuidString,
                    groupId: groupId,
                    date: Date(),
                    partNumber: self.partNumber,
                    totalParts: chunkCount,
                    message: String(chunk)
                )
                
                streamContinuation?.yield(packet)
            }
            return stream
        }
        return stream
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
