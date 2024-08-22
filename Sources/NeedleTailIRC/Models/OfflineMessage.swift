//
//  ChatDocument.swift
//  
//
//  Created by Cole M on 3/31/22.
//

import Foundation
import NeedleTailStructures

public struct OfflineMessage: Codable, Sendable {
    public let id: String
    public let createdAt: Date
    public let sender: IRCUserID
    public var recipients: [IRCMessageRecipient]
    public let messagePacket: MessagePacket
    public var sent: Bool

    public init(
        id: String,
        sender: IRCUserID,
        recipients: [IRCMessageRecipient],
        messagePacket: MessagePacket,
        sent: Bool
    ) {
        self.id = id
        self.createdAt = Date()
        self.sender = sender
        self.recipients = recipients
        self.messagePacket = messagePacket
        self.sent = sent
    }
}
