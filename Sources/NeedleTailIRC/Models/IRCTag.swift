//
//  IRCTag.swift
//  needletail-irc
//
//  Created by Cole M on 12/11/21.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

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

    // MARK: - IRCv3 tag escaping/unescaping (values)
    //
    // IRCv3 message tag value escapes:
    //  - \: => ;
    //  - \s => space
    //  - \r => CR
    //  - \n => LF
    //  - \\ => \
    public static func ircv3EscapeTagValue(_ value: String) -> String {
        // Order matters: escape backslash first.
        var out = value.replacingOccurrences(of: "\\", with: "\\\\")
        out = out.replacingOccurrences(of: ";", with: "\\:")
        out = out.replacingOccurrences(of: " ", with: "\\s")
        out = out.replacingOccurrences(of: "\r", with: "\\r")
        out = out.replacingOccurrences(of: "\n", with: "\\n")
        return out
    }

    public static func ircv3UnescapeTagValue(_ value: String) -> String {
        // Single-pass parser to avoid double-unescaping.
        var result = ""
        result.reserveCapacity(value.count)

        var i = value.startIndex
        while i < value.endIndex {
            let c = value[i]
            if c == "\\" {
                let next = value.index(after: i)
                guard next < value.endIndex else { break }
                let esc = value[next]
                switch esc {
                case ":":
                    result.append(";")
                case "s":
                    result.append(" ")
                case "r":
                    result.append("\r")
                case "n":
                    result.append("\n")
                case "\\":
                    result.append("\\")
                default:
                    // Unknown escape => drop backslash, keep char.
                    result.append(esc)
                }
                i = value.index(after: next)
            } else {
                result.append(c)
                i = value.index(after: i)
            }
        }
        return result
    }

    // MARK: - Safety caps (configurable defaults)
    public static let defaultMaxTagCount: Int = 256
    public static let defaultMaxTagKeyBytes: Int = 256
    public static let defaultMaxTagValueBytes: Int = 64 * 1024
    public static let defaultMaxTagSectionBytes: Int = 128 * 1024

    public static func validate(
        key: String,
        value: String,
        maxKeyBytes: Int = defaultMaxTagKeyBytes,
        maxValueBytes: Int = defaultMaxTagValueBytes
    ) -> Bool {
        guard !key.isEmpty else { return false }
        guard key.utf8.count <= maxKeyBytes, value.utf8.count <= maxValueBytes else { return false }
        if key.contains(" ") || key.contains(";") || key.contains("=") { return false }
        if key.utf8.contains(where: { $0 < 0x20 || $0 == 0x7F }) { return false }
        return true
    }
}


enum TagKey: String {
    case privateMessage, dccChat, passTag, reachableServers, externalNickOnline, externalNickOffline, membersOnline, cacheSession
}
