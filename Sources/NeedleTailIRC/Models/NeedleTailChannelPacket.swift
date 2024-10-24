//
//  NeedleTailChannelPacket.swift
//
//
//  Created by Cole M on 6/18/22.
//

import Foundation

/// A structure representing metadata for a channel in the NeedleTail system.
///
/// - Parameters:
///   - name: The name of the channel, represented as an `IRCChannelIdentifier`.
///   - channelOperatorAdmin: The identifier of the channel operator admin.
///   - channelOperators: A set of identifiers for channel operators.
///   - members: A set of identifiers for channel members.
///   - permissions: The permissions associated with the channel, represented by `IRCChannelPermissions`.
///   - destroyChannel: A Boolean flag indicating if the channel should be destroyed.
///   - blobId: An optional identifier for a related blob.
public struct NeedleTailChannelPacket: Codable, Sendable {
    
    /// A unique identifier for the channel packet, generated as a UUID string in uppercase.
    public var id = UUID().uuidString.uppercased()
    
    /// The name of the channel.
    public let name: NeedleTailChannel
    
    /// The identifier of the channel operator admin.
    public let channelOperatorAdmin: String
    
    /// A set of identifiers for the channel operators.
    public let channelOperators: Set<String>
    
    /// A set of identifiers for the members of the channel.
    public let members: Set<String>
    
    /// The permissions associated with the channel.
    public let permissions: IRCChannelPermissions
    
    /// A Boolean flag indicating whether the channel should be destroyed.
    public let destroyChannel: Bool
    
    /// An optional identifier for a related blob.
    public let blobId: String?
    
    /// Initializes a new `NeedleTailChannelPacket` instance with the provided parameters.
    /// - Parameters:
    ///   - name: The name of the channel.
    ///   - channelOperatorAdmin: The identifier of the channel operator admin.
    ///   - channelOperators: A set of identifiers for the channel operators.
    ///   - members: A set of identifiers for the members.
    ///   - permissions: The permissions associated with the channel.
    ///   - destroyChannel: A Boolean flag indicating if the channel should be destroyed (defaults to false).
    ///   - blobId: An optional identifier for a related blob (defaults to nil).
    public init(
        name: NeedleTailChannel,
        channelOperatorAdmin: String,
        channelOperators: Set<String>,
        members: Set<String>,
        permissions: IRCChannelPermissions,
        destroyChannel: Bool = false,
        blobId: String? = nil
    ) {
        self.name = name
        self.channelOperatorAdmin = channelOperatorAdmin
        self.channelOperators = channelOperators
        self.members = members
        self.permissions = permissions
        self.destroyChannel = destroyChannel
        self.blobId = blobId
    }
}

/// A structure representing a part message in the NeedleTail system.
///
/// - Parameters:
///   - message: The content of the part message.
///   - destroyChannel: A Boolean flag indicating if the channel should be destroyed.
///   - blobId: An optional identifier for a related blob.
public struct PartMessage: Codable, Sendable {
    
    /// A unique identifier for the part message, generated as a UUID string in uppercase.
    public var id = UUID().uuidString.uppercased()
    
    /// The content of the part message.
    public var message: String
    
    /// A Boolean flag indicating whether the channel should be destroyed.
    public let destroyChannel: Bool
    
    /// An optional identifier for a related blob.
    public let blobId: String?
    
    /// Initializes a new `PartMessage` instance with the provided parameters.
    /// - Parameters:
    ///   - message: The content of the part message.
    ///   - destroyChannel: A Boolean flag indicating if the channel should be destroyed.
    ///   - blobId: An optional identifier for a related blob.
    public init(
        message: String,
        destroyChannel: Bool,
        blobId: String? = nil
    ) {
        self.message = message
        self.destroyChannel = destroyChannel
        self.blobId = blobId
    }
}

