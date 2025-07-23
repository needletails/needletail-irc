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

public final class IRCPayloadEncoder: MessageToByteEncoder {
    public typealias OutboundIn = IRCPayload
    
    public init() {}

    public func encode(data: IRCPayload, out: inout ByteBuffer) throws {
        switch data {
        case .irc(let iRCMessage):
            let messageString = try NeedleTailIRCEncoder.encode(value: iRCMessage)
            out.writeString(messageString)
        case .dcc(let directMessage):
            try directMessage.encode(into: &out)
        }
    }
}


public enum IRCPayload: Codable, Sendable {
    case irc(IRCMessage), dcc(DirectMessage)
}
