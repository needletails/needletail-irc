//
//  IRCCommand.swift
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

/// A comprehensive representation of all IRC commands supported by the protocol.
///
/// `IRCCommand` provides type-safe access to all standard IRC commands as defined in RFC 2812 and RFC 1459,
/// plus additional IRCv3 extensions and custom commands. Each command case includes the necessary
/// parameters and provides compile-time safety for IRC operations.
///
/// ## Command Categories
///
/// The commands are organized into several categories:
/// - **Connection Commands**: NICK, USER, PASS, QUIT
/// - **Channel Commands**: JOIN, PART, LIST, MODE
/// - **Messaging Commands**: PRIVMSG, NOTICE
/// - **Information Commands**: WHOIS, WHO, ISON
/// - **Administrative Commands**: KICK, KILL, OPER
/// - **Server Commands**: PING, PONG, SQUIT
/// - **DCC Commands**: DCCCHAT, DCCSEND, DCCRESUME
/// - **CAP Commands**: IRCv3 capability negotiation
/// - **Numeric Commands**: Server responses and error codes
///
/// ## Examples
///
/// ```swift
/// // Join a channel
/// let joinCommand = IRCCommand.join(channels: [NeedleTailChannel("#general")!], keys: nil)
///
/// // Send a private message
/// let privMsgCommand = IRCCommand.privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!")
///
/// // Change nickname
/// let nickCommand = IRCCommand.nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)
///
/// // Set user mode
/// let modeCommand = IRCCommand.mode(nick, add: .invisible, remove: nil)
/// ```
///
/// ## Thread Safety
///
/// This enum is thread-safe and can be used concurrently from multiple threads.
public enum IRCCommand: Codable, Sendable {
    
    // MARK: - Cases
    
    /// The NICK command is used to change the user's nickname on the IRC network.
    case nick(NeedleTailNick)
    /// The USER command is part of the initial registration process when a user connects to an IRC server.
    case user(IRCUserDetails)
    /// The ISON command queries the server about the online status of a list of nicknames.
    case isOn([NeedleTailNick])
    /// The QUIT command is used to gracefully disconnect from the IRC network.
    case quit(String?)
    /// The PING command is sent by the server to verify that the client is still connected.
    case ping(server: String, server2: String?)
    /// The PONG command responds to a PING message sent by the server.
    case pong(server: String, server2: String?)
    /// The JOIN command allows users to join specific channels, optionally providing keys.
    case join(channels: [NeedleTailChannel], keys: [String]?)
    /// JOIN0 is used to unsubscribe from all channels.
    case join0
    /// The PART command indicates a user's intention to leave a channel.
    case part(channels: [NeedleTailChannel])
    /// PART with a part message: `PART <channel> *( "," <channel> ) :<message>` (RFC 2812 §3.2.2).
    case partMessage(channels: [NeedleTailChannel], message: String)
    /// The LIST command helps users discover channels of interest.
    case list(channels: [NeedleTailChannel]?, target: String?)
    /// PRIVMSG is used for chat messages and conversations.
    case privMsg([IRCMessageRecipient], String)
    /// NOTICE sends important messages that do not trigger automatic responses.
    case notice([IRCMessageRecipient], String)
    /// The MODE command sets specific modes for a given nickname.
    case mode(NeedleTailNick, add: IRCUserModeFlags?, remove: IRCUserModeFlags?)
    /// The MODEGET command retrieves the modes for a given nickname.
    case modeGet(NeedleTailNick)
    /// `MODE <channel> +<modes> <parameters> -<modes> <parameters>` with each sign's modes as a set.
    ///
    /// The parameters pair with the modes that take one in ``IRCChannelPermissions/stringValue``
    /// order (`o` before `v`, `l` before `k`), and extra parameters go to the last such mode, so
    /// `addMode: [.voice, .channelOperator], addParameters: ["bob", "alice"]` ops bob and voices
    /// alice. The parser stores parameters in that order. A line the set can't express, such as
    /// `+oov alice bob carol`, parses as ``channelModeChanges(_:_:)`` instead.
    case channelMode(NeedleTailChannel, addMode: IRCChannelPermissions?, addParameters: [String]?, removeMode: IRCChannelPermissions?, removeParameters: [String]?)
    /// `MODE <channel> <modestring> <parameters>` with every change kept in order
    /// (RFC 2812 §3.2.3), each pairing one mode with its parameter.
    case channelModeChanges(NeedleTailChannel, [IRCChannelModeChange])
    /// CHANNELMODE_GET retrieves the modes for a given channel.
    case channelModeGet(NeedleTailChannel)
    /// CHANNELMODE_GET_BANMASK retrieves banned users for a given channel.
    case channelModeGetBanMask(NeedleTailChannel)
    /// The WHOIS command provides information about a specified user.
    case whois(server: String?, usermasks: [String])
    /// The WHO command returns basic information about users.
    case who(usermask: String?, onlyOperators: Bool)
    /// KICK removes a user from a channel, allowing them to rejoin.
    case kick([NeedleTailChannel], [NeedleTailNick], [String])
    /// KILL disconnects a user from the IRC network.
    case kill(NeedleTailNick, String)
    /// This message is used to remove a server from the network. It informs other servers that a specific server is being shut down or disconnected.
    case sQuit(String, String) // SQUIT command with server name and reason
    /// This message is used when a server connects to another server. It includes information about the server, such as its name, version, and the number of hops from the originating server.
    case server(String, String, Int, String) // SERVER command with name, version, hopcount, and info
    /// A server can request a list of connected servers from another server using the LINKS command.
    case links(String?) // LINKS command with an optional mask
    /// Numeric commands are standardized codes for communication responses in IRC.
    case numeric(IRCCommandCode, [String])
    /// Other commands that may be used depending on the server.
    case otherCommand(String, [String])
    /// Other numeric commands used in IRC communication.
    case otherNumeric(Int, [String])
    /// The CAP command manages capabilities between the client and server.
    case cap(CAPSubCommand, [String])
    
