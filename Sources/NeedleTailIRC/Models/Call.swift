//
//  Call.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
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
    public var sender: String
    public var recipients: [String]
    public var createdAt: Date
    public var updatedAt: Date?
    public var endedAt: Date?
    public var supportsVideo: Bool
    public var missed: Bool?
    public var unanswered: Bool?
    public var rejected: Bool?
    public var failed: Bool?
    public var isActive: Bool
    public var isOutbound: Bool
     
    public init(
        id: UUID,
        sender: String,
        recipients: [String],
        createdAt: Date,
        updatedAt: Date? = nil,
        endedAt: Date? = nil,
        supportsVideo: Bool,
        missed: Bool? = nil,
        unanswered: Bool? = nil,
        rejected: Bool? = nil,
        failed: Bool? = nil,
        isActive: Bool,
        isOutbound: Bool
    ) {
        self.id = id
        self.sender = sender
        self.recipients = recipients
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.endedAt = endedAt
        self.supportsVideo = supportsVideo
        self.missed = missed
        self.unanswered = unanswered
        self.rejected = rejected
        self.failed = failed
        self.isActive = isActive
        self.isOutbound = isOutbound
    }
}
public enum NewDeviceState: Equatable, Codable, Sendable {
    case accepted, rejected, waiting, isOffline
}
