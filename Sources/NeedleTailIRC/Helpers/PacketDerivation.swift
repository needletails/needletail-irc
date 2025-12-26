//
//  PacketDerivation.swift
//  needletail-irc
//
//  Created by Cole M on 6/19/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import Foundation
import Algorithms
import BinaryCodable
import NeedleTailAsyncSequence
import NeedleTailLogger
import NIOCore

/// Represents authentication information for IRC connections.
///
/// `AuthPacket` contains the JWT token and nickname required for authenticating
/// with IRC servers that support JWT-based authentication.
///
/// ## Usage
///
/// ```swift
/// let authPacket = AuthPacket(
///     jwt: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
///     nick: "alice_12345678-1234-1234-1234-123456789abc"
/// )
/// ```
///
/// ## Thread Safety
///
/// This struct is thread-safe and can be used concurrently from multiple threads.
public struct AuthPacket: Codable, Sendable {
    /// The JWT token for authentication.
    public let jwt: String?
    /// The nickname associated with the authentication.
    public let nick: String?
    
    /// Initializes a new authentication packet.
    /// - Parameters:
    ///   - jwt: The JWT token for authentication.
    ///   - nick: The nickname for the user.
    public init(
        jwt: String,
        nick: String
    ) {
        self.jwt = jwt
        self.nick = nick
    }
}

/// Represents a multipart packet for handling large messages and data transfers.
///
/// `MultipartPacket` is used to break down large messages or data into smaller chunks
/// that can be transmitted over IRC protocol limitations. Each packet contains metadata
/// about its position in the overall message and the data itself.
///
/// ## Usage
///
/// ```swift
/// let packet = MultipartPacket(
///     groupId: "msg-123",
///     date: Date(),
///     partNumber: 1,
///     totalParts: 5,
///     message: "Hello, this is part 1 of 5"
/// )
/// ```
///
/// ## Thread Safety
///
/// This struct is thread-safe and can be used concurrently from multiple threads.
public struct MultipartPacket: Sendable, Codable, Hashable {
    /// Unique identifier for the group of packets that make up a complete message.
    public let groupId: String
    /// Timestamp when the packet was created.
    public var date: Date
    /// The position of this packet within the complete message (1-based).
    public var partNumber: Int
    /// Total number of parts that make up the complete message.
    public let totalParts: Int
    /// The message content for this packet (for text-based messages).
    public var message: String?
    /// The binary data for this packet (for file transfers).
    public var data: Data?
    
    /// Initializes a new multipart packet.
    /// - Parameters:
    ///   - groupId: Unique identifier for the packet group.
    ///   - date: Timestamp for the packet creation.
    ///   - partNumber: Position of this packet within the complete message.
    ///   - totalParts: Total number of parts in the complete message.
    ///   - message: Text content for this packet.
    ///   - data: Binary data for this packet.
    public init(
        groupId: String,
        date: Date = Date(),
        partNumber: Int = 0,
        totalParts: Int,
        message: String? = nil,
        data: Data? = nil
    ) {
        self.groupId = groupId
        self.date = date
        self.partNumber = partNumber
        self.totalParts = totalParts
        self.message = message
        self.data = data
    }
    
    func encode(into buffer: inout ByteBuffer) throws {
        // Prefix strings with length so decoding is unambiguous.
        let groupIdBytes = Array(groupId.utf8)
        buffer.writeInteger(UInt16(groupIdBytes.count), endianness: .big)
        buffer.writeBytes(groupIdBytes)
        
        let timeInterval = date.timeIntervalSince1970
        let bitPattern = timeInterval.bitPattern // UInt64
        buffer.writeInteger(bitPattern, endianness: .big)
        
        buffer.writeInteger(Int32(partNumber))
        buffer.writeInteger(Int32(totalParts))
        
        // Encode optional message
        if let message = message {
            buffer.writeInteger(UInt8(1))
            let messageBytes = Array(message.utf8)
            buffer.writeInteger(UInt32(messageBytes.count), endianness: .big)
            buffer.writeBytes(messageBytes)
        } else {
            buffer.writeInteger(UInt8(0))
        }
        
        // Encode optional data
        if let data = data {
            buffer.writeInteger(UInt8(1))
            buffer.writeInteger(UInt32(data.count))
            buffer.writeBytes(data)
        } else {
            buffer.writeInteger(UInt8(0))
        }
    }
    
    static func decode(from buffer: inout ByteBuffer) throws -> MultipartPacket {
        guard let groupIdLen = buffer.readInteger(endianness: .big, as: UInt16.self),
              let groupIdBytes = buffer.readBytes(length: Int(groupIdLen)),
              let groupId = String(bytes: groupIdBytes, encoding: .utf8) else {
            throw NIODecodeError("Missing groupId")
        }
        
        guard let bitPattern = buffer.readInteger(endianness: .big, as: UInt64.self) else {
            throw NIODecodeError("Missing timestamp bits")
        }
        let timeInterval = TimeInterval(bitPattern: bitPattern)
        let date = Date(timeIntervalSince1970: timeInterval)
        
        guard let partNumber = buffer.readInteger(as: Int32.self),
              let totalParts = buffer.readInteger(as: Int32.self) else {
            throw NIODecodeError("Missing part info")
        }
        
        var message: String? = nil
        if let hasMessage = buffer.readInteger(as: UInt8.self), hasMessage == 1 {
            guard let messageLen = buffer.readInteger(endianness: .big, as: UInt32.self),
                  let messageBytes = buffer.readBytes(length: Int(messageLen)),
                  let msg = String(bytes: messageBytes, encoding: .utf8) else {
                throw NIODecodeError("Invalid message payload")
            }
            message = msg
        }
        
        var data: Data? = nil
        if let hasData = buffer.readInteger(as: UInt8.self), hasData == 1,
           let dataLen = buffer.readInteger(as: UInt32.self),
           let bytes = buffer.readBytes(length: Int(dataLen)) {
            data = Data(bytes)
        }
        
        return MultipartPacket(
            groupId: groupId,
            date: date,
            partNumber: Int(partNumber),
            totalParts: Int(totalParts),
            message: message,
            data: data
        )
    }
}

