//
//  IRCServerIdentifier.swift
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

/// Represents a server identifier in the IRC protocol, ensuring it adheres to RFC 2812 compliance.
/// Conforms to `Hashable` for use in collections like sets and dictionaries.
public struct IRCServerIdentifier: Hashable, Sendable {
  
    /// The underlying string representation of the server name.
    private let original: String
    
    /// The canonical form of the server name, typically in lowercase.
    private let canonical: String
    
    /// Initializes a new server identifier from a given string.
    /// - Parameter s: The server name string to be validated and stored.
    /// - Returns: An optional `IRCServerIdentifier`. Returns `nil` if validation fails.
    public init?(_ s: String) {
        guard IRCServerIdentifier.validate(string: s) else {
            return nil
        }
        self.original = s
        self.canonical = s.lowercased()
    }
    
    /// Returns the original server name as a string.
    public var stringValue: String {
        return original
    }
    
    /// Hashes the canonical server name for use in hashing collections.
    /// - Parameter hasher: The hasher to combine the canonical server name.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(canonical)
    }
    
    /// Compares two `IRCServerIdentifier` instances for equality.
    /// - Parameters:
    ///   - lhs: The left-hand side server identifier.
    ///   - rhs: The right-hand side server identifier.
    /// - Returns: A Boolean value indicating whether the two identifiers are equal.
    public static func ==(lhs: IRCServerIdentifier, rhs: IRCServerIdentifier) -> Bool {
        return lhs.canonical == rhs.canonical
    }
    
    /// Validates the given server name against IRC standards as specified in RFC 2812.
    /// - Parameter string: The server name to validate.
    /// - Returns: A Boolean value indicating whether the server name is valid.
    public static func validate(string: String) -> Bool {
        let length = string.count
        
        // Check length constraints early to avoid further checks
        guard length > 1 && length <= 63 else {
            return false
        }

        // Ensure the server name consists of valid characters
        let validCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        
        // Use a single check for valid characters
        if string.rangeOfCharacter(from: validCharacters.inverted) != nil {
            return false
        }

        // Ensure the server name does not start or end with a dot or hyphen
        guard !string.hasPrefix(".") && !string.hasSuffix(".") &&
              !string.hasPrefix("-") && !string.hasSuffix("-") else {
            return false
        }

        // Ensure there are no consecutive dots
        // Check for ".." in one pass using a loop
        for i in 1..<length {
            if string[string.index(string.startIndex, offsetBy: i - 1)] == "." &&
               string[string.index(string.startIndex, offsetBy: i)] == "." {
                return false
            }
        }

        return true
    }
}
