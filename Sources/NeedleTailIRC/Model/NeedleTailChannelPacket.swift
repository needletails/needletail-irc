//
//  NeedleTailChannelPacket.swift
//
//
//  Created by Cole M on 6/18/22.
//

import Foundation
import CypherProtocol

public struct NeedleTailChannelPacket: Codable, Sendable {
    public let _id = UUID().uuidString.uppercased()
    public let name: IRCChannelName
    public let channelOperator: Username
    public let organizers: Set<Username>
    public let members: Set<Username>
    public let permissions: IRCChannelMode
    public let destroyChannel: Bool
    public let blobId: String?
    
    public init(
        name: IRCChannelName,
        channelOperator: Username,
        organizers: Set<Username>,
        members: Set<Username>,
        permissions: IRCChannelMode,
        destroyChannel: Bool = false,
        blobId: String? = nil
    ) {
        self.name = name
        self.channelOperator = channelOperator
        self.organizers = organizers
        self.members = members
        self.permissions = permissions
        self.destroyChannel = destroyChannel
        self.blobId = blobId
    }
}


public struct PartMessage: Codable, Sendable {
    public let _id = UUID().uuidString.uppercased()
    public var message: String
    
    public init(message: String) {
        self.message = message
    }
}
