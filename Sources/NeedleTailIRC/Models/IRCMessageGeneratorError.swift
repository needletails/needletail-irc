//
//  IRCMessageGeneratorError.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//

import Foundation

/// Errors raised while generating or transporting outbound IRC message frames.
public enum IRCMessageGeneratorError: Error, Sendable, Equatable {
    /// `transportMessage` completed without writing any frames.
    case zeroFramesGenerated
    /// Encoding `packet-metadata` failed; no contentless frame was yielded.
    case packetMetadataEncodeFailed
    /// A command with no required channel or recipient reached a throwing transport boundary.
    case emptyCommandRejected
    /// Encoding the requested authentication tag failed; no frame was yielded.
    case authPacketEncodeFailed
    /// The command name is not letters or a three-digit numeric (RFC 2812 §2.3.1).
    case invalidCommand
    /// The origin contains a space, so it can't be written as a prefix.
    case invalidOrigin
    /// A tag key is not `[+][vendor/]name` (IRCv3 message-tags).
    case invalidTagKey
    /// A parameter before the last is empty, contains a space or starts with `:`.
    case invalidParameter
    /// The line would carry more than ``IRCMessage/maxParameters`` parameters.
    case tooManyParameters
    /// The line without its tags is longer than ``IRCLineLimits/maxLineBytes``.
    case lineTooLong
    /// The tag section is longer than ``IRCLineLimits/maxTagBytes``.
    case tagsTooLong
}
