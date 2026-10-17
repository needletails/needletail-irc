//
//  IRCStandardLineCodec.swift
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

import NIOCore

/// Frames inbound bytes from a standard IRC server as ``IRCRawMessage`` values.
///
/// - Accepts CRLF and bare LF terminators.
/// - Skips blank (whitespace-only) lines.
/// - Decodes invalid UTF-8 lossily (U+FFFD) instead of dropping the line.
/// - A line that is not a valid IRC message is consumed and reported through
///   `unparsableLineHandler`; decoding continues with the next line.
/// - A line longer than `maxLineLength` fails the channel with ``IRCStandardError/Code/lineTooLong``.
public final class IRCStandardLineDecoder: ByteToMessageDecoder, @unchecked Sendable {
    public typealias InboundOut = IRCRawMessage

    /// IRCv3 message-tags allow 8191 bytes of tags plus the 512-byte RFC message.
    public static let defaultMaxLineLength: Int = 8191 + 512

    public let maxLineLength: Int
    public let limits: IRCParserLimits
    private let unparsableLineHandler: (@Sendable (String, any Error) -> Void)?

    public init(
        maxLineLength: Int = IRCStandardLineDecoder.defaultMaxLineLength,
        limits: IRCParserLimits = .standardIRC,
        unparsableLineHandler: (@Sendable (String, any Error) -> Void)? = nil
    ) {
        self.maxLineLength = maxLineLength
        self.limits = limits
        self.unparsableLineHandler = unparsableLineHandler
    }

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let view = buffer.readableBytesView
        guard let newlineIndex = view.firstIndex(of: IRCRawMessage.lf) else {
            if buffer.readableBytes > maxLineLength {
                throw IRCStandardError(.lineTooLong, "no terminator within \(maxLineLength) bytes")
            }
            return .needMoreData
        }

        let lineLength = view.distance(from: view.startIndex, to: newlineIndex)
        guard lineLength <= maxLineLength else {
            throw IRCStandardError(.lineTooLong, "line exceeds \(maxLineLength) bytes")
        }
        let hasCR = lineLength > 0 && view[view.index(before: newlineIndex)] == IRCRawMessage.cr
        let line = buffer.readString(length: hasCR ? lineLength - 1 : lineLength) ?? ""
        buffer.moveReaderIndex(forwardBy: hasCR ? 2 : 1)

        if line.utf8.allSatisfy({ $0 == IRCRawMessage.space || $0 == UInt8(ascii: "\t") }) {
            return .continue
        }

        do {
            let message = try IRCRawMessage.parse(line, limits: limits)
            context.fireChannelRead(wrapInboundOut(message))
        } catch {
            unparsableLineHandler?(line, error)
        }
        return .continue
    }
}

/// Writes ``IRCRawMessage`` values as CRLF-terminated lines.
public final class IRCRawMessageEncoder: MessageToByteEncoder, @unchecked Sendable {
    public typealias OutboundIn = IRCRawMessage

    public init() {}

    public func encode(data: IRCRawMessage, out: inout ByteBuffer) throws {
        try data.encode(into: &out)
    }
}
