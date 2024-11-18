//
//  IRCUserIdentifier.swift
//
//
//  Created by Cole M on 9/28/22.
//
import Foundation
import NeedleTailStructures

/// Represents an identifier for a user in the IRC (Internet Relay Chat) protocol.
/// It includes the user's nickname, optional username, and host information.
public struct IRCUserIdentifier: Codable, Hashable, CustomStringConvertible, Sendable {
    
    /// The nickname of the IRC user.
    public let nick: NeedleTailNick
    /// The optional username of the IRC user.
    public let user: String?
    /// The optional hostname of the IRC user.
    public let host: String?
    
    /// Initializes a new instance with a nickname, optional username, and hostname.
    /// - Parameters:
    ///   - nick: The nickname of the IRC user.
    ///   - user: The optional username of the user.
    ///   - host: The optional hostname of the user.
    public init(nick: NeedleTailNick, user: String? = nil, host: String? = nil) {
        self.nick = nick
        self.user = user
        self.host = host
    }
    
    /// Initializes a new instance from a string representation of the user ID.
    /// - Parameters:
    ///   - s: The string representation (e.g., "nick!user@host").
    ///   - deviceId: An optional UUID representing the device.
    public init?(_ s: String, deviceId: UUID? = nil) {
        let atIndex = s.firstIndex(of: Character(Constants.atString.rawValue))
        let exIndex = s.firstIndex(of: Character(Constants.exclamation.rawValue))
        
        // Extract host if it exists
        if let atIdx = atIndex {
            self.host = String(s[s.index(after: atIdx)...])
            
            // Extract user if it exists
            if let exIdx = exIndex, exIdx < atIdx {
                self.user = String(s[s.index(after: exIdx)..<atIdx])
                guard let nick = NeedleTailNick(name: String(s[..<exIdx]), deviceId: deviceId) else { return nil }
                self.nick = nick
            } else {
                self.user = nil
                guard let nick = NeedleTailNick(name: String(s[..<atIdx]), deviceId: deviceId) else { return nil }
                self.nick = nick
            }
        } else {
            // No host, assume the whole string is a nickname
            self.user = nil
            self.host = nil
            guard let nick = NeedleTailNick(name: s, deviceId: deviceId) else { return nil }
            self.nick = nick
        }
    }
    
    /// Hashable conformance to compute a hash value.
    public func hash(into hasher: inout Hasher) {
        nick.hash(into: &hasher)
    }
    
    /// Equatable conformance to compare two `IRCUserIdentifier` instances.
    public static func ==(lhs: IRCUserIdentifier, rhs: IRCUserIdentifier) -> Bool {
        return lhs.nick == rhs.nick && lhs.user == rhs.user && lhs.host == rhs.host
    }
    
    /// Returns a string representation of the user ID.
    public var stringValue: String {
        var ms = "\(nick)"
        if let host = host {
            if let user = user { ms += "\(Constants.exclamation)\(user)" }
            ms += "\(Constants.atString)\(host)"
        }
        return ms
    }
    
    /// A textual representation of the `IRCUserIdentifier`.
    public var description: String { return stringValue }
}
