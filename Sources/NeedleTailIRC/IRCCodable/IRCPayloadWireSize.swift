//
//  IRCPayloadWireSize.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//

import Foundation

/// Utilities for measuring and validating IRC payload sizes on the wire.
///
/// - Important: IRC message limits are enforced in bytes on the wire (including CRLF).
///   `IRCPayloadEncoder` appends CRLF (`\r\n`) to IRC lines, so validation must include +2 bytes.
public enum IRCPayloadWireSize: Sendable {
    /// Default max IRC line bytes used for budgeting in this SDK (including CRLF).
    ///
    /// - Note: Classic IRC is commonly 512 bytes including CRLF, but this SDK supports
    ///   deployments that negotiate/allow larger lines (e.g. encrypted/base64 payloads).
    public static let defaultMaxIRCLineBytes: Int = 16 * 1024

    /// Measures the encoded IRC line size in bytes **including CRLF**.
    ///
    /// - Returns: `nil` for `.dcc` payloads.
    public static func ircLineBytesIncludingCRLF(_ payload: IRCPayload) -> Int? {
        switch payload {
        case .irc(let message):
            return NeedleTailIRCEncoder.encode(value: message).utf8.count + 2
        case .dcc:
            return nil
        }
    }

    /// Returns true if the `.irc` payload is within `maxLineBytes` **including CRLF**.
    ///
    /// - Returns: `true` for `.dcc` payloads (not line-based).
    public static func validateIRCLineLimit(
        _ payload: IRCPayload,
        maxLineBytes: Int = defaultMaxIRCLineBytes
    ) -> Bool {
        guard let bytes = ircLineBytesIncludingCRLF(payload) else { return true }
        return bytes <= maxLineBytes
    }
}


