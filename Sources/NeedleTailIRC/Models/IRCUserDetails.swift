//
//  IRCUserDetails.swift
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

/// Represents detailed information about a user in the IRC (Internet Relay Chat) protocol.
/// According to RFC 1459 and RFC 2812, it includes the username,
/// optional user modes, hostname, server name, and real name.
public struct IRCUserDetails: Codable, Sendable, Equatable {
    
    /// The username of the IRC user.
    public var username: String
    /// The user mode flags associated with the user, if applicable.
    public let userModeFlags: IRCUserModeFlags?
    /// The hostname of the user, if available.
    public let hostname: String?
    /// The server name the user is connected to, if available.
    public let servername: String?
    /// The real name of the user, which may be a descriptive string.
    public let realname: String
    
    public var userMask: String {
          return "\(username)!\(username)@\(hostname ?? "unknown")"
      }
    
    /// Initializes a new instance with a username and optional user mode.
    /// - Parameters:
    ///   - username: The username of the IRC user.
    ///   - userModeFlags: The user mode flags for the user (optional).
    ///   - realname: The real name of the user.
    public init(
        username: String,
        userModeFlags: IRCUserModeFlags? = nil,
        realname: String
    ) {
        self.username = username
        self.userModeFlags = userModeFlags
        self.realname = realname
        self.hostname = "localhost"
        self.servername = "localhost"
    }
    
    /// Initializes a new instance with a username, hostname, server name, and real name.
    /// - Parameters:
    ///   - username: The username of the IRC user.
    ///   - hostname: The hostname of the user.
    ///   - servername: The server name the user is connected to.
    ///   - realname: The real name of the user.
    public init(
        username: String,
        hostname: String,
        servername: String,
        realname: String
    ) {
        self.username = username
        self.hostname = hostname
        self.servername = servername
        self.realname = realname
        self.userModeFlags = nil
    }
    
    /// Equatable conformance to compare two `IRCUserDetails` instances.
    public static func ==(lhs: IRCUserDetails, rhs: IRCUserDetails) -> Bool {
        return lhs.username == rhs.username &&
               lhs.realname == rhs.realname &&
               lhs.userModeFlags == rhs.userModeFlags &&
               lhs.servername == rhs.servername &&
               lhs.hostname == rhs.hostname
    }
}

extension IRCUserDetails: CustomStringConvertible {
    
    /// A textual representation of the `IRCUserDetails`, formatted for logging.
    public var description: String {
        var components = [
            "Username: \(username)",
            "Real Name: '\(realname)'"
        ]
        
        if let mode = userModeFlags {
            components.append("User Mode: \(mode)")
        }
        if let host = hostname {
            components.append("Hostname: \(host)")
        }
        if let server = servername {
            components.append("Server Name: \(server)")
        }
        
        return components.joined(separator: "\n")
    }
}
