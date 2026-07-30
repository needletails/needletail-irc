//
//  IRCPayloadDecoder.swift
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

public final class IRCPayloadDecoder: ByteToMessageDecoder, @unchecked Sendable {
    public typealias InboundOut = IRCPayload

    /// Default max IRC line length (bytes) before newline. Large enough for NeedleTail payloads.
    public static let defaultMaxLineLength: Int = 32_000_000

    public enum DecoderError: Error, Sendable {
        case lineTooLong(maxLineLength: Int)
    }
    
    private let logger: NeedleTailLogger
    let maxLineLength: Int
    /// When true, a leading byte in 0...4 is treated as a binary frame discriminator
    /// and decoded as a `DirectMessage`. When false, all bytes are framed as IRC lines.
    let allowsBinaryFrames: Bool

    /// Published default: IRC lines + binary `DirectMessage` frames (discriminator 0...4).
    /// Prefer the named factories at production call sites so intent is obvious.
    public init(logger: NeedleTailLogger = NeedleTailLogger()) {
        self.logger = logger
        self.maxLineLength = IRCPayloadDecoder.defaultMaxLineLength
        self.allowsBinaryFrames = true
    }

    /// Full configuration.
    public init(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCPayloadDecoder.defaultMaxLineLength,
        allowsBinaryFrames: Bool
    ) {
        self.logger = logger
        self.maxLineLength = maxLineLength
        self.allowsBinaryFrames = allowsBinaryFrames
    }

    /// Line-based IRC only. Use on sockets that never carry peer `DirectMessage` frames
    /// (NudgeServer IRC listener, SFU signaling, mock IRC servers). Prevents a low leading
    /// byte from being misread as a binary frame and stalling the connection.
    public static func lineBasedIRC(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCPayloadDecoder.defaultMaxLineLength
    ) -> IRCPayloadDecoder {
        IRCPayloadDecoder(logger: logger, maxLineLength: maxLineLength, allowsBinaryFrames: false)
    }

    /// IRC lines plus binary `DirectMessage` frames. Use on peer DCC sockets (and any
    /// client pipeline that may open DCC), where payloads are encoded with a 0...4 discriminator.
    public static func withBinaryFrames(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxLineLength: Int = IRCPayloadDecoder.defaultMaxLineLength
    ) -> IRCPayloadDecoder {
        IRCPayloadDecoder(logger: logger, maxLineLength: maxLineLength, allowsBinaryFrames: true)
    }

    static func shouldIgnoreIRCLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes > 0 else {
            return .needMoreData
        }
        
        guard let discriminator = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            return .needMoreData
        }
        
        if allowsBinaryFrames, (0...4).contains(discriminator) {
            // Binary DirectMessage frame (peer DCC path) — not line-based IRC.
            let originalReaderIndex = buffer.readerIndex
            do {
                var slice = buffer
                let directMessage = try DirectMessage.decode(from: &slice)
                let bytesRead = slice.readerIndex - originalReaderIndex
                buffer.moveReaderIndex(forwardBy: bytesRead)
                context.fireChannelRead(self.wrapInboundOut(.dcc(directMessage)))
                return .continue
            } catch {
                // Incomplete binary frame — wait for more bytes.
                buffer.moveReaderIndex(to: originalReaderIndex)
                return .needMoreData
            }
        } else {
            // Line-based IRC (including textual DCCCHAT / SDCCCHAT offers).
            let view = buffer.readableBytesView
            
            if let newlineIndex = view.firstIndex(of: UInt8(ascii: "\n")) {
                let offset = view.distance(from: view.startIndex, to: newlineIndex)
                let crIndex = newlineIndex > view.startIndex ? view.index(before: newlineIndex) : nil
                let hasCR = crIndex != nil && view[crIndex!] == UInt8(ascii: "\r")
                
                let sliceLength = hasCR ? offset - 1 : offset
                
                guard let lineBuffer = buffer.readSlice(length: sliceLength) else {
                    return .needMoreData
                }
                
                // Drop the \r?\n
                buffer.moveReaderIndex(forwardBy: hasCR ? 2 : 1)
                
                guard let line = lineBuffer.getString(at: 0, length: lineBuffer.readableBytes) else {
                    // Line bytes already consumed — do not stall waiting for more data.
                    logger.log(level: .error, message: "Failed to decode IRC line as UTF-8 after consume; skipping")
                    return .continue
                }
                guard !Self.shouldIgnoreIRCLine(line) else {
                    return .continue
                }
                do {
                    let message = try NeedleTailIRCParser.parseMessage(line)
                    context.fireChannelRead(self.wrapInboundOut(.irc(message)))
                } catch {
                    logger.log(level: .warning, message: "Failed to parse IRC line", metadata: [
                        "line": "\(line.prefix(128))",
                        "error": "\(error)"
                    ])
                }
                
                return .continue
            } else {
                if buffer.readableBytes > maxLineLength {
                    throw DecoderError.lineTooLong(maxLineLength: maxLineLength)
                }
                return .needMoreData
            }
        }
    }
}
