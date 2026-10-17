//
//  IRCISupport.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

/// A channel membership mode and the symbol shown before nicknames (`o` / `@`).
public struct IRCMembershipPrefix: Hashable, Sendable {
    public var mode: Character
    public var symbol: Character

    public init(mode: Character, symbol: Character) {
        self.mode = mode
        self.symbol = symbol
    }
}

/// Channel mode letters grouped by how they take parameters (`CHANMODES=A,B,C,D`).
public struct IRCChannelModeTypes: Hashable, Sendable {
    /// Type A: list modes (`b`, `e`, `I`). Always take a parameter; none means "show the list".
    public var list: Set<Character>
    /// Type B: always take a parameter (`k`).
    public var alwaysParameter: Set<Character>
    /// Type C: take a parameter only when set (`l`).
    public var parameterWhenSet: Set<Character>
    /// Type D: never take a parameter.
    public var noParameter: Set<Character>

    public init(
        list: Set<Character>,
        alwaysParameter: Set<Character>,
        parameterWhenSet: Set<Character>,
        noParameter: Set<Character>
    ) {
        self.list = list
        self.alwaysParameter = alwaysParameter
        self.parameterWhenSet = parameterWhenSet
        self.noParameter = noParameter
    }

    /// The RFC 2811 modes, used until a server advertises `CHANMODES`.
    public static let rfc2811 = IRCChannelModeTypes(
        list: ["b", "e", "I"],
        alwaysParameter: ["k"],
        parameterWhenSet: ["l"],
        noParameter: ["i", "m", "n", "p", "s", "t"]
    )

    /// Parses a `CHANMODES` value. Groups beyond the fourth are ignored.
    public init(chanmodes: String) {
        let groups = chanmodes.split(separator: ",", omittingEmptySubsequences: false).map { Set($0) }
        func group(_ index: Int) -> Set<Character> { index < groups.count ? groups[index] : [] }
        self.init(list: group(0), alwaysParameter: group(1), parameterWhenSet: group(2), noParameter: group(3))
    }
}

/// What a server supports, accumulated from `RPL_ISUPPORT` (005) replies.
///
/// ```swift
/// var isupport = IRCISupport()
/// isupport.apply(raw)              // for every inbound message; non-005 is ignored
/// isupport.caseMapping.equals(a, b)
/// ```
public struct IRCISupport: Hashable, Sendable {

    /// Every advertised token, keyed by uppercased name. Flags without a value map to `""`.
    public private(set) var tokens: [String: String] = [:]

    public init() {}

    /// Applies a 005 reply. Other messages are ignored. The first parameter (our nick) and the
    /// last (human-readable text) are not tokens.
    public mutating func apply(_ message: IRCRawMessage) {
        guard message.numeric == 5, message.parameters.count >= 3 else { return }
        apply(tokens: Array(message.parameters[1..<(message.parameters.count - 1)]))
    }

    /// Applies raw tokens such as `NICKLEN=30`, `EXCEPTS` or `-TARGMAX`.
    public mutating func apply(tokens newTokens: [String]) {
        for token in newTokens where !token.isEmpty {
            if token.hasPrefix("-") {
                tokens.removeValue(forKey: String(token.dropFirst()).uppercased())
                continue
            }
            let parts = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(parts[0]).uppercased()
            guard !key.isEmpty else { continue }
            tokens[key] = parts.count > 1 ? Self.unescape(String(parts[1])) : ""
        }
    }

    /// The token's value (`""` for flags), or `nil` when not advertised.
    public func value(for key: String) -> String? {
        tokens[key.uppercased()]
    }

    public func contains(_ key: String) -> Bool {
        tokens[key.uppercased()] != nil
    }

    // MARK: - Well-known tokens

    /// `CASEMAPPING`, defaulting to ``IRCCaseMapping/rfc1459``.
    public var caseMapping: IRCCaseMapping {
        guard let value = value(for: "CASEMAPPING"), !value.isEmpty else { return .rfc1459 }
        return IRCCaseMapping(rawValue: value.lowercased())
    }

    /// `CHANTYPES`, defaulting to `#&`.
    public var channelTypes: Set<Character> {
        guard let value = value(for: "CHANTYPES") else { return ["#", "&"] }
        return Set(value)
    }

    /// `PREFIX`, highest rank first, defaulting to `(ov)@+`. A malformed value keeps the default.
    public var membershipPrefixes: [IRCMembershipPrefix] {
        let fallback = [IRCMembershipPrefix(mode: "o", symbol: "@"), IRCMembershipPrefix(mode: "v", symbol: "+")]
        guard let value = value(for: "PREFIX") else { return fallback }
        if value.isEmpty { return [] }
        guard value.first == "(", let close = value.firstIndex(of: ")") else { return fallback }
        let modes = Array(value[value.index(after: value.startIndex)..<close])
        let symbols = Array(value[value.index(after: close)...])
        guard modes.count == symbols.count else { return fallback }
        return zip(modes, symbols).map { IRCMembershipPrefix(mode: $0, symbol: $1) }
    }

    /// `CHANMODES`, defaulting to ``IRCChannelModeTypes/rfc2811``.
    public var channelModes: IRCChannelModeTypes {
        guard let value = value(for: "CHANMODES") else { return .rfc2811 }
        return IRCChannelModeTypes(chanmodes: value)
    }

    public var nickLength: Int? { value(for: "NICKLEN").flatMap { Int($0) } }
    public var channelLength: Int? { value(for: "CHANNELLEN").flatMap { Int($0) } }
    public var topicLength: Int? { value(for: "TOPICLEN").flatMap { Int($0) } }
    public var network: String? { value(for: "NETWORK").flatMap { $0.isEmpty ? nil : $0 } }

    /// The `TARGMAX` limit for a command, or `nil` when there is no advertised limit.
    public func maxTargets(for command: String) -> Int? {
        guard let value = value(for: "TARGMAX") else { return nil }
        for entry in value.split(separator: ",") {
            let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].uppercased() == command.uppercased() else { continue }
            return Int(parts[1])
        }
        return nil
    }

    /// `true` when the name starts with one of the advertised channel types.
    public func isChannelName(_ name: String) -> Bool {
        guard let first = name.first else { return false }
        return channelTypes.contains(first)
    }

    /// Splits the membership symbols off a `NAMES` entry (`~@bob` → `[q, o]`, `bob`).
    public func splitMembershipPrefixes(_ entry: String) -> (prefixes: [IRCMembershipPrefix], nick: String) {
        let bySymbol = Dictionary(membershipPrefixes.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
        var prefixes: [IRCMembershipPrefix] = []
        var remainder = Substring(entry)
        while let first = remainder.first, let prefix = bySymbol[first] {
            prefixes.append(prefix)
            remainder = remainder.dropFirst()
        }
        return (prefixes, String(remainder))
    }

    /// ISUPPORT values escape bytes as `\xHH`.
    private static func unescape(_ value: String) -> String {
        guard value.contains("\\x") else { return value }
        let bytes = Array(value.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "\\"),
               index + 3 < bytes.count,
               bytes[index + 1] == UInt8(ascii: "x"),
               let byte = UInt8(String(decoding: bytes[(index + 2)...(index + 3)], as: UTF8.self), radix: 16) {
                output.append(byte)
                index += 4
            } else {
                output.append(bytes[index])
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
    }
}
