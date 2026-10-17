//
//  IRCv3Tags.swift
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

import Foundation

/// Lookups shared by the tag accessors on ``IRCRawMessage`` and ``IRCMessage``.
enum IRCv3TagLookup {
    /// IRCv3: when a key repeats, the last occurrence wins.
    static func value(_ key: String, in tags: [IRCTag]) -> String? {
        tags.last { $0.key == key }?.value
    }

    static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return makeFormatter(fractional: true).date(from: value)
            ?? makeFormatter(fractional: false).date(from: value)
    }

    static func string(from date: Date) -> String {
        makeFormatter(fractional: true).string(from: date)
    }

    private static func makeFormatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }
}

extension IRCRawMessage {
    /// The value of a tag, or `nil` when absent. Repeated keys resolve to the last value.
    public func tagValue(_ key: String) -> String? { IRCv3TagLookup.value(key, in: tags) }
    /// `time` (server-time).
    public var serverTime: Date? { IRCv3TagLookup.date(from: tagValue("time")) }
    /// `msgid` (message-ids).
    public var messageID: String? { tagValue("msgid") }
    /// `account` (account-tag).
    public var account: String? { tagValue("account") }
    /// `label` (labeled-response).
    public var label: String? { tagValue("label") }
    /// `batch` (batch).
    public var batchReference: String? { tagValue("batch") }
    /// Client-only tags (keys starting with `+`).
    public var clientOnlyTags: [IRCTag] { tags.filter { $0.key.hasPrefix("+") } }
}

extension IRCMessage {
    /// The value of a tag, or `nil` when absent. Repeated keys resolve to the last value.
    public func tagValue(_ key: String) -> String? { IRCv3TagLookup.value(key, in: tags ?? []) }
    /// `time` (server-time).
    public var serverTime: Date? { IRCv3TagLookup.date(from: tagValue("time")) }
    /// `msgid` (message-ids).
    public var messageID: String? { tagValue("msgid") }
    /// `account` (account-tag).
    public var account: String? { tagValue("account") }
    /// `label` (labeled-response).
    public var label: String? { tagValue("label") }
    /// `batch` (batch).
    public var batchReference: String? { tagValue("batch") }
    /// Client-only tags (keys starting with `+`).
    public var clientOnlyTags: [IRCTag] { (tags ?? []).filter { $0.key.hasPrefix("+") } }
}

extension IRCTag {
    /// A `time` tag in the IRCv3 server-time format (`2023-01-01T12:00:00.123Z`).
    public static func serverTime(_ date: Date) -> IRCTag {
        IRCTag(key: "time", value: IRCv3TagLookup.string(from: date))
    }

    /// A `label` tag for labeled-response.
    public static func label(_ value: String) -> IRCTag {
        IRCTag(key: "label", value: value)
    }
}
