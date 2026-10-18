//
//  IRCChannelModeChange.swift
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

/// One change in a channel MODE line: a sign, a single mode, and the parameter that mode takes.
///
/// ``IRCCommand/channelModeChanges(_:_:)`` keeps a list of these in the order they were sent,
/// for lines a set of modes can't express, such as `+oov alice bob carol`.
public struct IRCChannelModeChange: Codable, Hashable, Sendable {
    /// `true` for `+`, `false` for `-`.
    public var adding: Bool
    /// Exactly one mode.
    public var mode: IRCChannelPermissions
    /// The parameter this mode takes, if any (RFC 2811 §4).
    public var parameter: String?

    public init(adding: Bool, mode: IRCChannelPermissions, parameter: String? = nil) {
        self.adding = adding
        self.mode = mode
        self.parameter = parameter
    }
}