    // MARK: - CAP Subcommands
    
    public enum CAPSubCommand: String, Sendable, Codable {
        case ls = "LS", list = "LIST", req = "REQ", ack = "ACK", nak = "NAK", end = "END"
        public var commandAsString: String { rawValue }
    }
    
    // DCC Chat <nick> <host> <ip>
    case dccChat(NeedleTailNick, String, Int)
    // DCC Chat <nick> <filename> <filesize> <host> <ip>
    case dccSend(NeedleTailNick, String, Int, String, Int)
    // offset is bytes to resume
    // DCC RESUME <nick> <filename> <file_size> <ip_address> <port> <offset>
    case dccResume(NeedleTailNick, String, Int, String, Int, Int)
    
    case sdccChat(NeedleTailNick, String, Int)
    case sdccSend(NeedleTailNick, String, Int, String, Int)
    case sdccResume(NeedleTailNick, String, Int, String, Int, Int)
    
    // MARK: - Other RFC 2812 commands and common server extensions
    /// Sets or removes the away status for a user.
    case away(String?) // AWAY command
    /// Authenticates a user as an IRC operator.
    case oper(String, String) // OPER command (username, password)
    /// Requests an invite to an invite-only channel.
    case knock(NeedleTailChannel, String?) // KNOCK command (channel, optional message)
    /// Sets or removes a silence mask for ignoring users.
    case silence(String) // SILENCE command (mask)
    /// Invites a user to a channel.
    case invite(NeedleTailNick, NeedleTailChannel) // INVITE command
    /// Sets or gets the topic for a channel.
    case topic(NeedleTailChannel, String?) // TOPIC command (channel, optional topic)
    /// Lists users in a channel or all channels.
    case names(NeedleTailChannel?) // NAMES command (optional channel)
    /// Clears all modes from a channel.
    case clearmode(NeedleTailChannel, String) // CLEARMODE command (channel, mode)
    // MARK: - Administrative/Server Commands
    /// Reloads server configuration files.
    case rehash // REHASH command
    /// Restarts the IRC server.
    case restart // RESTART command
    /// Shuts down the IRC server.
    case die // DIE command
    /// Connects to another server.
    case connect(String, Int, String?) // CONNECT command (target server, port, remote server)
    /// Traces the server connection path.
    case trace(String?) // TRACE command (optional target)
    /// Requests server statistics.
    case stats(String?, String?) // STATS command (optional query, optional target)
    /// Requests server administrator information.
    case admin(String?) // ADMIN command (optional target)
    /// Requests server information.
    case info(String?) // INFO command (optional target)
    /// Requests server version.
    case version(String?) // VERSION command (optional target)
    /// Requests server time.
    case time(String?) // TIME command (optional target)
    /// Requests user statistics.
    case lusers(String?, String?) // LUSERS command (optional mask, optional target)
    /// Requests the message of the day.
    case motd(String?) // MOTD command (optional target)
    /// Requests server rules.
    case rules(String?) // RULES command (optional target)
    /// Requests the server network map.
    case map // MAP command
    /// Requests a list of users.
    case users(String?) // USERS command (optional target)
    /// Sends a wallops message to all operators.
    case wallops(String) // WALLOPS command
    /// Sends a global operator message.
    case globops(String) // GLOBOPS command
    /// Sends a local operator message.
    case locops(String) // LOCOPS command
    /// `PASS <password>`: the connection password, sent before NICK and USER (RFC 2812 §3.1.1).
    case pass(String)
    /// `SERVICE <nickname> <reserved> <distribution> <type> <reserved> <info>`: registers a
    /// service (RFC 2812 §3.1.6). The reserved parameters are written as `*` and `0`.
    case service(nickname: String, distribution: String, type: String, info: String)
    /// `SERVLIST [ <mask> [ <type> ] ]`: lists the services on the network (RFC 2812 §3.5.1).
    case servlist(mask: String?, type: String?)
    /// `SQUERY <servicename> <text>`: a message to a service (RFC 2812 §3.5.2).
    case squery(serviceName: String, text: String)
    /// `WHOWAS <nickname> *( "," <nickname> ) [ <count> [ <target> ] ]`: nicknames that no
    /// longer exist (RFC 2812 §3.6.3). A target needs a count.
    case whowas([NeedleTailNick], count: Int?, target: String?)
    /// `ERROR <error message>`: a server reports a serious error, usually before it closes the
    /// link (RFC 2812 §3.7.4).
    case error(String)
    /// `SUMMON <user> [ <target> [ <channel> ] ]`: asks a user on a server host to join IRC
    /// (RFC 2812 §4.5). A channel needs a target.
    case summon(user: String, target: String?, channel: NeedleTailChannel?)
    /// `USERHOST <nickname> *( SPACE <nickname> )`: up to five nicknames' user@host
    /// (RFC 2812 §4.8).
    case userhost([NeedleTailNick])
    
