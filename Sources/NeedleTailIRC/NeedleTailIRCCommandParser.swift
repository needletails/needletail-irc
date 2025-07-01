//
//  NeedleTailIRCCommandParser.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/22.
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
import NeedleTailLogger

/// A comprehensive command parser for IRC protocol commands that converts string-based commands
/// into structured `IRCCommand` objects.
///
/// The `NeedleTailIRCCommandParser` provides functionality to parse IRC command strings and their
/// arguments into type-safe `IRCCommand` instances. It supports all standard IRC commands as defined
/// in RFC 2812 and RFC 1459, plus additional IRCv3 extensions and custom commands.
///
/// ## Usage
///
/// ```swift
/// // Parse a NICK command
/// let command = try NeedleTailIRCCommandParser.parse(
///     command: "NICK",
///     arguments: ["alice_12345678-1234-1234-1234-123456789abc"]
/// )
///
/// // Parse a PRIVMSG command
/// let messageCommand = try NeedleTailIRCCommandParser.parse(
///     command: "PRIVMSG",
///     arguments: ["#general", "Hello, everyone!"]
/// )
/// ```
///
/// ## Supported Commands
///
/// The parser supports all standard IRC commands including:
/// - **Connection Commands**: NICK, USER, QUIT, PASS
/// - **Channel Commands**: JOIN, PART, LIST, MODE
/// - **Messaging Commands**: PRIVMSG, NOTICE
/// - **Information Commands**: WHOIS, WHO, ISON
/// - **Administrative Commands**: KICK, KILL, OPER
/// - **Server Commands**: PING, PONG, SQUIT
/// - **DCC Commands**: DCCCHAT, DCCSEND, DCCRESUME
/// - **CAP Commands**: IRCv3 capability negotiation
///
/// ## Error Handling
///
/// The parser provides detailed error information through `CommandParserErrors`:
/// - Invalid nickname formats
/// - Missing or unexpected arguments
/// - Invalid channel names
/// - Missing recipients
/// - Invalid message targets
///
/// ## Thread Safety
///
/// This parser is thread-safe and can be used concurrently from multiple threads.
public struct NeedleTailIRCCommandParser: Sendable {
    
    /// Errors that can occur during command parsing.
    public enum CommandParserErrors: Error, Sendable {
        /// Invalid nickname format or content.
        case invalidNick(String)
        /// Invalid user information.
        case invalidInfo
        /// Invalid argument format or content.
        case invalidArgument(String)
        /// Invalid channel name format.
        case invalidChannelName(String)
        /// Missing required recipient information.
        case missingRecipient
        /// Invalid message target specification.
        case invalidMessageTarget(String)
        /// Missing required argument.
        case missingArgument
        /// Unexpected number of arguments provided.
        case unexpectedArguments(String)
    }
    
