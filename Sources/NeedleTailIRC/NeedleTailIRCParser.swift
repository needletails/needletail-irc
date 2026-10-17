//
//  NeedleTailIRCParser.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/22.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import NeedleTailLogger

/// Errors that can occur during IRC message parsing.
public enum MessageParsingErrors: Error, Sendable {
    /// Invalid arguments provided for a command.
    case invalidArguments(String)
    /// Invalid CAP (capability) command format.
    case invalidCAPCommand(String)
    /// Invalid message tag format.
    case invalidTag
}

/// Optional resource limits for parsing untrusted IRCv3 tag sections.
public struct IRCParserLimits: Sendable, Equatable {
    public var maxTagSectionBytes: Int
    public var maxTagCount: Int
    public var maxTagKeyBytes: Int
    public var maxTagValueBytes: Int

    public static let standardIRC = IRCParserLimits(
        maxTagSectionBytes: IRCTag.defaultMaxTagSectionBytes,
        maxTagCount: IRCTag.defaultMaxTagCount,
        maxTagKeyBytes: IRCTag.defaultMaxTagKeyBytes,
        maxTagValueBytes: IRCTag.defaultMaxTagValueBytes
    )

    public init(
        maxTagSectionBytes: Int,
        maxTagCount: Int,
        maxTagKeyBytes: Int,
        maxTagValueBytes: Int
    ) {
        self.maxTagSectionBytes = maxTagSectionBytes
        self.maxTagCount = maxTagCount
        self.maxTagKeyBytes = maxTagKeyBytes
        self.maxTagValueBytes = maxTagValueBytes
    }
}

/// A comprehensive parser for IRC messages that conforms to RFC 2812 and RFC 1459 standards.
/// 
/// This parser implements the IRC message format as specified in the IRC protocol:
/// ['@' <tags> SPACE] [':' <source> SPACE] <command> <parameters> <crlf>
/// 
/// For numeric replies, the target is extracted as the first parameter according to the protocol.
///
/// The `NeedleTailIRCParser` provides functionality to parse raw IRC message strings into structured
/// `IRCMessage` objects. It supports all standard IRC commands, IRCv3 message tags, and handles
/// both numeric and string-based commands.
///
/// ## Usage
///
/// ```swift
/// // Parse a simple IRC message
/// let message = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello, world!")
///
/// // Parse a message with IRCv3 tags
/// let taggedMessage = try NeedleTailIRCParser.parseMessage("@time=2023-01-01T12:00:00Z :alice!alice@localhost PRIVMSG #general :Hello!")
/// ```
///
/// ## Message Format
///
/// The parser supports the standard IRC message format:
/// ```
/// [@tags] [:prefix] command [parameters] [:trailing]
/// ```
///
/// - **Tags**: IRCv3 message tags (optional)
/// - **Prefix**: Message origin (optional)
/// - **Command**: IRC command or numeric code
/// - **Parameters**: Command arguments
/// - **Trailing**: Final parameter (can contain spaces)
///
/// ## Thread Safety
///
/// This parser is thread-safe and can be used concurrently from multiple threads.
public struct NeedleTailIRCParser: Sendable {
    static let logger = NeedleTailLogger("[ com.needletails.irc.message.parser ]")
    static let maxTagSectionBytes: Int = IRCTag.defaultMaxTagSectionBytes
    static let maxTagCount: Int = IRCTag.defaultMaxTagCount
    
    public init() {}
    
    enum IRCCommandKey {
        case int(Int)
        case string(String)
    }
    
    /// Parses a raw IRC message string into a structured `IRCMessage` object.
    ///
    /// This method handles the complete parsing of IRC messages, including:
    /// - IRCv3 message tags
    /// - Message prefixes (origin)
    /// - Command parsing (both string and numeric)
    /// - Parameter extraction
    /// - Trailing parameter handling
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Parse a simple message
    /// let message = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello!")
    ///
    /// // Parse a message with tags
    /// let taggedMessage = try NeedleTailIRCParser.parseMessage("@time=2023-01-01T12:00:00Z :alice PRIVMSG #general :Hello!")
    ///
    /// // Parse a numeric response
    /// let numericMessage = try NeedleTailIRCParser.parseMessage(":server 001 alice :Welcome to the server!")
    /// ```
    ///
    /// ## Message Format Support
    ///
    /// The parser supports all standard IRC message formats:
    /// - Messages with and without tags
    /// - Messages with and without prefixes
    /// - String commands (PRIVMSG, JOIN, etc.)
    /// - Numeric commands (001, 433, etc.)
    /// - Messages with trailing parameters
    ///
    /// - Parameter message: The raw IRC message string to parse.
    /// - Throws: `MessageParsingErrors` for invalid message formats.
    /// - Returns: An `IRCMessage` representing the parsed message.
    public static func parseMessage(_ message: String) throws -> IRCMessage {
        try parseMessage(message, limits: nil)
    }

