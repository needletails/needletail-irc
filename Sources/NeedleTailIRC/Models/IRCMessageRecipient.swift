//
//  IRCMessageRecipient.swift
//
//
//  Created by Cole M on 9/28/22.
//

import Foundation
import NeedleTailStructures

/// Represents a recipient of an IRC message payload, which can be a channel, a nickname, or a wildcard for all recipients.
public enum IRCMessageRecipient: Codable, Hashable, Sendable {
    case channel(NeedleTailChannel)
    case nick(NeedleTailNick)
    case all // Represents all recipients (wildcard)
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .channel(let name):
            hasher.combine(name)
        case .nick(let name):
            hasher.combine(name)
        case .all:
            hasher.combine(0) // Using 0 as a fixed value for the all case
        }
    }
    
    public static func ==(lhs: IRCMessageRecipient, rhs: IRCMessageRecipient) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all):
            return true
        case (.channel(let lhsName), .channel(let rhsName)):
            return lhsName == rhsName
        case (.nick(let lhsName), .nick(let rhsName)):
            return lhsName == rhsName
        default:
            return false
        }
    }
}

public extension IRCMessageRecipient {
    /// Initializes an `IRCPayloadRecipient` from a string.
    /// - Parameter s: The string representation of the recipient.
    /// - Returns: An optional `IRCPayloadRecipient`. Returns `nil` if parsing fails.
    init?(_ string: String) {
        if string == Constants.star.rawValue {
            self = .all
        } else if let channel = string.ircChanneled {
            self = .channel(channel)
        } else if let nick = IRCMessageRecipient.createNick(from: string) {
            self = .nick(nick)
        } else {
            return nil
        }
    }
    
    /// Creates a `NeedleTailNick` from a string.
    /// - Parameter string: The string representation of the nick.
    /// - Returns: An optional `NeedleTailNick`. Returns `nil` if parsing fails.
    private static func createNick(from string: String) -> NeedleTailNick? {
        guard let underscoreIndex = string.firstIndex(of: Constants.underScore.rawValue.first!) else {
            return nil
        }
        
        let name = String(string[..<underscoreIndex])
        let deviceIdSubstring = string[string.index(after: underscoreIndex)...]
        
        guard let deviceId = UUID(uuidString: String(deviceIdSubstring)) else {
            return nil
        }
        
        return NeedleTailNick(name: name, deviceId: deviceId)
    }
    
    
    /// Returns a string representation of the recipient.
    var stringValue: String {
        switch self {
        case .channel(let name):
            return name.stringValue
        case .nick(let name):
            return name.stringValue
        case .all:
            return Constants.star.rawValue
        }
    }
}

extension IRCMessageRecipient: CustomStringConvertible {
    public var description: String {
        switch self {
        case .channel(let name):
            return "Channel: \(name.description)"
        case .nick(let name):
            return "Nickname: \(name.description)"
        case .all:
            return "All: \(Constants.star.rawValue)"
        }
    }
}