    // MARK: - Computed Properties
    
    /// Returns the string representation of the command.
    public var commandAsString: String {
        switch self {
        case .nick: return Constants.nick.rawValue
        case .user: return Constants.user.rawValue
        case .isOn: return Constants.isOn.rawValue
        case .quit: return Constants.quit.rawValue
        case .ping: return Constants.ping.rawValue
        case .pong: return Constants.pong.rawValue
        case .join: return Constants.join.rawValue
        case .join0: return Constants.join.rawValue
        case .part, .partMessage: return Constants.part.rawValue
        case .list: return Constants.list.rawValue
        case .privMsg: return Constants.privMsg.rawValue
        case .notice: return Constants.notice.rawValue
        case .cap: return Constants.cap.rawValue
        case .mode, .modeGet: return Constants.mode.rawValue
        case .whois: return Constants.whoIs.rawValue
        case .who: return Constants.who.rawValue
        case .channelMode, .channelModeChanges: return Constants.mode.rawValue
        case .channelModeGet, .channelModeGetBanMask: return Constants.mode.rawValue
        case .kick: return Constants.kick.rawValue
        case .kill: return Constants.kill.rawValue
        case .sQuit: return Constants.sQuit.rawValue
        case .server: return Constants.server.rawValue
        case .links: return Constants.links.rawValue
         /// Avoid using non-secure
        case .dccChat: return Constants.dccChat.rawValue
        case .dccSend: return Constants.dccSend.rawValue
        case .dccResume: return Constants.dccResume.rawValue
        /// Use
        case .sdccChat: return Constants.sdccChat.rawValue
        case .sdccSend: return Constants.sdccSend.rawValue
        case .sdccResume: return Constants.sdccResume.rawValue

            /*
             In the context of IRC (Internet Relay Chat), the term "otherCommands" is quite broad and can encompass a wide range of commands beyond the standard IRC commands like PRIVMSG, JOIN, PART, MODE, etc. These "otherCommands" may vary depending on the specific IRC server software, client implementations, or custom features/extensions. Here are some examples of additional or specialized commands that may be used in IRC:
             OPER: Used by IRC operators to gain operator privileges and access special commands.
             KNOCK: Allows users to request an invite to a moderated channel.
             SILENCE: Used to ignore messages from specific users.
             INVITE: Invites a user to join a specific channel.
             TOPIC: Sets or retrieves the topic of a channel.
             KICKBAN: Kicks a user from a channel and sets a ban on them simultaneously.
             AWAY: Sets an away message to inform others when a user is not actively monitoring the chat.
             LISTEN: Allows users to listen to a specific channel without joining it.
             IGNORE: Ignores messages from specific users or channels.
             WALLOPS: Sends a message to all operators on the network.
             */
        case .otherCommand(let cmd, _): return cmd
            /*
             In IRC (Internet Relay Chat), numeric commands, also known as numeric replies or numeric codes, are standardized codes used by servers and clients to communicate various responses, errors, and information during IRC sessions. These numeric commands provide a concise and standardized way to convey specific messages. Here are some additional examples of common numeric commands in IRC:
             RPL_ENDOFNAMES (366): Indicates the end of the list of users in a channel.
             RPL_TOPIC (332): Provides the topic of a channel.
             RPL_MOTDSTART (375): Indicates the start of the message of the day.
             RPL_MOTD (372): Provides a line of the message of the day.
             RPL_ENDOFMOTD (376): Indicates the end of the message of the day.
             ERR_NICKNAMEINUSE (433): Indicates that the chosen nickname is already in use.
             RPL_WHOISIDLE (317): Provides information about how long a user has been idle.
             RPL_WHOISCHANNELS (319): Lists the channels a user is currently in.
             RPL_ISON (303): Indicates which users from a list are currently online.
             ERR_CANNOTSENDTOCHAN (404): Indicates that a message cannot be sent to a channel.
             */
        case .otherNumeric(let cmd, _):
            let s = String(cmd)
            if s.count >= 3 { return s }
            return String(repeating: "0", count: 3 - s.count) + s
            /*
             Numeric commands in IRC (Internet Relay Chat) are standardized numeric codes that servers and clients use to communicate various responses, errors, and information during IRC sessions. These numeric commands serve as a way to convey specific messages in a concise and standardized format. Here are some common uses of numeric commands in IRC:
             Connection Responses:
             Numeric commands are used to indicate successful connections, such as welcoming a user to the network (e.g., RPL_WELCOME - 001) or acknowledging a successful connection (e.g., RPL_YOURHOST - 002).
             Channel Operations:
             Numeric commands are used to manage channel operations, such as notifying users when they join a channel (e.g., RPL_NAMREPLY - 353) or when they leave a channel (e.g., RPL_PART - PART).
             Error Messages:
             Numeric commands are used to convey error messages or responses, such as notifying users of an invalid command (e.g., ERR_UNKNOWNCOMMAND - 421) or an incorrect password (e.g., ERR_PASSWDMISMATCH - 464).
             User Information:
             Numeric commands are used to provide information about users, such as listing users in a channel (e.g., RPL_WHOREPLY - 352) or providing details about a specific user (e.g., RPL_WHOISUSER - 311).
             Server Information:
             Numeric commands are used to exchange information about servers, such as providing details about the server's version (e.g., RPL_VERSION - 351) or the server's connection status (e.g., RPL_LUSERCLIENT - 251).
             */
        case .numeric(let cmd, _):
            let s = String(cmd.rawValue)
            if s.count >= 3 { return s }
            return String(repeating: "0", count: 3 - s.count) + s
        // Add cases for new commands in commandAsString
        case .away: return Constants.away.rawValue
        case .oper: return Constants.oper.rawValue
        case .knock: return Constants.knock.rawValue
        case .silence: return Constants.silence.rawValue
        case .invite: return Constants.invite.rawValue
        case .topic: return Constants.topic.rawValue
        case .names: return Constants.names.rawValue
        case .clearmode: return Constants.clearmode.rawValue
        case .rehash: return Constants.rehash.rawValue
        case .restart: return Constants.restart.rawValue
        case .die: return Constants.die.rawValue
        case .connect: return Constants.connect.rawValue
        case .trace: return Constants.trace.rawValue
        case .stats: return Constants.stats.rawValue
        case .admin: return Constants.admin.rawValue
        case .info: return Constants.info.rawValue
        case .version: return Constants.version.rawValue
        case .time: return Constants.time.rawValue
        case .lusers: return Constants.lusers.rawValue
        case .motd: return Constants.motd.rawValue
        case .rules: return Constants.rules.rawValue
        case .map: return Constants.map.rawValue
        case .users: return Constants.users.rawValue
        case .wallops: return Constants.wallops.rawValue
        case .globops: return Constants.globops.rawValue
        case .locops: return Constants.locops.rawValue
        case .pass: return Constants.pass.rawValue
        case .service: return Constants.service.rawValue
        case .servlist: return Constants.servlist.rawValue
        case .squery: return Constants.squery.rawValue
        case .whowas: return Constants.whowas.rawValue
        case .error: return Constants.error.rawValue
        case .summon: return Constants.summon.rawValue
        case .userhost: return Constants.userhost.rawValue
        }
    }
    
