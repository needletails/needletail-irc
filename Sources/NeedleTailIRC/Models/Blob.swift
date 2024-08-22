//
//  ChannelBlob.swift
//
//
//  Created by Cole M on 7/2/22.
//
import Foundation
import CypherProtocol

public struct ChannelBlob<C: Codable & Sendable>: Codable, Sendable {
    public let _id: String = UUID().uuidString.uppercased()
    public var metadata: NeedleTailChannelPacket
    public var blob: C
    
    public init(
        metadata: NeedleTailChannelPacket,
        blob: C
    ) {
        self.metadata = metadata
        self.blob = blob
    }
}
