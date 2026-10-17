//
//  IRCStandardTranslator.swift
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

// MARK: - Name rules

extension NeedleTailNick.NameRules {
    /// Nickname rules for standard IRC servers: underscores allowed, no forced lowercasing
    /// (use with `NeedleTailNick(name:deviceId:nameRules:)`, which preserves case).
    ///
    /// `NeedleTailNick` itself requires at least two characters, so single-character nicks
    /// cannot be represented; the translator falls back to `.otherCommand` for those.
    public static var standardIRC: NeedleTailNick.NameRules {
        var rules = NeedleTailNick.NameRules()
        rules.disallowsUnderScore = false
        rules.allowsStartingDigit = true
        return rules
    }
}

// MARK: - Translator

/// Converts between lossless ``IRCRawMessage`` values and the typed ``IRCMessage`` model,
/// following RFC 1459 / RFC 2812 semantics.
///
/// Inbound, a message is mapped to a typed ``IRCCommand`` case only when the case can hold it
/// faithfully; everything else becomes `.otherCommand(command, parameters)` or
/// `.otherNumeric(code, parameters)` with the parameters exactly as received. Nothing is dropped.
///
/// Outbound, typed cases are written the standard way, and `.otherCommand`, `.numeric` and
/// `.otherNumeric` are treated as plain parameter lists, so they can carry any command.
public enum IRCStandardTranslator {

    // MARK: Inbound

    /// Maps a standard IRC message onto the typed model. Never fails.
    ///
    /// - Numerics: the first parameter becomes ``IRCMessage/target``; the rest are the arguments.
    /// - `CAP` replies: the target nick (or `*`) becomes ``IRCMessage/target``. Multi-line
    ///   continuations and subcommands without a ``IRCCommand/CAPSubCommand`` case (`NEW`, `DEL`)
    ///   are delivered as `.otherCommand("CAP", parameters)`.
    public static func message(from raw: IRCRawMessage) -> IRCMessage {
        let tags = raw.tags.isEmpty ? nil : raw.tags
        let parameters = raw.parameters

        if let numeric = raw.numeric {
            let arguments = Array(parameters.dropFirst())
            let command: IRCCommand = IRCCommandCode(rawValue: numeric)
                .map { .numeric($0, arguments) } ?? .otherNumeric(numeric, arguments)
            return IRCMessage(origin: raw.source, target: parameters.first, command: command, tags: tags)
        }

        if raw.command == "CAP", let capability = capability(parameters) {
            return IRCMessage(origin: raw.source, target: capability.target, command: capability.command, tags: tags)
        }

        let command = typedCommand(raw.command, parameters) ?? .otherCommand(raw.command, parameters)
        return IRCMessage(origin: raw.source, command: command, tags: tags)
    }

    private static func typedCommand(_ command: String, _ p: [String]) -> IRCCommand? {
        switch command {
        case "PRIVMSG", "NOTICE":
            guard p.count == 2, let recipients = recipients(p[0]) else { return nil }
            return command == "PRIVMSG" ? .privMsg(recipients, p[1]) : .notice(recipients, p[1])
        case "NICK":
            guard p.count >= 1, let nick = nick(p[0]) else { return nil }
            return .nick(nick)
        case "JOIN":
            guard (1...3).contains(p.count) else { return nil }
            if p.count == 1, p[0] == "0" { return .join0 }
            guard let channels = channels(p[0]) else { return nil }
            // Three parameters is extended-join (`JOIN #chan account :Real Name`); no keys.
            let keys = p.count == 2 ? p[1].split(separator: ",", omittingEmptySubsequences: false).map(String.init) : nil
            return .join(channels: channels, keys: keys)
        case "PART":
            guard (1...2).contains(p.count), let channels = channels(p[0]) else { return nil }
            return .part(channels: channels)
        case "QUIT":
            guard p.count <= 1 else { return nil }
            return .quit(p.first)
        case "PING", "PONG":
            guard (1...2).contains(p.count) else { return nil }
            let second = p.count == 2 ? p[1] : nil
            return command == "PING" ? .ping(server: p[0], server2: second) : .pong(server: p[0], server2: second)
        case "KICK":
            guard (2...3).contains(p.count), let channels = channels(p[0]), let users = nicks(p[1]) else { return nil }
            return .kick(channels, users, p.count == 3 ? [p[2]] : [])
        case "TOPIC":
            guard (1...2).contains(p.count), let channel = NeedleTailChannel(p[0]) else { return nil }
            return .topic(channel, p.count == 2 ? p[1] : nil)
        case "INVITE":
            guard p.count == 2, let nick = nick(p[0]), let channel = NeedleTailChannel(p[1]) else { return nil }
            return .invite(nick, channel)
        case "AWAY":
            guard p.count <= 1 else { return nil }
            return .away(p.first.flatMap { $0.isEmpty ? nil : $0 })
        case "MODE":
            return mode(p)
        case "USER":
            guard p.count == 4 else { return nil }
            return .user(IRCUserDetails(username: p[0], hostname: p[1], servername: p[2], realname: p[3]))
        case "ISON":
            let values = p.flatMap { $0.split(separator: " ").map(String.init) }
            guard !values.isEmpty else { return nil }
            let parsed = values.compactMap(nick)
            guard parsed.count == values.count else { return nil }
            return .isOn(parsed)
        case "WHOIS":
            switch p.count {
            case 1: return .whois(server: nil, usermasks: p[0].split(separator: ",").map(String.init))
            case 2: return .whois(server: p[0], usermasks: p[1].split(separator: ",").map(String.init))
            default: return nil
            }
        case "WHO":
            switch p.count {
            case 0: return .who(usermask: nil, onlyOperators: false)
            case 1: return .who(usermask: p[0], onlyOperators: false)
            case 2 where p[1] == "o": return .who(usermask: p[0], onlyOperators: true)
            default: return nil
            }
        case "KILL":
            guard p.count == 2, let nick = nick(p[0]) else { return nil }
            return .kill(nick, p[1])
        default:
            return nil
        }
    }

