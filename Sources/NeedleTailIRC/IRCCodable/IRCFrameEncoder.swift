//
//  IRCFrameEncoder.swift
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

/// NIO adapter that writes ``IRCFrame`` values to the socket.
///
/// All wire rules live on the payload types (see ``IRCWireEncodable``); this handler
/// only delegates and logs. Errors propagate so the pipeline can fail the write promise.
public final class IRCFrameEncoder: MessageToByteEncoder, @unchecked Sendable {
    public typealias OutboundIn = IRCFrame

    private let logger: NeedleTailLogger

    public init(logger: NeedleTailLogger = NeedleTailLogger()) {
        self.logger = logger
    }

    public func encode(data: IRCFrame, out: inout ByteBuffer) throws {
        do {
            try data.encode(into: &out)
        } catch IRCMessageGeneratorError.emptyCommandRejected {
            // Caller sent a frame with nobody to route to. The throw is the contract;
            // logging it as an encode failure hides real codec errors in test output.
            throw IRCMessageGeneratorError.emptyCommandRejected
        } catch {
            logger.log(level: .error, message: "Failed to encode IRCFrame", metadata: [
                "frame": "\(data)",
                "error": "\(error)"
            ])
            throw error
        }
    }
}
