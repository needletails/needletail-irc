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
}
