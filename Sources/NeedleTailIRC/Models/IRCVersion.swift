//
//  IRCVersion.swift
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

/// The IRC protocol level a connection speaks, which decides whether outgoing lines carry tags.
public enum IRCVersion: Sendable, Equatable {
    /// Classic IRC (RFC 1459 and RFC 2812). Lines carry no tags: a server without IRCv3
    /// reads a leading `@...` as the command and answers 421.
    case v1
    /// IRCv3 with the `message-tags` capability acknowledged. Lines carry tags. NeedleTail
    /// servers speak this.
    case v3
}
