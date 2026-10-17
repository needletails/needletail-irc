//
//  IRCRawMessage.swift
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

/// A lossless standard IRC message (RFC 1459 / RFC 2812 framing with IRCv3 message tags).
///
/// ```
/// ['@' <tags> SPACE] [':' <source> SPACE] <command> *( SPACE <middle> ) [ SPACE ':' <trailing> ]
/// ```
///
/// `parameters` holds every parameter in order; the trailing parameter is the last element,
/// stored verbatim (spaces and colons included). Nothing is split on commas and nothing is
/// trimmed, so this type is the opt-in, standards-compliant counterpart of ``IRCMessage``.
/// Use ``IRCStandardTranslator`` (or `IRCMessage(standardIRC:)`) to bridge between the two.
public struct IRCRawMessage: Hashable, Sendable, CustomStringConvertible {

    /// RFC 2812 allows at most 15 parameters.
    public static let maxParameters = 15

    /// IRCv3 message tags, in wire order. Values are unescaped.
    public var tags: [IRCTag]
    /// The source (prefix) without its leading `:`.
    public var source: String?
    /// The command, uppercased when parsed. Either letters or a three-digit numeric.
    public var command: String
    /// All parameters in order, the trailing parameter last.
    public var parameters: [String]
    /// When `true`, the last parameter is always written as a trailing parameter (`:value`),
    /// as clients conventionally do for message text. When `false` the colon is written only
    /// when the value requires it. The parser sets this when the line used a trailing parameter,
    /// so parsing and re-serializing reproduces the line. It does not take part in equality.
    public var forcesTrailingParameter: Bool

    public init(
        tags: [IRCTag] = [],
        source: String? = nil,
        command: String,
        parameters: [String] = [],
        forcesTrailingParameter: Bool = false
    ) {
        self.tags = tags
        self.source = source
        self.command = command
        self.parameters = parameters
        self.forcesTrailingParameter = forcesTrailingParameter
    }

    /// The numeric value when ``command`` is a three-digit reply code.
    public var numeric: Int? {
        let utf8 = command.utf8
        guard utf8.count == 3, utf8.allSatisfy(Self.isDigit) else { return nil }
        return Int(command)
    }

    /// ``source`` split into nick, user and host.
    public var sourceComponents: IRCSource? {
        source.flatMap(IRCSource.init)
    }

    // MARK: - Equatable / Hashable

    // `IRCTag` compares by key only; a raw message must compare tag values too.
    public static func == (lhs: IRCRawMessage, rhs: IRCRawMessage) -> Bool {
        lhs.command == rhs.command
            && lhs.source == rhs.source
            && lhs.parameters == rhs.parameters
            && lhs.tags.count == rhs.tags.count
            && zip(lhs.tags, rhs.tags).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(command)
        hasher.combine(source)
        hasher.combine(parameters)
        for tag in tags {
            hasher.combine(tag.key)
            hasher.combine(tag.value)
        }
    }

    // MARK: - Description

    private static let redactedCommands: Set<String> = ["PASS", "AUTHENTICATE", "OPER"]

    /// Log-safe summary. Parameters of `PASS`, `AUTHENTICATE` and `OPER` are redacted.
    public var description: String {
        let shown: [String]
        if Self.redactedCommands.contains(command.uppercased()) {
            shown = parameters.enumerated().map { index, value in
                command.uppercased() == "OPER" && index == 0 ? value : "<redacted>"
            }
        } else {
            shown = parameters
        }
        var output = "<IRCRawMessage:"
        if !tags.isEmpty {
            output += " tags=" + tags.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
        }
        if let source { output += " from=\(source)" }
        output += " command=\(command)"
        if !shown.isEmpty {
            output += " params=[" + shown.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
        }
        return output + ">"
    }

    // MARK: - Byte constants

    static let space = UInt8(ascii: " ")
    static let colon = UInt8(ascii: ":")
    static let at = UInt8(ascii: "@")
    static let semicolon = UInt8(ascii: ";")
    static let equals = UInt8(ascii: "=")
    static let cr = UInt8(ascii: "\r")
    static let lf = UInt8(ascii: "\n")
    static let nul: UInt8 = 0

    static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    static func isLetter(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
    }

    static func isValidCommand(_ command: String) -> Bool {
        let utf8 = command.utf8
        guard !utf8.isEmpty else { return false }
        if utf8.allSatisfy(isLetter) { return true }
        return utf8.count == 3 && utf8.allSatisfy(isDigit)
    }

    static func containsForbiddenByte(_ value: String) -> Bool {
        value.utf8.contains { $0 == nul || $0 == cr || $0 == lf }
    }
}

// MARK: - Parsing

extension IRCRawMessage {