    private static func capability(_ p: [String]) -> (target: String?, command: IRCCommand)? {
        func subcommand(_ value: String) -> IRCCommand.CAPSubCommand? {
            IRCCommand.CAPSubCommand(rawValue: value.uppercased())
        }
        func capabilities(_ value: String?) -> [String] {
            value?.split(separator: " ").map(String.init) ?? []
        }
        // Server form: CAP <target> <subcommand> [*] [:<capabilities>]
        if p.count >= 2, subcommand(p[0]) == nil, let sub = subcommand(p[1]) {
            let rest = Array(p.dropFirst(2))
            guard rest.count <= 1 else { return nil } // `*` continuation: keep it lossless
            return (p[0], .cap(sub, capabilities(rest.first)))
        }
        // Client form: CAP <subcommand> [<arguments>]
        if let first = p.first, let sub = subcommand(first) {
            let rest = Array(p.dropFirst())
            guard rest.count <= 1 else { return nil }
            return (nil, .cap(sub, capabilities(rest.first)))
        }
        return nil
    }

    // RFC 2811: these channel modes always take a parameter; `l` only when set.
    private static let channelModesWithParameter: Set<Character> = ["O", "o", "v", "b", "e", "I", "k"]
    private static let channelModesWithParameterWhenSet: Set<Character> = ["l"]

    private static func mode(_ p: [String]) -> IRCCommand? {
        guard let target = p.first else { return nil }

        if let channel = NeedleTailChannel(target) {
            if p.count == 1 { return .channelModeGet(channel) }
            let arguments = Array(p.dropFirst(2))
            if p[1] == "+b", arguments.isEmpty { return .channelModeGetBanMask(channel) }
            return channelModeChange(channel, modeString: p[1], arguments: arguments)
        }

        guard let nick = nick(target) else { return nil }
        if p.count == 1 { return .modeGet(nick) }
        guard p.count == 2 else { return nil }

        var add = IRCUserModeFlags()
        var remove = IRCUserModeFlags()
        var adding: Bool?
        for character in p[1] {
            switch character {
            case "+": adding = true
            case "-": adding = false
            default:
                guard let adding, let flag = IRCUserModeFlags(String(character)) else { return nil }
                if adding { add.insert(flag) } else { remove.insert(flag) }
            }
        }
        guard !add.isEmpty || !remove.isEmpty else { return nil }
        return .mode(nick, add: add.isEmpty ? nil : add, remove: remove.isEmpty ? nil : remove)
    }

