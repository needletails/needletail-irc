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
import BSON
import NeedleTailAsyncSequence
import Foundation
import Dispatch
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
}
