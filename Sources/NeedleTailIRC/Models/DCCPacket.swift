//
//  DCCPacket.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/24.
//
import NIOCore

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
    public let channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>
    public let writer: NIOAsyncChannelOutboundWriter<ByteBuffer>
    
    public init(
        id: String,
        channel: NIOAsyncChannel<ByteBuffer, ByteBuffer>,
        writer: NIOAsyncChannelOutboundWriter<ByteBuffer>
    ) {
        self.id = id
        self.channel = channel
        self.writer = writer
    }
}

public enum DCCType: Sendable {
    case chat, file(String, Int)
}
