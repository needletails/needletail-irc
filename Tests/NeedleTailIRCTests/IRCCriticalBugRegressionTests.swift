//
//  IRCCriticalBugRegressionTests.swift
//  needletail-irc
//
//  TDD regression tests for critical/high IRC bugs (parser, decoder, encoder).
//

import Testing
import Foundation
import NIOCore
import NIOEmbedded
@testable import NeedleTailIRC

@Suite(.serialized)
struct IRCCriticalBugRegressionTests {

    // MARK: - Parser

    @Test func testParsePrefixOnlyLineThrowsNotTraps() throws {
        #expect(throws: (any Error).self) {
            _ = try NeedleTailIRCParser.parseMessage(":nickonly")
        }
        #expect(throws: (any Error).self) {
            _ = try NeedleTailIRCParser.parseMessage("@tag=val :nick")
        }
    }

    @Test func testPrivMsgSingleTokenColonBodyParses() throws {
        // RFC-legal: single-token body without trailing colon. Mid-token ':' must not split.
        let message = try NeedleTailIRCParser.parseMessage("PRIVMSG #c 1:2")
        guard case .privMsg(let recipients, let body) = message.command else {
            Issue.record("Expected .privMsg, got \(message.command)")
            return
        }
        #expect(recipients.count == 1)
        if case .channel(let channel) = recipients.first {
            #expect(channel.stringValue == "#c")
        } else {
            Issue.record("Expected channel recipient #c")
        }
        #expect(body == "1:2")
    }

    /// PIN: verified-correct today — must stay green after splitArguments fix.
    @Test func testPrefixedPrivMsgEmbeddedColonTrailingPin() throws {
        let message = try NeedleTailIRCParser.parseMessage(":nick!u@h PRIVMSG #c :He said :hi")
        guard case .privMsg(_, let body) = message.command else {
            Issue.record("Expected .privMsg, got \(message.command)")
            return
        }
        #expect(body == "He said :hi")
    }

    // MARK: - Decoder

    /// PIN / defensive: NIO `getString` lossy-decodes invalid UTF-8 (never nil), so the
    /// historic "needMoreData after consume" stall is not reachable via bad UTF-8 alone.
    /// Still require the next valid line to decode; GREEN keeps `.continue` if string decode fails.
    @Test func testDecoderInvalidUTF8LineDoesNotBlockNextLine() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCPayloadDecoder()))
        defer { _ = try? channel.finish() }

        var buffer = channel.allocator.buffer(capacity: 64)
        buffer.writeBytes([0xFF, 0xFE]) // invalid UTF-8 (lossy → U+FFFD under NIO getString)
        buffer.writeString("\r\n")
        buffer.writeString("PRIVMSG #x :ok\r\n")

        try channel.writeInbound(buffer)

        var sawOK = false
        while let payload = try channel.readInbound(as: IRCPayload.self) {
            if case .irc(let msg) = payload, case .privMsg(_, let body) = msg.command, body == "ok" {
                sawOK = true
            }
        }
        #expect(sawOK, "Valid PRIVMSG after invalid UTF-8 line must still decode")
    }

    @Test func testDecoderRejectsOversizedLineWithoutNewline() throws {
        let maxLen = 1024
        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCPayloadDecoder.withBinaryFrames(maxLineLength: maxLen))
        )
        defer { _ = try? channel.finish() }

        var buffer = channel.allocator.buffer(capacity: maxLen + 64)
        buffer.writeString(String(repeating: "A", count: maxLen + 1))

        var threw = false
        do {
            try channel.writeInbound(buffer)
        } catch {
            threw = true
        }
        #expect(threw, "Decoder must reject oversized line without newline")
    }

    @Test func testDecoderLineBasedIRCTreatsLowBytesAsIRC() throws {
        let channel = EmbeddedChannel(
            handler: ByteToMessageHandler(IRCPayloadDecoder.lineBasedIRC())
        )
        defer { _ = try? channel.finish() }

        // Leading 0x00 would take the binary-frame branch when binary framing is enabled.
        // With lineBasedIRC + a newline later, IRC line framing must proceed.
        var buffer = channel.allocator.buffer(capacity: 64)
        buffer.writeBytes([0x00])
        buffer.writeString("PRIVMSG #x :from-null-prefix\r\n")

        try channel.writeInbound(buffer)

        var sawIRC = false
        while let payload = try channel.readInbound(as: IRCPayload.self) {
            if case .irc = payload {
                sawIRC = true
            }
            if case .dcc = payload {
                Issue.record("Binary-frame path must not run for lineBasedIRC()")
            }
        }
        // Either we got an IRC payload, or the bad line was skipped and we continued —
        // but we must not be stuck forever in DCC needMoreData with no progress.
        // Writing a clean follow-up line proves the decoder is still framing IRC.
        var follow = channel.allocator.buffer(capacity: 32)
        follow.writeString("PRIVMSG #x :ok2\r\n")
        try channel.writeInbound(follow)
        while let payload = try channel.readInbound(as: IRCPayload.self) {
            if case .irc(let msg) = payload, case .privMsg(_, let body) = msg.command, body == "ok2" {
                sawIRC = true
            }
        }
        #expect(sawIRC, "With lineBasedIRC(), IRC framing must continue after low first byte")
    }

    // MARK: - Encoder

    @Test func testEncoderStripsEmbeddedNewlinesFromIRCLine() throws {
        guard let channel = NeedleTailChannel("#c") else {
            Issue.record("Failed to create channel")
            return
        }
        let message = IRCMessage(
            command: .privMsg([.channel(channel)], "line1\nline2")
        )
        let encoder = IRCPayloadEncoder()
        var out = ByteBufferAllocator().buffer(capacity: 128)
        try encoder.encode(data: .irc(message), out: &out)

        guard let written = out.getString(at: out.readerIndex, length: out.readableBytes) else {
            Issue.record("Expected encoded string")
            return
        }
        #expect(written.hasSuffix("\r\n"))
        let withoutFraming = String(written.dropLast(2))
        #expect(!withoutFraming.contains("\n"), "Body must not contain mid-line newline")
        #expect(!withoutFraming.contains("\r"), "Body must not contain mid-line CR")
    }
}
