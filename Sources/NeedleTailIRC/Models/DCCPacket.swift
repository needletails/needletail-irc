//
//  DCCPacket.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/24.
//

public struct DCCPacket: Sendable {
    public let initialParameter: String
    public let address: String
    public let port: Int
    public let offsetBytes: Int?
    
    public init(initialParameter: String, address: String, port: Int, offsetBytes: Int? = nil) {
        self.initialParameter = initialParameter
        self.address = address
        self.port = port
        self.offsetBytes = offsetBytes
    }
}