    /// Parses the IRC command and its arguments into a structured `IRCCommand` object.
    ///
    /// This method is the main entry point for command parsing. It takes a command string
    /// and an array of arguments, then delegates to the appropriate parsing method based
    /// on the command type.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Parse a NICK command
    /// let nickCommand = try NeedleTailIRCCommandParser.parse(
    ///     command: "NICK",
    ///     arguments: ["alice_12345678-1234-1234-1234-123456789abc"]
    /// )
    ///
    /// // Parse a JOIN command
    /// let joinCommand = try NeedleTailIRCCommandParser.parse(
    ///     command: "JOIN",
    ///     arguments: ["#general,#random", "key1,key2"]
    /// )
    ///
    /// // Parse a PRIVMSG command
    /// let privMsgCommand = try NeedleTailIRCCommandParser.parse(
    ///     command: "PRIVMSG",
    ///     arguments: ["#general", "Hello, everyone!"]
    /// )
    /// ```
    ///
    /// ## Supported Commands
    ///
    /// The parser supports all standard IRC commands:
    /// - **Connection**: NICK, USER, QUIT, PASS
    /// - **Channels**: JOIN, PART, LIST, MODE
    /// - **Messaging**: PRIVMSG, NOTICE
    /// - **Information**: WHOIS, WHO, ISON
    /// - **Administrative**: KICK, KILL, OPER
    /// - **Server**: PING, PONG, SQUIT, SERVER, LINKS
    /// - **DCC**: DCCCHAT, DCCSEND, DCCRESUME (both secure and non-secure variants)
    /// - **IRCv3**: CAP commands
    /// - **Additional**: All RFC 2812 and RFC 1459 commands
    ///
    /// - Parameters:
    ///   - command: The command string (e.g., "NICK", "PRIVMSG").
    ///   - arguments: The list of arguments associated with the command.
    /// - Throws: Various `CommandParserErrors` based on invalid input.
    /// - Returns: An `IRCCommand` instance representing the parsed command.
    public static func parse(command: String, arguments: [String]) throws -> IRCCommand {
        let uppercasedCommand = command.uppercased()
        
        switch uppercasedCommand {
        case Constants.nick.rawValue:
            return try parseNickCommand(arguments)
        case Constants.user.rawValue:
            return try parseUserCommand(arguments)
        case Constants.quit.rawValue:
            return try parseQuitCommand(arguments)
        case Constants.join.rawValue:
            return try parseJoinCommand(arguments)
        case Constants.part.rawValue:
            return try parsePartCommand(arguments)
        case Constants.mode.rawValue:
            return try parseModeCommand(arguments)
        case Constants.list.rawValue:
            return try parseListCommand(arguments)
        case Constants.kick.rawValue:
            return try parseKickCommand(arguments)
        case Constants.privMsg.rawValue, Constants.notice.rawValue:
            return try parsePrivMsgOrNoticeCommand(arguments, command: uppercasedCommand)
        case Constants.who.rawValue:
            return try parseWhoCommand(arguments)
        case Constants.whoIs.rawValue:
            return try parseWhoIsCommand(arguments)
        case Constants.kill.rawValue:
            return try parseKillCommand(arguments)
        case Constants.ping.rawValue:
            return try parsePingCommand(arguments)
        case Constants.pong.rawValue:
            return try parsePongCommand(arguments)
        case Constants.isOn.rawValue:
            return try parseIsOnCommand(arguments)
        case Constants.cap.rawValue:
            return try parseCapCommand(arguments)
        case Constants.dccChat.rawValue:
            return try parseDCCChatCommand(arguments, isSecure: false)
        case Constants.sdccChat.rawValue:
            return try parseDCCChatCommand(arguments, isSecure: true)
        case Constants.dccSend.rawValue:
            return try parseDCCSendCommand(arguments, isSecure: false)
        case Constants.sdccSend.rawValue:
            return try parseDCCSendCommand(arguments, isSecure: true)
        case Constants.dccResume.rawValue:
            return try parseDCCResumeCommand(arguments, isSecure: false)
        case Constants.sdccResume.rawValue:
            return try parseDCCResumeCommand(arguments, isSecure: true)
        case Constants.sQuit.rawValue:
            return try parseSQuitCommand(arguments)
        case Constants.server.rawValue:
            return try parseServerCommand(arguments)
        case Constants.links.rawValue:
            return try parseLinksCommand(arguments)
        case Constants.away.rawValue:
            return try parseAwayCommand(arguments)
        case Constants.oper.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.knock.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.silence.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.invite.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.topic.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.names.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.ban.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.unban.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.kickban.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.clearmode.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.except.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.unexcept.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.inviteExcept.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.uninviteExcept.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.quiet.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.unquiet.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.voice.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.devoice.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.halfop.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.dehalfop.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.protect.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.deprotect.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.owner.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.deowner.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.rehash.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.restart.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.die.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.connect.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.trace.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.stats.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.admin.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.info.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.version.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.time.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.lusers.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.motd.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.rules.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.map.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.users.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.wallops.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.globops.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.locops.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.adl.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.odlist.rawValue:
            return .otherCommand(uppercasedCommand, arguments)
        case Constants.ctcp.rawValue:
            return try parseCTCPCommand(arguments)
        case Constants.ctcpreply.rawValue:
            return try parseCTCPReplyCommand(arguments)
        default:
            return .otherCommand(uppercasedCommand, arguments)
        }
    }
    
    // MARK: - Individual Command Parsing Methods
    
