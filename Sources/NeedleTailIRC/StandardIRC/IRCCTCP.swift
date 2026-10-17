//
//  IRCCTCP.swift
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

/// A standard CTCP request or reply: `\x01COMMAND argument\x01` inside PRIVMSG or NOTICE text.
///
/// This is the form standard clients and servers use. NeedleTail's own `IRCCommand.ctcp`
/// is written in this form by ``IRCStandardTranslator``.
public struct IRCCTCPMessage: Hashable, Sendable {
    /// The CTCP command, uppercased (`ACTION`, `VERSION`, `PING`, ...).
    public var command: String
    public var argument: String?

    public init(command: String, argument: String? = nil) {
        self.command = command.uppercased()
        self.argument = argument
    }

    /// Parses message text. The closing `\x01` is optional, as many clients omit it.
    public init?(text: String) {
        var scalars = Array(text.unicodeScalars)
        guard scalars.first == "\u{1}" else { return nil }
        scalars.removeFirst()
        if scalars.last == "\u{1}" { scalars.removeLast() }
        var body = String.UnicodeScalarView()
        body.append(contentsOf: scalars)
        let parts = String(body).split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty else { return nil }
        self.init(command: String(first), argument: parts.count > 1 ? String(parts[1]) : nil)
    }

    /// The message text, `\x01COMMAND argument\x01`.
    public var text: String {
        "\u{1}\(command)\(argument.map { " \($0)" } ?? "")\u{1}"
    }

    /// `/me` text.
    public static func action(_ text: String) -> IRCCTCPMessage {
        IRCCTCPMessage(command: "ACTION", argument: text)
    }
}

extension IRCRawMessage {
    /// The CTCP payload of a PRIVMSG (request) or NOTICE (reply), if any.
    public var ctcp: IRCCTCPMessage? {
        guard command == "PRIVMSG" || command == "NOTICE", parameters.count == 2 else { return nil }
        return IRCCTCPMessage(text: parameters[1])
    }

    /// `true` for a CTCP reply (CTCP inside NOTICE).
    public var isCTCPReply: Bool {
        command == "NOTICE" && ctcp != nil
    }

    /// A CTCP request: `PRIVMSG <target> :\x01...\x01`.
    public static func ctcp(_ message: IRCCTCPMessage, to target: String) -> IRCRawMessage {
        IRCRawMessage(command: "PRIVMSG", parameters: [target, message.text], forcesTrailingParameter: true)
    }

    /// A CTCP reply: `NOTICE <target> :\x01...\x01`.
    public static func ctcpReply(_ message: IRCCTCPMessage, to target: String) -> IRCRawMessage {
        IRCRawMessage(command: "NOTICE", parameters: [target, message.text], forcesTrailingParameter: true)
    }
}
