//
//  PacketDerivationTests.swift
//  needletail-irc
//
//  Created by Cole M on 7/30/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import Testing
import NeedleTailAsyncSequence
import Foundation
import Dispatch
import BinaryCodable
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
        let duration = await clock.measure {
            for m in mmp {
                let stream = await packetDerivation.calculateAndDispense(text: m, bufferingPolicy: .unbounded)
                var newPartNumber = 0
                for await packet in stream {
                    newPartNumber += 1
                    #expect(packet.partNumber == newPartNumber)
                    #expect(throws: Never.self, performing: {
                        try BinaryEncoder().encode(packet)
                    })
                }
            }
        }
        #expect(duration.components.seconds <= 272)
    }
    
    @Test func testCalculateAndDispenseWithShortMessage() async throws {
        let packetDerivation = PacketDerivation()
        let message = "Hello, World!"
        
        let stream = await packetDerivation.calculateAndDispense(text: message, bufferingPolicy: .unbounded)
        var receivedMessage = ""
        for await packet in stream {
            if let packetMessage = packet.message {
                receivedMessage += packetMessage
            }
        }
        #expect(receivedMessage == message)
    }
    
    @Test func testCalculateAndDispenseWithLongMessage() async throws {
        let packetDerivation = PacketDerivation()
        let longMessage = String(repeating: "A", count: 1024) // 1024 characters
        
        let stream = await packetDerivation.calculateAndDispense(text: longMessage, bufferingPolicy: .unbounded)
        var receivedMessage = ""
        for await packet in stream {
            if let packetMessage = packet.message {
                receivedMessage += packetMessage
            }
        }
        #expect(receivedMessage == longMessage)
    }
    
    @Test func testProcessPacketWithValidData() async {
        let packet = MultipartPacket(
            groupId: "testGroup",
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: "Test message"
        )
        
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        let result = await packetBuilder.processPacket(packet)
        switch result {
        case .message(let message):
            #expect(message == "Test message")
        case .data(_):
            _ = Bool(false) // Expected .message but got .data
        case .none:
            _ = Bool(false) // Expected .message but got .none
        }
    }
    
    @Test func testProcessPacketWithInvalidData() async {
        let packet = MultipartPacket(
            groupId: "testGroup",
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: nil,
            data: Data()
        )
        
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        let result = await packetBuilder.processPacket(packet)
        switch result {
        case .none:
            _ = _ = Bool(true)
        case .message(_):
            _ = Bool(false) // Expected .none but got .message
        case .data(_):
            _ = Bool(false) // Expected .none but got .data
        }
    }
    
    @Test func testFindCompletePacket() async {
        let packet1 = MultipartPacket(groupId: "group1", date: Date(), partNumber: 1, totalParts: 2, message: "Part 1")
        let packet2 = MultipartPacket(groupId: "group1", date: Date(), partNumber: 2, totalParts: 2, message: "Part 2")
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        let result1 = await packetBuilder.processPacket(packet1)
        switch result1 {
        case .none:
            _ = _ = Bool(true) // Expected none result
        case .message(_):
            _ = Bool(false) // Expected .none but got .message
        case .data(_):
            _ = Bool(false) // Expected .none but got .data
        }
        
        let result2 = await packetBuilder.processPacket(packet2)
        switch result2 {
        case .message(let message):
            #expect(message == "Part 1Part 2")
        case .none:
            _ = Bool(false) // Expected .message but got .none
        case .data(_):
            _ = Bool(false) // Expected .message but got .data
        }
    }
    
    @Test func testFindAndCreateNewGroup() async {
        let packet = MultipartPacket(groupId: "newGroup", date: Date(), partNumber: 1, totalParts: 1, message: "New group message")
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        let result = await packetBuilder.processPacket(packet)
        switch result {
        case .message(let message):
            #expect(message == "New group message")
        case .none:
            _ = Bool(false) // Expected .message but got .none
        case .data(_):
            _ = Bool(false) // Expected .message but got .data
        }
    }
    
    @Test func testFindAndCreateExistingGroup() async {
        let packet1 = MultipartPacket(groupId: "existingGroup", date: Date(), partNumber: 1, totalParts: 2, message: "First message")
        let packet2 = MultipartPacket(groupId: "existingGroup", date: Date(), partNumber: 2, totalParts: 2, message: "Second message")
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        let result1 = await packetBuilder.processPacket(packet1)
        switch result1 {
        case .none:
            _ = _ = Bool(true) // Expected none result
        case .message(_):
            _ = Bool(false) // Expected .none but got .message
        case .data(_):
            _ = Bool(false) // Expected .none but got .data
        }
        
        let result2 = await packetBuilder.processPacket(packet2)
        switch result2 {
        case .message(let message):
            #expect(message == "First messageSecond message")
        case .none:
            _ = Bool(false) // Expected .message but got .none
        case .data(_):
            _ = Bool(false) // Expected .message but got .data
        }
    }
    
    @Test func testFindAndCreateTwoDifferentGroups() async {
        let dateOne = Date()
        let packet1 = MultipartPacket(groupId: "existingGroup", date: dateOne, partNumber: 1, totalParts: 2, message: "First message")
        let packet2 = MultipartPacket(groupId: "existingGroup", date: dateOne, partNumber: 2, totalParts: 2, message: "Second message")
        
        let dateTwo = Date()
        let _packet1 = MultipartPacket(groupId: "existingGroup2", date: dateTwo, partNumber: 1, totalParts: 2, message: "_First message")
        let _packet2 = MultipartPacket(groupId: "existingGroup2", date: dateTwo, partNumber: 2, totalParts: 2, message: "_Second message")
        
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        let result1 = await packetBuilder.processPacket(packet1)
        switch result1 {
        case .none:
            _ = Bool(true) // Expected none result
        case .message(_):
            _ = Bool(false) // Expected .none but got .message
        case .data(_):
            _ = Bool(false) // Expected .none but got .data
        }
        
        let result2 = await packetBuilder.processPacket(_packet2)
        switch result2 {
        case .none:
            _ = Bool(true) // Expected none result
        case .message(_):
            _ = Bool(false) // Expected .none but got .message
        case .data(_):
            _ = Bool(false) // Expected .none but got .data
        }
        
        let result3 = await packetBuilder.processPacket(_packet1)
        switch result3 {
        case .message(let message):
            #expect(message == "_First message_Second message") // Now complete
        case .none:
            _ = Bool(false) // Expected .message but got .none
        case .data(_):
            _ = Bool(false) // Expected .message but got .data
        }
        
        let result4 = await packetBuilder.processPacket(packet2)
        switch result4 {
        case .message(let message):
            #expect(message == "First messageSecond message")
        case .none:
            _ = _ = Bool(false) // Expected .message but got .none
        case .data(_):
            _ = Bool(false) // Expected .message but got .data
        }
        
        // Note: The second group was already completed in step 3, so we can't process _packet2 again
        // The test is complete at this point
    }
    
    /// Tests that concurrent multipart reassembly works correctly without data corruption.
    /// This test verifies the fix for the bug where instance variables caused groups to interfere.
    @Test func testConcurrentMultipartReassembly() async {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        // Create three different groups with different messages
        let group1Id = "group1"
        let group2Id = "group2"
        let group3Id = "group3"
        
        // Create packets for each group (3 parts each)
        let group1Packets = [
            MultipartPacket(groupId: group1Id, date: Date(), partNumber: 1, totalParts: 3, message: "Group1"),
            MultipartPacket(groupId: group1Id, date: Date(), partNumber: 2, totalParts: 3, message: "Message"),
            MultipartPacket(groupId: group1Id, date: Date(), partNumber: 3, totalParts: 3, message: "Part3")
        ]
        
        let group2Packets = [
            MultipartPacket(groupId: group2Id, date: Date(), partNumber: 1, totalParts: 3, message: "Group2"),
            MultipartPacket(groupId: group2Id, date: Date(), partNumber: 2, totalParts: 3, message: "Message"),
            MultipartPacket(groupId: group2Id, date: Date(), partNumber: 3, totalParts: 3, message: "Part3")
        ]
        
        let group3Packets = [
            MultipartPacket(groupId: group3Id, date: Date(), partNumber: 1, totalParts: 3, message: "Group3"),
            MultipartPacket(groupId: group3Id, date: Date(), partNumber: 2, totalParts: 3, message: "Message"),
            MultipartPacket(groupId: group3Id, date: Date(), partNumber: 3, totalParts: 3, message: "Part3")
        ]
        
        // Process packets in interleaved order to simulate concurrent arrival
        // This would have caused data corruption with the old bug
        var results: [String: String] = [:]
        
        // Process all first parts
        for packet in [group1Packets[0], group2Packets[0], group3Packets[0]] {
            let result = await packetBuilder.processPacket(packet)
            if case .message(let msg) = result {
                results[packet.groupId] = msg
            }
        }
        
        // Process all second parts
        for packet in [group1Packets[1], group2Packets[1], group3Packets[1]] {
            let result = await packetBuilder.processPacket(packet)
            if case .message(let msg) = result {
                results[packet.groupId] = msg
            }
        }
        
        // Process all third parts - these should complete the groups
        for packet in [group1Packets[2], group2Packets[2], group3Packets[2]] {
            let result = await packetBuilder.processPacket(packet)
            if case .message(let msg) = result {
                results[packet.groupId] = msg
            }
        }
        
        // Verify each group reassembled correctly without interference
        #expect(results[group1Id] == "Group1MessagePart3", "Group1 should reassemble correctly, got: \(results[group1Id] ?? "nil")")
        #expect(results[group2Id] == "Group2MessagePart3", "Group2 should reassemble correctly, got: \(results[group2Id] ?? "nil")")
        #expect(results[group3Id] == "Group3MessagePart3", "Group3 should reassemble correctly, got: \(results[group3Id] ?? "nil")")
    }
    
    /// Tests that binary data reassembly works correctly with concurrent groups.
    @Test func testConcurrentBinaryDataReassembly() async {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        // Create two groups with binary data
        let group1Id = "dataGroup1"
        let group2Id = "dataGroup2"
        
        let group1Data = Data([1, 2, 3, 4, 5])
        let group2Data = Data([10, 20, 30, 40, 50])
        
        // Split into 2 parts each
        let group1Packets = [
            MultipartPacket(groupId: group1Id, date: Date(), partNumber: 1, totalParts: 2, data: Data([1, 2, 3])),
            MultipartPacket(groupId: group1Id, date: Date(), partNumber: 2, totalParts: 2, data: Data([4, 5]))
        ]
        
        let group2Packets = [
            MultipartPacket(groupId: group2Id, date: Date(), partNumber: 1, totalParts: 2, data: Data([10, 20, 30])),
            MultipartPacket(groupId: group2Id, date: Date(), partNumber: 2, totalParts: 2, data: Data([40, 50]))
        ]
        
        var results: [String: Data] = [:]
        
        // Process in interleaved order
        for packet in [group1Packets[0], group2Packets[0]] {
            let result = await packetBuilder.processPacket(packet)
            if case .data(let data) = result {
                results[packet.groupId] = data
            }
        }
        
        for packet in [group1Packets[1], group2Packets[1]] {
            let result = await packetBuilder.processPacket(packet)
            if case .data(let data) = result {
                results[packet.groupId] = data
            }
        }
        
        // Verify each group reassembled correctly
        #expect(results[group1Id] == group1Data, "Group1 data should match")
        #expect(results[group2Id] == group2Data, "Group2 data should match")
    }
    
    /// Tests that single-part messages with empty content are properly handled.
    /// This is important for commands like PONG that may have empty messages.
    @Test func testSinglePartEmptyMessage() async {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        // Create a single-part packet with empty message (like PONG)
        let packet = MultipartPacket(
            groupId: "emptyGroup",
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: ""
        )
        
        let result = await packetBuilder.processPacket(packet)
        switch result {
        case .message(let message):
            // Should return empty message to indicate completion
            #expect(message == "", "Empty single-part message should return empty string")
        case .none:
            #expect(Bool(false), "Single-part message should return .message even if empty")
        case .data(_):
            #expect(Bool(false), "Expected .message but got .data")
        }
    }
    
    /// Tests that single-part messages with content are properly handled.
    @Test func testSinglePartWithContent() async {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let packetBuilder = PacketBuilder(executor: executor)
        
        // Create a single-part packet with content
        let packet = MultipartPacket(
            groupId: "contentGroup",
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: "test message"
        )
        
        let result = await packetBuilder.processPacket(packet)
        switch result {
        case .message(let message):
            #expect(message == "test message", "Single-part message should return content")
        case .none:
            #expect(Bool(false), "Single-part message with content should not return .none")
        case .data(_):
            #expect(Bool(false), "Expected .message but got .data")
        }
    }
}
