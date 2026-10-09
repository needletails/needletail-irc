import Foundation
import NIOCore
import NIOEmbedded
import Testing
@testable import NeedleTailIRC

@Suite(.serialized)
struct DCCMessageFramingTests {
    @Test("Every DCCMessage case round-trips through the NIO codec")
    func allCasesRoundTrip() throws {
        let packet = MultipartPacket(
            groupId: "group",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            partNumber: 2,
            totalParts: 3,
            message: "hello",
            data: Data([1, 2, 3])
        )
        let messages: [DCCMessage] = [
            .serviceName("chat"),
            .message(packet),
            .multipart(packet),
            .blob(Data([4, 5, 6])),
            .close,
        ]

        for message in messages {
            let decoded = try decodeSingle(encode(message))
            expectEquivalent(decoded, message)
        }
    }

    @Test("Multipart frames decode when delivered one byte at a time")
    func fragmentedMultipartFrame() throws {
        let packet = MultipartPacket(
            groupId: "fragmented",
            date: Date(timeIntervalSince1970: 1_700_000_001),
            partNumber: 1,
            totalParts: 1,
            message: "payload"
        )
        var encoded = try encode(.message(packet))
        let bytes = encoded.readBytes(length: encoded.readableBytes) ?? []
        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
        )
        defer { _ = try? channel.finish() }

        for byte in bytes {
            var fragment = channel.allocator.buffer(capacity: 1)
            fragment.writeInteger(byte)
            try channel.writeInbound(fragment)
        }

        let inbound = try channel.readInbound(as: IRCFrame.self)
        let payload = try #require(inbound)
        guard case .dcc(let decoded) = payload else {
            Issue.record("Expected a DCC payload")
            return
        }
        expectEquivalent(decoded, .message(packet))
    }

    @Test("Coalesced self-delimiting frames decode independently")
    func coalescedFrames() throws {
        let packet = MultipartPacket(
            groupId: "coalesced",
            date: Date(timeIntervalSince1970: 1_700_000_002),
            partNumber: 1,
            totalParts: 1,
            message: "payload"
        )
        var first = try encode(.multipart(packet))
        var second = try encode(.blob(Data([9, 8, 7])))
        var combined = ByteBuffer()
        combined.writeBuffer(&first)
        combined.writeBuffer(&second)

        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
        )
        defer { _ = try? channel.finish() }
        try channel.writeInbound(combined)

        let firstInbound = try channel.readInbound(as: IRCFrame.self)
        let secondInbound = try channel.readInbound(as: IRCFrame.self)
        let firstPayload = try #require(firstInbound)
        let secondPayload = try #require(secondInbound)
        guard case .dcc(let firstMessage) = firstPayload,
              case .dcc(let secondMessage) = secondPayload
        else {
            Issue.record("Expected two DCC payloads")
            return
        }
        expectEquivalent(firstMessage, .multipart(packet))
        expectEquivalent(secondMessage, .blob(Data([9, 8, 7])))
    }

    /// `serviceName` is the first frame on every Bonjour peer connection and the receiver
    /// refuses to rebind it, so it must be self-delimiting like every other case.
    @Test("serviceName followed by another frame in the same read does not swallow it")
    func serviceNameCoalescedWithNextFrame() throws {
        var first = try encode(.serviceName("chat"))
        var second = try encode(.close)
        var combined = ByteBuffer()
        combined.writeBuffer(&first)
        combined.writeBuffer(&second)

        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
        )
        defer { _ = try? channel.finish() }
        try channel.writeInbound(combined)

        let firstInbound = try #require(try channel.readInbound(as: IRCFrame.self))
        let secondInbound = try #require(try channel.readInbound(as: IRCFrame.self))
        guard case .dcc(let name) = firstInbound, case .dcc(let close) = secondInbound else {
            Issue.record("Expected two DCC frames")
            return
        }
        expectEquivalent(name, .serviceName("chat"))
        expectEquivalent(close, .close)
    }

    @Test("serviceName delivered one byte at a time emits exactly one complete name")
    func serviceNameFragmented() throws {
        var encoded = try encode(.serviceName("alice@device"))
        let bytes = encoded.readBytes(length: encoded.readableBytes) ?? []
        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
        )
        defer { _ = try? channel.finish() }

        for (index, byte) in bytes.enumerated() {
            var fragment = channel.allocator.buffer(capacity: 1)
            fragment.writeInteger(byte)
            try channel.writeInbound(fragment)
            if index < bytes.count - 1 {
                #expect(try channel.readInbound(as: IRCFrame.self) == nil, "no partial name before byte \(index + 1)")
            }
        }

        let inbound = try #require(try channel.readInbound(as: IRCFrame.self))
        guard case .dcc(let decoded) = inbound else {
            Issue.record("Expected a DCC frame")
            return
        }
        expectEquivalent(decoded, .serviceName("alice@device"))
        #expect(try channel.readInbound(as: IRCFrame.self) == nil)
    }

    @Test("Truncated frames do not consume input or emit output")
    func truncatedFrameNeedsMoreData() throws {
        let packet = MultipartPacket(
            groupId: "truncated",
            date: Date(timeIntervalSince1970: 1_700_000_003),
            partNumber: 1,
            totalParts: 1,
            message: "payload"
        )
        var encoded = try encode(.message(packet))
        encoded.moveWriterIndex(to: encoded.writerIndex - 1)
        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
        )
        try channel.writeInbound(encoded)
        #expect(try channel.readInbound(as: IRCFrame.self) == nil)
    }

    @Test("Oversized declared binary fields fail instead of buffering forever")
    func oversizedLengthThrows() {
        var malformed = ByteBuffer()
        malformed.writeInteger(UInt8(1))
        malformed.writeInteger(UInt32(IRCFrameDecoder.defaultMaxLineLength + 1))

        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
        )
        defer { _ = try? channel.finish() }
        #expect(throws: (any Error).self) {
            try channel.writeInbound(malformed)
        }
    }
}

private func encode(_ message: DCCMessage) throws -> ByteBuffer {
    let channel = EmbeddedChannel(
        handler: MessageToByteHandler(IRCFrameEncoder())
    )
    defer { _ = try? channel.finish() }
    try channel.writeOutbound(IRCFrame.dcc(message))
    let outbound = try channel.readOutbound(as: ByteBuffer.self)
    return try #require(outbound)
}

private func decodeSingle(_ buffer: ByteBuffer) throws -> DCCMessage {
    let channel = EmbeddedChannel(
        handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames())
    )
    defer { _ = try? channel.finish() }
    try channel.writeInbound(buffer)
    let inbound = try channel.readInbound(as: IRCFrame.self)
    let payload = try #require(inbound)
    guard case .dcc(let message) = payload else {
        throw DCCMessageTestError.expectedDCC
    }
    return message
}

private func expectEquivalent(_ lhs: DCCMessage, _ rhs: DCCMessage) {
    switch (lhs, rhs) {
    case (.serviceName(let lhs), .serviceName(let rhs)):
        #expect(lhs == rhs)
    case (.message(let lhs), .message(let rhs)),
         (.multipart(let lhs), .multipart(let rhs)):
        #expect(lhs == rhs)
    case (.blob(let lhs), .blob(let rhs)):
        #expect(lhs == rhs)
    case (.close, .close):
        break
    default:
        Issue.record("DCCMessage cases differ: \(lhs), \(rhs)")
    }
}

private enum DCCMessageTestError: Error {
    case expectedDCC
}
