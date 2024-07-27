import NIOCore
import Logging
import NeedleTailLogger
import NeedleTailAsyncSequence
import AsyncAlgorithms

public protocol NeedleTailClientDelegate: AnyObject, Sendable, IRCDispatcher, NeedleTailWriterDelegate {
    
    func transportMessage(_
                          consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                          logger: NeedleTailLogger,
                          priority: Priority,
                          writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                          origin: String,
                          command: IRCCommand,
                          tags: [IRCTags]?
    ) async throws
}

public protocol NeedleTailWriterDelegate: AnyObject, Sendable {
    
    
    func sendAndFlushMessage(_
                             consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                             logger: NeedleTailLogger,
                             priority: Priority,
                             writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                             message: IRCMessage
    ) async throws
}


//TODO: Fa Fu: Getting fat/rich
extension NeedleTailWriterDelegate {
    
    public func sendAndFlushMessage(_
                                    consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                                    logger: NeedleTailLogger = NeedleTailLogger(.init(label: "[NeedleTailWriterDelegate]")),
                                    priority: Priority,
                                    writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                                    message: IRCMessage
    ) async throws {
        do {
            if #available(iOS 17.0, macOS 14, *) {
                try await withThrowingDiscardingTaskGroup { group in
                    logger.log(level: .debug, message: "Feed message \(message.command.commandAsString)")
                    let messageString = await NeedleTailIRCEncoder.encode(value: message)
                    //IRC only allows 512 characters per message so we need to create packets according to the spec size
                    let buffers = try await NeedleTailIRCEncoder.derivePacket(ircMessage: messageString)
                    for buffer in buffers {
                        await consumer.feedConsumer(
                            buffer,
                            priority: priority
                        )
                    }
                    for try await result in NeedleTailAsyncSequence(consumer: consumer) {
                        switch result {
                        case .success(let buffer):
                            group.addTask {
                                do {
                                    try await writer.write(buffer)
                                    logger.log(level: .debug, message: "AsyncWriter Wrote Buffer")
                                } catch {
                                    logger.log(level: .error, message: "\(error)")
                                    return
                                }
                            }
                        case .consumed:
                            return
                        }
                    }
                }
            } else {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    let messageString = await NeedleTailIRCEncoder.encode(value: message)
                    //IRC only allows 512 characters per message so we need to create packets according to the spec size
                    let buffers = try await NeedleTailIRCEncoder.derivePacket(ircMessage: messageString)
                    for await buffer in buffers.async {
                        await consumer.feedConsumer(
                            buffer,
                            priority: priority
                        )
                    }
                    for try await result in NeedleTailAsyncSequence(consumer: consumer) {
                        switch result {
                        case .success(let buffer):
                            group.addTask {
                                do {
                                    try await writer.write(buffer)
                                    logger.log(level: .trace, message: "AsyncWriter Wrote Buffer")
                                } catch {
                                    logger.log(level: .error, message: "\(error)")
                                    return
                                }
                            }
                        case .consumed:
                            return
                        }
                    }
                }
            }
        } catch {
            throw error
        }
    }
}

//MARK: Client Side
extension NeedleTailClientDelegate {
    
    public func transportMessage(_
                                 consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                                 logger: NeedleTailLogger = NeedleTailLogger(.init(label: "[NeedleTailWriter]")),
                                 priority: Priority = .standard,
                                 writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                                 origin: String = "",
                                 command: IRCCommand,
                                 tags: [IRCTags]? = nil
    ) async throws {
        switch command {
        case .PRIVMSG(let recipients, let messageLines):
            let lines = messageLines.components(separatedBy: Constants.cLF.rawValue)
                .map { $0.replacingOccurrences(of: Constants.cCR.rawValue, with: Constants.space.rawValue) }
            for await line in lines.async {
                let message = IRCMessage(origin: origin, command: .PRIVMSG(recipients, line), tags: tags)
                try await self.sendAndFlushMessage(
                    consumer,
                    logger: logger,
                    priority: priority,
                    writer: writer,
                    message: message
                )
            }
        case .ISON(let nicks):
            let message = IRCMessage(origin: origin, command: .ISON(nicks), tags: tags)
            try await sendAndFlushMessage(
                consumer,
                logger: logger,
                priority: priority,
                writer: writer,
                message: message
            )
        case .NOTICE(let recipients, let messageLines):
            let lines = messageLines.components(separatedBy: Constants.cLF.rawValue)
                .map { $0.replacingOccurrences(of: Constants.cCR.rawValue, with: Constants.space.rawValue) }
            for await line in lines.async {
                let message = IRCMessage(origin: origin, command: .NOTICE(recipients, line), tags: tags)
                try await sendAndFlushMessage(
                    consumer,
                    logger: logger,
                    priority: priority,
                    writer: writer,
                    message: message
                )
            }
        default:
            let message = IRCMessage(origin: origin, command: command, tags: tags)
            try await sendAndFlushMessage(
                consumer,
                logger: logger,
                priority: priority,
                writer: writer,
                message: message
            )
        }
    }
}