    /// Maps a channel mode change onto `.channelMode` only when the typed case can re-encode it
    /// with every parameter still paired to its mode letter.
    private static func channelModeChange(_ channel: NeedleTailChannel, modeString: String, arguments: [String]) -> IRCCommand? {
        var add = IRCChannelPermissions()
        var remove = IRCChannelPermissions()
        var addParameters: [String] = []
        var removeParameters: [String] = []
        var addParameterLetters: [Character] = []
        var removeParameterLetters: [Character] = []
        var adding: Bool?
        var nextArgument = 0

        for character in modeString {
            switch character {
            case "+": adding = true
            case "-": adding = false
            default:
                guard let adding, let flag = IRCChannelPermissions(String(character)) else { return nil }
                guard !add.contains(flag), !remove.contains(flag) else { return nil }
                let takesParameter = channelModesWithParameter.contains(character)
                    || (adding && channelModesWithParameterWhenSet.contains(character))
                if takesParameter {
                    guard nextArgument < arguments.count else { return nil }
                    if adding {
                        addParameters.append(arguments[nextArgument])
                        addParameterLetters.append(character)
                    } else {
                        removeParameters.append(arguments[nextArgument])
                        removeParameterLetters.append(character)
                    }
                    nextArgument += 1
                }
                if adding { add.insert(flag) } else { remove.insert(flag) }
            }
        }

        guard nextArgument == arguments.count, !add.isEmpty || !remove.isEmpty else { return nil }

        // Outbound writes letters in `stringValue` order; parameters must line up with that.
        func canonicalParameterLetters(_ set: IRCChannelPermissions, adding: Bool) -> [Character] {
            set.stringValue.filter {
                channelModesWithParameter.contains($0) || (adding && channelModesWithParameterWhenSet.contains($0))
            }
        }
        guard canonicalParameterLetters(add, adding: true) == addParameterLetters,
              canonicalParameterLetters(remove, adding: false) == removeParameterLetters
        else { return nil }

        return .channelMode(
            channel,
            addMode: add.isEmpty ? nil : add,
            addParameters: addParameters.isEmpty ? nil : addParameters,
            removeMode: remove.isEmpty ? nil : remove,
            removeParameters: removeParameters.isEmpty ? nil : removeParameters
        )
    }

    private static func nick(_ value: String) -> NeedleTailNick? {
        NeedleTailNick(name: value, deviceId: nil, nameRules: .standardIRC)
    }

    private static func nicks(_ list: String) -> [NeedleTailNick]? {
        let values = list.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let parsed = values.compactMap(nick)
        return parsed.count == values.count && !parsed.isEmpty ? parsed : nil
    }

    private static func channels(_ list: String) -> [NeedleTailChannel]? {
        let values = list.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let parsed = values.compactMap(NeedleTailChannel.init)
        return parsed.count == values.count && !parsed.isEmpty ? parsed : nil
    }

    private static func recipients(_ list: String) -> [IRCMessageRecipient]? {
        let values = list.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let parsed = values.compactMap { value -> IRCMessageRecipient? in
            if value == "*" { return .all }
            if let channel = NeedleTailChannel(value) { return .channel(channel) }
            return nick(value).map(IRCMessageRecipient.nick)
        }
        return parsed.count == values.count && !parsed.isEmpty ? parsed : nil
    }

    // MARK: Outbound

    /// Commands whose last parameter is free text, and how many parameters they have when
    /// that text is present. The text is always written as a trailing parameter.
    private static let textCommandParameterCount: [String: Int] = [
        "PRIVMSG": 2, "NOTICE": 2, "PART": 2, "KICK": 3, "TOPIC": 2, "QUIT": 1, "AWAY": 1,
        "ERROR": 1, "KILL": 2, "WALLOPS": 1, "GLOBOPS": 1, "LOCOPS": 1, "USER": 4,
        "SQUIT": 2, "KNOCK": 2, "SETNAME": 1,
    ]

