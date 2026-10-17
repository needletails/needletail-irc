//
//  IRCStandardPipeline.swift
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

/// Options for `ChannelPipeline.SynchronousOperations.addStandardIRCHandlers(configuration:)`.
public struct IRCStandardConfiguration: Sendable {
    /// Maximum inbound line length in bytes, including tags.
    public var maxLineLength: Int
    /// Limits applied to inbound IRCv3 tag sections.
    public var parserLimits: IRCParserLimits
    /// Called for every inbound message with both the lossless and the typed form, before the
    /// typed form is passed down the pipeline. Use it for details the typed model cannot hold
    /// (PART reasons, CAP continuations, extended-join fields, ...).
    public var rawObserver: (@Sendable (IRCRawMessage, IRCMessage) -> Void)?
    /// Called with lines that are not valid IRC messages. They are skipped either way.
    public var unparsableLineHandler: (@Sendable (String, any Error) -> Void)?
    /// When set, an ``IRCStandardKeepAliveHandler`` answers PINGs and detects dead connections.
    /// Off by default, because existing applications usually answer PING themselves.
    public var keepAlive: IRCStandardKeepAliveConfiguration?

    public init(
        maxLineLength: Int = IRCStandardLineDecoder.defaultMaxLineLength,
        parserLimits: IRCParserLimits = .standardIRC,
        rawObserver: (@Sendable (IRCRawMessage, IRCMessage) -> Void)? = nil,
        unparsableLineHandler: (@Sendable (String, any Error) -> Void)? = nil,
        keepAlive: IRCStandardKeepAliveConfiguration? = nil
    ) {
        self.maxLineLength = maxLineLength
        self.parserLimits = parserLimits
        self.rawObserver = rawObserver
        self.unparsableLineHandler = unparsableLineHandler
        self.keepAlive = keepAlive
    }
}

/// Turns ``IRCRawMessage`` values into `IRCFrame.text` so existing handlers and
/// `NIOAsyncChannel<IRCFrame, IRCFrame>` consumers work unchanged.
public final class IRCStandardInboundBridge: ChannelInboundHandler, @unchecked Sendable {
    public typealias InboundIn = IRCRawMessage
    public typealias InboundOut = IRCFrame

    private let rawObserver: (@Sendable (IRCRawMessage, IRCMessage) -> Void)?

    public init(rawObserver: (@Sendable (IRCRawMessage, IRCMessage) -> Void)? = nil) {
        self.rawObserver = rawObserver
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let raw = unwrapInboundIn(data)
        let message = IRCMessage(standardIRC: raw)
        rawObserver?(raw, message)
        context.fireChannelRead(wrapInboundOut(.text(message)))
    }
}

/// Writes ``IRCFrame`` values to a standard IRC server.
///
/// `.text` frames go through ``IRCStandardTranslator/rawMessage(from:)``. `.binary` and `.dcc`
/// frames are NeedleTail-only and fail the write with ``IRCStandardError/Code/unsupportedFrame``.
public final class IRCStandardFrameEncoder: MessageToByteEncoder, @unchecked Sendable {
    public typealias OutboundIn = IRCFrame

    public init() {}

    public func encode(data: IRCFrame, out: inout ByteBuffer) throws {
        switch data {
        case .text(let message):
            try IRCRawMessage(standardIRC: message).encode(into: &out)
        case .binary:
            throw IRCStandardError(.unsupportedFrame, "binary frames cannot be sent to a standard IRC server")
        case .dcc:
            throw IRCStandardError(.unsupportedFrame, "DCC frames cannot be sent to a standard IRC server")
        }
    }
}

extension ChannelPipeline.SynchronousOperations {
    /// Installs the standard IRC / IRCv3 codec in place of `IRCFrameDecoder` / `IRCFrameEncoder`.
    ///
    /// Handlers added after this call keep reading and writing ``IRCFrame``:
    ///
    /// ```swift
    /// try channel.pipeline.syncOperations.addStandardIRCHandlers()
    /// return try NIOAsyncChannel<IRCFrame, IRCFrame>(wrappingChannelSynchronously: channel)
    /// ```
    ///
    /// Add TLS (if any) before calling this.
    public func addStandardIRCHandlers(configuration: IRCStandardConfiguration = .init()) throws {
        try addHandler(ByteToMessageHandler(IRCStandardLineDecoder(
            maxLineLength: configuration.maxLineLength,
            limits: configuration.parserLimits,
            unparsableLineHandler: configuration.unparsableLineHandler
        )))
        try addHandler(MessageToByteHandler(IRCStandardFrameEncoder()))
        try addHandler(IRCStandardInboundBridge(rawObserver: configuration.rawObserver))
        if let keepAlive = configuration.keepAlive {
            try addHandler(IRCStandardKeepAliveHandler(configuration: keepAlive))
        }
    }
}
