//
//  Call.swift
//  
//
//  Created by Cole M on 4/8/24.
//

import Foundation

public struct Call: Sendable, Codable {
    
    public struct Props: Sendable, Codable {
        public var id: UUID
        public var data: Data
        public init(id: UUID, data: Data) {
            self.id = id
            self.data = data
        }
    }
    
    
    public var id: UUID
    public var sender: NeedleTailNick
    public var recipients: [NeedleTailNick]
    public var createdAt: Date
    public var updatedAt: Date?
    public var endedAt: Date?
    public var supportsVideo: Bool
    public var rejected: Bool?
    public var missed: Bool?
    public var isActive: Bool
    public var isOutbound: Bool
     
    public init(id: UUID, sender: NeedleTailNick, recipients: [NeedleTailNick], createdAt: Date, updatedAt: Date? = nil, endedAt: Date? = nil, supportsVideo: Bool, rejected: Bool? = nil, missed: Bool? = nil, isActive: Bool, isOutbound: Bool) {
        self.id = id
        self.sender = sender
        self.recipients = recipients
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.endedAt = endedAt
        self.supportsVideo = supportsVideo
        self.rejected = rejected
        self.missed = missed
        self.isActive = isActive
        self.isOutbound = isOutbound
    }
}
