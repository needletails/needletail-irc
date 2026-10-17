//
//  IRCSource.swift
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

/// The source (prefix) of a standard IRC message: `servername` or `nick[!user][@host]`.
///
/// Unlike ``IRCUserIdentifier`` this performs no nickname validation and never changes case,
/// so it can represent anything a standard server sends.
public struct IRCSource: Hashable, Sendable, CustomStringConvertible {
    /// The nickname, or the server name for server-originated messages.
    public var nick: String
    /// The username (ident), if present.
    public var user: String?
    /// The hostname, if present.
    public var host: String?

    public init(nick: String, user: String? = nil, host: String? = nil) {
        self.nick = nick
        self.user = user
        self.host = host
    }

    /// Parses `nick!user@host`, `nick@host`, `nick` or `server.name`.
    /// Returns `nil` when any present component is empty.
    public init?(_ string: String) {
        let bang = string.firstIndex(of: "!")
        let at = string.firstIndex(of: "@")
        if let bang, let at, at < bang { return nil }

        let nickEnd = bang ?? at ?? string.endIndex
        let nick = String(string[..<nickEnd])
        guard !nick.isEmpty else { return nil }

        var user: String?
        if let bang {
            let userEnd = at ?? string.endIndex
            let value = String(string[string.index(after: bang)..<userEnd])
            guard !value.isEmpty else { return nil }
            user = value
        }

        var host: String?
        if let at {
            let value = String(string[string.index(after: at)...])
            guard !value.isEmpty else { return nil }
            host = value
        }

        self.init(nick: nick, user: user, host: host)
    }

    /// `true` when the source looks like a server name (no user/host and contains a dot).
    /// Nicknames cannot contain `.`, so this is reliable for standard servers.
    public var isServer: Bool {
        user == nil && host == nil && nick.contains(".")
    }

    /// The wire form, `nick!user@host`.
    public var stringValue: String {
        var value = nick
        if let user { value += "!\(user)" }
        if let host { value += "@\(host)" }
        return value
    }

    public var description: String { stringValue }
}