    /// Writes a typed message the standard way.
    ///
    /// - Throws: ``IRCStandardError`` with code ``IRCStandardError/Code/unsupportedOnStandardIRC``
    ///   for NeedleTail-only commands (DCC, SDCC, server-specific aliases with no portable mode
    ///   letter), and ``IRCStandardError/Code/missingTarget`` for commands without a target.
    public static func rawMessage(from message: IRCMessage) throws -> IRCRawMessage {
        let tags = message.tags ?? []
        let source = message.origin.flatMap { $0.isEmpty ? nil : $0 }
        let commandName = message.command.commandAsString

        func make(_ command: String, _ parameters: [String], trailing: Bool = false) -> IRCRawMessage {
            IRCRawMessage(tags: tags, source: source, command: command, parameters: parameters, forcesTrailingParameter: trailing)
        }
        func requireTargets(_ count: Int) throws {
            guard count > 0 else {
                throw IRCStandardError(.missingTarget, "\(commandName) needs at least one target")
            }
        }
        func unsupported() -> IRCStandardError {
            IRCStandardError(.unsupportedOnStandardIRC, "\(commandName) has no standard IRC form")
        }
        func modeChange(_ channel: NeedleTailChannel, _ change: String, _ parameter: String) -> IRCRawMessage {
            make("MODE", [channel.stringValue, change, parameter])
        }
        func optional(_ values: String?...) -> [String] { values.compactMap { $0 } }

        switch message.command {
        case .numeric(_, let arguments), .otherNumeric(_, let arguments):
            return make(commandName, optional(message.target) + arguments, trailing: !arguments.isEmpty)
        case .otherCommand(let command, let arguments):
            let name = command.uppercased()
            let trailing = textCommandParameterCount[name] == arguments.count
            return make(command, arguments, trailing: trailing)

        case .nick(let nick):
            return make("NICK", [nick.stringValue])
        case .user(let details):
            return make("USER", [details.username, "0", "*", details.realname], trailing: true)
        case .isOn(let nicks):
            try requireTargets(nicks.count)
            return make("ISON", nicks.map(\.stringValue))
        case .quit(let reason):
            return make("QUIT", optional(reason), trailing: reason != nil)
        case .ping(let server, let server2):
            return make("PING", optional(server, server2))
        case .pong(let server, let server2):
            return make("PONG", optional(server, server2))
        case .join(let channels, let keys):
            try requireTargets(channels.count)
            var parameters = [channels.map(\.stringValue).joined(separator: ",")]
            if let keys, !keys.isEmpty { parameters.append(keys.joined(separator: ",")) }
            return make("JOIN", parameters)
        case .join0:
            return make("JOIN", ["0"])
        case .part(let channels):
            try requireTargets(channels.count)
            return make("PART", [channels.map(\.stringValue).joined(separator: ",")])
        case .list(let channels, let target):
            if let channels, !channels.isEmpty {
                return make("LIST", [channels.map(\.stringValue).joined(separator: ",")] + optional(target))
            }
            return make("LIST", optional(target))
        case .privMsg(let recipients, let text), .notice(let recipients, let text):
            try requireTargets(recipients.count)
            return make(commandName, [recipients.map(\.stringValue).joined(separator: ","), text], trailing: true)
        case .mode(let nick, let add, let remove):
            let change = modeString(add: add?.stringValue, remove: remove?.stringValue)
            return make("MODE", [nick.stringValue] + (change.isEmpty ? [] : [change]))
        case .modeGet(let nick):
            return make("MODE", [nick.stringValue])
        case .channelMode(let channel, let add, let addParameters, let remove, let removeParameters):
            let change = modeString(add: add?.stringValue, remove: remove?.stringValue)
            return make(
                "MODE",
                [channel.stringValue] + (change.isEmpty ? [] : [change]) + (addParameters ?? []) + (removeParameters ?? [])
            )
        case .channelModeGet(let channel):
            return make("MODE", [channel.stringValue])
        case .channelModeGetBanMask(let channel):
            return make("MODE", [channel.stringValue, "+b"])
        case .whois(let server, let usermasks):
            try requireTargets(usermasks.count)
            return make("WHOIS", optional(server) + [usermasks.joined(separator: ",")])
        case .who(let usermask, let onlyOperators):
            if let usermask { return make("WHO", [usermask] + (onlyOperators ? ["o"] : [])) }
            return make("WHO", onlyOperators ? ["0", "o"] : [])
        case .kick(let channels, let users, let comments):
            try requireTargets(channels.count)
            try requireTargets(users.count)
            let comment = comments.filter { !$0.isEmpty }.joined(separator: " ")
            return make(
                "KICK",
                [channels.map(\.stringValue).joined(separator: ","), users.map(\.stringValue).joined(separator: ",")]
                    + (comment.isEmpty ? [] : [comment]),
                trailing: !comment.isEmpty
            )
        case .kill(let nick, let comment):
            return make("KILL", [nick.stringValue, comment], trailing: true)
        case .sQuit(let server, let reason):
            return make("SQUIT", [server, reason], trailing: true)
        case .links(let mask):
            return make("LINKS", optional(mask))
        case .cap(let subcommand, let capabilities):
            let forcesTrailing = !capabilities.isEmpty
                && (message.target != nil || [.req, .ack, .nak].contains(subcommand))
            return make(
                "CAP",
                optional(message.target) + [subcommand.rawValue] + (capabilities.isEmpty ? [] : [capabilities.joined(separator: " ")]),
                trailing: forcesTrailing
            )
        case .away(let text):
            return make("AWAY", optional(text), trailing: text != nil)
        case .oper(let name, let password):
            return make("OPER", [name, password])
        case .knock(let channel, let text):
            return make("KNOCK", [channel.stringValue] + optional(text), trailing: text != nil)
        case .silence(let mask):
            return make("SILENCE", [mask])
        case .invite(let nick, let channel):
            return make("INVITE", [nick.stringValue, channel.stringValue])
        case .topic(let channel, let topic):
            return make("TOPIC", [channel.stringValue] + optional(topic), trailing: topic != nil)
        case .names(let channel):
            return make("NAMES", optional(channel?.stringValue))
        case .ban(let channel, let mask):
            return modeChange(channel, "+b", mask)
        case .unban(let channel, let mask):
            return modeChange(channel, "-b", mask)
        case .except(let channel, let mask):
            return modeChange(channel, "+e", mask)
        case .unexcept(let channel, let mask):
            return modeChange(channel, "-e", mask)
        case .inviteExcept(let channel, let mask):
            return modeChange(channel, "+I", mask)
        case .uninviteExcept(let channel, let mask):
            return modeChange(channel, "-I", mask)
        case .voice(let channel, let nick):
            return modeChange(channel, "+v", nick.stringValue)
        case .devoice(let channel, let nick):
            return modeChange(channel, "-v", nick.stringValue)
        case .halfop(let channel, let nick):
            return modeChange(channel, "+h", nick.stringValue)
        case .dehalfop(let channel, let nick):
            return modeChange(channel, "-h", nick.stringValue)
        case .rehash, .restart, .die, .map:
            return make(commandName, [])
        case .connect(let target, let port, let remote):
            return make("CONNECT", [target, String(port)] + optional(remote))
        case .trace(let target), .admin(let target), .info(let target), .version(let target),
             .time(let target), .motd(let target), .rules(let target), .users(let target):
            return make(commandName, optional(target))
        case .stats(let query, let target):
            return make("STATS", optional(query, target))
        case .lusers(let mask, let target):
            return make("LUSERS", optional(mask, target))
        case .wallops(let text), .globops(let text), .locops(let text):
            return make(commandName, [text], trailing: true)
        case .ctcp(let target, let command, let argument):
            return make("PRIVMSG", [target.stringValue, ctcpText(command, argument)], trailing: true)
        case .ctcpreply(let target, let command, let argument):
            return make("NOTICE", [target.stringValue, ctcpText(command, argument.isEmpty ? nil : argument)], trailing: true)

        // Mode letters for these differ between server families (e.g. `+q` is quiet on
        // Solanum but owner on UnrealIRCd and InspIRCd); send `.otherCommand("MODE", ...)` instead.
        case .quiet, .unquiet, .protect, .deprotect, .owner, .deowner, .kickban, .clearmode:
            throw unsupported()
        case .server, .adl, .odlist:
            throw unsupported()
        case .dccChat, .dccSend, .dccResume, .sdccChat, .sdccSend, .sdccResume:
            throw unsupported()
        }
    }

    private static func modeString(add: String?, remove: String?) -> String {
        var value = ""
        if let add, !add.isEmpty { value += "+\(add)" }
        if let remove, !remove.isEmpty { value += "-\(remove)" }
        return value
    }

    private static func ctcpText(_ command: String, _ argument: String?) -> String {
        "\u{1}\(command)\(argument.map { " \($0)" } ?? "")\u{1}"
    }
}

// MARK: - Conveniences on the existing types

extension IRCMessage {
    /// Maps a standard IRC message onto the typed model. See ``IRCStandardTranslator/message(from:)``.
    public init(standardIRC raw: IRCRawMessage) {
        self = IRCStandardTranslator.message(from: raw)
    }

    /// The standard IRC wire form of this message, without CRLF.
    public func standardIRCWireLine() throws -> String {
        try IRCStandardTranslator.rawMessage(from: self).wireLine()
    }
}

extension IRCRawMessage {
    /// Writes a typed message the standard way. See ``IRCStandardTranslator/rawMessage(from:)``.
    public init(standardIRC message: IRCMessage) throws {
        self = try IRCStandardTranslator.rawMessage(from: message)
    }
}
