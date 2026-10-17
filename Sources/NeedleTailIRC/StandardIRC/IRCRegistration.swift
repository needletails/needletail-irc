//
//  IRCRegistration.swift
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

/// What to register with on a standard IRC server.
public struct IRCRegistrationConfiguration: Sendable, CustomStringConvertible {
    /// Capabilities requested by default when the server offers them.
    public static let defaultCapabilities: Set<String> = [
        "account-tag", "away-notify", "batch", "cap-notify", "message-tags", "multi-prefix", "server-time",
    ]

    public var nick: String
    public var username: String
    public var realname: String
    /// Tried in order when the nick is taken; afterwards `_` is appended.
    public var alternativeNicks: [String]
    /// Server password (`PASS`), if the server needs one.
    public var password: String?
    public var capabilities: Set<String>
    /// SASL credentials. When set, `sasl` is requested and authentication runs before `CAP END`.
    public var sasl: IRCSASLCredentials?
    /// When `true`, registration fails (and sends `QUIT`) if SASL is unavailable or fails.
    public var requiresSASL: Bool

    public init(
        nick: String,
        username: String,
        realname: String,
        alternativeNicks: [String] = [],
        password: String? = nil,
        capabilities: Set<String> = IRCRegistrationConfiguration.defaultCapabilities,
        sasl: IRCSASLCredentials? = nil,
        requiresSASL: Bool = false
    ) {
        self.nick = nick
        self.username = username
        self.realname = realname
        self.alternativeNicks = alternativeNicks
        self.password = password
        self.capabilities = capabilities
        self.sasl = sasl
        self.requiresSASL = requiresSASL
    }

    public var description: String {
        "IRCRegistrationConfiguration(nick: \(nick), username: \(username), password: \(password == nil ? "none" : "<redacted>"), sasl: \(sasl?.mechanism ?? "none"))"
    }
}

/// Client registration with a standard IRC server: CAP negotiation, optional SASL, NICK/USER,
/// nick collisions, PING replies and ISUPPORT. A value-type state machine with no I/O.
///
/// ```swift
/// var registration = IRCRegistration(configuration: .init(nick: "alice", username: "alice", realname: "Alice"))
/// send(registration.start())
/// // for every inbound IRCRawMessage:
/// send(registration.handle(message))
/// if registration.isRegistered { ... }
/// ```
public struct IRCRegistration: Sendable {

    public let configuration: IRCRegistrationConfiguration

    public private(set) var isRegistered = false
    /// The nick the server currently knows us by.
    public private(set) var currentNick: String
    /// Accumulated 005 tokens.
    public private(set) var isupport = IRCISupport()
    /// The account from SASL (900), if logged in.
    public private(set) var account: String?
    /// Set when the server refused us. Registration should be considered over.
    public private(set) var failure: IRCStandardError?

    public private(set) var negotiator: IRCCapabilityNegotiator
    public private(set) var authenticator: IRCSASLAuthenticator?

    public var enabledCapabilities: Set<String> { negotiator.enabled }

    private var remainingAlternatives: [String]
    private var hasStartedSASL = false

    /// Used when the server does not advertise `NICKLEN`.
    static let fallbackNickLength = 30

    public init(configuration: IRCRegistrationConfiguration) {
        self.configuration = configuration
        self.currentNick = configuration.nick
        self.remainingAlternatives = configuration.alternativeNicks
        var capabilities = configuration.capabilities
        if configuration.sasl != nil { capabilities.insert("sasl") }
        self.negotiator = IRCCapabilityNegotiator(
            requesting: capabilities,
            holdsForSASL: configuration.sasl != nil
        )
    }

    /// `CAP LS 302`, then `PASS` (if any), `NICK` and `USER`.
    public mutating func start() -> [IRCRawMessage] {
        var messages = negotiator.start()
        if let password = configuration.password {
            messages.append(IRCRawMessage(command: "PASS", parameters: [password]))
        }
        messages.append(IRCRawMessage(command: "NICK", parameters: [configuration.nick]))
        messages.append(IRCRawMessage(
            command: "USER",
            parameters: [configuration.username, "0", "*", configuration.realname],
            forcesTrailingParameter: true
        ))
        return messages
    }

    /// Processes one inbound message and returns the messages to send in response.
    public mutating func handle(_ message: IRCRawMessage) -> [IRCRawMessage] {
        var out: [IRCRawMessage] = []

        if message.command == "PING" {
            out.append(IRCRawMessage(command: "PONG", parameters: message.parameters))
        }

        let wasFinished = negotiator.isFinished
        out += negotiator.handle(message)

        if let credentials = configuration.sasl, negotiator.isWaitingForSASL, !hasStartedSASL {
            hasStartedSASL = true
            var sasl = IRCSASLAuthenticator(credentials: credentials)
            out += sasl.start()
            authenticator = sasl
        } else if var sasl = authenticator, !sasl.isFinished {
            out += sasl.handle(message)
            authenticator = sasl
            if let account = sasl.account { self.account = account }
            if sasl.isFinished {
                if !sasl.succeeded, configuration.requiresSASL {
                    out += fail(.saslFailed, sasl.failureReason ?? "SASL authentication failed")
                } else {
                    out += negotiator.finish()
                }
            }
        }

        if configuration.requiresSASL, configuration.sasl != nil, !wasFinished, negotiator.isFinished,
           !negotiator.enabled.contains("sasl"), failure == nil {
            out += fail(.saslFailed, "the server does not offer SASL")
        }

        if let numeric = message.numeric {
            handleNumeric(numeric, message, into: &out)
        } else if message.command == "ERROR" {
            failure = IRCStandardError(.registrationFailed, message.parameters.last ?? "")
        } else if message.command == "NICK", let newNick = message.parameters.first,
                  let source = message.sourceComponents,
                  isupport.caseMapping.equals(source.nick, currentNick) {
            currentNick = newNick
        }

        return out
    }

    private mutating func handleNumeric(_ numeric: Int, _ message: IRCRawMessage, into out: inout [IRCRawMessage]) {
        switch numeric {
        case 1:
            isRegistered = true
            if let nick = message.parameters.first { currentNick = nick }
        case 5:
            isupport.apply(message)
        case 432, 433, 436, 437:
            // After registration a nick error answers the application's own NICK; not ours to retry.
            guard !isRegistered else { break }
            if let next = nextNick() {
                currentNick = next
                out.append(IRCRawMessage(command: "NICK", parameters: [next]))
            } else {
                failure = IRCStandardError(.registrationFailed, "no usable nickname")
            }
        case 464, 465:
            failure = IRCStandardError(.registrationFailed, message.parameters.last ?? "")
        default:
            break
        }
    }

    private mutating func nextNick() -> String? {
        if !remainingAlternatives.isEmpty {
            return remainingAlternatives.removeFirst()
        }
        let candidate = currentNick + "_"
        guard candidate.utf8.count <= (isupport.nickLength ?? Self.fallbackNickLength) else { return nil }
        return candidate
    }

    private mutating func fail(_ code: IRCStandardError.Code, _ detail: String) -> [IRCRawMessage] {
        failure = IRCStandardError(code, detail)
        return [IRCRawMessage(command: "QUIT", parameters: [detail], forcesTrailingParameter: true)]
    }
}
