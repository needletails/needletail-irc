//
//  IRCTag.swift
//
//
//  Created by Cole M on 12/11/21.
//

import Foundation

/// Represents a tag used in the IRC protocol, consisting of a key-value pair.
/// This structure conforms to `Hashable`, `Codable`, and `Sendable`.
public struct IRCTag: Hashable, Codable, Sendable {
    
    /// The type of string literal used for the key.
    public typealias StringLiteralType = String
    
    /// The key of the tag.
    public let key: String
    
    /// The value associated with the key.
    public let value: String
    
    /// Initializes a new tag with a specified key and value.
    /// - Parameters:
    ///   - key: The key of the tag.
    ///   - value: The value associated with the key.
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
    
    /// Returns the key of the tag as a string representation.
    public var stringValue: String {
        return key
    }
    
    /// Computes a hash value for the tag based on its key.
    /// - Parameter hasher: The hasher to use for combining the key's hash.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    /// Compares two `IRCTag` instances for equality.
    /// - Parameters:
    ///   - lhs: The left-hand side tag.
    ///   - rhs: The right-hand side tag.
    /// - Returns: A Boolean value indicating whether the two tags are equal.
    public static func ==(lhs: IRCTag, rhs: IRCTag) -> Bool {
        return lhs.key == rhs.key
    }
    
    /// Validates the given string for compliance with IRC tag standards.
    /// The string must be less than 4096 characters in length.
    /// - Parameter string: The string to validate.
    /// - Returns: A Boolean value indicating whether the string is valid.
    public static func validate(string: String) -> Bool {
        return string.count < 4096
    }
}
