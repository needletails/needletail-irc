//
//  IRCMessageRecipient.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/22.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import Foundation

/// Represents a recipient of an IRC message payload, which can be a channel, a nickname, or a wildcard for all recipients.
public enum IRCMessageRecipient: Codable, Hashable, Sendable {
    case channel(NeedleTailChannel)
    case nick(NeedleTailNick)
    case all // Represents all recipients (wildcard)
    /// Any other RFC 2812 §3.3.1 target, written as sent: a server mask (`$*.example.net`) or a
    /// user address (`nick!user@host`, `user%host@servername`, `user%host`, `user@servername`).
    case mask(String)
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .channel(let name):
            hasher.combine(name)
        case .nick(let name):
            hasher.combine(name)
        case .all:
            hasher.combine(0) // Using 0 as a fixed value for the all case
        case .mask(let mask):
            hasher.combine(mask)
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
        case (.mask(let lhsMask), .mask(let rhsMask)):
            return lhsMask == rhsMask
        default:
            return false
        }
    }
}

public extension IRCMessageRecipient {
    /// Initializes an `IRCMessageRecipient` from a string.
    /// - Parameter string: The string representation of the recipient.
    /// - Returns: An optional `IRCMessageRecipient`. Returns `nil` if parsing fails.
    init?(_ string: String) {
        if string == Constants.star.rawValue {
            self = .all
        } else if let channel = string.constructedChannel {
            self = .channel(channel)
        } else if let nick = IRCMessageRecipient.createNick(from: string) {
            self = .nick(nick)
        } else if IRCMessageRecipient.isMask(string) {
            self = .mask(string)
        } else {
            return nil
        }
    }
    
    /// RFC 2812 §3.3.1: `"$" mask`, `nickname "!" user "@" host`, `user [ "%" host ] "@" servername`
    /// or `user "%" host`. Each part is non-empty, and none holds a space, comma, NUL, CR or LF.
    static func isMask(_ string: String) -> Bool {
        guard !string.isEmpty,
              !string.unicodeScalars.contains(where: { $0 == " " || $0 == "," || $0 == "\0" || $0 == "\r" || $0 == "\n" }) else {
            return false
        }
        if string.hasPrefix("$") {
            return string.count > 1
        }
        func split(_ value: Substring, at separator: Character) -> (Substring, Substring)? {
            guard let index = value.firstIndex(of: separator) else { return nil }
            let head = value[..<index], tail = value[value.index(after: index)...]
            return head.isEmpty || tail.isEmpty ? nil : (head, tail)
        }
        let value = Substring(string)
        if value.contains("!") {
            // nickname "!" user "@" host
            guard let (nick, address) = split(value, at: "!"), NeedleTailNick(wireValue: String(nick)) != nil,
                  let (user, _) = split(address, at: "@") else { return false }
            return !user.contains("!")
        }
        if value.contains("@") {
            // user [ "%" host ] "@" servername
            guard let (userAndHost, _) = split(value, at: "@") else { return false }
            return !userAndHost.contains("%") || split(userAndHost, at: "%") != nil
        }
        // user "%" host
        return split(value, at: "%") != nil
    }
    
    /// Creates a `NeedleTailNick` from a string.
    /// - Parameter string: The string representation of the nick.
    /// - Returns: An optional `NeedleTailNick`. Returns `nil` if parsing fails.
    private static func createNick(from string: String) -> NeedleTailNick? {
        NeedleTailNick(wireValue: string)
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
        case .mask(let mask):
            return mask
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
        case .mask(let mask):
            return "Mask: \(mask)"
        }
    }
}
