//
//  WireFormat.swift
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

// MARK: - Protocol

/// A value that can serialise itself onto an IRC socket.
///
/// Every payload carried by ``IRCFrame`` conforms, as does `IRCFrame` itself, so the
/// NIO encoder is a thin adapter and each type owns its own wire contract:
///
/// - ``IRCMessage``: an RFC 1459 line terminated by CRLF.
/// - ``IRCBinaryMessage``: a `0xFF`-discriminated, length-prefixed binary frame.
/// - ``DCCMessage``: a `0...4`-discriminated peer frame.
///
/// Decoding is deliberately *not* part of this protocol. Each family has a different
/// framing rule (newline scan vs. discriminator + length) and a different error policy
/// (a bad text line is skipped because the next newline resynchronises the stream; a bad
/// binary frame is fatal because nothing does). Each type exposes its own
/// `static func decode(from:…)` and ``IRCFrameDecoder`` dispatches on the leading byte.
public protocol IRCWireEncodable: Sendable {
    /// Appends this value's wire representation to `buffer`.
    ///
    /// Must either write a complete frame or throw without partially writing.
    func encode(into buffer: inout ByteBuffer) throws
}

// MARK: - Decode errors

/// Internal error used by every `decode(from:)` to tell ``IRCFrameDecoder`` whether to
/// wait for more bytes (`incomplete`) or fail the connection (`malformed`).
struct NIODecodeError: Error, CustomStringConvertible {
    enum Kind: Equatable {
        case incomplete
        case malformed
    }

    let kind: Kind
    let message: String
    var description: String { message }

    static func incomplete(_ message: String) -> NIODecodeError {
        NIODecodeError(kind: .incomplete, message: message)
    }

    static func malformed(_ message: String) -> NIODecodeError {
        NIODecodeError(kind: .malformed, message: message)
    }
}

// MARK: - ByteBuffer helpers

/// Shared length-prefixed field helpers used by `MultipartPacket`, `DCCMessage`, and
/// `IRCBinaryMessage`. All lengths are big-endian `UInt32` and are bounded against a
/// caller-supplied limit *before* any allocation.
extension ByteBuffer {
    mutating func writeLengthPrefixedUTF8(_ value: String) throws {
        let bytes = value.utf8
        guard bytes.count <= Int(UInt32.max) else {
            throw NIODecodeError.malformed("UTF-8 field is too large to encode")
        }
        writeInteger(UInt32(bytes.count))
        writeString(value)
    }

    mutating func readLengthPrefixedUTF8(
        field: String,
        maxLength: Int
    ) throws -> String {
        guard let encodedLength = readInteger(as: UInt32.self) else {
            throw NIODecodeError.incomplete("Missing \(field) length")
        }
        guard Int(encodedLength) <= maxLength else {
            throw NIODecodeError.malformed("\(field) exceeds configured limit")
        }
        guard let value = readString(length: Int(encodedLength)) else {
            throw NIODecodeError.incomplete("Incomplete \(field)")
        }
        return value
    }

    /// Writes a presence byte (0/1) followed, when present, by a length-prefixed UTF-8 string.
    mutating func writeOptionalLengthPrefixedUTF8(_ value: String?) throws {
        guard let value else {
            writeInteger(UInt8(0))
            return
        }
        writeInteger(UInt8(1))
        try writeLengthPrefixedUTF8(value)
    }

    /// Reads a presence byte (0/1) followed, when present, by a length-prefixed UTF-8 string.
    mutating func readOptionalLengthPrefixedUTF8(
        field: String,
        maxLength: Int
    ) throws -> String? {
        guard let present = readInteger(as: UInt8.self) else {
            throw NIODecodeError.incomplete("Missing \(field) presence flag")
        }
        switch present {
        case 0:
            return nil
        case 1:
            return try readLengthPrefixedUTF8(field: field, maxLength: maxLength)
        default:
            throw NIODecodeError.malformed("Invalid \(field) presence flag")
        }
    }
}
