//
//  PacketDerivationTests.swift
//  needletail-irc
//
//  Created by Cole M on 7/30/24.
//


import XCTest
import Testing
import BSON
import CypherMessaging
@testable import NeedleTailIRC

final class PacketDerivationTests {
    
    
    @Test func testCalculateAndDispenseWithShortMessage() async throws {
        let packetDerivation = PacketDerivation()
        let message = "Hello, World!"
        
        let packets = try await packetDerivation.calculateAndDispense(ircMessage: message)
        #expect(packets.count == 1)
        // Further assertions can be made on the content of the packets
    }
    
    @Test func testCalculateAndDispenseWithLongMessage() async throws {
        let packetDerivation = PacketDerivation()
        let longMessage = String(repeating: "A", count: 1024) // 1024 characters
        
        let packets = try await packetDerivation.calculateAndDispense(ircMessage: longMessage)
        
        #expect(packets.count > 1)
        // Further assertions can be made on the content of the packets
    }
    
    @Test func testProcessPacketWithValidData() async {
        let packet = IRCPacket(
            id: UUID().uuidString,
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
        let packet1 = IRCPacket(id: UUID().uuidString, groupId: "group1", date: Date(), partNumber: 1, totalParts: 2, message: "Part 1")
        let packet2 = IRCPacket(id: UUID().uuidString, groupId: "group1", date: Date(), partNumber: 2, totalParts: 2, message: "Part 2")
        let packetBuilder = PacketBuilder()
        
        await packetBuilder.findAndCreate(packet: packet1)
        await packetBuilder.findAndCreate(packet: packet2)
        
        let result = await packetBuilder.findCompletePacket()
        #expect(result == "Part 1Part 2")
    }
    
    @Test func testFindAndCreateNewGroup() async {
        let packet = IRCPacket(id: UUID().uuidString, groupId: "newGroup", date: Date(), partNumber: 1, totalParts: 1, message: "New group message")
        let packetBuilder = PacketBuilder()
        await packetBuilder.findAndCreate(packet: packet)
        await #expect(packetBuilder.deque.count == 1)
        await #expect(packetBuilder.deque.first?.first?.groupId == "newGroup")
    }
    
    @Test func testFindAndCreateExistingGroup() async {
        let packet1 = IRCPacket(id: UUID().uuidString, groupId: "existingGroup", date: Date(), partNumber: 1, totalParts: 1, message: "First message")
        let packet2 = IRCPacket(id: UUID().uuidString, groupId: "existingGroup", date: Date(), partNumber: 2, totalParts: 2, message: "Second message")
        let packetBuilder = PacketBuilder()
        await packetBuilder.findAndCreate(packet: packet1)
        await packetBuilder.findAndCreate(packet: packet2)
        
        
        await #expect(packetBuilder.deque.count == 1)
        await #expect(packetBuilder.deque.first?.count == 2)
    }
    
    @Test func testFindAndCreateTwoDifferentGroups() async {
        let dateOne = Date()
        let packet1 = IRCPacket(id: UUID().uuidString, groupId: "existingGroup", date: dateOne, partNumber: 1, totalParts: 2, message: "First message")
        let packet2 = IRCPacket(id: UUID().uuidString, groupId: "existingGroup", date: dateOne, partNumber: 2, totalParts: 2, message: "Second message")
        
        let dateTwo = Date()
        let _packet1 = IRCPacket(id: UUID().uuidString, groupId: "existingGroup2", date: dateTwo, partNumber: 1, totalParts: 2, message: "_First message")
        let _packet2 = IRCPacket(id: UUID().uuidString, groupId: "existingGroup2", date: dateTwo, partNumber: 2, totalParts: 2, message: "_Second message")
        
        
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
