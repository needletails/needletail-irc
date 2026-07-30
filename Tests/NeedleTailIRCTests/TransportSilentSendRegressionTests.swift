//
//  TransportSilentSendRegressionTests.swift
//  needletail-irc
//
//  TDD: silent-send gaps in createMessages / transportMessage.
//

import Testing
import Foundation
import NIOCore
import NeedleTailLogger
import BinaryCodable
@testable import NeedleTailIRC

private struct ThrowingPacketMetadataEncoder: BinaryEncoding {
    enum StubError: Error { case forced }
    func encode<T: Encodable>(_ value: T) throws -> Data {
        if value is MultipartPacket {
            throw StubError.forced
        }
        return try BinaryEncoder().encode(value)
    }
}

private final class CountingWriterDelegate: NeedleTailWriterDelegate, @unchecked Sendable {
    // Default implementations come from the protocol extension.
}

@Suite(.serialized)
struct TransportSilentSendRegressionTests {

    @Test func testTransportMessageThrowsWhenGeneratorYieldsZeroFrames() async throws {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let delegate = CountingWriterDelegate()
        let (writer, _) = NIOAsyncChannelOutboundWriter<IRCPayload>.makeTestingWriter()
        let empty = AsyncThrowingStream<IRCMessage, Error> { continuation in
            continuation.finish()
        }

        await #expect(throws: IRCMessageGeneratorError.zeroFramesGenerated) {
            try await delegate.transportMessage(
                messages: empty,
                executor: executor,
                writer: writer
            )
        }
    }

    @Test func testCreateMessagesEveryFrameCarriesPacketMetadata() async throws {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let generator = IRCMessageGenerator(executor: executor)
        let logger = NeedleTailLogger("[ TransportSilentSendRegressionTests ]")
        let channel = NeedleTailChannel("#meta")!

        let cases: [(String, IRCCommand)] = [
            ("small", .privMsg([.channel(channel)], "hello")),
            ("multipart", .privMsg([.channel(channel)], String(repeating: "x", count: 600))),
            ("other", .otherCommand("CUSTOM", ["payload-body"])),
        ]

        for (label, command) in cases {
            let stream = await generator.createMessages(
                origin: "alice",
                command: command,
                logger: logger
            )
            var frames: [IRCMessage] = []
            for try await message in stream {
                frames.append(message)
            }
            #expect(!frames.isEmpty, "\(label) should yield at least one frame")
            for (index, frame) in frames.enumerated() {
                let hasMetadata = frame.tags?.contains(where: { $0.key == "packet-metadata" }) ?? false
                #expect(hasMetadata, "\(label) frame \(index) missing packet-metadata")
            }
        }
    }

    @Test func testCreateMessagesSurfacesMetadataEncodeFailure() async throws {
        let executor = TestableExecutor(queue: DispatchQueue.global())
        let generator = IRCMessageGenerator(
            executor: executor,
            binaryEncoder: ThrowingPacketMetadataEncoder()
        )
        let logger = NeedleTailLogger("[ TransportSilentSendRegressionTests ]")
        let channel = NeedleTailChannel("#fail")!

        let stream = await generator.createMessages(
            origin: "alice",
            command: .privMsg([.channel(channel)], "must not yield"),
            logger: logger
        )

        var yieldedWithoutMetadata = 0
        var thrown: Error?
        do {
            for try await message in stream {
                let hasMetadata = message.tags?.contains(where: { $0.key == "packet-metadata" }) ?? false
                if !hasMetadata {
                    yieldedWithoutMetadata += 1
                }
            }
        } catch {
            thrown = error
        }

        #expect(yieldedWithoutMetadata == 0, "Must not yield contentless frames on encode failure")
        #expect(thrown as? IRCMessageGeneratorError == .packetMetadataEncodeFailed)
    }
}
