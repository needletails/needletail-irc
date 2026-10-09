import Foundation
import NIOCore
import Testing
@testable import NeedleTailIRC

/// `IRCMessage`'s own wire contract, exercised directly on `ByteBuffer` without a NIO pipeline.
/// Mirrors the shape used by `IRCBinaryMessage` and `DCCMessage`.
struct IRCMessageWireTests {

    private let channel = NeedleTailChannel("#c")!

    // MARK: - Encode

    @Test("encode(into:) writes the line plus CRLF")
    func encodeAppendsTerminator() throws {
        let message = IRCMessage(command: .privMsg([.channel(channel)], "hello"))
        var buffer = ByteBuffer()
        try message.encode(into: &buffer)
        let written = buffer.getString(at: 0, length: buffer.readableBytes)
        #expect(written == "PRIVMSG #c :hello\r\n")
    }

    @Test("Embedded CR/LF are stripped so a line cannot contain its own terminator")
    func encodeStripsEmbeddedLineBreaks() throws {
        let message = IRCMessage(command: .privMsg([.channel(channel)], "line1\r\nline2\nline3\rline4"))
        let line = try message.wireLine()
        #expect(!line.unicodeScalars.contains("\n"))
        #expect(!line.unicodeScalars.contains("\r"))
        #expect(line.hasSuffix("line1line2line3line4"))
    }

    /// Regression: "\r\n" is one Swift `Character`, so a Character-level strip let a CRLF
    /// pair through and the body could smuggle a second command onto the wire.
    @Test("CRLF pair in a body cannot inject a second IRC command")
    func encodePreventsCRLFInjection() throws {
        let message = IRCMessage(command: .privMsg([.channel(channel)], "hi\r\nQUIT :bye"))
        var buffer = ByteBuffer()
        try message.encode(into: &buffer)

        var decoded: [IRCMessage] = []
        while buffer.readableBytes > 0 {
            if case .message(let m) = try IRCMessage.decode(from: &buffer, maxLineLength: 512) {
                decoded.append(m)
            }
        }
        #expect(decoded.count == 1, "exactly one command must come out, got \(decoded.map(\.command.description))")
        if let only = decoded.first, case .privMsg(_, let body) = only.command {
            #expect(body == "hiQUIT :bye")
        } else {
            Issue.record("Expected a single PRIVMSG")
        }
    }

    @Test("Empty JOIN/PART/PRIVMSG/NOTICE are rejected at encode")
    func encodeRejectsEmptyCommands() {
        let empties: [IRCCommand] = [
            .join(channels: [], keys: nil),
            .part(channels: []),
            .privMsg([], "x"),
            .notice([], "x"),
        ]
        for command in empties {
            var buffer = ByteBuffer()
            #expect(throws: IRCMessageGeneratorError.emptyCommandRejected) {
                try IRCMessage(command: command).encode(into: &buffer)
            }
            #expect(buffer.readableBytes == 0, "nothing may be written on failure")
        }
    }

    @Test("IRCFrame.encode(into:) delegates to the payload")
    func frameDelegates() throws {
        let message = IRCMessage(command: .privMsg([.channel(channel)], "via frame"))
        var direct = ByteBuffer()
        var viaFrame = ByteBuffer()
        try message.encode(into: &direct)
        try IRCFrame.text(message).encode(into: &viaFrame)
        #expect(direct == viaFrame)
    }

    // MARK: - Decode

    @Test("decode(from:) consumes exactly one CRLF line and parses it")
    func decodeConsumesOneLine() throws {
        var buffer = ByteBuffer(string: "PRIVMSG #c :one\r\nPRIVMSG #c :two\r\n")
        let first = try IRCMessage.decode(from: &buffer, maxLineLength: 512)
        guard case .message(let message) = first, case .privMsg(_, let body) = message.command else {
            Issue.record("Expected parsed PRIVMSG")
            return
        }
        #expect(body == "one")
        #expect(buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) == "PRIVMSG #c :two\r\n")
    }

    @Test("Bare LF terminator is accepted")
    func decodeAcceptsBareLF() throws {
        var buffer = ByteBuffer(string: "PRIVMSG #c :lf\n")
        guard case .message(let message) = try IRCMessage.decode(from: &buffer, maxLineLength: 512),
              case .privMsg(_, let body) = message.command else {
            Issue.record("Expected parsed PRIVMSG")
            return
        }
        #expect(body == "lf")
        #expect(buffer.readableBytes == 0)
    }

    @Test("No terminator yet → incomplete, nothing consumed")
    func decodeIncompleteWithoutNewline() {
        var buffer = ByteBuffer(string: "PRIVMSG #c :partial")
        let before = buffer.readerIndex
        do {
            _ = try IRCMessage.decode(from: &buffer, maxLineLength: 512)
            Issue.record("Expected incomplete")
        } catch let error as NIODecodeError {
            #expect(error.kind == .incomplete)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(buffer.readerIndex == before)
    }

    @Test("Pending bytes over maxLineLength without a newline throw lineTooLong")
    func decodeRejectsOversizedPendingLine() {
        var buffer = ByteBuffer(string: String(repeating: "A", count: 65))
        #expect(throws: IRCMessage.LineError.lineTooLong(maxLineLength: 64)) {
            _ = try IRCMessage.decode(from: &buffer, maxLineLength: 64)
        }
    }

    @Test("A terminated line over maxLineLength also throws lineTooLong")
    func decodeRejectsOversizedTerminatedLine() {
        var buffer = ByteBuffer(string: String(repeating: "A", count: 65) + "\r\n")
        #expect(throws: IRCMessage.LineError.lineTooLong(maxLineLength: 64)) {
            _ = try IRCMessage.decode(from: &buffer, maxLineLength: 64)
        }
    }

    @Test("Blank line is consumed and reported as ignored")
    func decodeIgnoresBlank() throws {
        var buffer = ByteBuffer(string: " \t\r\nPRIVMSG #c :after\r\n")
        guard case .ignored(.blank) = try IRCMessage.decode(from: &buffer, maxLineLength: 512) else {
            Issue.record("Expected .ignored(.blank)")
            return
        }
        guard case .message = try IRCMessage.decode(from: &buffer, maxLineLength: 512) else {
            Issue.record("Following line must still decode")
            return
        }
    }

    @Test("Unparsable line is consumed and reported, not thrown")
    func decodeReportsUnparsable() throws {
        var buffer = ByteBuffer(string: " NICK alice\r\nPRIVMSG #c :after\r\n")
        guard case .ignored(.unparsable(let line, _)) = try IRCMessage.decode(from: &buffer, maxLineLength: 512) else {
            Issue.record("Expected .ignored(.unparsable)")
            return
        }
        #expect(line == " NICK alice")
        guard case .message = try IRCMessage.decode(from: &buffer, maxLineLength: 512) else {
            Issue.record("Following line must still decode")
            return
        }
    }

    @Test("Encode → decode round-trips the command")
    func roundTrip() throws {
        let original = IRCMessage(
            origin: "alice!a@h",
            command: .privMsg([.channel(channel)], "round trip"),
            tags: [IRCTag(key: "msgid", value: "42")]
        )
        var buffer = ByteBuffer()
        try original.encode(into: &buffer)
        guard case .message(let decoded) = try IRCMessage.decode(from: &buffer, maxLineLength: 512) else {
            Issue.record("Expected message")
            return
        }
        #expect(decoded.origin == original.origin)
        #expect(decoded.command.description == original.command.description)
        #expect(decoded.tags == original.tags)
        #expect(buffer.readableBytes == 0)
    }
}