    /// Returns whether this command is a numeric command (server response).
    public var isNumeric: Bool {
        switch self {
        case .numeric, .otherNumeric:
            return true
        default:
            return false
        }
    }
    
    /// Returns the arguments for the command as an array of strings.
    public var arguments: [String] {
        switch self {
        case .nick(let nick):
            return [nick.stringValue]
        case .user(let info):
            return [info.username, info.hostname ?? "", info.servername ?? Constants.star.rawValue, info.realname]
        case .isOn(let nicks):
            return nicks.map { $0.stringValue }
        case .quit(let message):
            return [message ?? ""]
        case .ping(let server, let server2):
            return [server, server2 ?? ""]
        case .pong(let server, let server2):
            return [server, server2 ?? ""]
        case .join(let channels, let keys):
            let joinedChannels = channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)
            return keys != nil ? [joinedChannels, keys!.joined(separator: Constants.comma.rawValue)] : [joinedChannels]
        case .join0:
            return ["0"]
        case .part(let channels):
            return [channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)]
        case .partMessage(let channels, let message):
            return [channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue), message]
        case .list(let channels, let target):
            let joinedChannels = channels?.map { $0.stringValue }.joined(separator: Constants.comma.rawValue) ?? ""
            return target != nil ? [joinedChannels, target!] : [joinedChannels]
        case .privMsg(let recipients, let message), .notice(let recipients, let message):
            return [recipients.map { $0.stringValue }.joined(separator: Constants.comma.rawValue), message]
        case .mode(let name, let add, let remove):
            let addString = add.map { "\(Constants.plus.rawValue)\($0.stringValue) " } ?? ""
            let removeString = remove.map { "\(Constants.minus.rawValue)\($0.stringValue) " } ?? ""
            return [name.stringValue, "\(addString)\(removeString)".trimmingCharacters(in: .whitespaces)]
        case .channelMode(let name, let add, let addParameters, let remove, let removeParameters):
            let addString = add.map { "\(Constants.plus.rawValue)\($0.stringValue) " } ?? ""
            let removeString = remove.map { "\(Constants.minus.rawValue)\($0.stringValue) " } ?? ""
            let paramsString = (addParameters ?? []).joined(separator: Constants.comma.rawValue) + " " + (removeParameters ?? []).joined(separator: Constants.comma.rawValue)
            return [name.stringValue, "\(addString)\(removeString)\(paramsString)".trimmingCharacters(in: .whitespaces)]
        case .channelModeChanges(let channel, let changes):
            return [channel.stringValue, NeedleTailIRCEncoder.modeString(changes)] + changes.compactMap(\.parameter)
        case .modeGet(let name):
            return [name.stringValue]
        case .channelModeGet(let name), .channelModeGetBanMask(let name):
            return [name.stringValue]
        case .whois(let server, let usermasks):
            return [server ?? "", usermasks.joined(separator: Constants.comma.rawValue)]
        case .who(let usermask, let onlyOperators):
            if let usermask = usermask {
                return [usermask, onlyOperators ? Constants.oString.rawValue : ""]
            } else {
                return onlyOperators ? [Constants.oString.rawValue] : []
            }
        case .kick(let channels, let users, let comments):
            let channelList = channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)
            let userList = users.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)
            return [channelList, userList, comments.joined(separator: Constants.comma.rawValue)]
        case .kill(let nick, let comment):
            return [nick.stringValue, comment]
        case .sQuit(let serverName, let reason):
            return [serverName, reason]
        case .server(let serverName, let version, let hopCount, let info):
            return [serverName, version, String(hopCount), info]
        case .links(let mask):
            if let mask = mask {
                return [mask]
            } else {
                return []
            }
        case .dccChat(let nickname, let address, let port), .sdccChat(let nickname, let address, let port):
            return [nickname.stringValue, address, String(port)]
        case .dccSend(let nickname, let filename, let filesize, let address, let port), .sdccSend(let nickname, let filename, let filesize, let address, let port):
            return [nickname.stringValue, filename, String(filesize), address, String(port)]
        case .dccResume(let nickname, let filename, let filesize, let address, let port, let offset), .sdccResume(let nickname, let filename, let filesize, let address, let port, let offset):
            return [nickname.stringValue, filename, String(filesize), address, String(port), String(offset)]
        case .numeric(_, let args), .otherCommand(_, let args), .otherNumeric(_, let args):
            return args
        case .cap(let subCommand, let parameters):
            var args = ["CAP", subCommand.rawValue]
            args.append(contentsOf: parameters)
            return args
        case .away(let message): return message != nil ? [message!] : []
        case .oper(let username, let password): return [username, password]
        case .knock(let channel, let message): return [channel.stringValue, message ?? ""]
        case .silence(let mask): return [mask]
        case .invite(let nickname, let channel): return [nickname.stringValue, channel.stringValue]
        case .topic(let channel, let topic): return [channel.stringValue, topic ?? ""]
        case .names(let channel): return channel != nil ? [channel!.stringValue] : []
        case .clearmode(let channel, let mode): return [channel.stringValue, mode]
        case .rehash: return []
        case .restart: return []
        case .die: return []
        case .connect(let targetServer, let port, let remoteServer): return [targetServer, String(port), remoteServer ?? ""]
        case .trace(let target): return target != nil ? [target!] : []
        case .stats(let query, let target): return [query ?? "", target ?? ""]
        case .admin(let target): return target != nil ? [target!] : []
        case .info(let target): return target != nil ? [target!] : []
        case .version(let target): return target != nil ? [target!] : []
        case .time(let target): return target != nil ? [target!] : []
        case .lusers(let mask, let target): return [mask ?? "", target ?? ""]
        case .motd(let target): return target != nil ? [target!] : []
        case .rules(let target): return target != nil ? [target!] : []
        case .map: return []
        case .users(let target): return target != nil ? [target!] : []
        case .wallops(let message): return [message]
        case .globops(let message): return [message]
        case .locops(let message): return [message]
        case .pass(let password): return [password]
        case .service(let nickname, let distribution, let type, let info): return [nickname, "*", distribution, type, "0", info]
        case .servlist(let mask, let type): return [mask, type].compactMap { $0 }
        case .squery(let serviceName, let text): return [serviceName, text]
        case .whowas(let nicks, let count, let target):
            return [nicks.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)] + [count.map(String.init), target].compactMap { $0 }
        case .error(let message): return [message]
        case .summon(let user, let target, let channel): return [user, target, channel?.stringValue].compactMap { $0 }
        case .userhost(let nicks): return nicks.map { $0.stringValue }
        }
    }

    
    // MARK: - CustomStringConvertible Conformance
    
    /// Command name, plus arguments for the cases that carry them.
    /// Every command has a name; nothing falls through to a placeholder.
    public var description: String {
        switch self {
        case .ping(let server, let server2):
            return server2 != nil ? "\(commandAsString) '\(server)' '\(server2!)'" : "\(commandAsString) '\(server)'"
        case .quit(let message):
            return message != nil ? "\(Constants.quit.rawValue) '\(message!)'" : Constants.quit.rawValue
        case .nick(let nick): return "\(Constants.nick.rawValue) '\(nick.stringValue)'"
        case .user(let info): return "\(Constants.user.rawValue) '\(info.username)'"
        case .isOn(let nicks): return "\(Constants.isOn.rawValue) '\(nicks.map { $0.stringValue }.joined(separator: Constants.comma.rawValue))'"
        case .kick(let channels, let users, let comments):
            return "\(Constants.kick.rawValue) '\(channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue))' '\(users.map { $0.stringValue }.joined(separator: Constants.comma.rawValue))' '\(comments.joined(separator: Constants.comma.rawValue))'"
        case .kill(let nick, let comment): return "\(Constants.kill.rawValue) '\(nick.stringValue)' '\(comment)'"
        case .otherCommand(let cmd, let args): return "<IRCCommand: \(cmd) args=\(args.joined(separator: Constants.comma.rawValue))>"
        case .otherNumeric(let cmd, let args): return "<IRCCommand: \(cmd) args=\(args.joined(separator: Constants.comma.rawValue))>"
        case .numeric(let cmd, let args): return "<IRCCommand: \(cmd.rawValue) args=\(args.joined(separator: Constants.comma.rawValue))>"
        default: return commandAsString
        }
    }
}
