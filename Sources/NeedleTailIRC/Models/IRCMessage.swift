//
//  IRCMessage.swift
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

import Foundation

/// A comprehensive representation of an IRC protocol message.
///
/// `IRCMessage` encapsulates all the components of an IRC message according to RFC 2812 and RFC 1459 standards,
/// including support for IRCv3 message tags. It provides a structured way to work with IRC messages
/// in a type-safe manner.
///
/// ## Message Structure
///
/// An IRC message follows this format:
/// ```
/// [@tags] [:prefix] command [parameters] [:trailing]
/// ```
///
/// ## Examples
///
/// ```swift
/// // Simple private message
/// let message = IRCMessage(
///     origin: "alice!alice@localhost",
///     command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, everyone!")
/// )
///
/// // Message with IRCv3 tags
/// let taggedMessage = IRCMessage(
///     origin: "alice",
///     command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
/// )
///
/// // Server response
/// let serverMessage = IRCMessage(
///     origin: "server.example.com",
///     target: "alice",
///     command: .numeric(.replyWelcome, ["Welcome to the server!"])
/// )
/// ```
///
/// ## Thread Safety
///
/// This struct is thread-safe and can be used concurrently from multiple threads.
public struct IRCMessage: Codable, Sendable {
    
    /// A unique identifier for the message, automatically generated.
    ///
    /// This ID can be used for message tracking, deduplication, or correlation purposes.
    public var id: UUID = UUID()
    
    /// The origin of the message, typically the sender's nickname or server name.
    ///
    /// The origin can be in various formats:
    /// - `nickname!username@hostname` for user messages
    /// - `servername` for server messages
    /// - `nil` for messages without an origin
    public var origin: String?
    
    /// The target of the message, which can be a channel or a user.
    ///
    /// For numeric responses, this is typically the target user's nickname.
    /// For other commands, it may represent the intended recipient.
    public var target: String?
    
    /// The IRC command associated with the message.
    ///
    /// This can be any valid IRC command including:
    /// - Standard commands (PRIVMSG, JOIN, PART, etc.)
    /// - Numeric responses (001, 433, etc.)
    /// - Custom commands
    public var command: IRCCommand
    
    /// Optional IRCv3 message tags associated with the message.
    ///
    /// Tags provide additional metadata about the message, such as:
    /// - Timestamps
    /// - Account information
    /// - Message IDs
    /// - Custom metadata
    public var tags: [IRCTag]?

    /// A string representation of the message for logging and debugging.
    public var description: String {
        var output = "<IRCProtocolMessage:"
        if let tags = tags {
            output += tags.map { "@\($0.key)=\($0.value)" }.joined(separator: "; ")
        }
        if let origin = origin { output += " from=\(origin)" }
        if let target = target { output += " to=\(target)" }
        output += " command=\(command.description)>"
        return output
    }
    
    /// Initializes an IRC protocol message with optional parameters.
    public init(
        origin: String? = nil,
        target: String? = nil,
        command: IRCCommand,
        tags: [IRCTag]? = nil
    ) {
        self.origin = origin
        self.target = target
        self.command = command
        self.tags = tags
    }

    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case origin = "a"
        case target = "b"
        case command = "c"
        case tags = "d"
    }

    // MARK: - Codable Conformance
    public init(from decoder: Decoder) async throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        command = try container.decode(IRCCommand.self, forKey: .command)
        tags = try container.decodeIfPresent([IRCTag].self, forKey: .tags)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(tags, forKey: .tags)
    }
}

// MARK: - Equatable Conformance
extension IRCMessage: Equatable {
    public static func == (lhs: IRCMessage, rhs: IRCMessage) -> Bool {
        return lhs.id == rhs.id
    }
}
