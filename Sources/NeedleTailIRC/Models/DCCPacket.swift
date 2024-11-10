//
//  DCCPacket.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/24.
//

public struct DCCPacket: Sendable {
    public let nickname: NeedleTailNick
    public let filename: String?
    public let filesize: Int?
    public let address: String
    public let port: Int
    public let offsetBytes: Int?
    
    public init(nickname: NeedleTailNick, filename: String? = nil, filesize: Int? = nil, address: String, port: Int, offsetBytes: Int? = nil) {
        self.nickname = nickname
        self.filename = filename
        self.filesize = filesize
        self.address = address
        self.port = port
        self.offsetBytes = offsetBytes
    }
}
