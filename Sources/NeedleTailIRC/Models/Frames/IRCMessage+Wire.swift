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

    /// The most parameters a line may carry (RFC 2812 §2.3.1).
    public static let maxParameters = 15

    /// The validated, single-line wire form of this message, **without** the terminator.
    ///
    /// This is the one place a text line is checked and encoded, so every caller (NIO codec,
    /// `sendAndFlushMessage`, tests, diagnostics) gets the same bytes. It throws an
    /// ``IRCMessageGeneratorError`` unless the message can be written as one RFC 2812 line with
    /// IRCv3 tags:
    /// - `JOIN`/`PART` need channels and `PRIVMSG`/`NOTICE` need recipients:
    ///   ``IRCMessageGeneratorError/emptyCommandRejected``. The server would reject them.
    /// - The command is letters or three digits: ``IRCMessageGeneratorError/invalidCommand``.
    /// - The origin has no space: ``IRCMessageGeneratorError/invalidOrigin``.
    /// - Tag keys are `[+][vendor/]name`: ``IRCMessageGeneratorError/invalidTagKey``.
    /// - Every parameter before the last is one non-empty word that doesn't start with `:`, and
    ///   message targets are channels, nicks or RFC 2812 masks:
    ///   ``IRCMessageGeneratorError/invalidParameter``.
    /// - At most ``maxParameters`` parameters: ``IRCMessageGeneratorError/tooManyParameters``.
    /// - An encoder result that is empty: ``IRCMessageGeneratorError/emptyCommandRejected``.
    ///
    /// Line length is kept by the chunker, not checked here: `IRCMessageGenerator` cuts text into
    /// 512-byte pieces carried in `packet-metadata`, so each frame's line stays short.
    /// - Embedded NUL, `\r` and `\n` are removed. A line may not contain them; stripping is
    ///   preferred over throwing so a stray newline in user text degrades the message rather
    ///   than dropping it. Callers that need to know this happened can compare `wireLine()`
    ///   against `NeedleTailIRCEncoder.encode(value:)`.
    public func wireLine() throws -> String {
        try validateWireLine()

        let line = Self.removingForbiddenScalars(NeedleTailIRCEncoder.encode(value: self))
        guard !line.isEmpty else {
            throw IRCMessageGeneratorError.emptyCommandRejected
        }
        return line
    }

    /// Removes NUL, CR and LF, which a line may not contain.
    static func removingForbiddenScalars(_ line: String) -> String {
        // Operate on scalars, not Characters: "\r\n" is a single grapheme cluster and would
        // slip past a Character-level comparison, leaving a terminator inside the line
        // (i.e. an IRC command injection vector).
        var line = line
        line.unicodeScalars.removeAll { $0 == "\0" || $0 == "\r" || $0 == "\n" }
        return line
    }

    /// The checks ``wireLine()`` documents, without encoding the tags. `sendAndFlushMessage` runs
    /// them before writing, so an invalid line throws before it reaches the NIO pipeline.
    func validateWireLine() throws {
        switch command {
        case .join(let channels, _) where channels.isEmpty,
             .part(let channels) where channels.isEmpty,
             .partMessage(let channels, _) where channels.isEmpty:
            throw IRCMessageGeneratorError.emptyCommandRejected
        case .privMsg(let recipients, _) where recipients.isEmpty,
             .notice(let recipients, _) where recipients.isEmpty:
            throw IRCMessageGeneratorError.emptyCommandRejected
        default:
            break
        }

        // command = 1*letter / 3digit
        let name = command.commandAsString.unicodeScalars
        let isWord = !name.isEmpty && name.allSatisfy { ("A"..."Z").contains($0) || ("a"..."z").contains($0) }
        let isNumeric = name.count == 3 && name.allSatisfy { ("0"..."9").contains($0) }
        guard isWord || isNumeric else {
            throw IRCMessageGeneratorError.invalidCommand
        }
        if let origin, origin.contains(Constants.space.rawValue) {
            throw IRCMessageGeneratorError.invalidOrigin
        }
        for tag in tags ?? [] where !IRCTag.isValidIRCv3Key(tag.key) {
            throw IRCMessageGeneratorError.invalidTagKey
        }
        switch command {
        case .privMsg(let recipients, _), .notice(let recipients, _):
            for case .mask(let mask) in recipients where !IRCMessageRecipient.isMask(mask) {
                throw IRCMessageGeneratorError.invalidParameter
            }
        default:
            break
        }
        for middle in Self.middleParameters(of: self) {
            guard !middle.isEmpty,
                  !middle.contains(Constants.space.rawValue),
                  !middle.hasPrefix(Constants.colon.rawValue) else {
                throw IRCMessageGeneratorError.invalidParameter
            }
        }
        // Count what a receiver will see. Tags and origin don't change it, so leave them out.
        guard let line = try? NeedleTailIRCParser.tokenize(
            NeedleTailIRCEncoder.encode(value: IRCMessage(target: target, command: command))
        ) else {
            throw IRCMessageGeneratorError.invalidParameter
        }
        guard line.parameters.count <= Self.maxParameters else {
            throw IRCMessageGeneratorError.tooManyParameters
        }
    }

    /// Caller strings the encoder writes as middle parameters, where a space, an empty value or
    /// a leading `:` would change the line's meaning. Trailing parameters aren't listed.
    static func middleParameters(of message: IRCMessage) -> [String] {
        var middles: [String] = []
        if let target = message.target, NeedleTailIRCEncoder.carriesTarget(message.command) {
            middles.append(target)
        }
        switch message.command {
        case .user(let details):
            middles.append(details.username)
            if details.userModeFlags == nil {
                middles += [details.hostname ?? "", details.servername ?? "*"]
            }
        case .ping(let server, let server2), .pong(let server, let server2):
            if server2 != nil { middles.append(server) }
        case .join(_, let keys):
            if let keys, !keys.isEmpty { middles.append(keys.joined(separator: Constants.comma.rawValue)) }
        case .list(_, let target), .who(let target, _), .links(let target), .trace(let target),
             .admin(let target), .info(let target), .version(let target), .time(let target),
             .motd(let target), .rules(let target), .users(let target):
            if let target { middles.append(target) }
        case .channelMode(_, let add, let addParameters, let remove, let removeParameters):
            if add?.stringValue.isEmpty == false { middles += addParameters ?? [] }
            if remove?.stringValue.isEmpty == false { middles += removeParameters ?? [] }
        case .whois(let server, let usermasks):
            if let server { middles.append(server) }
            if !usermasks.isEmpty { middles.append(usermasks.joined(separator: Constants.comma.rawValue)) }
        case .dccChat(_, let address, _), .sdccChat(_, let address, _):
            middles.append(address)
        case .dccSend(_, let filename, _, let address, _), .sdccSend(_, let filename, _, let address, _),
             .dccResume(_, let filename, _, let address, _, _), .sdccResume(_, let filename, _, let address, _, _):
            middles += [filename, address]
        case .sQuit(let serverName, _):
            middles.append(serverName)
        case .server(let serverName, let version, _, _):
            middles += [serverName, version]
        case .oper(let username, _):
            middles.append(username)
        case .silence(let mask), .clearmode(_, let mask):
            middles.append(mask)
        case .connect(let targetServer, _, let remoteServer):
            middles.append(targetServer)
            if let remoteServer { middles.append(remoteServer) }
        case .stats(let first, let second), .lusers(let first, let second):
            middles += [first, second].compactMap { $0 }
        case .numeric(_, let arguments), .otherNumeric(_, let arguments):
            // Without a target the arguments are one trailing parameter (NeedleTail form).
            if message.target != nil { middles += arguments.dropLast() }
        case .otherCommand(_, let arguments):
            // One argument is written as trailing; several as RFC parameters.
            if arguments.count > 1 { middles += arguments.dropLast() }
        default:
            break
        }
        return middles
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
