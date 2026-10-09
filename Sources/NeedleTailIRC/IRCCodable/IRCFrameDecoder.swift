//
//  IRCFrameDecoder.swift
//  needletail-irc
//
//  Created by Cole M on 7/20/25.
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
import NeedleTailLogger

/// NIO adapter that frames inbound bytes as ``IRCFrame`` values.
///
/// The handler owns exactly two decisions: which family the leading byte selects
/// (subject to ``BinaryFraming``), and how to translate a payload type's decode result
/// into NIO's `DecodingState`. Each payload type owns its own framing rule and limits:
///
/// - ``IRCMessage/decode(from:maxLineLength:)`` — newline-delimited; a bad line is
///   consumed and reported as ``IRCMessage/IgnoredLine`` so the stream continues.
/// - ``IRCBinaryMessage/decode(from:maxFrameLength:)`` and
///   ``DCCMessage/decode(from:maxFrameLength:)`` — discriminator + length; a bad frame
///   throws, because there is no delimiter to resynchronise on.
public final class IRCFrameDecoder: ByteToMessageDecoder, @unchecked Sendable {
    public typealias InboundOut = IRCFrame

    /// Default max IRC line length (bytes) before newline. Large enough for NeedleTail payloads.
    public static let defaultMaxLineLength: Int = 32_000_000
    /// Default maximum declared size for one binary frame field.
    public static let defaultMaxBinaryFrameLength: Int = 32_000_000

    /// Line-framing errors. Defined on ``IRCMessage``; aliased here for source compatibility.
    public typealias DecoderError = IRCMessage.LineError

    /// Which non-line frame families this decoder will recognise from the leading byte.
    ///
    /// Anything not enabled here is framed as IRC text, so a socket that must never see a
    /// given family (e.g. the server listener and DCC) simply leaves it out.
    public struct BinaryFraming: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        /// `DCCMessage` frames, discriminator `0...4`. Peer-to-peer sockets only.
        public static let dcc = BinaryFraming(rawValue: 1 << 0)
        /// `IRCBinaryMessage` frames, discriminator `IRCBinaryMessage.discriminator`. Server connection.
        public static let ircBinary = BinaryFraming(rawValue: 1 << 1)

