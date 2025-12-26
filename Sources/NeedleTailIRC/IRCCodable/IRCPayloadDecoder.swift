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
    
    private let logger: NeedleTailLogger
    private let maxIRCLineBytesIncludingCRLF: Int
    private let maxBufferedIRCBytesWithoutNewline: Int
    private let closeOnInboundViolation: Bool
    
    public init(
        logger: NeedleTailLogger = NeedleTailLogger(),
        maxIRCLineBytesIncludingCRLF: Int = IRCPayloadWireSize.defaultMaxIRCLineBytes,
        maxBufferedIRCBytesWithoutNewline: Int = 64 * 1024,
        closeOnInboundViolation: Bool = true
    ) {
        self.logger = logger
        self.maxIRCLineBytesIncludingCRLF = maxIRCLineBytesIncludingCRLF
        self.maxBufferedIRCBytesWithoutNewline = maxBufferedIRCBytesWithoutNewline
        self.closeOnInboundViolation = closeOnInboundViolation
    }
    
    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes > 0 else {
            return .needMoreData
        }
        
        guard let discriminator = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            return .needMoreData
        }
        
        if (0...4).contains(discriminator) {
            // === Handle DCC (binary messages) ===
            let originalReaderIndex = buffer.readerIndex
            do {
                var slice = buffer
                let directMessage = try DirectMessage.decode(from: &slice)
                let bytesRead = slice.readerIndex - originalReaderIndex
                buffer.moveReaderIndex(forwardBy: bytesRead)
                context.fireChannelRead(self.wrapInboundOut(.dcc(directMessage)))
                return .continue
            } catch {
                // Likely not enough bytes yet — wait for more
                buffer.moveReaderIndex(to: originalReaderIndex)
                return .needMoreData
            }
        } else {
            // === Handle IRC (line-based, replicates LineBasedFrameDecoder) ===
            let view = buffer.readableBytesView
            
            if let newlineIndex = view.firstIndex(of: UInt8(ascii: "\n")) {
                let offset = view.distance(from: view.startIndex, to: newlineIndex)
                let crIndex = newlineIndex > view.startIndex ? view.index(before: newlineIndex) : nil
                let hasCR = crIndex != nil && view[crIndex!] == UInt8(ascii: "\r")
                
                let sliceLength = hasCR ? offset - 1 : offset
                let bytesIncludingCRLF = sliceLength + (hasCR ? 2 : 1)

                // Legit reason: protects against protocol violations and avoids large allocations.
                // If the incoming line exceeds the configured IRC limit, treat it as a protocol violation.
                if bytesIncludingCRLF > maxIRCLineBytesIncludingCRLF {
                    // Consume through the newline and continue.
                    buffer.moveReaderIndex(forwardBy: offset + 1)
                    logger.log(level: .error, message: "Inbound IRC line exceeded limit", metadata: [
                        "bytesIncludingCRLF": "\(bytesIncludingCRLF)",
                        "maxBytes": "\(maxIRCLineBytesIncludingCRLF)"
                    ])
                    context.fireErrorCaught(NeedleTailError.payloadTooLarge)
                    if closeOnInboundViolation {
                        context.close(promise: nil)
                    }
                    return .continue
                }
                
                guard let lineBuffer = buffer.readSlice(length: sliceLength) else {
                    return .needMoreData
                }
                
                // Drop the \r?\n
                buffer.moveReaderIndex(forwardBy: hasCR ? 2 : 1)
                
                guard let line = lineBuffer.getString(at: 0, length: lineBuffer.readableBytes) else {
                    return .needMoreData
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
                // No newline yet; prevent unbounded buffering.
                if buffer.readableBytes > maxBufferedIRCBytesWithoutNewline {
                    logger.log(level: .error, message: "Inbound IRC buffer exceeded limit without newline", metadata: [
                        "bufferedBytes": "\(buffer.readableBytes)",
                        "maxBufferedBytes": "\(maxBufferedIRCBytesWithoutNewline)"
                    ])
                    // Drop buffered data and close (default) to prevent DoS via unbounded buffering.
                    buffer.moveReaderIndex(to: buffer.writerIndex)
                    context.fireErrorCaught(NeedleTailError.payloadTooLarge)
                    if closeOnInboundViolation {
                        context.close(promise: nil)
                    }
                    return .continue
                }
                return .needMoreData
            }
        }
    }
}
