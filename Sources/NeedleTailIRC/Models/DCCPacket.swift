//
//  DCCPacket.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import struct NIOCore.NIOAsyncChannelOutboundWriter
import struct NIOCore.NIOAsyncChannel
import struct NIOCore.ByteBuffer
import struct Foundation.Data

public enum DirectMessage: Codable, Sendable {
    case serviceName(String), message(MultipartPacket), multipart(MultipartPacket), blob(Data), close
    
    public func encode(into buffer: inout ByteBuffer) throws {
           switch self {
           case .serviceName(let name):
               buffer.writeInteger(UInt8(0))
               buffer.writeString(name)

           case .message(let packet):
               buffer.writeInteger(UInt8(1))
               try packet.encode(into: &buffer)

           case .multipart(let packet):
               buffer.writeInteger(UInt8(2))
               try packet.encode(into: &buffer)

           case .blob(let data):
               buffer.writeInteger(UInt8(3))
               buffer.writeInteger(UInt32(data.count))
               buffer.writeBytes(data)

           case .close:
               buffer.writeInteger(UInt8(4))
           }
       }
    
    static func decode(from buffer: inout ByteBuffer) throws -> DirectMessage {
            guard let type = buffer.readInteger(as: UInt8.self) else {
                throw NIODecodeError("Missing enum discriminator")
            }

            switch type {
            case 0:
                guard let name = buffer.readString(length: buffer.readableBytes) else {
                    throw NIODecodeError("Missing serviceName string")
                }
                return .serviceName(name)

            case 1:
                return .message(try MultipartPacket.decode(from: &buffer))

            case 2:
                return .multipart(try MultipartPacket.decode(from: &buffer))

            case 3:
                guard let length = buffer.readInteger(as: UInt32.self),
                      let data = buffer.readBytes(length: Int(length)) else {
                    throw NIODecodeError("Invalid blob data")
                }
                return .blob(Data(data))

            case 4:
                return .close

            default:
                throw NIODecodeError("Unknown enum discriminator: \(type)")
            }
        }
}

public enum DCCState: String, Sendable, Codable {
    case none, requested, accepted, connecting, connected, disconnected
}

public struct DCCMetadata: Sendable {
    public let recipient: NeedleTailNick
    public let filename: String?
    public let filesize: Int?
    public let address: String
    public let port: Int
    public let offsetBytes: Int?
    
    public init(
        recipient: NeedleTailNick,
        filename: String? = nil,
        filesize: Int? = nil,
        address: String,
        port: Int,
        offsetBytes: Int? = nil
    ) {
        self.recipient = recipient
        self.filename = filename
        self.filesize = filesize
        self.address = address
        self.port = port
        self.offsetBytes = offsetBytes
    }
}

public struct DCCChannelContext: Sendable {
    public let id: String
    public let channel: NIOAsyncChannel<IRCPayload, IRCPayload>
    public let writer: NIOAsyncChannelOutboundWriter<IRCPayload>
    
    public init(
        id: String,
        channel: NIOAsyncChannel<IRCPayload, IRCPayload>,
        writer: NIOAsyncChannelOutboundWriter<IRCPayload>
    ) {
        self.id = id
        self.channel = channel
        self.writer = writer
    }
}

public enum DCCType: Sendable {
    case chat, file(String, Int)
}