struct NIODecodeError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
    
    init(_ message: String) {
        self.message = message
    }
}

/// A utility for breaking down large messages and data into smaller packets for IRC transmission.
///
/// `PacketDerivation` handles the process of splitting large content into smaller chunks
/// that can be transmitted over IRC protocol limitations (typically 512 bytes per message).
/// It supports both text-based messages and binary data.
///
/// ## Features
///
/// - **Text Chunking**: Splits large text messages into smaller chunks
/// - **Binary Data Chunking**: Splits binary data into manageable packets
/// - **Async Stream Support**: Provides async streams for processing packets
/// - **Configurable Chunk Size**: Allows customization of packet sizes
/// - **Metadata Tracking**: Maintains packet ordering and grouping information
///
/// ## Usage
///
/// ```swift
/// let packetDeriver = PacketDerivation()
///
/// // Split a large text message
/// let textStream = await packetDeriver.calculateAndDispense(
///     text: "This is a very long message that needs to be split...",
///     chunkCount: 512
/// )
///
/// // Split binary data
/// let dataStream = await packetDeriver.calculateAndDispense(
///     data: largeFileData,
///     chunkCount: 512
/// )
///
/// // Process the packets
/// for await packet in textStream {
///     print("Part \(packet.partNumber) of \(packet.totalParts): \(packet.message ?? "")")
/// }
/// ```
///
/// ## IRC Protocol Compliance
///
/// The default chunk size of 512 bytes ensures compliance with IRC protocol limitations
/// while allowing for message overhead (tags, prefixes, etc.).
///
/// ## Thread Safety
///
/// This struct is thread-safe and can be used concurrently from multiple threads.
public struct PacketDerivation: Sendable {
    
    /// Initializes a new packet derivation instance.
    public init() {}
    
    /// Calculates and dispenses packets from text or binary data as an async stream.
    ///
    /// This method takes either text or binary data and breaks it down into smaller packets
    /// that can be transmitted over IRC. It returns an async stream that yields packets
    /// in the correct order.
    ///
    /// ## Text Processing
    ///
    /// When processing text, the method:
    /// - Splits the text into chunks of the specified size
    /// - Creates packets with message content
    /// - Maintains proper ordering and grouping
    ///
    /// ## Binary Data Processing
    ///
    /// When processing binary data, the method:
    /// - Splits the data into chunks of the specified size
    /// - Creates packets with binary data content
    /// - Maintains proper ordering and grouping
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let packetDeriver = PacketDerivation()
    ///
    /// // Process text
    /// let textStream = await packetDeriver.calculateAndDispense(
    ///     text: "Hello, this is a long message that needs splitting",
    ///     chunkCount: 20
    /// )
    ///
    /// // Process binary data
    /// let dataStream = await packetDeriver.calculateAndDispense(
    ///     data: imageData,
    ///     chunkCount: 1024
    /// )
    ///
    /// // Process with custom buffering policy
    /// let customStream = await packetDeriver.calculateAndDispense(
    ///     text: longMessage,
    ///     chunkCount: 512,
    ///     bufferingPolicy: .bufferingNewest(10)
    /// )
    /// ```
    ///
    /// ## IRC Requirements
    ///
    /// The default chunk count of 512 bytes is designed to meet IRC protocol requirements
    /// while allowing space for message overhead including tags, prefixes, and command structure.
    ///
    /// - Parameters:
    ///   - text: The text content to split into packets (optional).
    ///   - data: The binary data to split into packets (optional).
    ///   - chunkCount: The maximum size of each packet in bytes (default: 512).
    ///   - bufferingPolicy: The buffering policy for the async stream (default: .unbounded).
    /// - Returns: An async stream that yields `MultipartPacket` instances.
    public func calculateAndDispense(
        text: String? = nil,
        data: Data? = nil,
        chunkCount: Int = 512,
        bufferingPolicy: AsyncStream<MultipartPacket>.Continuation.BufferingPolicy = .unbounded
    ) async -> AsyncStream<MultipartPacket> {
        var streamContinuation: AsyncStream<MultipartPacket>.Continuation?
        let stream = AsyncStream<MultipartPacket>(bufferingPolicy: bufferingPolicy) { continuation in
            streamContinuation = continuation
        }
        let groupId = UUID().uuidString
        let packetDate = Date()
        
        if let text {
            // Commit 8b7e95f… behavior: chunk by count using Algorithms' String chunks.
            let chunks = text.chunks(ofCount: chunkCount)
            let totalParts = chunks.count
            var packets = [MultipartPacket]()
            packets.reserveCapacity(totalParts)
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
            
            for packet in packets.sorted(by: { $0.partNumber < $1.partNumber }) {
                streamContinuation?.yield(packet)
            }
            
            // Finish the stream if all packets have been yielded
            if totalParts > 0 {
                streamContinuation?.finish()
            }
            
        } else if let data {
            let chunks = data.chunks(ofCount: chunkCount)
            let totalParts = chunks.count
            var packets = [MultipartPacket]()
            packets.reserveCapacity(totalParts)
            
            for (index, chunk) in chunks.enumerated() {
                let packet = MultipartPacket(
                    groupId: groupId,
                    date: packetDate,
                    partNumber: index + 1, // Use index for part number
                    totalParts: totalParts,
                    data: chunk
                )
                packets.append(packet)
            }
            
            for packet in packets.sorted(by: { $0.partNumber < $1.partNumber }) {
                streamContinuation?.yield(packet)
            }
            
            // Finish the stream if all packets have been yielded
            if totalParts > 0 {
                streamContinuation?.finish()
            }
        }
        return stream
    }
}