    /// Parses one line. A single trailing `\r\n`, `\n` or `\r` is ignored.
    ///
    /// Repeated spaces between components are tolerated, as most servers do. Leading spaces
    /// inside the trailing parameter are preserved.
    ///
    /// - Throws: ``IRCStandardError`` when the line is not a valid IRC message.
    public static func parse(_ line: String, limits: IRCParserLimits = .standardIRC) throws -> IRCRawMessage {
        var bytes = Array(line.utf8)
        if bytes.last == lf {
            bytes.removeLast()
            if bytes.last == cr { bytes.removeLast() }
        } else if bytes.last == cr {
            bytes.removeLast()
        }
        if bytes.contains(where: { $0 == nul || $0 == cr || $0 == lf }) {
            throw IRCStandardError(.forbiddenCharacter, "NUL, CR or LF inside a line")
        }

        var index = 0
        let count = bytes.count

        func skipSpaces() {
            while index < count, bytes[index] == space { index += 1 }
        }
        func nextToken() -> ArraySlice<UInt8> {
            let start = index
            while index < count, bytes[index] != space { index += 1 }
            return bytes[start..<index]
        }

        skipSpaces()
        guard index < count else { throw IRCStandardError(.emptyLine) }

        var tags: [IRCTag] = []
        if bytes[index] == at {
            let section = nextToken()
            guard index < count else {
                throw IRCStandardError(.invalidTags, "tag section is not followed by a command")
            }
            guard section.count <= limits.maxTagSectionBytes else {
                throw IRCStandardError(.invalidTags, "tag section exceeds \(limits.maxTagSectionBytes) bytes")
            }
            tags = try parseTags(section.dropFirst(), limits: limits)
            skipSpaces()
        }

        var source: String?
        if index < count, bytes[index] == colon {
            let token = nextToken().dropFirst()
            guard !token.isEmpty else { throw IRCStandardError(.invalidSource, "empty source") }
            source = String(decoding: token, as: UTF8.self)
            skipSpaces()
        }

        guard index < count else { throw IRCStandardError(.missingCommand) }
        let rawCommand = String(decoding: nextToken(), as: UTF8.self)
        let command = rawCommand.uppercased()
        guard isValidCommand(command) else {
            throw IRCStandardError(.invalidCommand, "\"\(rawCommand.prefix(32))\"")
        }

        var parameters: [String] = []
        var hasTrailing = false
        while true {
            skipSpaces()
            guard index < count else { break }
            if bytes[index] == colon {
                parameters.append(String(decoding: bytes[(index + 1)...], as: UTF8.self))
                hasTrailing = true
                break
            }
            parameters.append(String(decoding: nextToken(), as: UTF8.self))
        }

        return IRCRawMessage(
            tags: tags,
            source: source,
            command: command,
            parameters: parameters,
            forcesTrailingParameter: hasTrailing
        )
    }

    private static func parseTags(_ section: ArraySlice<UInt8>, limits: IRCParserLimits) throws -> [IRCTag] {
        let segments = section.split(separator: semicolon, omittingEmptySubsequences: true)
        guard segments.count <= limits.maxTagCount else {
            throw IRCStandardError(.invalidTags, "more than \(limits.maxTagCount) tags")
        }
        return try segments.map { segment in
            let parts = segment.split(separator: equals, maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(decoding: parts[0], as: UTF8.self)
            let rawValue = parts.count > 1 ? String(decoding: parts[1], as: UTF8.self) : ""
            let value = IRCTag.ircv3UnescapeTagValue(rawValue)
            guard IRCTag.validate(
                key: key,
                value: value,
                maxKeyBytes: limits.maxTagKeyBytes,
                maxValueBytes: limits.maxTagValueBytes
            ) else {
                throw IRCStandardError(.invalidTags, "invalid or oversized tag \"\(key.prefix(32))\"")
            }
            return IRCTag(key: key, value: value)
        }
    }
}

// MARK: - Serialization

extension IRCRawMessage: IRCWireEncodable {

    /// The wire form without the CRLF terminator.
    ///
    /// The last parameter is written as a trailing parameter (`:value`) when
    /// ``forcesTrailingParameter`` is set, or when it has to be: when it is empty, contains a
    /// space, or starts with `:`.
    ///
    /// - Throws: ``IRCStandardError`` for anything that cannot be represented safely, including
    ///   NUL, CR or LF in any field (this prevents command injection).
    public func wireLine() throws -> String {
        var output = ""

        if !tags.isEmpty {
            let encoded = try tags.map { tag -> String in
                guard IRCTag.validate(key: tag.key, value: tag.value, maxKeyBytes: .max, maxValueBytes: .max) else {
                    throw IRCStandardError(.invalidTags, "invalid tag key \"\(tag.key.prefix(32))\"")
                }
                return tag.value.isEmpty ? tag.key : "\(tag.key)=\(IRCTag.ircv3EscapeTagValue(tag.value))"
            }
            output += "@" + encoded.joined(separator: ";") + " "
        }

        if let source {
            guard !source.isEmpty, !source.utf8.contains(Self.space) else {
                throw IRCStandardError(.invalidSource, "source must be non-empty and contain no spaces")
            }
            guard !Self.containsForbiddenByte(source) else {
                throw IRCStandardError(.forbiddenCharacter, "source")
            }
            output += ":\(source) "
        }

        guard Self.isValidCommand(command) else {
            throw IRCStandardError(.invalidCommand, "\"\(command.prefix(32))\"")
        }
        output += command

        guard parameters.count <= Self.maxParameters else {
            throw IRCStandardError(.tooManyParameters, "\(parameters.count) parameters")
        }

        for (index, parameter) in parameters.enumerated() {
            guard !Self.containsForbiddenByte(parameter) else {
                throw IRCStandardError(.forbiddenCharacter, "parameter \(index)")
            }
            let isLast = index == parameters.count - 1
            let needsTrailing = parameter.isEmpty
                || parameter.utf8.contains(Self.space)
                || parameter.utf8.first == Self.colon
            if needsTrailing || (isLast && forcesTrailingParameter) {
                guard isLast else {
                    throw IRCStandardError(
                        .invalidParameter,
                        "parameter \(index) must be non-empty, contain no spaces and not start with ':'"
                    )
                }
                output += " :\(parameter)"
            } else {
                output += " \(parameter)"
            }
        }
        return output
    }

    /// Writes ``wireLine()`` followed by CRLF. Nothing is written if serialization fails.
    public func encode(into buffer: inout ByteBuffer) throws {
        let line = try wireLine()
        buffer.writeString(line)
        buffer.writeString("\r\n")
    }
}
