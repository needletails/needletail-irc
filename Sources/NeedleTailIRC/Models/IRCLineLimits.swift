//
//  IRCLineLimits.swift
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

/// Outbound size limits for a standard IRC connection. NeedleTail sends larger lines, so nothing
/// applies them unless you pass them to ``IRCMessage/validateWireLine(limits:)`` or return them
/// from `NeedleTailWriterDelegate.outboundLineLimits`.
///
/// Sizes are UTF-8 bytes. Tags are counted apart from the rest of the line (IRCv3 message-tags).
public struct IRCLineLimits: Sendable, Equatable {
    /// The line without its tags, including CRLF. RFC 2812 §2.3 allows 512.
    public var maxLineBytes: Int
    /// The tag section, including its leading `@` and the space after it.
    public var maxTagBytes: Int

    public init(maxLineBytes: Int, maxTagBytes: Int) {
        self.maxLineBytes = maxLineBytes
        self.maxTagBytes = maxTagBytes
    }

    /// What a client may send: 512-byte lines and 4094 bytes of tag data (4096 with `@` and the space).
    public static let standardClient = IRCLineLimits(maxLineBytes: 512, maxTagBytes: 4096)
    /// What a server may send: 512-byte lines and 8191 bytes of tags.
    public static let standardServer = IRCLineLimits(maxLineBytes: 512, maxTagBytes: 8191)
}