    /// Parses a NICK command with the format: NICK <nickname>_<deviceId>
    /// - Parameter arguments: Array containing the nickname with device ID.
    /// - Throws: `CommandParserErrors.invalidNick` or `CommandParserErrors.unexpectedArguments`.
    /// - Returns: An `IRCCommand.nick` instance.
    private static func parseNickCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 1 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)")
        }
        let first = arguments.first ?? ""
        let splitNick = first.split(separator: "_", maxSplits: 1)
        
        guard let name = splitNick.first.map(String.init), let id = splitNick.last.map(String.init), let deviceId = UUID(uuidString: id) else {
            throw CommandParserErrors.invalidNick(first)
        }
        
        guard let nick = NeedleTailNick(name: name, deviceId: deviceId) else {
            throw CommandParserErrors.invalidNick("\(name) \(deviceId)")
        }
        return .nick(nick)
    }
    
    /// Parses a USER command with the format: USER <username> <hostname> <servername> <realname>
    /// - Parameter arguments: Array containing username, hostname, servername, and realname.
    /// - Throws: `CommandParserErrors.unexpectedArguments` or `CommandParserErrors.invalidInfo`.
    /// - Returns: An `IRCCommand.user` instance.
    private static func parseUserCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 4 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 4 Found: \(arguments.count)")
        }
        
        let username = arguments[0]
        let realname = arguments[3]
        let modeOrHostname = arguments[1]
        let maskOrServername = arguments[2]
        
        if let mode = UInt32(modeOrHostname) {
            let userMode = IRCUserModeFlags(rawValue: mode)
            return .user(IRCUserDetails(username: username, userModeFlags: userMode, realname: realname))
        } else {
            return .user(IRCUserDetails(username: username, hostname: modeOrHostname, servername: maskOrServername, realname: realname))
        }
    }
    
    private static func parseQuitCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 1 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)")
        }
        return .quit(arguments.first)
    }
    
    private static func parseJoinCommand(_ arguments: [String]) throws -> IRCCommand {
        guard (1...2).contains(arguments.count) else {
            throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)")
        }
        // Only treat as join0 if the arguments are exactly ["0"]
        if arguments.count == 1, arguments[0].trimmingCharacters(in: .whitespacesAndNewlines) == "0" {
            return .join0
        }
        let (channels, keys, _) = try getChannels(arguments)
        return .join(channels: channels, keys: keys)
    }
    
    private static func parsePartCommand(_ arguments: [String]) throws -> IRCCommand {
        guard (1...2).contains(arguments.count) else {
            throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments \(arguments.count)")
        }
        let (channels, _, _) = try getChannels(arguments)
        return .part(channels: channels)
    }
    
    private static func parseModeCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count >= 1, let recipientString = arguments.first, let recipient = IRCMessageRecipient(recipientString) else {
            throw CommandParserErrors.missingRecipient
        }
        
        switch recipient {
        case .channel(let channelName):
            return try parseChannelMode(arguments, channelName: channelName.stringValue)
        case .nick(let nick):
            return try parseNickMode(arguments, nick: nick)
        case .all:
            throw CommandParserErrors.invalidMessageTarget(arguments.first ?? "")
        }
    }
    
    private static func parseChannelMode(_ arguments: [String], channelName: String) throws -> IRCCommand {
        guard let channelName = channelName.constructedChannel else { throw CommandParserErrors.invalidChannelName(channelName) }
        guard arguments.count > 1 else { return .channelModeGet(channelName) }
        
        var add = IRCChannelPermissions()
        var remove = IRCChannelPermissions()
        var addParameters = [String]()
        var removeParameters = [String]()
        
        let args = arguments.dropFirst()
        if let addIndex = args.firstIndex(where: { $0.contains(Constants.plus.rawValue) }) {
            add.insert(IRCChannelPermissions(String(args[addIndex].dropFirst()))!)
            if args.count >= 2, !args[1].contains(Constants.minus.rawValue) {
                addParameters.append(contentsOf: args[2].components(separatedBy: Constants.comma.rawValue))
            }
        }
        
        if let minusIndex = args.firstIndex(where: { $0.contains(Constants.minus.rawValue) }) {
            remove.insert(IRCChannelPermissions(String(args[minusIndex].dropFirst()))!)
            if args.count >= 2, let lastArg = args.last, !lastArg.contains(Constants.minus.rawValue) {
                removeParameters.append(contentsOf: lastArg.components(separatedBy: Constants.comma.rawValue))
            }
        }
        
        if add == .banMask && addParameters.isEmpty && remove.isEmpty {
            return .channelModeGetBanMask(channelName)
        } else {
            return .channelMode(channelName, addMode: add, addParameters: addParameters, removeMode: remove, removeParameters: removeParameters)
        }
    }
    
    private static func parseNickMode(_ arguments: [String], nick: NeedleTailNick) throws -> IRCCommand {
        guard arguments.count > 1 else { return .modeGet(nick) }
        
        var add = IRCUserModeFlags()
        var remove = IRCUserModeFlags()
        
        for arg in arguments.dropFirst() {
            var isAdd = true
            for c in arg {
                if c == Character(Constants.plus.rawValue) {
                    isAdd = true
                } else if c == Character(Constants.minus.rawValue) {
                    isAdd = false
                } else if let mode = IRCUserModeFlags(String(c)) {
                    if isAdd {
                        add.insert(mode)
                    } else {
                        remove.insert(mode)
                    }
                } else {
                    NeedleTailLogger(.init(label: "[ com.needletails.irc.command.parser ]")).log(level: .warning, message: "IRCParser: unexpected IRC mode: \(c) \(arg)")
                }
            }
        }
        return .mode(nick, add: add, remove: remove)
    }
    
    private static func parseListCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count <= 2 else {
            throw CommandParserErrors.unexpectedArguments("Expected at max 2 arguments Found: \(arguments.count)")
        }
        
        if arguments.first == Constants.star.rawValue {
            return .list(channels: [], target: arguments.joined(separator: Constants.space.rawValue))
        } else {
            let (channels, serverList, _) = try getChannels(arguments)
            return .list(channels: channels, target: serverList?.first)
        }
    }
    
    private static func parseKickCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 3 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 3 Found: \(arguments.count)")
        }
        
        // Parse channels (first argument)
        let channelStrings = arguments[0].split(separator: ",").map(String.init)
        let channels = try channelStrings.compactMap { channelName in
            guard let channel = channelName.constructedChannel else {
                throw CommandParserErrors.invalidChannelName(channelName)
            }
            return channel
        }
        
        // Parse users (second argument)
        let userStrings = arguments[1].split(separator: ",").map(String.init)
        let users = try userStrings.compactMap { userName in
            guard let user = userName.constructedNick else {
                throw CommandParserErrors.invalidNick(userName)
            }
            return user
        }
        
        // Parse reason (third argument, remove colon prefix if present)
        let reason = arguments[2].hasPrefix(":") ? String(arguments[2].dropFirst()) : arguments[2]
        
        return .kick(channels, users, [reason])
    }
    
    private static func parseCTCPCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count >= 2 else {
            throw CommandParserErrors.unexpectedArguments("Expected at least 2 arguments for CTCP, found: \(arguments.count)")
        }
        
        guard let target = arguments[0].constructedNick else {
            throw CommandParserErrors.invalidNick(arguments[0])
        }
        
        let command = arguments[1]
        let argument = arguments.count > 2 ? arguments[2] : nil
        
        return .ctcp(target, command, argument)
    }
    
    private static func parseCTCPReplyCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 3 else {
            throw CommandParserErrors.unexpectedArguments("Expected 3 arguments for CTCPREPLY, found: \(arguments.count)")
        }
        
        guard let target = arguments[0].constructedNick else {
            throw CommandParserErrors.invalidNick(arguments[0])
        }
        
        let command = arguments[1]
        let argument = arguments[2]
        
        return .ctcpreply(target, command, argument)
    }
    
    private static func parsePrivMsgOrNoticeCommand(_ arguments: [String], command: String) throws -> IRCCommand {
        guard arguments.count == 2, let recipientString = arguments.first, let message = arguments.last else {
            throw CommandParserErrors.missingArgument
        }
        
        let recipients = recipientString.split(separator: ",").compactMap { IRCMessageRecipient(String($0.trimmingCharacters(in: .whitespacesAndNewlines))) }
        
        return command == Constants.privMsg.rawValue ? .privMsg(recipients, message) : .notice(recipients, message)
    }
    
    private static func parseWhoCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count <= 2 else {
            throw CommandParserErrors.unexpectedArguments("Expected less than or equal to: 2 Found: \(arguments.count)")
        }
        
        guard let first = arguments.first else {
            throw CommandParserErrors.missingArgument
        }
        
        let onlyOperators = arguments.count == 2 && arguments[1] == Constants.oString.rawValue
        return .who(usermask: first, onlyOperators: onlyOperators)
    }
    
    private static func parseWhoIsCommand(_ arguments: [String]) throws -> IRCCommand {
        guard (1...2).contains(arguments.count) else {
            throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)")
        }
        
        let maskArg = arguments.count == 1 ? arguments.first! : arguments.last!
        let masks = maskArg.split(separator: ",").map(String.init)
        return .whois(server: arguments.count == 1 ? nil : arguments.first, usermasks: Array(masks))
    }
    
    private static func parseKillCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 2 else {
            throw CommandParserErrors.unexpectedArguments("Expected 2 arguments Found: \(arguments.count)")
        }
        
        let first = arguments.first!.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = arguments.last!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let nick = first.components(separatedBy: ",").compactMap({ $0.constructedNick }).first else {
            throw CommandParserErrors.invalidNick(first)
        }
        
        return .kill(nick, last)
    }
    
    private static func parsePingCommand(_ arguments: [String]) throws -> IRCCommand {
        guard (1...2).contains(arguments.count) else {
            throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)")
        }
        
        let first = arguments.first!
        let last = arguments.count > 1 ? arguments.last : nil
        return .ping(server: first, server2: last)
    }
    
    private static func parsePongCommand(_ arguments: [String]) throws -> IRCCommand {
        guard (1...2).contains(arguments.count) else {
            throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)")
        }
        
        let first = arguments.first!
        let last = arguments.count > 1 ? arguments.last : nil
        return .pong(server: first, server2: last)
    }
    
    private static func parseIsOnCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count >= 1 else {
            throw CommandParserErrors.unexpectedArguments("Expected at least 1 arguments Found: \(arguments.count)")
        }
        
        let nicks = try arguments.compactMap { arg in
            guard let nick = arg.constructedNick else {
                throw CommandParserErrors.invalidNick(arg)
            }
            return nick
        }
        
        return .isOn(nicks)
    }
    
    private static func parseCapCommand(_ arguments: [String]) throws -> IRCCommand {
        guard (1...2).contains(arguments.count) else {
            throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)")
        }
        
        guard let first = arguments.first else {
            throw CommandParserErrors.missingArgument
        }
        
        guard let subcmd = IRCCommand.CAPSubCommand(rawValue: first) else {
            throw CommandParserErrors.invalidArgument("Invalid CAP command: \(first)")
        }
        
        let capIDs = arguments.count > 1 ? arguments[1].components(separatedBy: Constants.space.rawValue) : []
        return .cap(subcmd, capIDs)
    }
    
    private static func parseDCCChatCommand(_ arguments: [String], isSecure: Bool) throws -> IRCCommand {
        guard arguments.count == 3 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 3 Found: \(arguments.count)")
        }
        
        let nickname = arguments[0]
        let ipaddress = arguments[1]
        let port = arguments[2]
        guard let constructedNick = nickname.constructedNick else { throw NeedleTailError.nilNickName }
        return isSecure ? .sdccChat(constructedNick, ipaddress, Int(port) ?? 0) : .dccChat(constructedNick, ipaddress, Int(port) ?? 0)
    }
    
    private static func parseDCCSendCommand(_ arguments: [String], isSecure: Bool) throws -> IRCCommand {
        guard arguments.count == 5 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 5 Found: \(arguments.count)")
        }
        
        let nickname = arguments[0]
        let filename = arguments[1]
        let filesize = arguments[2]
        let isAddress = arguments[3]
        let port = arguments[4]
        guard let constructedNick = nickname.constructedNick else { throw NeedleTailError.nilNickName }
        return isSecure ? .sdccSend(constructedNick, filename, Int(filesize) ?? 0, isAddress, Int(port) ?? 0) : .dccSend(constructedNick, filename, Int(filesize) ?? 0, isAddress, Int(port) ?? 0)
    }
    
    private static func parseDCCResumeCommand(_ arguments: [String], isSecure: Bool) throws -> IRCCommand {
        guard arguments.count == 6 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 6 Found: \(arguments.count)")
        }
        
        let nickname = arguments[0]
        let filename = arguments[1]
        let filesize = arguments[2]
        let isAddress = arguments[3]
        let port = arguments[4]
        let offset = arguments[5]
        guard let constructedNick = nickname.constructedNick else { throw NeedleTailError.nilNickName }
        return isSecure ? .sdccResume(constructedNick, filename, Int(filesize) ?? 0, isAddress, Int(port) ?? 0, Int(offset) ?? 0) : .dccResume(constructedNick, filename, Int(filesize) ?? 0, isAddress, Int(port) ?? 0, Int(offset) ?? 0)
    }
    
    private static func parseSQuitCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 2 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)")
        }
        let serverName = arguments[0]
        let reason = arguments[1]
        return .sQuit(serverName, reason)
    }
    
    private static func parseServerCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 4 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)")
        }
        let serverName = arguments[0]
        let version = arguments[1]
        let hopCount = arguments[2]
        let info = arguments[3]
        return .server(serverName, version, Int(hopCount) ?? 0, info)
    }
    
    private static func parseLinksCommand(_ arguments: [String]) throws -> IRCCommand {
        guard arguments.count == 1 else {
            throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)")
        }
        let mask = arguments[0]
        return .links(mask)
    }
    
    private static func parseAwayCommand(_ arguments: [String]) throws -> IRCCommand {
        // AWAY command can have 0 or 1 arguments
        // If no arguments, remove away status
        // If 1 argument, set away message
        if arguments.isEmpty {
            return .away(nil)
        } else {
            return .away(arguments[0])
        }
    }
    
    /// Extracts channels and optional metadata/message from the arguments.
    /// - Parameter arguments: The list of arguments containing channels and metadata.
    /// - Throws: `CommandParserErrors` if any argument is invalid.
    /// - Returns: A tuple of verified channels, optional metadata list, and optional message list.
    static func getChannels(_ arguments: [String]) throws -> ([NeedleTailChannel], [String]?, [String]) {
        var verifiedChannels = [NeedleTailChannel]()
        var metadataList = [String]()
        var messageList = [String]()
        
        let joinedArguments = arguments.count == 1 ? arguments[0].components(separatedBy: Constants.space.rawValue) : arguments
        guard let channelStrings = joinedArguments.first else { throw CommandParserErrors.invalidArgument("") }
        
        for channelName in channelStrings.split(separator: ",").map(String.init) {
            guard let verified = channelName.constructedChannel else {
                throw CommandParserErrors.invalidChannelName(channelName)
            }
            verifiedChannels.append(verified)
        }
        
        if joinedArguments.indices.contains(1) {
            let metadata = joinedArguments[1]
            metadataList = metadata.split(separator: ",").map(String.init)
            if metadataList.isEmpty {
                messageList.append(metadata)
            }
            return (verifiedChannels, metadataList, [])
        } else if joinedArguments.indices.contains(2) {
            let message = joinedArguments[2]
            messageList = message.split(separator: ",").map(String.init)
            return (verifiedChannels, metadataList, messageList)
        } else {
            return (verifiedChannels, nil, [])
        }
    }
}

public extension IRCCommand {
    
    /// Initializes an `IRCCommand` instance from the command string and arguments.
    /// - Parameters:
    ///   - command: The command string (e.g., "NICK").
    ///   - arguments: The list of arguments associated with the command.
    /// - Throws: `CommandParserErrors` for invalid commands.
    init(command: String, arguments: [String]) throws {
        self = try NeedleTailIRCCommandParser.parse(command: command, arguments: arguments)
    }
    
    /// Initializes an `IRCCommand` instance from a numeric code and arguments.
    /// - Parameters:
    ///   - numeric: The numeric code representing the command.
    ///   - arguments: The list of arguments associated with the command.
    /// - Throws: `CommandParserErrors` for invalid commands.
    init(numeric: Int, arguments: [String]) throws {
        if let code = IRCCommandCode(rawValue: numeric) {
            self = .numeric(code, arguments)
        } else {
            self = .otherNumeric(numeric, arguments)
        }
    }
}
