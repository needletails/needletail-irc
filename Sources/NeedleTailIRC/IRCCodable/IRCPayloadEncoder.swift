//
//  IRCPayloadEncoder.swift
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

public final class IRCPayloadEncoder: MessageToByteEncoder, @unchecked Sendable {
    public typealias OutboundIn = IRCPayload

    private let logger: NeedleTailLogger

    public init(logger: NeedleTailLogger = NeedleTailLogger()) {
        self.logger = logger
    }

    public func encode(data: IRCPayload, out: inout ByteBuffer) throws {
        switch data {
        case .irc(let iRCMessage):
            let messageString = NeedleTailIRCEncoder.encode(value: iRCMessage)
            
            // Ensure message is not empty
            guard !messageString.isEmpty else {
                logger.log(level: .warning, message: "Attempted to encode empty IRC message. Skipping.")
                return
            }

            out.writeString(messageString + "\r\n")

        case .dcc(let directMessage):
            do {
                try directMessage.encode(into: &out)
            } catch {
                logger.log(level: .error, message: "Failed to encode DirectMessage", metadata: [
                    "messageType": "\(directMessage)",
                    "error": "\(error)"
                ])
                throw error
            }
        }
    }
}

public enum IRCPayload: Codable, Sendable {
    case irc(IRCMessage), dcc(DirectMessage)
}
