//
//  IRCFrame.swift
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

import struct NIOCore.ByteBuffer

/// One unit read from, or written to, a NeedleTail IRC socket.
///
/// The leading byte on the wire selects the family:
///
/// | First byte | Family | Payload |
/// |---|---|---|
/// | `0xFF` | ``binary(_:)`` | ``IRCBinaryMessage`` |
/// | `0x00...0x04` | ``dcc(_:)`` | ``DCCMessage`` |
/// | anything else | ``text(_:)`` | ``IRCMessage`` (CRLF-terminated line) |
///
/// `0xFF` can never begin a UTF-8 text line and `0x00...0x04` are not legal IRC
/// first characters, so the dispatch is unambiguous. ``IRCFrameDecoder`` decides per
/// socket which binary families are accepted at all.
public enum IRCFrame: Codable, Sendable {
    /// RFC 1459 line. Client ↔ server.
    case text(IRCMessage)
    /// Length-prefixed opaque bytes routed by the server. Client ↔ server.
    case binary(IRCBinaryMessage)
    /// DCC peer protocol frame. Client ↔ client.
    case dcc(DCCMessage)
}

extension IRCFrame: IRCWireEncodable {
    /// Writes the wrapped payload using its own wire contract.
    public func encode(into buffer: inout ByteBuffer) throws {
        switch self {
        case .text(let message):
            try message.encode(into: &buffer)
        case .binary(let message):
            try message.encode(into: &buffer)
        case .dcc(let message):
            try message.encode(into: &buffer)
        }
    }
}

extension IRCFrame: CustomStringConvertible {
    /// Compact, payload-free summary safe for logs (never dumps binary bodies).
    public var description: String {
        switch self {
        case .text(let message):
            return message.description
        case .binary(let message):
            return message.description
        case .dcc(let message):
            return message.description
        }
    }
}
