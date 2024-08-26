//
//  PacketDerivationTests.swift
//  needletail-irc
//
//  Created by Cole M on 7/30/24.
//

import Testing
import BSON
import CypherMessaging
import NeedleTailAsyncSequence
@testable import NeedleTailIRC

final class PacketDerivationTests {
    
    /// Tests about 325 MB Derivation at a bout 2 minutes.. Not bad for a large file
    @Test func testsSendMultiPartMessagePackets() async throws {
        let packetDerivation = PacketDerivation()
        let mms = String(repeating: "M", count: 10777216)
        var mmp: [String] = []
        for _ in 0..<32 {
            mmp.append(mms)
        }
        let clock = ContinuousClock()
        let duration = try await clock.measure {
        for m in mmp {
            let stream = try await packetDerivation.calculateAndDispense(ircMessage: m, bufferingPolicy: .unbounded)
            await packetDerivation.streamContinuation?.finish()
            var newPartNumber = 0
            for await packet in stream {
                newPartNumber += 1
                #expect(packet.partNumber == newPartNumber)
                #expect(throws: Never.self, performing: {
                    try BSONEncoder().encode(packet).makeByteBuffer()
                })
            }
            }
        }
        #expect(duration.components.seconds <= 272)
    }
    
    @Test func testCalculateAndDispenseWithShortMessage() async throws {
        let packetDerivation = PacketDerivation()
        let message = "Hello, World!"
        
        let stream = try await packetDerivation.calculateAndDispense(ircMessage: message, bufferingPolicy: .unbounded)
        await packetDerivation.streamContinuation?.finish()
        for await packet in stream {
            #expect(packet.message == message)
        }
    }
    
    @Test func testCalculateAndDispenseWithLongMessage() async throws {
        let packetDerivation = PacketDerivation()
        let longMessage = String(repeating: "A", count: 1024) // 1024 characters
        
        let stream = try await packetDerivation.calculateAndDispense(ircMessage: longMessage, bufferingPolicy: .unbounded)
        await packetDerivation.streamContinuation?.finish()
        for await packet in stream {
            #expect(packet.message == longMessage)
        }
    }
    
    @Test func testProcessPacketWithValidData() async {
        let packet = IRCPacket(
            groupId: "testGroup",
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: "Test message"
        )
        
        let buffer = ByteBuffer(data: try! BSONEncoder().encodeData(packet))
        let packetBuilder = PacketBuilder()
        let result = await packetBuilder.processPacket(buffer)
        #expect(result == "Test message")
    }
    
    @Test func testProcessPacketWithInvalidData() async {
        let invalidBuffer = ByteBuffer(data: Data()) // Empty data
        let packetBuilder = PacketBuilder()
        let result = await packetBuilder.processPacket(invalidBuffer)
        #expect(result == nil)
    }
    
    @Test func testFindCompletePacket() async {
        let packet1 = IRCPacket(groupId: "group1", date: Date(), partNumber: 1, totalParts: 2, message: "Part 1")
        let packet2 = IRCPacket(groupId: "group1", date: Date(), partNumber: 2, totalParts: 2, message: "Part 2")
        let packetBuilder = PacketBuilder()
        
        await packetBuilder.findAndCreate(packet: packet1)
        await packetBuilder.findAndCreate(packet: packet2)
        
        let result = await packetBuilder.findCompletePacket()
        #expect(result == "Part 1Part 2")
    }
    
    @Test func testFindAndCreateNewGroup() async {
        let packet = IRCPacket(groupId: "newGroup", date: Date(), partNumber: 1, totalParts: 1, message: "New group message")
        let packetBuilder = PacketBuilder()
        await packetBuilder.findAndCreate(packet: packet)
        await #expect(packetBuilder.deque.count == 1)
        await #expect(packetBuilder.deque.first?.first?.groupId == "newGroup")
    }
    
    @Test func testFindAndCreateExistingGroup() async {
        let packet1 = IRCPacket(groupId: "existingGroup", date: Date(), partNumber: 1, totalParts: 1, message: "First message")
        let packet2 = IRCPacket(groupId: "existingGroup", date: Date(), partNumber: 2, totalParts: 2, message: "Second message")
        let packetBuilder = PacketBuilder()
        await packetBuilder.findAndCreate(packet: packet1)
        await packetBuilder.findAndCreate(packet: packet2)
        
        
        await #expect(packetBuilder.deque.count == 1)
        await #expect(packetBuilder.deque.first?.count == 2)
    }
    
    @Test func testFindAndCreateTwoDifferentGroups() async {
        let dateOne = Date()
        let packet1 = IRCPacket(groupId: "existingGroup", date: dateOne, partNumber: 1, totalParts: 2, message: "First message")
        let packet2 = IRCPacket(groupId: "existingGroup", date: dateOne, partNumber: 2, totalParts: 2, message: "Second message")
        
        let dateTwo = Date()
        let _packet1 = IRCPacket(groupId: "existingGroup2", date: dateTwo, partNumber: 1, totalParts: 2, message: "_First message")
        let _packet2 = IRCPacket(groupId: "existingGroup2", date: dateTwo, partNumber: 2, totalParts: 2, message: "_Second message")
        
        
        let packetBuilder = PacketBuilder()
        await packetBuilder.findAndCreate(packet: packet1)
        await packetBuilder.findAndCreate(packet: _packet2)

        
        let result = await packetBuilder.findCompletePacket()
        #expect(result == nil)
        await packetBuilder.findAndCreate(packet: _packet1)
        await packetBuilder.findAndCreate(packet: packet2)
        let result2 = await packetBuilder.findCompletePacket()
        #expect(result == nil)
        #expect(result2 == "First messageSecond message")
        
        if await !packetBuilder.deque.isEmpty {
            let result3 = await packetBuilder.findCompletePacket()
            #expect(result3 == "_First message_Second message")
        }
    }    
}