/// An actor responsible for reassembling multipart packets into complete messages or data.
///
/// `PacketBuilder` manages the process of collecting and reassembling multipart packets
/// that were split for transmission over IRC. It maintains state for multiple packet groups
/// and ensures proper ordering and completion detection.
///
/// ## Features
///
/// - **Packet Grouping**: Organizes packets by their group ID
/// - **Completion Detection**: Automatically detects when all parts are received
/// - **Message Reassembly**: Reconstructs text messages from packet parts
/// - **Data Reassembly**: Reconstructs binary data from packet parts
/// - **Thread Safety**: Uses actor isolation for safe concurrent access
///
/// ## Usage
///
/// ```swift
/// let executor = // ... your executor
/// let packetBuilder = PacketBuilder(executor: executor)
///
/// // Process incoming packets
/// let result = await packetBuilder.processPacket(packet)
/// switch result {
/// case .message(let completeMessage):
///     print("Complete message: \(completeMessage)")
/// case .data(let completeData):
///     print("Complete data: \(completeData.count) bytes")
/// case .none:
///     print("Packet processed, but message not yet complete")
/// }
/// ```
///
/// ## Thread Safety
///
/// This actor is thread-safe and can be used concurrently from multiple threads.
public actor PacketBuilder {
    
    private let executor: any AnyExecutor
    private var packetsByGroupId: [String: [MultipartPacket]] = [:]
    private var groupFirstSeen: [String: Date] = [:]
    private var groupBytes: [String: Int] = [:]
    private var totalBufferedBytes: Int = 0
    private var builtData: Data?
    private var joinedMessage: String?

    /// Max number of concurrent multipart groups to track.
    public var maxConcurrentGroups: Int = 256
    /// Max buffered bytes (message UTF-8 + data bytes) per group before dropping it.
    public var maxBytesPerGroup: Int = 2 * 1024 * 1024
    /// Max buffered bytes across all groups before dropping oldest groups.
    public var maxTotalBufferedBytes: Int = 16 * 1024 * 1024
    /// Timeout after which an incomplete group is dropped.
    public var timeout: TimeInterval = 30.0
    
    /// Initializes a new packet builder with the specified executor.
    /// - Parameter executor: The executor to use for task management.
    public init(executor: any AnyExecutor) {
        self.executor = executor
    }
    
    /// Returns the unowned executor for this actor.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    /// Represents the result of processing a packet.
    public enum ProcessedResult: Sendable {
        /// A complete text message has been assembled.
        case message(String)
        /// Complete binary data has been assembled.
        case data(Data)
        /// No complete message or data is ready yet.
        case none
    }
    
    /// Processes a multipart packet and returns the result if a complete message is assembled.
    ///
    /// This method adds the packet to the appropriate group and checks if all parts
    /// have been received. If so, it reassembles the complete message or data.
    ///
    /// ## Processing Logic
    ///
    /// 1. **Group Identification**: Finds or creates a group for the packet's group ID
    /// 2. **Packet Addition**: Adds the packet to the appropriate group
    /// 3. **Completion Check**: Determines if all parts have been received
    /// 4. **Reassembly**: If complete, reassembles the message or data
    /// 5. **Cleanup**: Removes the completed group from memory
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let packetBuilder = PacketBuilder(executor: executor)
    ///
    /// // Process first packet
    /// let result1 = await packetBuilder.processPacket(packet1)
    /// // Returns .none (not complete yet)
    ///
    /// // Process final packet
    /// let result2 = await packetBuilder.processPacket(packet5)
    /// // Returns .message("Complete message content")
    /// ```
    ///
    /// - Parameter packet: The multipart packet to process.
    /// - Returns: A `ProcessedResult` indicating the processing outcome.
    public func processPacket(_ packet: MultipartPacket) -> ProcessedResult {
        var packet = packet
        if var message = packet.message, message.first == ":" {
                    message = String(message.dropFirst())
            packet.message = message
        }
        cleanupExpiredGroups(now: Date())

        let groupId = packet.groupId
        let packetSize = estimatePacketSize(packet)

        // Ensure group exists
        if packetsByGroupId[groupId] == nil {
            // Evict oldest groups if we're at capacity.
            if packetsByGroupId.count >= maxConcurrentGroups {
                evictOldestGroups(toFitAdditionalBytes: packetSize)
            }
            packetsByGroupId[groupId] = []
            groupFirstSeen[groupId] = Date()
            groupBytes[groupId] = 0
        }

        // Enforce group and global byte budgets.
        let existingGroupBytes = groupBytes[groupId] ?? 0
        if existingGroupBytes + packetSize > maxBytesPerGroup {
            dropGroup(groupId)
            return .none
        }
        if totalBufferedBytes + packetSize > maxTotalBufferedBytes {
            evictOldestGroups(toFitAdditionalBytes: packetSize)
            if totalBufferedBytes + packetSize > maxTotalBufferedBytes {
                // Still cannot fit; drop this group.
                dropGroup(groupId)
                return .none
            }
        }

        packetsByGroupId[groupId, default: []].append(packet)
        groupBytes[groupId] = existingGroupBytes + packetSize
        totalBufferedBytes += packetSize

        return finishProcess(groupId: groupId)
    }

    private func estimatePacketSize(_ packet: MultipartPacket) -> Int {
        let msgBytes = packet.message?.utf8.count ?? 0
        let dataBytes = packet.data?.count ?? 0
        return msgBytes + dataBytes
    }

    private func cleanupExpiredGroups(now: Date) {
        guard timeout > 0 else { return }
        let expired = groupFirstSeen.compactMap { (gid, first) -> String? in
            now.timeIntervalSince(first) > timeout ? gid : nil
        }
        for gid in expired {
            dropGroup(gid)
        }
    }

    private func evictOldestGroups(toFitAdditionalBytes additional: Int) {
        // Evict oldest groups until we have room or no groups remain.
        while totalBufferedBytes + additional > maxTotalBufferedBytes, let oldest = oldestGroupId() {
            dropGroup(oldest)
        }
    }

    private func oldestGroupId() -> String? {
        groupFirstSeen.min(by: { $0.value < $1.value })?.key
    }

    private func dropGroup(_ groupId: String) {
        if let bytes = groupBytes[groupId] {
            totalBufferedBytes = max(0, totalBufferedBytes - bytes)
        }
        packetsByGroupId[groupId] = nil
        groupFirstSeen[groupId] = nil
        groupBytes[groupId] = nil
    }
    
    /// Finishes processing a packet group and reassembles the complete message or data.
    ///
    /// This method checks if all parts of a packet group have been received and,
    /// if so, reassembles the complete content. It handles both text messages
    /// and binary data appropriately.
    ///
    /// ## Reassembly Process
    ///
    /// 1. **Completion Check**: Verifies all parts are present
    /// 2. **Sorting**: Orders packets by part number
    /// 3. **Content Assembly**: Combines message or data content
    /// 4. **Cleanup**: Resets state for the completed group
    ///
    /// - Parameter groupIndex: The index of the packet group to process.
    /// - Returns: A `ProcessedResult` with the assembled content or .none if incomplete.
    private func finishProcess(groupId: String) -> ProcessedResult {
        guard let groupPackets = packetsByGroupId[groupId], let first = groupPackets.first else {
            return .none
        }
        // Check if we have all parts
        if groupPackets.count == first.totalParts {
            let sortedParts = groupPackets.sorted { $0.partNumber < $1.partNumber }
            
            for packet in sortedParts {
                if let message = packet.message {
                    if joinedMessage == nil {
                        joinedMessage = ""
                    }
                    
                    if let currentJoinedMessage = joinedMessage {
                        joinedMessage = currentJoinedMessage + message
                    }
                    
                } else if let data = packet.data {
                    // Initialize builtData if it's nil
                    if builtData == nil {
                        builtData = Data()
                    }
                    
                    // Safely append the data to builtData
                    if var currentBuiltData = builtData {
                        currentBuiltData.append(data)
                        builtData = currentBuiltData // Update the instance variable
                    }
                }
            }
            
            defer {
                joinedMessage = nil
                builtData = nil
            }
            // Return either the joined message or the built data
            if let joinedMessage, !joinedMessage.isEmpty {
                // Remove the completed group
                dropGroup(groupId)
                return .message(joinedMessage)
            } else if let builtData, !builtData.isEmpty {
                // Remove the completed group
                dropGroup(groupId)
                return .data(builtData)
            }
            return .none
        }
        return .none
    }
}