    /// Parses an IRC message while enforcing explicit IRCv3 tag resource limits.
    public static func parseMessage(
        _ message: String,
        limits: IRCParserLimits
    ) throws -> IRCMessage {
        try parseMessage(message, limits: Optional(limits))
    }

    private static func parseMessage(
        _ message: String,
        limits: IRCParserLimits?
    ) throws -> IRCMessage {
        var origin: String?
        var tags: [String] = []
        var command = ""
        var taglessMessage = ""
        
        // 1. Separate Tags (only if the message starts with '@')
        if message.hasPrefix(Constants.atString.rawValue) {
            guard let firstSpaceIndex = tagSectionEnd(in: message) else {
                throw MessageParsingErrors.invalidTag
            }
            let tagString = String(message[..<firstSpaceIndex])
            if let limits, tagString.utf8.count > limits.maxTagSectionBytes {
                throw MessageParsingErrors.invalidTag
            }
            // 2. Set Tagless Message
            taglessMessage = String(message[message.index(after: firstSpaceIndex)...])
            tags.append(tagString)
        } else {
            // 2. Set Tagless Message
            taglessMessage = message
        }
        
        // 3. Split into source, command and parameters (RFC 2812 §2.3.1)
        let line = try tokenize(taglessMessage)
        origin = line.origin
        command = line.command

        // 5. Parse Tags
        let parsedTags = !tags.isEmpty
            ? try parseTags(tags: tags[0], limits: limits)
            : nil
        
        // 6. Parse Arguments
        let (arguments, target) = try parseArgument(
            command: command,
            parameters: line.parameters,
            hasTrailing: line.hasTrailing
        )
        
        // 7. Create IRCCommand
        let builtCommand: IRCCommand
        if let numericCommand = Int(command) {
            builtCommand = try IRCCommand(numeric: numericCommand, arguments: arguments)
        } else {
            builtCommand = try IRCCommand(command: command, arguments: arguments)
        }
        // 8. Return the constructed IRCMessage
        return IRCMessage(origin: origin, target: target, command: builtCommand, tags: parsedTags)
    }

    private static func tagSectionEnd(in message: String) -> String.Index? {
        var boundary = message.firstIndex(of: Character(Constants.space.rawValue))
        while let currentBoundary = boundary,
              currentBoundary > message.startIndex,
              message[message.index(before: currentBoundary)] == Character(Constants.semiColon.rawValue)
        {
            let nextStart = message.index(after: currentBoundary)
            boundary = message[nextStart...].firstIndex(of: Character(Constants.space.rawValue))
        }
        return boundary
    }
    
    
    /// One line split per RFC 2812 §2.3.1: middles, then at most one trailing parameter.
    struct TokenizedLine {
        var origin: String?
        var command: String
        var parameters: [String]
        /// `true` when the last parameter was written as `:trailing`.
        var hasTrailing: Bool
    }

    /// Splits a tag-free line into source, command and parameters.
    ///
    /// The trailing parameter is kept verbatim (spaces, colons and commas included).
    /// Repeated spaces between parameters are tolerated.
    static func tokenize(_ line: String) throws -> TokenizedLine {
        var rest = Substring(line)
        func skipSpaces() {
            while rest.first == " " { rest.removeFirst() }
        }
        func nextToken() -> Substring {
            let end = rest.firstIndex(of: " ") ?? rest.endIndex
            let token = rest[..<end]
            rest = rest[end...]
            return token
        }

        // A line starts with its prefix or its command; a leading space is malformed.
        guard rest.first != " " else {
            throw MessageParsingErrors.invalidArguments("Line starts with a space.")
        }
        var origin: String?
        if rest.first == ":" {
            let token = nextToken().dropFirst()
            guard !token.isEmpty else {
                throw MessageParsingErrors.invalidArguments("Empty prefix.")
            }
            origin = String(token)
            skipSpaces()
            guard !rest.isEmpty else {
                throw MessageParsingErrors.invalidArguments("Prefix-only line missing command.")
            }
        }
        guard !rest.isEmpty else {
            throw MessageParsingErrors.invalidArguments("Empty message.")
        }
        let command = String(nextToken()).uppercased()

        var parameters: [String] = []
        var hasTrailing = false
        while true {
            skipSpaces()
            guard !rest.isEmpty else { break }
            if rest.first == ":" {
                parameters.append(String(rest.dropFirst()))
                hasTrailing = true
                break
            }
            parameters.append(String(nextToken()))
        }
        return TokenizedLine(origin: origin, command: command, parameters: parameters, hasTrailing: hasTrailing)
    }
    