        public static let none: BinaryFraming = []
        public static let all: BinaryFraming = [.dcc, .ircBinary]
    }
    
    private let logger: NeedleTailLogger
    let maxLineLength: Int
    /// Binary frame families recognised from the leading byte. Everything else is an IRC line.
    let binaryFraming: BinaryFraming
    let maxBinaryFrameLength: Int

    /// Backwards-compatible view: `true` when any binary family is enabled.
    var allowsBinaryFrames: Bool { !binaryFraming.isEmpty }

    /// Published default: IRC lines + every binary frame family.
    /// Prefer the named factories at production call sites so intent is obvious.
    public convenience init(logger: NeedleTailLogger = NeedleTailLogger()) {
        self.init(logger: logger, binaryFraming: .all)
    }

    /// Full configuration.
    public init(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCFrameDecoder.defaultMaxLineLength,
        binaryFraming: BinaryFraming,
        maxBinaryFrameLength: Int = IRCFrameDecoder.defaultMaxBinaryFrameLength
    ) {
        self.logger = logger
        self.maxLineLength = maxLineLength
        self.binaryFraming = binaryFraming
        self.maxBinaryFrameLength = maxBinaryFrameLength
    }

    /// Source-compatible shim: `true` enables every binary family, `false` none.
    public convenience init(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCFrameDecoder.defaultMaxLineLength,
        allowsBinaryFrames: Bool,
        maxBinaryFrameLength: Int = IRCFrameDecoder.defaultMaxBinaryFrameLength
    ) {
        self.init(
            logger: logger,
            maxLineLength: maxLineLength,
            binaryFraming: allowsBinaryFrames ? .all : .none,
            maxBinaryFrameLength: maxBinaryFrameLength
        )
    }

    /// Line-based IRC only. Use on sockets that must never carry any binary frame
    /// (SFU signaling, mock IRC servers). Prevents a low leading byte from being misread
    /// as a binary frame and stalling the connection.
    public static func lineBasedIRC(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCFrameDecoder.defaultMaxLineLength
    ) -> IRCFrameDecoder {
        IRCFrameDecoder(logger: logger, maxLineLength: maxLineLength, binaryFraming: .none)
    }

    /// IRC lines plus `IRCBinaryMessage` frames, but **not** DCC. Use on the server's
    /// client listener: it must route binary messages yet must never interpret a `0...4`
    /// byte as a peer frame.
    public static func serverIRC(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCFrameDecoder.defaultMaxLineLength,
        maxBinaryFrameLength: Int = IRCFrameDecoder.defaultMaxBinaryFrameLength
    ) -> IRCFrameDecoder {
        IRCFrameDecoder(
            logger: logger,
            maxLineLength: maxLineLength,
            binaryFraming: .ircBinary,
            maxBinaryFrameLength: maxBinaryFrameLength
        )
    }

    /// IRC lines plus every binary family. Use on client pipelines, which talk to the
    /// server (`IRCBinaryMessage`) and may also open DCC (`DCCMessage`).
    public static func withBinaryFrames(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCFrameDecoder.defaultMaxLineLength
    ) -> IRCFrameDecoder {
        IRCFrameDecoder(logger: logger, maxLineLength: maxLineLength, binaryFraming: .all)
    }

    /// IRC plus every binary family with an explicit binary field-size limit.
    public static func withBinaryFrames(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCFrameDecoder.defaultMaxLineLength,
        maxBinaryFrameLength: Int
    ) -> IRCFrameDecoder {
        IRCFrameDecoder(
            logger: logger,
            maxLineLength: maxLineLength,
            binaryFraming: .all,
            maxBinaryFrameLength: maxBinaryFrameLength
        )
    }

    /// Kept for callers/tests; the rule itself lives on ``IRCMessage``.
    static func shouldIgnoreIRCLine(_ line: String) -> Bool {
        IRCMessage.isIgnorableLine(line)
    }

    // MARK: - ByteToMessageDecoder

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard let discriminator = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            return .needMoreData
        }

        if binaryFraming.contains(.ircBinary), discriminator == IRCBinaryMessage.discriminator {
            // Server-routed binary. Checked first: 0xFF can never start a UTF-8 line and is
            // outside the DCC range, so this test is unambiguous.
            return try decodeFrame(context: context, buffer: &buffer) { slice in
                .binary(try IRCBinaryMessage.decode(from: &slice, maxFrameLength: maxBinaryFrameLength))
            }
        }

        if binaryFraming.contains(.dcc), (0...4).contains(discriminator) {
            return try decodeFrame(context: context, buffer: &buffer) { slice in
                .dcc(try DCCMessage.decode(from: &slice, maxFrameLength: maxBinaryFrameLength))
            }
        }

        // Line-based IRC (including textual DCC CHAT / SDCC CHAT offers).
        return try decodeFrame(context: context, buffer: &buffer) { slice in
            switch try IRCMessage.decode(from: &slice, maxLineLength: maxLineLength) {
            case .message(let message):
                return .text(message)
            case .ignored(let reason):
                logIgnoredLine(reason)
                return nil
            }
        }
    }

    // MARK: - Shared frame driver

    /// Runs one family's decoder against a copy of `buffer` and advances the real reader
    /// index only once a whole frame has been consumed.
    ///
    /// - `NIODecodeError.incomplete` → rewind, `.needMoreData`.
    /// - A decoded frame → fire it, `.continue`.
    /// - `nil` → the bytes were consumed but produced nothing (ignored text line), `.continue`.
    /// - Any other error → rewind and rethrow so the pipeline can fail the connection.
    private func decodeFrame(
        context: ChannelHandlerContext,
        buffer: inout ByteBuffer,
        _ decode: (inout ByteBuffer) throws -> IRCFrame?
    ) throws -> DecodingState {
        let originalReaderIndex = buffer.readerIndex
        do {
            var slice = buffer
            let frame = try decode(&slice)
            buffer.moveReaderIndex(forwardBy: slice.readerIndex - originalReaderIndex)
            if let frame {
                context.fireChannelRead(self.wrapInboundOut(frame))
            }
            return .continue
        } catch let error as NIODecodeError where error.kind == .incomplete {
            buffer.moveReaderIndex(to: originalReaderIndex)
            return .needMoreData
        } catch {
            buffer.moveReaderIndex(to: originalReaderIndex)
            throw error
        }
    }

    private func logIgnoredLine(_ reason: IRCMessage.IgnoredLine) {
        switch reason {
        case .blank:
            break
        case .unparsable(let line, let error):
            logger.log(level: .warning, message: "Failed to parse IRC line", metadata: [
                "line": "\(line.prefix(128))",
                "error": "\(error)"
            ])
        }
    }
}
