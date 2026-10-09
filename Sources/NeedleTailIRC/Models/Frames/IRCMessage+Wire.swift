//
//  IRCMessage+Wire.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import struct NIOCore.ByteBuffer

// MARK: - Encode

extension IRCMessage: IRCWireEncodable {

    /// RFC 1459 line terminator.
    public static let lineTerminator = "\r\n"

    /// The validated, single-line wire form of this message, **without** the terminator.
    ///
    /// Rules enforced here, so every caller (NIO codec, tests, diagnostics) gets the same bytes:
    /// - `JOIN`/`PART` with no channels and `PRIVMSG`/`NOTICE` with no recipients are rejected
    ///   with ``IRCMessageGeneratorError/emptyCommandRejected``; the server would reject them and
    ///   the local generator would otherwise have silently produced a dead frame.
    /// - An encoder result that is empty is rejected for the same reason.
    /// - Embedded `\r` / `\n` are removed. A line may not contain its own terminator; stripping is
    ///   preferred over throwing so a stray newline in user text degrades the message rather
    ///   than dropping it. Callers that need to know this happened can compare `wireLine()`
    ///   against `NeedleTailIRCEncoder.encode(value:)`.
    public func wireLine() throws -> String {
        switch command {
        case .join(let channels, _) where channels.isEmpty,
             .part(let channels) where channels.isEmpty:
            throw IRCMessageGeneratorError.emptyCommandRejected
        case .privMsg(let recipients, _) where recipients.isEmpty,
             .notice(let recipients, _) where recipients.isEmpty:
            throw IRCMessageGeneratorError.emptyCommandRejected
        default:
            break
        }

        var line = NeedleTailIRCEncoder.encode(value: self)
        guard !line.isEmpty else {
            throw IRCMessageGeneratorError.emptyCommandRejected
        }
        // Operate on scalars, not Characters: "\r\n" is a single grapheme cluster and would
        // slip past a Character-level comparison, leaving a terminator inside the line
        // (i.e. an IRC command injection vector).
        line.unicodeScalars.removeAll { $0 == "\r" || $0 == "\n" }
        return line
    }

    /// Writes `wireLine()` followed by CRLF.
    public func encode(into buffer: inout ByteBuffer) throws {
        let line = try wireLine()
        buffer.writeString(line)
        buffer.writeString(Self.lineTerminator)
    }
}

// MARK: - Decode

extension IRCMessage {

    /// Errors raised while framing inbound bytes as IRC lines.
    public enum LineError: Error, Sendable, Equatable {
        /// More than `maxLineLength` bytes were seen before (or within) a line terminator.
        case lineTooLong(maxLineLength: Int)
    }

    /// Why a consumed line produced no ``IRCMessage``.
    ///
    /// These are *not* errors: the line's bytes have been consumed and the stream is
    /// resynchronised at the next line, so decoding should continue. ``IRCFrameDecoder``
    /// logs them.
    public enum IgnoredLine: Sendable, CustomStringConvertible {
        /// Whitespace-only line. Some servers emit these as keep-alives.
        case blank
        /// The parser rejected the line. `line` is the consumed text (lossily decoded if it
        /// was not valid UTF-8).
        case unparsable(line: String, error: any Error)

        public var description: String {
            switch self {
            case .blank:
                return "blank line"
            case .unparsable(let line, let error):
                return "unparsable line \"\(line.prefix(128))\": \(error)"
            }
        }
    }

    /// Outcome of consuming exactly one line from a buffer.
    public enum LineDecodeResult: Sendable {
        case message(IRCMessage)
        case ignored(IgnoredLine)
    }

    /// True for lines that carry nothing and should be dropped without parsing.
    static func isIgnorableLine(_ line: String) -> Bool {
        line.allSatisfy { $0.isWhitespace || $0.isNewline }
    }

    /// Consumes one `\r?\n`-terminated line from `buffer` and parses it.
    ///
    /// - Throws: `NIODecodeError.incomplete` when no terminator is present yet (the caller
    ///   should rewind and wait for more bytes); ``LineError/lineTooLong(maxLineLength:)``
    ///   when the pending line exceeds `maxLineLength` with or without a terminator.
    /// - Returns: `.message` on success, or `.ignored` after consuming a line that cannot
    ///   yield a message. In both cases the line and its terminator have been consumed.
    static func decode(
        from buffer: inout ByteBuffer,
        maxLineLength: Int
    ) throws -> LineDecodeResult {
        let view = buffer.readableBytesView

        guard let newlineIndex = view.firstIndex(of: UInt8(ascii: "\n")) else {
            if buffer.readableBytes > maxLineLength {
                throw LineError.lineTooLong(maxLineLength: maxLineLength)
            }
            throw NIODecodeError.incomplete("No line terminator yet")
        }

        let lineLength = view.distance(from: view.startIndex, to: newlineIndex)
        guard lineLength <= maxLineLength else {
            throw LineError.lineTooLong(maxLineLength: maxLineLength)
        }

        let hasCR = lineLength > 0 && view[view.index(before: newlineIndex)] == UInt8(ascii: "\r")
        let bodyLength = hasCR ? lineLength - 1 : lineLength

        // `readString` is lossy for invalid UTF-8 (U+FFFD), never nil when enough bytes exist.
        // The bytes are consumed either way so a bad line can never stall the stream.
        let line = buffer.readString(length: bodyLength) ?? ""
        buffer.moveReaderIndex(forwardBy: hasCR ? 2 : 1)

        guard !isIgnorableLine(line) else {
            return .ignored(.blank)
        }

        do {
            return .message(try NeedleTailIRCParser.parseMessage(line))
        } catch {
            return .ignored(.unparsable(line: line, error: error))
        }
    }
}