    /// Parses IRC tags from a given tag string.
    /// - Parameter tags: The string containing tags.
    /// - Throws: `MessageParsingErrors` for invalid tag formats.
    /// - Returns: An array of `IRCTag` if successful, otherwise `nil`.
    static func parseTags(
        tags: String = "",
        limits: IRCParserLimits? = nil
    ) throws -> [IRCTag]? {
        guard tags.hasPrefix(Constants.atString.rawValue) else { return nil }
        
        var tagArray: [IRCTag] = []
        let raw = String(tags.dropFirst())
        let seperatedTags = raw.components(separatedBy: Constants.semiColon.rawValue)
        if let limits, seperatedTags.count > limits.maxTagCount {
            throw MessageParsingErrors.invalidTag
        }
        
        for tag in seperatedTags {
            var cleanedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedTag.isEmpty else { continue }
            
            // Backward compatibility:
            // Older versions of this SDK encoded tags as "@k1=v1;@k2=v2" (an extra '@' per tag).
            // Accept and normalize that format by stripping a leading '@' on each tag segment.
            if cleanedTag.hasPrefix(Constants.atString.rawValue) {
                cleanedTag = String(cleanedTag.dropFirst())
            }
            let kvpArray = cleanedTag.split(separator: Character(Constants.equalsString.rawValue), maxSplits: 1)
            guard let key = kvpArray.first else {
                throw MessageParsingErrors.invalidArguments("Invalid tag format.")
            }
            let rawValue = kvpArray.count > 1 ? String(kvpArray[1]) : ""
            let value = IRCTag.ircv3UnescapeTagValue(rawValue)
            let k = String(key)
            let maxKeyBytes = limits?.maxTagKeyBytes ?? .max
            let maxValueBytes = limits?.maxTagValueBytes ?? .max
            guard IRCTag.validate(
                key: k,
                value: value,
                maxKeyBytes: maxKeyBytes,
                maxValueBytes: maxValueBytes
            ) else {
                throw MessageParsingErrors.invalidArguments("Invalid tag key/value.")
            }
            tagArray.append(IRCTag(key: k, value: value))
        }
        return tagArray
    }
    
    /// Maps RFC parameters onto command arguments and an optional target.
    ///
    /// - Numerics: the first parameter is the target (RFC 2812 §2.4) and the rest are the
    ///   arguments, verbatim. A numeric whose only parameter is a trailing one (`465 :a, b`)
    ///   is the legacy NeedleTail form, which has no target and joins its arguments with
    ///   commas; it is split on commas as before.
    /// - `CAP` replies from a server (`CAP <nick|*> <subcommand> ...`): the first parameter
    ///   is the target.
    /// - Everything else: the parameters are the arguments.
    static func parseArgument(command: String, parameters: [String], hasTrailing: Bool) throws -> ([String], String?) {
        switch try parseCommand(command: command) {
        case .int:
            if parameters.count == 1, hasTrailing {
                let legacy = parameters[0]
                    .components(separatedBy: Constants.comma.rawValue)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return (legacy, nil)
            }
            guard let target = parameters.first else { return ([], nil) }
            return (Array(parameters.dropFirst()), target)
        case .string(let cmd):
            if cmd == Constants.cap.rawValue,
               parameters.count >= 2,
               IRCCommand.CAPSubCommand(rawValue: parameters[0].uppercased()) == nil,
               (IRCCommand.CAPSubCommand(rawValue: parameters[1].uppercased()) != nil
                   || ["NEW", "DEL"].contains(parameters[1].uppercased())) {
                return (Array(parameters.dropFirst()), parameters[0])
            }
            return (parameters, nil)
        }
    }
    
    /// Parses the command into a numeric or string key.
    /// - Parameter command: The command string to parse.
    /// - Throws: `MessageParsingErrors` for invalid command formats.
    /// - Returns: An `IRCCommandKey` representing the command type.
    static func parseCommand(command: String) throws -> IRCCommandKey {
        guard !command.isEmpty else {
            throw MessageParsingErrors.invalidArguments("Invalid command format.")
        }
        
        if let firstChar = command.first, firstChar.isLetter {
            return .string(command)
        } else {
            let numericCommand = command.components(separatedBy: .decimalDigits.inverted).compactMap(Int.init).first
            guard let validNumeric = numericCommand else {
                throw MessageParsingErrors.invalidArguments("Invalid command format.")
            }
            return .int(validNumeric)
        }
    }
}
