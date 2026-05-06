//
//  NeedleTailChannel.swift
//  needletail-irc
//
//  Created by Cole M on 9/23/22.
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

    /// The normalized channel name used for stable IRC wire, cache, and storage comparisons.
    public var canonicalWireName: String {
        canonical
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

    /// Maximum number of characters allowed after the channel prefix (`#`, `&`, `+`, `!`) while satisfying `validate`.
    public static let maxChannelBodyLength = 49

    /// Builds a wire-safe channel name from user-facing text (spaces, mixed case, optional leading `#` / `&` / `+` / `!`).
    ///
    /// Keeps ASCII letters, digits, and underscores as runs; inserts `-` between runs separated by spaces or punctuation.
    /// Returns `nil` when nothing usable remains or the result fails `validate`.
    public static func derivedName(fromUserFacing userInput: String, preferredPrefix: Character = "#") -> String? {
        guard "#&+!".contains(preferredPrefix) else { return nil }
        var remainder = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else { return nil }
        if let first = remainder.first, first.isChannelNamePrefixed {
            remainder.removeFirst()
            remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !remainder.isEmpty else { return nil }

        var segments: [String] = []
        var current = ""
        func flushCurrent() {
            if !current.isEmpty {
                segments.append(current)
                current = ""
            }
        }
        for scalar in remainder.lowercased().unicodeScalars {
            if scalar.isASCII,
               ((0x61...0x7A).contains(scalar.value)) // a-z
               || ((0x30...0x39).contains(scalar.value)) // 0-9
               || scalar.value == 0x5F { // _
                current.append(Character(scalar))
            } else {
                flushCurrent()
            }
        }
        flushCurrent()
        var slug = segments.joined(separator: "-")
        guard !slug.isEmpty else { return nil }
        if slug.count > maxChannelBodyLength {
            slug = String(slug.prefix(maxChannelBodyLength))
        }
        while slug.last == "-" || slug.last == "_" {
            slug.removeLast()
        }
        guard !slug.isEmpty else { return nil }

        let candidate = String(preferredPrefix) + slug
        let wire = candidate.ircLowercased
        guard validate(string: wire) else { return nil }
        return wire
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

public extension NeedleTailChannel {
    /// UUID suffix from a canonical `#slug_uuid` channel identity.
    var identityUUIDString: String? {
        NeedleTailChannelIdentity.uuidString(fromWireName: canonicalWireName)
    }

    /// Human-friendly channel title derived from a canonical wire id like `#travel_<uuid>`.
    ///
    /// This preserves legacy channel names unchanged and only strips a trailing UUID suffix when
    /// the channel name matches the canonical `#slug_uuid` format.
    var displayTitle: String {
        let raw = stringValue
        let withoutPrefix = raw.first?.isChannelNamePrefixed == true ? String(raw.dropFirst()) : raw
        guard identityUUIDString != nil,
              let separatorIndex = withoutPrefix.lastIndex(of: "_")
        else {
            return withoutPrefix
        }

        let title = String(withoutPrefix[..<separatorIndex])
        return title.isEmpty ? withoutPrefix : title
    }
}

extension Character {
    public var isChannelNamePrefixed: Bool {
        "#&+!".contains(self)
    }
}
