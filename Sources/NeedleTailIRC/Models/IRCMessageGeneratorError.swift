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
}
