//
//  IRCChannelIdentifier.swift
//
//
//  Created by Cole M on 9/23/22.
//

import Foundation

/// A representation of an IRC channel name that is thread-safe and conforms to Codable,
/// Hashable, and CustomStringConvertible protocols. This class uses a lock to protect
/// mutable state, making it Sendable for concurrent use.
///
/// - Important: The channel name must be valid as per IRC specifications and is stored
///   in both its original and normalized forms.
public final class NeedleTailChannel: Codable, Hashable, CustomStringConvertible, Sendable {
    
    public typealias StringLiteralType = String
    
    private let original: String
    private let canonical: String
    
    /// Initializes a new IRCChannelIdentifier instance if the provided string is valid.
    /// - Parameter s: The string representation of the channel name.
    /// - Returns: An optional IRCChannelIdentifier instance; returns nil if validation fails.
    public init?(_ s: String) {
        guard Self.validate(string: s) else { return nil }
        original = s
        canonical = s.ircLowercased
    }
    
    /// The string value of the channel name.
    public var stringValue: String {
        original
    }
    
    /// Computes a hash value based on the normalized channel name.
    public func hash(into hasher: inout Hasher) {
        canonical.hash(into: &hasher)
    }
    
    /// Compares two IRCChannelIdentifier instances for equality based on their normalized values.
    public static func ==(lhs: NeedleTailChannel, rhs: NeedleTailChannel) -> Bool {
        return lhs.canonical == rhs.canonical
    }
    
    /// A textual description of the IRCChannelIdentifier instance.
    public var description: String {
        stringValue
    }
    
    /// Validates the given string as a potential IRC channel name.
    /// - Parameter string: The string to validate.
    /// - Returns: A Boolean indicating whether the string is a valid IRC channel name.
    public static func validate(string: String) -> Bool {
        guard string.count > 1 && string.count <= 50 else {
            return false
        }
        
        // Validate the first character of the channel name
        guard let firstChar = string.first, "#&+!".contains(firstChar) else {
            return false
        }
        
        // Check for valid characters (excluding certain ASCII control characters)
        return !string.utf8.contains(where: { !isValidCharacter($0) })
    }
    
    private static func isValidCharacter(_ c: UInt8) -> Bool {
        return c != 7 && c != 32 && c != 44 // Excludes BEL, SPACE, and COMMA
    }
    
    // MARK: - Codable Conformance
    enum CodingKeys: String, CodingKey, Sendable {
        case original = "a"
        case canonical = "b"
    }
    
    /// Decodes an IRCChannelIdentifier from the given decoder.
    public init(from decoder: Decoder) async throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.original = try container.decode(String.self, forKey: .original)
        self.canonical = try container.decode(String.self, forKey: .canonical)
    }
    
    /// Encodes the IRCChannelIdentifier to the given encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(original, forKey: .original)
        try container.encode(canonical, forKey: .canonical)
    }
}

// MARK: - String Extension
extension String {
    public var constructedChannel: NeedleTailChannel? {
        return NeedleTailChannel(self)
    }
}
