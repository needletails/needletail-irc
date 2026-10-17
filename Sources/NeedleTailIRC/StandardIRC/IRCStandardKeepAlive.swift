//
//  IRCStandardKeepAlive.swift
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

/// Options for ``IRCStandardKeepAliveHandler``.
public struct IRCStandardKeepAliveConfiguration: Sendable {
    /// Answer server `PING` with `PONG`. The `PING` is still passed on to later handlers,
    /// so turn this off if the application already answers it.
    public var respondsToPing: Bool
    /// Send our own `PING` after this long without inbound traffic. `nil` disables it.
    public var idleInterval: TimeAmount?
    /// Close the connection when nothing arrives this long after our `PING`.
    public var timeout: TimeAmount

    public init(
        respondsToPing: Bool = true,
        idleInterval: TimeAmount? = .seconds(90),
        timeout: TimeAmount = .seconds(60)
    ) {
        self.respondsToPing = respondsToPing
        self.idleInterval = idleInterval
        self.timeout = timeout
    }
}

/// Answers server PINGs and detects dead connections. Sits after ``IRCStandardInboundBridge``
/// and works on ``IRCFrame``. Installed by `addStandardIRCHandlers` when
/// ``IRCStandardConfiguration/keepAlive`` is set.
public final class IRCStandardKeepAliveHandler: ChannelDuplexHandler, @unchecked Sendable {
    public typealias InboundIn = IRCFrame
    public typealias InboundOut = IRCFrame
    public typealias OutboundIn = IRCFrame
    public typealias OutboundOut = IRCFrame

    /// The token sent in our own `PING`.
    public static let pingToken = "keepalive"

    private let configuration: IRCStandardKeepAliveConfiguration
    private var idleTask: Scheduled<Void>?
    private var timeoutTask: Scheduled<Void>?

    public init(configuration: IRCStandardKeepAliveConfiguration = .init()) {
        self.configuration = configuration
    }

    public func handlerAdded(context: ChannelHandlerContext) {
        if context.channel.isActive { scheduleIdle(context: context) }
    }

    public func handlerRemoved(context: ChannelHandlerContext) {
        cancelTimers()
    }

    public func channelActive(context: ChannelHandlerContext) {
        scheduleIdle(context: context)
        context.fireChannelActive()
    }

    public func channelInactive(context: ChannelHandlerContext) {
        cancelTimers()
        context.fireChannelInactive()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        timeoutTask?.cancel()
        timeoutTask = nil
        scheduleIdle(context: context)

        if configuration.respondsToPing,
           case .text(let message) = unwrapInboundIn(data),
           case .ping(let server, let server2) = message.command {
            context.writeAndFlush(
                wrapOutboundOut(.text(IRCMessage(command: .pong(server: server, server2: server2)))),
                promise: nil
            )
        }
        context.fireChannelRead(data)
    }

    private func scheduleIdle(context: ChannelHandlerContext) {
        idleTask?.cancel()
        guard let interval = configuration.idleInterval else { return }
        let loopBoundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
        idleTask = context.eventLoop.scheduleTask(in: interval) { [self] in
            self.sendPing(context: loopBoundContext.value)
        }
    }

    private func sendPing(context: ChannelHandlerContext) {
        guard context.channel.isActive else { return }
        context.writeAndFlush(
            wrapOutboundOut(.text(IRCMessage(command: .ping(server: Self.pingToken, server2: nil)))),
            promise: nil
        )
        let loopBoundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
        timeoutTask = context.eventLoop.scheduleTask(in: configuration.timeout) { [self] in
            let context = loopBoundContext.value
            self.cancelTimers()
            context.fireErrorCaught(IRCStandardError(.keepAliveTimeout, "no reply within the keepalive timeout"))
            context.close(promise: nil)
        }
    }

    private func cancelTimers() {
        idleTask?.cancel()
        idleTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
