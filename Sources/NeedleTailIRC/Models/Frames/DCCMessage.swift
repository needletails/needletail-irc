//
//  DCCMessage.swift
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

/// A frame on a peer-to-peer DCC socket.
///
/// Wire layout: one discriminator byte (`0...4`) followed by a case-specific body.
/// Every variable-length field (`serviceName`, multipart strings, `blob`) is `UInt32`
/// length-prefixed, so each frame is self-delimiting, and is bounded against the decoder's
/// `maxFrameLength` before allocation.
public enum DCCMessage: Codable, Sendable, IRCWireEncodable {
    case serviceName(String), message(MultipartPacket), multipart(MultipartPacket), blob(Data), close

    /// Payload-free summary safe for logs.
    public var description: String {
        switch self {
        case .serviceName(let name): return "<DCCMessage serviceName=\(name)>"
        case .message(let packet): return "<DCCMessage message group=\(packet.groupId) part=\(packet.partNumber)/\(packet.totalParts)>"
        case .multipart(let packet): return "<DCCMessage multipart group=\(packet.groupId) part=\(packet.partNumber)/\(packet.totalParts)>"
        case .blob(let data): return "<DCCMessage blob bytes=\(data.count)>"
        case .close: return "<DCCMessage close>"
        }
    }
    
    public func encode(into buffer: inout ByteBuffer) throws {
           switch self {
           case .serviceName(let name):
               buffer.writeInteger(UInt8(0))
               try buffer.writeLengthPrefixedUTF8(name)

           case .message(let packet):
               buffer.writeInteger(UInt8(1))
               try packet.encode(into: &buffer)

           case .multipart(let packet):
               buffer.writeInteger(UInt8(2))
               try packet.encode(into: &buffer)

           case .blob(let data):
               guard data.count <= Int(UInt32.max) else {
                   throw NIODecodeError.malformed("Blob is too large to encode")
               }
               buffer.writeInteger(UInt8(3))
               buffer.writeInteger(UInt32(data.count))
               buffer.writeBytes(data)

           case .close:
               buffer.writeInteger(UInt8(4))
           }
       }
    
    static func decode(
        from buffer: inout ByteBuffer,
        maxFrameLength: Int
    ) throws -> DCCMessage {
            guard let type = buffer.readInteger(as: UInt8.self) else {
                throw NIODecodeError.incomplete("Missing enum discriminator")
            }

            switch type {
            case 0:
                // Length-prefixed so the name is self-delimiting. It is the first frame on a
                // peer connection and may share a read with the next frame or arrive fragmented.
                return .serviceName(
                    try buffer.readLengthPrefixedUTF8(
                        field: "serviceName",
                        maxLength: maxFrameLength
                    )
                )

            case 1:
                return .message(
                    try MultipartPacket.decode(
                        from: &buffer,
                        maxFieldLength: maxFrameLength
                    )
                )

            case 2:
                return .multipart(
                    try MultipartPacket.decode(
                        from: &buffer,
                        maxFieldLength: maxFrameLength
                    )
                )

            case 3:
                guard let length = buffer.readInteger(as: UInt32.self) else {
                    throw NIODecodeError.incomplete("Missing blob length")
                }
                guard Int(length) <= maxFrameLength else {
                    throw NIODecodeError.malformed("Blob exceeds configured limit")
                }
                guard let data = buffer.readBytes(length: Int(length)) else {
                    throw NIODecodeError.incomplete("Incomplete blob data")
                }
                return .blob(Data(data))

            case 4:
                return .close

            default:
                throw NIODecodeError.malformed("Unknown enum discriminator: \(type)")
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

/// A peer DCC socket. Carries whole ``IRCFrame`` values because a DCC connection speaks
/// both text lines (handshake) and ``DCCMessage`` frames (transfer).
public struct DCCChannelContext: Sendable {
    public let id: String
    public let channel: NIOAsyncChannel<IRCFrame, IRCFrame>
    public let writer: NIOAsyncChannelOutboundWriter<IRCFrame>
    
    public init(
        id: String,
        channel: NIOAsyncChannel<IRCFrame, IRCFrame>,
        writer: NIOAsyncChannelOutboundWriter<IRCFrame>
    ) {
        self.id = id
        self.channel = channel
        self.writer = writer
    }
}

public enum DCCType: Sendable {
    case chat, file(String, Int)
}