//MARK: Server Side
public protocol NeedleTailServerMessageDelegate: AnyObject, IRCDispatcher, NeedleTailWriterDelegate {}

extension NeedleTailServerMessageDelegate {
    
    
    public func sendAndFlushMessage(_
                                    consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                                    logger: NeedleTailLogger = NeedleTailLogger(.init(label: "[NeedleTailServerMessageDelegate]")),
                                    priority: Priority = .standard,
                                    writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                                    message: IRCMessage
    ) async throws {
        do {
            if #available(iOS 17.0, macOS 14, *) {
                try await withThrowingDiscardingTaskGroup { group in
                    let messageString = await NeedleTailIRCEncoder.encode(value: message)
                    //IRC only allows 512 characters per message so we need to create packets according to the spec size
                   let buffers = try await NeedleTailIRCEncoder.derivePacket(ircMessage: messageString)
                    for await buffer in buffers.async {
                        await consumer.feedConsumer(
                            buffer,
                            priority: priority
                        )
                    }
                    for try await result in NeedleTailAsyncSequence(consumer: consumer) {
                        switch result {
                        case .success(let buffer):
                            group.addTask {
                                do {
                                    try await writer.write(buffer)
                                    logger.log(level: .trace, message: "AsyncWriter Wrote Buffer")
                                } catch {
                                    logger.log(level: .error, message: "\(error)")
                                    return
                                }
                            }
                        case .consumed:
                            return
                        }
                    }
                }
            } else {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    let messageString = await NeedleTailIRCEncoder.encode(value: message)
                    //IRC only allows 512 characters per message so we need to create packets according to the spec size
                    let buffers = try await NeedleTailIRCEncoder.derivePacket(ircMessage: messageString)
                    for await buffer in buffers.async {
                        await consumer.feedConsumer(
                            buffer,
                            priority: priority
                        )
                    }
                    for try await result in NeedleTailAsyncSequence(consumer: consumer) {
                        switch result {
                        case .success(let buffer):
                            group.addTask {
                                do {
                                    try await writer.write(buffer)
                                    logger.log(level: .trace, message: "AsyncWriter Wrote Buffer")
                                } catch {
                                    logger.log(level: .error, message: "\(error)")
                                    return
                                }
                            }
                        case .consumed:
                            return
                        }
                    }
                }
            }
        } catch {
            throw error
        }
    }
    
    
    public func sendError(_
                          consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                          writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                          origin: String,
                          target: String,
                          code: IRCCommandCode,
                          message: String? = nil,
                          args: [String] = []
    ) async throws {
        let enrichedArgs = args + [ message ?? code.errorMessage ]
        let message = IRCMessage(origin: origin,
                                 target: target,
                                 command: .numeric(code, enrichedArgs),
                                 tags: nil)
        try await sendAndFlushMessage(
            consumer,
            writer: writer,
            message: message
        )
    }
    
    
    public func sendReply(_
                          consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                          writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                          origin: String,
                          target: String,
                          code: IRCCommandCode,
                          args: [String]
    ) async throws {
        let message = IRCMessage(origin: origin,
                                 target: target,
                                 command: .numeric(code, args),
                                 tags: nil)
        try await sendAndFlushMessage(
            consumer,
            writer: writer,
            message: message
        )
    }
    
    
    public func sendMotD(_
                         consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                         writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                         origin: String,
                         target: String,
                         message: String
    ) async throws {
        guard !message.isEmpty else { return }
        let origin = origin
        try await sendReply(
            consumer,
            writer: writer,
            origin: origin,
            target: target,
            code: .replyMotDStart,
            args: ["- Message of the Day -"]
        )
        
        let lines = message.components(separatedBy: Constants.cLF.rawValue)
            .map { $0.replacingOccurrences(of: Constants.cCR.rawValue, with: Constants.space.rawValue) }
            .map { Constants.minus.rawValue + Constants.space.rawValue + $0 }
        
        for line in lines {
            let message = IRCMessage(origin: origin,
                                     target: target,
                                     command: .numeric(.replyMotD, [line]),
                                     tags: nil)
            try await sendAndFlushMessage(
                consumer,
                writer: writer,
                message: message
            )
        }
        try await sendReply(
            consumer,
            writer: writer,
            origin: origin,
            target: target,
            code: .replyEndOfMotD,
            args: ["End of /MOTD command."]
        )
    }
}
