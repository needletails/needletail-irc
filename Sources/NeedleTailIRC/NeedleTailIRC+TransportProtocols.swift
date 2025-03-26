//
//  NeedleTailIRC+TransportProtocols.swift
//
//
//  Created by Cole M on 9/28/22.
//
import Foundation
import NIOCore
import Logging
import NeedleTailLogger
import NeedleTailAsyncSequence
import AsyncAlgorithms
import BSON

public protocol NeedleTailClientDelegate: AnyObject, Sendable, IRCEventProtocol, NeedleTailWriterDelegate {

    func transportMessage(_
                          consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                          logger: NeedleTailLogger,
                          writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                          origin: String,
                          command: IRCCommand,
                          tags: [IRCTag]?,
                          authPacket: AuthPacket?
    ) async throws
}

public protocol NeedleTailWriterDelegate: AnyObject, Sendable {
    func sendAndFlushMessage(_
                             consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                             logger: NeedleTailLogger,
                             writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                             message: IRCMessage
    ) async throws
}

extension NeedleTailWriterDelegate {
    
    public func sendAndFlushMessage(_
                                    consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                                    logger: NeedleTailLogger = NeedleTailLogger(.init(label: "[ com.needletails.writer.delegate ]")),
                                    writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                                    message: IRCMessage
    ) async throws {
            try await withThrowingDiscardingTaskGroup { group in
                group.addTask {
                    let messageString = await NeedleTailIRCEncoder.encode(value: message)
                    do {
                        try await writer.write(ByteBuffer(string: messageString))
                    } catch {
                       await logger.log(level: .error, message: "Send And Flush Error: \(error)")
                        throw error
                    }
                }
            }
    }
}

//MARK: Client Side
extension NeedleTailClientDelegate {
    
    public func transportMessage(_
                                 consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                                 logger: NeedleTailLogger = NeedleTailLogger(.init(label: "[ com.needletails.client.delegate ]")),
                                 writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                                 origin: String = "",
                                 command: IRCCommand,
                                 tags: [IRCTag]? = nil,
                                 authPacket: AuthPacket? = nil
    ) async throws {
        let messageGenerator = IRCMessageGenerator()
        let messageStream = await messageGenerator.createMessages(
            origin: origin,
            command: command,
            tags: tags,
            authPacket: authPacket,
            logger: logger)
        var packetsSent: Int = 0
        for try await message in messageStream {
            if command.commandAsString == Constants.multipartMediaUpload.rawValue {
                packetsSent += 1
            }
            let messageString = await NeedleTailIRCEncoder.encode(value: message)
            let bb = ByteBuffer(string: messageString)
            
            try await self.sendAndFlushMessage(
                consumer,
                logger: logger,
                writer: writer,
                message: message
            )
        }
    }
}

//MARK: Server Side
public protocol NeedleTailServerMessageDelegate: AnyObject, IRCEventProtocol, NeedleTailWriterDelegate {}

extension NeedleTailServerMessageDelegate {
    
    
    public func sendAndFlushMessage(_
                                    consumer: NeedleTailAsyncConsumer<ByteBuffer>,
                                    logger: NeedleTailLogger = NeedleTailLogger(.init(label: "[ com.needletails.server.delegate ]")),
                                    writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
                                    message: IRCMessage
    ) async throws {
        do {
            try await withThrowingDiscardingTaskGroup { group in
                group.addTask {
                    let messageString = await NeedleTailIRCEncoder.encode(value: message)
                    do {
                        try await writer.write(ByteBuffer(string: messageString))
                    } catch {
                       await logger.log(level: .error, message: "Send And Flush Error: \(error)")
                        throw error
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
        let enrichedArgs = args + [ message ?? code.formattedErrorMessage ]
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
