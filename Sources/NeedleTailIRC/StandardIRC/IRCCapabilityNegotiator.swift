//
//  IRCCapabilityNegotiator.swift
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

/// IRCv3 capability negotiation (`CAP LS 302` … `CAP END`) as a value-type state machine.
///
/// It performs no I/O: feed it every inbound message with ``handle(_:)`` and send whatever it
/// returns. Supports multi-line `LS`/`LIST`, capability values (`sasl=PLAIN,EXTERNAL`),
/// `cap-notify` (`NEW`/`DEL`), and servers without CAP support (finishes on 001 or 421).
public struct IRCCapabilityNegotiator: Sendable {

    /// Capabilities this client wants. Only those the server offers are requested.
    public let requested: Set<String>
    /// The CAP version sent with `LS`.
    public let version: Int
    /// When `true` and `sasl` is acknowledged, `CAP END` is held until ``finish()`` is called,
    /// so SASL can run first.
    public let holdsForSASL: Bool

    /// Capabilities the server offers, with their values (`""` when there is none).
    public private(set) var available: [String: String] = [:]
    /// Capabilities currently enabled on the connection.
    public private(set) var enabled: Set<String> = []
    /// `true` once `CAP END` has been sent or the server turned out not to support CAP.
    public private(set) var isFinished = false
    /// `true` while `CAP END` is being held for SASL.
    public private(set) var isWaitingForSASL = false

    private var pending: Set<String> = []
    private var listBuffer: [String: String] = [:]
    private var enabledListBuffer: Set<String> = []

    /// RFC line limit minus CRLF.
    static let maxLineBytes = 510

    public init(requesting capabilities: Set<String>, version: Int = 302, holdsForSASL: Bool = false) {
        self.requested = capabilities
        self.version = version
        self.holdsForSASL = holdsForSASL
    }

    /// `CAP LS <version>`. Send it before `NICK`/`USER`.
    public mutating func start() -> [IRCRawMessage] {
        [IRCRawMessage(command: "CAP", parameters: ["LS", String(version)])]
    }

    /// Sends `CAP END` if it has not been sent yet (for example after SASL completes).
    public mutating func finish() -> [IRCRawMessage] {
        guard !isFinished else { return [] }
        isFinished = true
        isWaitingForSASL = false
        return [IRCRawMessage(command: "CAP", parameters: ["END"])]
    }

    /// Processes one inbound message and returns the messages to send in response.
    public mutating func handle(_ message: IRCRawMessage) -> [IRCRawMessage] {
        if let numeric = message.numeric {
            switch numeric {
            case 1:
                // The server registered us without negotiating; it does not support CAP.
                isFinished = true
                isWaitingForSASL = false
            case 421 where message.parameters.dropFirst().first?.uppercased() == "CAP":
                // ERR_UNKNOWNCOMMAND for CAP: no CAP support, registration continues without END.
                isFinished = true
                isWaitingForSASL = false
            case 410:
                // ERR_INVALIDCAPCMD: the server speaks CAP but rejected a subcommand. End cleanly.
                return finish()
            default:
                break
            }
            return []
        }

        guard message.command == "CAP", message.parameters.count >= 2 else { return [] }
        let subcommand = message.parameters[1].uppercased()
        let rest = Array(message.parameters.dropFirst(2))
        let isContinuation = rest.count >= 2 && rest[0] == "*"
        let list = rest.last ?? ""

        switch subcommand {
        case "LS":
            listBuffer.merge(Self.parseList(list)) { _, new in new }
            guard !isContinuation else { return [] }
            available.merge(listBuffer) { _, new in new }
            listBuffer = [:]
            guard !isFinished else { return [] }
            let wanted = requested.intersection(available.keys).subtracting(enabled)
            guard !wanted.isEmpty else { return finish() }
            pending.formUnion(wanted)
            return Self.requests(for: wanted)

        case "ACK":
            for name in Self.names(in: list) {
                if name.hasPrefix("-") {
                    enabled.remove(String(name.dropFirst()))
                } else {
                    enabled.insert(name)
                }
                pending.remove(name.hasPrefix("-") ? String(name.dropFirst()) : name)
            }
            return finishIfSettled()

        case "NAK":
            pending.subtract(Self.names(in: list))
            return finishIfSettled()

        case "NEW":
            let offered = Self.parseList(list)
            available.merge(offered) { _, new in new }
            let wanted = requested.intersection(offered.keys).subtracting(enabled).subtracting(pending)
            guard !wanted.isEmpty else { return [] }
            pending.formUnion(wanted)
            return Self.requests(for: wanted)

        case "DEL":
            for name in Self.names(in: list) {
                available.removeValue(forKey: name)
                enabled.remove(name)
                pending.remove(name)
            }
            return []

        case "LIST":
            enabledListBuffer.formUnion(Self.names(in: list))
            guard !isContinuation else { return [] }
            enabled = enabledListBuffer
            enabledListBuffer = []
            return []

        default:
            return []
        }
    }

    private mutating func finishIfSettled() -> [IRCRawMessage] {
        guard !isFinished, pending.isEmpty else { return [] }
        if holdsForSASL, enabled.contains("sasl") {
            isWaitingForSASL = true
            return []
        }
        return finish()
    }

    /// `CAP REQ` lines, each within the 510-byte limit.
    static func requests(for capabilities: Set<String>) -> [IRCRawMessage] {
        let prefixBytes = "CAP REQ :".utf8.count
        var messages: [IRCRawMessage] = []
        var current: [String] = []
        var currentBytes = 0
        for name in capabilities.sorted() {
            let added = (current.isEmpty ? 0 : 1) + name.utf8.count
            if !current.isEmpty, prefixBytes + currentBytes + added > maxLineBytes {
                messages.append(request(current))
                current = []
                currentBytes = 0
            }
            currentBytes += (current.isEmpty ? 0 : 1) + name.utf8.count
            current.append(name)
        }
        if !current.isEmpty { messages.append(request(current)) }
        return messages
    }

    private static func request(_ names: [String]) -> IRCRawMessage {
        IRCRawMessage(command: "CAP", parameters: ["REQ", names.joined(separator: " ")], forcesTrailingParameter: true)
    }

    /// `name[=value]` tokens separated by spaces.
    static func parseList(_ list: String) -> [String: String] {
        var result: [String: String] = [:]
        for token in list.split(separator: " ") {
            let parts = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            result[String(parts[0])] = parts.count > 1 ? String(parts[1]) : ""
        }
        return result
    }

    /// Capability names, ignoring values and the deprecated `~`/`=` modifiers.
    static func names(in list: String) -> [String] {
        list.split(separator: " ").map { token in
            var name = Substring(token.split(separator: "=", maxSplits: 1).first ?? token)
            while let first = name.first, first == "~" || first == "=" { name = name.dropFirst() }
            return String(name)
        }
    }
}
