//
//  IRCPayloadRecipient.swift
//
//
//  Created by Cole M on 9/28/22.
//

import Foundation

/// `<IRCProtocolMessage: @example=test from=user1 to=#general command=PRIVMSG>`
/// `:alice!alice@localhost PRIVMSG #general :Hello, everyone! @exampleTag=value`
/// `:prefix COMMAND [params...] [tags]`
/// Represents a message in the IRC protocol, containing details such as origin, target, command, arguments, and optional tags.
public struct IRCMessage: Codable, Sendable {
    
    /// Unique identifier for the message.
    public var id: UUID = UUID()
    
    /// The origin of the message, typically the sender's nickname.
    public var origin: String?
    
    /// The target of the message, which can be a channel or a user.
    public var target: String?
    
    /// The IRC messageType associated with the message.
    public var command: IRCCommand
    
    /// Arguments for the command, with a maximum of 15 allowed.
    public var arguments: [String]?
    
    /// Optional tags associated with the message.
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
        arguments: [String]? = nil,
        tags: [IRCTag]? = nil
    ) {
        self.origin = origin
        self.target = target
        self.command = command
        self.arguments = arguments
        self.tags = tags
    }

    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case origin = "a"
        case target = "b"
        case arguments = "c"
        case command = "d"
        case tags = "e"
    }

    // MARK: - Codable Conformance
    public init(from decoder: Decoder) async throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        origin = try container.decodeIfPresent(String.self, forKey: .origin)
        command = try container.decode(IRCCommand.self, forKey: .command)
        arguments = try container.decodeIfPresent([String].self, forKey: .arguments)
        tags = try container.decodeIfPresent([IRCTag].self, forKey: .tags)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(origin, forKey: .origin)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(arguments, forKey: .arguments)
        try container.encodeIfPresent(tags, forKey: .tags)
    }
}

// MARK: - Equatable Conformance
extension IRCMessage: Equatable {
    public static func == (lhs: IRCMessage, rhs: IRCMessage) -> Bool {
        return lhs.id == rhs.id
    }
}