/// An actor responsible for generating IRC messages from commands and handling multipart transmission.
///
/// `IRCMessageGenerator` creates properly formatted IRC messages from commands and manages
/// the process of breaking down large content into multipart packets for transmission.
/// It integrates with the packet derivation system to handle message size limitations.
///
/// ## Features
///
/// - **Message Generation**: Creates IRC messages from commands
/// - **Multipart Handling**: Breaks down large content into packets
/// - **Tag Management**: Handles IRCv3 message tags
/// - **Authentication**: Supports JWT-based authentication
/// - **Async Streams**: Provides async streams for message transmission
/// - **Packet Reassembly**: Can reassemble chunked messages
///
/// ## Usage
///
/// ```swift
/// let executor = // ... your executor
/// let messageGenerator = IRCMessageGenerator(executor: executor)
///
/// // Generate messages for a command
/// let messageStream = await messageGenerator.createMessages(
///     origin: "alice",
///     command: .privMsg([.channel(channel)], "Hello, world!"),
///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
/// )
///
/// // Process the generated messages
/// for await message in messageStream {
///     // Send the message
///     try await sendMessage(message)
/// }
/// ```
///
/// ## Thread Safety
///
/// This actor is thread-safe and can be used concurrently from multiple threads.
public actor IRCMessageGenerator: Sendable {
    
    let executor: any AnyExecutor
    
    private let packetBuilder: PacketBuilder
    
    /// Initializes a new IRC message generator with the specified executor.
    /// - Parameter executor: The executor to use for task management.
    public init(executor: any AnyExecutor) {
        self.executor = executor
        self.packetBuilder = PacketBuilder(executor: executor)
    }
    
    /// Returns the unowned executor for this actor.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
    
    // MARK: - IRC wire-size budgeting
    //
    // IRC message size limits are enforced in BYTES on the wire (including CRLF), not in Character count.
    // This helper computes packet sizes such that the encoded IRC line for each packet fits within
    // `maxLineBytes` (default 512).
    private func buildPacketTags(
        baseTags: [IRCTag]?,
        authPacket: AuthPacket?,
        currentPacket: MultipartPacket,
        logger: NeedleTailLogger
    ) -> [IRCTag] {
        var mutableTags = [IRCTag]()

        if let authPacket {
            do {
                let value = try BinaryEncoder().encode(authPacket).base64EncodedString()
                mutableTags.append(IRCTag(key: "irc-protected", value: value))
            } catch {
                logger.log(level: .error, message: "Error Encoding Auth Packet, \(error)")
            }
        }

        if let baseTags {
            mutableTags.append(contentsOf: baseTags)
        }

        do {
            let packetMetadata = try BinaryEncoder().encode(currentPacket).base64EncodedString()
            mutableTags.append(IRCTag(key: "packet-metadata", value: packetMetadata))
        } catch {
            logger.log(level: .error, message: "Failed to encode IRCTag for packet metadata: \(error)")
        }

        return mutableTags
    }

    private func buildAuthAndBaseTags(
        baseTags: [IRCTag]?,
        authPacket: AuthPacket?,
        logger: NeedleTailLogger
    ) -> [IRCTag] {
        var mutableTags = [IRCTag]()
        if let authPacket {
            do {
                let value = try BinaryEncoder().encode(authPacket).base64EncodedString()
                mutableTags.append(IRCTag(key: "irc-protected", value: value))
            } catch {
                logger.log(level: .error, message: "Error Encoding Auth Packet, \(error)")
            }
        }
        if let baseTags {
            mutableTags.append(contentsOf: baseTags)
        }
        return mutableTags
    }

    private func modifiedCommandForPacket(original command: IRCCommand, packetMessage: String) -> IRCCommand {
        switch command {
        // Commit 8b7e95f… behavior: wrapper command carries no payload; payload is inside packet-metadata.
        case .privMsg(let recipients, _):
            return .privMsg(recipients, "")
        case .notice(let recipients, _):
            return .notice(recipients, "")
        case .quit:
            return .quit(packetMessage)
        case .otherCommand(let otherCommand, _):
            return .otherCommand(otherCommand, [])
        case .otherNumeric(let otherNumeric, _):
            return .otherNumeric(otherNumeric, [])
        default:
            return command
        }
    }

    private func encodedLineByteCount(
        origin: String,
        command: IRCCommand,
        tags: [IRCTag]
    ) -> Int {
        let msg = IRCMessage(origin: origin, command: command, tags: tags)
        // IRCPayloadEncoder appends CRLF.
        return NeedleTailIRCEncoder.encode(value: msg).utf8.count + 2
    }

    /// Returns a prefix of `text[start...]` that is <= `maxBytes` in UTF-8 bytes, without splitting Characters.
    private func nextChunk(
        text: String,
        start: String.Index,
        maxBytes: Int
    ) -> (chunk: Substring, next: String.Index) {
        precondition(maxBytes > 0)
        var end = start
        var used = 0

        while end < text.endIndex {
            let next = text.index(after: end)
            let bytesForChar = text[end..<next].utf8.count
            if used + bytesForChar > maxBytes {
                break
            }
            used += bytesForChar
            end = next
        }

        // Ensure forward progress even for an extremely large single Character.
        if end == start, start < text.endIndex {
            end = text.index(after: start)
        }

        return (text[start..<end], end)
    }

    /// Splits `text` into `MultipartPacket`s sized so that each encoded IRC line fits within `maxLineBytes`.
    ///
    /// - Important: Payload remains inside the base64 `packet-metadata` tag (your required format).
    private func packetizeTextForIRCLimit(
        text: String,
        origin: String,
        command: IRCCommand,
        tags: [IRCTag]?,
        authPacket: AuthPacket?,
        logger: NeedleTailLogger,
        maxLineBytes: Int
    ) -> [MultipartPacket] {
        let maxBytes = max(64, maxLineBytes) // avoid pathological tiny limits
        let groupId = UUID().uuidString
        let packetDate = Date()

        // Baseline overhead with an empty payload packet.
        let baselinePacket = MultipartPacket(groupId: groupId, date: packetDate, partNumber: 1, totalParts: 1, message: "", data: nil)
        let baselineTags = buildPacketTags(baseTags: tags, authPacket: authPacket, currentPacket: baselinePacket, logger: logger)
        let baselineCmd = modifiedCommandForPacket(original: command, packetMessage: "")
        let baselineLineBytes = encodedLineByteCount(origin: origin, command: baselineCmd, tags: baselineTags)

        if baselineLineBytes >= maxBytes {
            logger.log(level: .error, message: "Baseline IRC wrapper exceeds max bytes; cannot send multipart in-tag payload.", metadata: [
                "baselineBytes": "\(baselineLineBytes)",
                "maxBytes": "\(maxBytes)"
            ])
            return []
        }

        // Heuristic: base64 expands ~4/3, so compute a safe starting guess.
        let available = max(1, (maxBytes - baselineLineBytes) - 8)
        let targetChunkBytes = max(1, (available * 3) / 4)

        var packets: [MultipartPacket] = []
        var cursor = text.startIndex
        var part = 1

        while cursor < text.endIndex {
            // Binary search the largest chunk that fits.
            var low = 1
            var high = max(1, targetChunkBytes)
            var bestChunk: Substring = ""
            var bestNext: String.Index = cursor

            // Ensure high doesn't jump beyond remaining text.
            let (initialChunk, initialNext) = nextChunk(text: text, start: cursor, maxBytes: high)
            if initialNext == cursor {
                // Should not happen, but ensure progress.
                let (c, n) = nextChunk(text: text, start: cursor, maxBytes: 1)
                bestChunk = c
                bestNext = n
            } else {
                // Use the initial attempt to seed high accurately.
                // (high is in bytes; nextChunk already clamps to remaining chars)
                _ = initialChunk
                _ = initialNext
            }

            while low <= high {
                let mid = (low + high) / 2
                let (chunk, next) = nextChunk(text: text, start: cursor, maxBytes: mid)
                let packet = MultipartPacket(groupId: groupId, date: packetDate, partNumber: part, totalParts: 0, message: String(chunk), data: nil)
                let t = buildPacketTags(baseTags: tags, authPacket: authPacket, currentPacket: packet, logger: logger)
                let cmd = modifiedCommandForPacket(original: command, packetMessage: String(chunk))
                let bytes = encodedLineByteCount(origin: origin, command: cmd, tags: t)

                if bytes <= maxBytes {
                    bestChunk = chunk
                    bestNext = next
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }

            if bestNext == cursor {
                // Even a single Character couldn't be made to fit under the maxBytes given overhead.
                // We must still progress, but this will likely fail the outbound encoder if strict.
                let (chunk, next) = nextChunk(text: text, start: cursor, maxBytes: 1)
                bestChunk = chunk
                bestNext = next
                logger.log(level: .warning, message: "Unable to fit even minimal chunk within max bytes; overhead too large.", metadata: [
                    "part": "\(part)",
                    "maxBytes": "\(maxBytes)",
                    "baselineBytes": "\(baselineLineBytes)"
                ])
            }

            packets.append(
                MultipartPacket(
                    groupId: groupId,
                    date: packetDate,
                    partNumber: part,
                    totalParts: 1,
                    message: String(bestChunk),
                    data: nil
                )
            )
            part += 1
            cursor = bestNext
        }

        let total = packets.count
        return packets.enumerated().map { idx, p in
            MultipartPacket(
                groupId: p.groupId,
                date: p.date,
                partNumber: idx + 1,
                totalParts: total,
                message: p.message,
                data: p.data
            )
        }
    }

    
    
    
    /// Creates an IRC message with the specified parameters.
    ///
    /// This method constructs an IRC message from the given command and parameters,
    /// handling authentication tags and packet metadata as needed.
    ///
    /// ## Message Construction
    ///
    /// The method handles:
    /// - Command formatting and parameter extraction
    /// - Authentication packet encoding (if provided)
    /// - IRCv3 tag management
    /// - Packet metadata for multipart messages
    ///
    /// - Parameters:
    ///   - command: The IRC command to create a message for.
    ///   - origin: The origin of the message.
    ///   - tags: Optional IRCv3 tags to include.
    ///   - authPacket: Optional authentication packet.
    ///   - logger: Logger instance for error reporting.
    ///   - currentPacket: The current multipart packet being processed.
    ///   - continuation: The async stream continuation for yielding messages.
    func createIRCMessage(
        for command: IRCCommand,
        origin: String,
        tags: [IRCTag]? = nil,
        authPacket: AuthPacket? = nil,
        logger: NeedleTailLogger,
        currentPacket: MultipartPacket,
        continuation: AsyncStream<IRCMessage>.Continuation
    ) async {
        var mutableTags = [IRCTag]()
        if let authPacket {
            do {
                let value = try BinaryEncoder().encode(authPacket).base64EncodedString()
                mutableTags.append(IRCTag(key: "irc-protected", value: value))
            } catch {
                logger.log(level: .error, message: "Error Encoding Auth Packet, \(error)")
            }
        }
        if let tags {
            mutableTags.append(contentsOf: tags)
        }
        
        // Commit 8b7e95f… behavior: encode the full packet (including payload) into the packet-metadata tag,
        // and use a wrapper command that carries no payload (except QUIT).
        guard let packetMessage = currentPacket.message else { return }
        let modifiedCommand = modifiedCommandForPacket(original: command, packetMessage: packetMessage)
        
        do {
            let packetMetadata = try BinaryEncoder().encode(currentPacket).base64EncodedString()
            mutableTags.append(IRCTag(key: "packet-metadata", value: packetMetadata))
        } catch {
            logger.log(level: .error, message: "Failed to encode IRCTag for packet metadata: \(error)")
        }
        
        let message = IRCMessage(
            origin: origin,
            command: modifiedCommand,
            tags: mutableTags)
        //Yields a message but the message mutable tags are empty.
        continuation.yield(message)
        if currentPacket.partNumber == currentPacket.totalParts {
            continuation.finish()
        }
    }
    
    /// Creates a stream of IRC messages from a command, handling multipart content as needed.
    ///
    /// This method is the main entry point for message generation. It takes an IRC command
    /// and creates an async stream of properly formatted IRC messages. For large content,
    /// it automatically breaks the content into multipart packets.
    ///
    /// ## Message Generation Process
    ///
    /// 1. **Command Analysis**: Determines the type of command and its content
    /// 2. **Content Assessment**: Checks if content needs to be split into packets
    /// 3. **Packet Creation**: Uses `PacketDerivation` to create multipart packets
    /// 4. **Message Generation**: Creates IRC messages for each packet
    /// 5. **Stream Yielding**: Yields messages through the async stream
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let messageGenerator = IRCMessageGenerator(executor: executor)
    ///
    /// // Simple message
    /// let simpleStream = await messageGenerator.createMessages(
    ///     origin: "alice",
    ///     command: .privMsg([.channel(channel)], "Hello!")
    /// )
    ///
    /// // Message with tags
    /// let taggedStream = await messageGenerator.createMessages(
    ///     origin: "alice",
    ///     command: .privMsg([.channel(channel)], "Hello!"),
    ///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
    /// )
    ///
    /// // Large message (automatically split)
    /// let largeMessage = String(repeating: "Hello, world! ", count: 100)
    /// let largeStream = await messageGenerator.createMessages(
    ///     origin: "alice",
    ///     command: .privMsg([.channel(channel)], largeMessage)
    /// )
    /// ```
    ///
    /// ## Command Support
    ///
    /// The generator supports all IRC commands including:
    /// - **Messaging**: PRIVMSG, NOTICE
    /// - **Connection**: NICK, USER, QUIT
    /// - **Channels**: JOIN, PART, MODE
    /// - **Information**: WHOIS, WHO, ISON
    /// - **Custom**: Other commands and numeric responses
    ///
    /// - Parameters:
    ///   - origin: The origin of the messages.
    ///   - command: The IRC command to create messages for.
    ///   - tags: Optional IRCv3 tags to include in messages.
    ///   - authPacket: Optional authentication packet for JWT-based auth.
    ///   - logger: Logger instance for error reporting.
    /// - Returns: An async stream that yields `IRCMessage` instances.
    public func createMessages(
        origin: String,
        command: IRCCommand,
        tags: [IRCTag]? = nil,
        authPacket: AuthPacket? = nil,
        logger: NeedleTailLogger,
        maxIRCLineBytesIncludingCRLF: Int = IRCPayloadWireSize.defaultMaxIRCLineBytes
    ) async -> AsyncStream<IRCMessage> {
        var streamContinuation: AsyncStream<IRCMessage>.Continuation?
        let stream = AsyncStream<IRCMessage>(bufferingPolicy: .unbounded) { continuation in
            streamContinuation = continuation
        }
        
        // Helper function to handle empty messages
        func handleEmptyMessage(for command: IRCCommand) async {
            let packet = await createEmptyPacket()
            guard let continuation = streamContinuation else { return }
            await createIRCMessage(
                for: command,
                origin: origin,
                tags: tags,
                authPacket: authPacket,
                logger: logger,
                currentPacket: packet,
                continuation: continuation)
        }
        
        // Helper function to process packets and create IRC messages
        func processPackets(
            packets: AsyncStream<MultipartPacket>,
            command: IRCCommand
        ) async {
            guard let continuation = streamContinuation else { return }
            for await packet in packets {
                //Packets from the stream are properly fed here, but when we create messages the next stream that the CreateMessages method calls contains the next continuation items but the items are empty. Yields a message but the message mutable tags are empty.
                await createIRCMessage(
                    for: command,
                    origin: origin,
                    tags: tags,
                    authPacket: authPacket,
                    logger: logger,
                    currentPacket: packet,
                    continuation: continuation)
            }
        }
        
        // Function to handle message processing
        func handleMessage(for command: IRCCommand, message: String, chunkCount: Int = 512) async {
            if message.isEmpty {
                await handleEmptyMessage(for: command)
            } else {
                // Fast-path: if the full message fits without multipart wrapping, don't add `packet-metadata` at all.
                // This avoids needless overhead for commands like PASS and prevents "baseline exceeds max" failures.
                let singleTags = buildAuthAndBaseTags(baseTags: tags, authPacket: authPacket, logger: logger)
                let single = IRCMessage(origin: origin, command: command, tags: singleTags.isEmpty ? nil : singleTags)
                let singleBytes = NeedleTailIRCEncoder.encode(value: single).utf8.count + 2
                if singleBytes <= chunkCount {
                    streamContinuation?.yield(single)
                    streamContinuation?.finish()
                    return
                }

                let packetsArray = packetizeTextForIRCLimit(
                    text: message,
                    origin: origin,
                    command: command,
                    tags: tags,
                    authPacket: authPacket,
                    logger: logger,
                    maxLineBytes: chunkCount
                )
                if packetsArray.isEmpty {
                    // Baseline overhead too large; we cannot packetize in-tag payload under this max.
                    // Surface as an error so the caller can adjust (increase max bytes or reduce overhead).
                    streamContinuation?.finish()
                    return
                }
                let packets = AsyncStream<MultipartPacket>(bufferingPolicy: .unbounded) { c in
                    for p in packetsArray { c.yield(p) }
                    c.finish()
                }
                await processPackets(packets: packets, command: command)
            }
        }
        
        switch command {
        case .privMsg(_, let message), .notice(_, let message):
            await handleMessage(for: command, message: message, chunkCount: maxIRCLineBytesIncludingCRLF)
            
        case .quit(let message):
            if let message = message {
                await handleMessage(for: command, message: message, chunkCount: maxIRCLineBytesIncludingCRLF)
            } else {
                await handleEmptyMessage(for: command)
            }
            
        case .otherCommand(let otherCommand, let messageArray):
            let message = messageArray.joined(separator: Constants.comma.rawValue)
            await handleMessage(for: .otherCommand(otherCommand, [message]),
                                message: message,
                                chunkCount: maxIRCLineBytesIncludingCRLF)
        case .otherNumeric(let otherNumeric, let messageArray):
            let message = messageArray.joined(separator: Constants.comma.rawValue)
            await handleMessage(for: .otherNumeric(otherNumeric, [message]), message: message, chunkCount: maxIRCLineBytesIncludingCRLF)
            
        default:
            await handleEmptyMessage(for: command)
        }
        return stream
    }
    
    /// Creates an empty packet for commands that don't require content.
    /// - Returns: A `MultipartPacket` representing an empty packet.
    private func createEmptyPacket() async -> MultipartPacket {
        return MultipartPacket(
            groupId: UUID().uuidString,
            date: Date(),
            partNumber: 1,
            totalParts: 1,
            message: ""
        )
    }
    
    /// Reassembles a chunked IRC message from its packet metadata.
    ///
    /// This method takes a wrapper IRC message that contains packet metadata in its tags
    /// and reassembles the complete message by processing the individual packets.
    ///
    /// ## Reassembly Process
    ///
    /// 1. **Metadata Extraction**: Extracts packet metadata from IRC tags
    /// 2. **Packet Processing**: Uses `PacketBuilder` to process the packet
    /// 3. **Message Reconstruction**: Rebuilds the complete IRC message
    /// 4. **Command Restoration**: Restores the original command with complete content
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let messageGenerator = IRCMessageGenerator(executor: executor)
    ///
    /// // Reassemble a chunked message
    /// let reassembledMessage = try await messageGenerator.messageReassembler(ircMessage: chunkedMessage)
    /// if let completeMessage = reassembledMessage {
    ///     print("Complete message: \(completeMessage)")
    /// }
    /// ```
    ///
    /// ## Supported Commands
    ///
    /// The reassembler supports:
    /// - **PRIVMSG**: Private messages
    /// - **NOTICE**: Notice messages
    /// - **QUIT**: Quit messages
    /// - **Other Commands**: Custom commands with array parameters
    /// - **Numeric Commands**: Server responses
    ///
    /// - Parameter ircMessage: The wrapper IRC message containing packet metadata.
    /// - Returns: A reassembled `IRCMessage` with complete content, or `nil` if reassembly fails.
    public func messageReassembler(ircMessage: IRCMessage) async throws -> IRCMessage? {
        var ircMessage = ircMessage
        
        guard let packetTag = ircMessage.tags?.first(where: { $0.key == "packet-metadata" }) else { return nil }
        guard let data = Data(base64Encoded: packetTag.value) else { return nil }
        let packet = try BinaryDecoder().decode(MultipartPacket.self, from: data)
        
        switch ircMessage.command {
        case .privMsg(let recipients, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    ircMessage.command = .privMsg(recipients, processedMessage)
                } else {
                    ircMessage.command = .privMsg(recipients, "")
                }
            default:
                return nil
            }
        case .notice(let recipients, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    ircMessage.command = .notice(recipients, processedMessage)
                } else {
                    ircMessage.command = .notice(recipients, "")
                }
            default:
                return nil
            }
        case .quit(_):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    ircMessage.command = .quit(processedMessage)
                } else {
                    ircMessage.command = .quit("")
                }
            default:
                return nil
            }
        case .otherCommand(let command, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
                    ircMessage.command = .otherCommand(command, rebuiltArray)
                } else {
                    ircMessage.command = .otherCommand(command, [""])
                }
            default:
                return nil
            }
        case .otherNumeric(let command, _):
            switch await packetBuilder.processPacket(packet) {
            case .message(let processedMessage):
                if !processedMessage.isEmpty {
                    let rebuiltArray = processedMessage.components(separatedBy: Constants.comma.rawValue)
                    ircMessage.command = .otherNumeric(command, rebuiltArray)
                } else {
                    ircMessage.command = .otherNumeric(command, [""])
                }
            default:
                return nil
            }
        default:
            return ircMessage
        }
        return ircMessage
    }
}
