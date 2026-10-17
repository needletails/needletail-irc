//
//  IRCCaseMapping.swift
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

/// How a server compares nicknames and channel names, as advertised by `CASEMAPPING` in 005.
///
/// Use ``IRCISupport/caseMapping`` for the current server rather than assuming one.
public struct IRCCaseMapping: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Only `A-Z` fold to `a-z`.
    public static let ascii = IRCCaseMapping(rawValue: "ascii")
    /// `A-Z[]\~` fold to `a-z{}|^`. The RFC 1459 default.
    public static let rfc1459 = IRCCaseMapping(rawValue: "rfc1459")
    /// `A-Z[]\` fold to `a-z{}|`.
    public static let rfc1459Strict = IRCCaseMapping(rawValue: "rfc1459-strict")
    /// PRECIS (RFC 7613) mapping; approximated with Unicode lowercasing.
    public static let rfc7613 = IRCCaseMapping(rawValue: "rfc7613")

    /// The case-folded form, for use as a dictionary key or for comparison.
    /// Unknown mappings fall back to Unicode lowercasing.
    public func fold(_ value: String) -> String {
        switch rawValue {
        case Self.ascii.rawValue:
            return Self.fold(value, extra: [:])
        case Self.rfc1459.rawValue:
            return Self.fold(value, extra: ["[": "{", "]": "}", "\\": "|", "~": "^"])
        case Self.rfc1459Strict.rawValue:
            return Self.fold(value, extra: ["[": "{", "]": "}", "\\": "|"])
        default:
            return value.lowercased()
        }
    }

    /// `true` when both names are the same under this mapping.
    public func equals(_ lhs: String, _ rhs: String) -> Bool {
        fold(lhs) == fold(rhs)
    }

    private static func fold(_ value: String, extra: [Unicode.Scalar: Unicode.Scalar]) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            if scalar.value >= 0x41, scalar.value <= 0x5A, let lower = Unicode.Scalar(scalar.value + 0x20) {
                scalars.append(lower)
            } else if let mapped = extra[scalar] {
                scalars.append(mapped)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }
}
