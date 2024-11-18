//
//  ChannelBlob.swift
//
//
//  Created by Cole M on 7/2/22.
//
import Foundation

/// A generic structure representing a channel blob, which includes metadata and the associated data blob.
///
/// - Parameters:
///   - C: The type of the data blob, which must conform to Codable and Sendable.
public struct IRCChannelBlob<C: Codable & Sendable>: Codable, Sendable {
    
    /// A unique identifier for the channel blob, generated as a UUID string in uppercase.
    public var id: String = UUID().uuidString.uppercased()
    
    /// Metadata associated with the channel, represented by a `NeedleTailChannelPacket`.
    public var metadata: NeedleTailChannelPacket
    
    /// The data blob of type `C` associated with the channel.
    public var blob: C
    
    /// Initializes a new ChannelBlob instance with the provided metadata and blob.
    /// - Parameters:
    ///   - metadata: The metadata for the channel.
    ///   - blob: The data blob associated with the channel.
    public init(
        metadata: NeedleTailChannelPacket,
        blob: C
    ) {
        self.metadata = metadata
        self.blob = blob
    }
}
