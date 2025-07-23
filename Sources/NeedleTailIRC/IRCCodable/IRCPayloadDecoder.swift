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

public final class IRCPayloadDecoder: ByteToMessageDecoder {
    public typealias InboundOut = IRCPayload
    
    public init() {}

    public func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        guard buffer.readableBytes > 0 else {
            return .needMoreData
        }

        // Peek the first byte to determine the message type
        guard let discriminator = buffer.getInteger(at: buffer.readerIndex, as: UInt8.self) else {
            return .needMoreData
        }

        // Discriminator for DirectMessage ranges from 0...4 (from your enum)
        if (0...4).contains(discriminator) {
            // Decode as DirectMessage
            let originalReaderIndex = buffer.readerIndex
            do {
                var slice = buffer // Copy buffer for isolated decoding
                let directMessage = try DirectMessage.decode(from: &slice)
                let bytesRead = slice.readerIndex - buffer.readerIndex
                buffer.moveReaderIndex(forwardBy: bytesRead)

                context.fireChannelRead(self.wrapInboundOut(.dcc(directMessage)))
                return .continue
            } catch {
                // If decoding fails, don't consume buffer
                buffer.moveReaderIndex(to: originalReaderIndex)
                throw error
            }
        } else {
            // Fallback to try as UTF-8 String (IRCMessage)
            if let string = buffer.readString(length: buffer.readableBytes) {
                let message = try NeedleTailIRCParser.parseMessage(string)
                context.fireChannelRead(self.wrapInboundOut(.irc(message)))
                return .continue
            }
        }

        return .needMoreData
    }
}
