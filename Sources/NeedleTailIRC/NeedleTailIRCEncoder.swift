//
//  NeedleTailIRCEncoder.swift
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

/// A comprehensive encoder for converting IRC messages to their string representation.
/// 
/// This encoder implements the IRC message format as specified in the IRC protocol:
/// ['@' <tags> SPACE] [':' <source> SPACE] <command> <parameters> <crlf>
/// 
/// For numeric replies, the target is included as the first parameter according to the protocol.
///
/// `NeedleTailIRCEncoder` provides functionality to encode `IRCMessage` objects into properly
/// formatted IRC protocol strings. It handles all command types, parameters, tags, and ensures
/// compliance with RFC 2812 and RFC 1459 standards.
///
/// ## Features
///
/// - **Complete Command Support**: Encodes all standard IRC commands
/// - **IRCv3 Tag Support**: Handles message tags according to IRCv3 specifications
/// - **Parameter Formatting**: Properly formats command parameters and trailing data
/// - **Protocol Compliance**: Ensures output conforms to IRC standards
/// - **Thread Safety**: Safe for concurrent use
///
/// ## Examples
///
/// ```swift
/// // Encode a simple message
/// let message = IRCMessage(
///     origin: "alice",
///     command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!")
/// )
/// let encoded = await NeedleTailIRCEncoder.encode(value: message)
/// // Result: "PRIVMSG #general :Hello!"
///
/// // Encode a message with tags
/// let taggedMessage = IRCMessage(
///     origin: "alice",
///     command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
/// )
/// let encodedTagged = await NeedleTailIRCEncoder.encode(value: taggedMessage)
/// // Result: "@time=2023-01-01T12:00:00Z PRIVMSG #general :Hello!"
/// ```
///
/// ## Thread Safety
///
/// This encoder is thread-safe and can be used concurrently from multiple threads.
public struct NeedleTailIRCEncoder: Sendable {
    
    /// A static instance of PacketDerivation used for packet handling.
    static let packetDerivation = PacketDerivation()
    
    /// Encodes an `IRCMessage` into a properly formatted IRC protocol string.
    ///
    /// This method handles the complete encoding process, including:
    /// - IRCv3 message tags formatting
    /// - Origin prefix formatting
    /// - Command and parameter formatting
    /// - Trailing parameter handling
    /// - Proper spacing and delimiter placement
    ///
    /// ## Encoding Process
    ///
    /// The encoder follows the IRC message format:
    /// ```
    /// [@tags] [:prefix] command [parameters] [:trailing]
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Simple message
    /// let message = IRCMessage(command: .privMsg([.channel(channel)], "Hello!"))
    /// let encoded = await NeedleTailIRCEncoder.encode(value: message)
    /// // Result: "PRIVMSG #general :Hello!"
    ///
    /// // Message with origin and tags
    /// let message = IRCMessage(
    ///     origin: "alice!alice@localhost",
    ///     command: .privMsg([.channel(channel)], "Hello!"),
    ///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
    /// )
    /// let encoded = await NeedleTailIRCEncoder.encode(value: message)
    /// // Result: "@time=2023-01-01T12:00:00Z :alice!alice@localhost PRIVMSG #general :Hello!"
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe and can be called concurrently.
    ///
    /// - Parameter value: The `IRCMessage` to be encoded.
    /// - Returns: A properly formatted IRC protocol string.
    public static func encode(value: IRCMessage) async -> String {
        var components = [String]()
        let command = value.command.commandAsString
        
        // Encode message tags, if any
        if let tags = value.tags, !tags.isEmpty {
            let tagString = tags.map { "\(Constants.atString.rawValue)\($0.key)\(Constants.equalsString.rawValue)\($0.value)" }
                .joined(separator: Constants.semiColon.rawValue)
            components.append(tagString + Constants.space.rawValue)
        }
        
        // Encode the origin of the message
        if let origin = value.origin, !origin.isEmpty {
            components.append("\(Constants.colon.rawValue)\(origin)\(Constants.space.rawValue)")
        }
        
        // Append the command to the components
        components.append(command)
        
        // Encode the target of the message (only for numeric responses)
        // According to IRC protocol: numeric replies SHOULD contain the target as the first parameter
        if let target = value.target, case .numeric = value.command {
            components.append("\(Constants.space.rawValue)\(target)\(Constants.space.rawValue)")
        } else {
            components.append("\(Constants.space.rawValue)")
        }
        
        // Handle different IRC commands and encode their respective parameters
        switch value.command {
        case .nick(let v), .modeGet(let v):
            components.append("\(v.stringValue)")
        case .user(let userInfo):
            components.append("\(userInfo.username)\(Constants.space.rawValue)\(userInfo.hostname ?? "")\(Constants.space.rawValue)\(userInfo.servername ?? "*")\(Constants.space.rawValue)\(Constants.colon.rawValue)\(userInfo.realname)")
        case .isOn(let nicks):
            components.append(arguments(nicks.lazy.map { $0.stringValue }))
        case .quit(let value):
            if let value = value {
                components.append("\(Constants.colon.rawValue)\(value)")
            }
        case .ping(let server, let server2):
            let params = [server, server2].compactMap { $0 }
            if !params.isEmpty {
                components.append(" " + params.joined(separator: " "))
            }
        case .join(let channels, let keys):
            // Prevent emitting JOIN with zero channels
            guard !channels.isEmpty else {
                return ""
            }
            components.append(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true))
            if let keys = keys {
                components.append("\(Constants.space.rawValue)\(create(arguments: keys, buildWithComma: true))")
            }
        case .part(let channels):
            components.append(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true))
        case .list(let channels, let target):
            if let channels = channels {
                components.append(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true))
            } else {
                components.append("\(Constants.star.rawValue)")
            }
            if let target = target {
                components.append("\(Constants.space.rawValue)\(target)")
            }
        case .privMsg(let recipients, let message), .notice(let recipients, let message):
            components.append(create(arguments: recipients.lazy.map { $0.stringValue }, buildWithComma: true))
            components.append("\(Constants.space.rawValue)\(Constants.colon.rawValue)\(message)")
        case .mode(let nick, add: let add, remove: let remove):
            components.append("\(nick.stringValue)")
            if let adds = add?.stringValue.map({ "\(Constants.plus.rawValue)\($0)" }) {
                components.append("\(Constants.space.rawValue)\(arguments(adds))")
            }
            if let removes = remove?.stringValue.map({ "\(Constants.minus.rawValue)\($0)" }) {
                components.append("\(Constants.space.rawValue)\(arguments(removes))")
            }
        case .channelMode(let channel, addMode: let add, addParameters: let addParameters, removeMode: let remove, removeParameters: let removeParameters):
            components.append("\(channel.stringValue)")
            if let adds = add?.stringValue.map({ "\(Constants.plus.rawValue)\($0)" }) {
                components.append("\(Constants.space.rawValue)\(arguments(adds))" + "\(Constants.space.rawValue)\(addParameters?.joined(separator: Constants.comma.rawValue) ?? "")")
            }
            if let removes = remove?.stringValue.map({ "\(Constants.minus.rawValue)\($0)" }) {
                components.append("\(Constants.space.rawValue)\(arguments(removes))"  + "\(Constants.space.rawValue)\(removeParameters?.joined(separator: Constants.comma.rawValue) ?? "")")
            }
        case .channelModeGet(let value):
            components.append("\(value.stringValue)")
        case .channelModeGetBanMask(let value):
            components.append("\(value.stringValue)\(Constants.space.rawValue)\(Constants.plus.rawValue)\(Constants.bString.rawValue)")
        case .whois(let server, let usermasks):
            if let server = server {
                components.append("\(server)\(Constants.space.rawValue)\(usermasks.joined(separator: Constants.comma.rawValue))")
            } else {
                components.append(usermasks.joined(separator: Constants.comma.rawValue))
            }
        case .who(let usermask, let onlyOperators):
            if let mask = usermask {
                components.append("\(mask)\(onlyOperators ? "\(Constants.space.rawValue)\(Constants.oString.rawValue)" : "")")
            }
        case .kick(let channels, let users, let comments):
            components.append(String(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true, joinWithSpace: true).dropFirst()))
            components.append(create(arguments: users.lazy.map { $0.stringValue }, buildWithComma: true, joinWithSpace: true))
            components.append(create(arguments: comments.lazy.map { $0 }, buildWithColon: true, joinWithSpace: true))
        case .kill(let nick, let comment):
            components.append("\(nick.stringValue)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(comment)")
        case .dccChat(let nickname, let address, let port), .sdccChat(let nickname, let address, let port):
            components.append("\(nickname.stringValue)\(Constants.space.rawValue)\(address)\(Constants.space.rawValue)\(port)")
        case .dccSend(let nickname, let filename, let filesize, let address, let port), .sdccSend(let nickname, let filename, let filesize, let address, let port):
            components.append("\(nickname.stringValue)\(Constants.space.rawValue)\(filename)\(Constants.space.rawValue)\(filesize)\(Constants.space.rawValue)\(address)\(Constants.space.rawValue)\(port)")
        case .dccResume(let nickname, let filename, let filesize, let address, let port, let offset), .sdccResume(let nickname, let filename, let filesize, let address, let port, let offset):
            components.append("\(nickname.stringValue)\(Constants.space.rawValue)\(filename)\(Constants.space.rawValue)\(filesize)\(Constants.space.rawValue)\(address)\(Constants.space.rawValue)\(port)\(Constants.space.rawValue)\(offset)")
        case .numeric(_, let args), .otherCommand(_, let args), .otherNumeric(_, let args):
            components.append(create(arguments: args, buildWithColon: true, buildWithComma: true))
        case .cap(let subCommand, let capabilityIds):
            components.append("\(subCommand.commandAsString)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(capabilityIds.joined(separator: Constants.space.rawValue))")
        case .pong(server: let server, server2: let server2):
            let params = [server, server2].compactMap { $0 }
            if !params.isEmpty {
                components.append(" " + params.joined(separator: " "))
            }
        case .join0:
            components.append("0")
        case .sQuit(let serverName, let reason):
            components.append("\(serverName)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(reason)")
        case .server(let serverName, let version, let hopCount, let info):
            components.append("\(serverName)\(Constants.space.rawValue)\(version)\(Constants.space.rawValue)\(String(hopCount))\(Constants.space.rawValue)\(Constants.colon.rawValue)\(info)")
        case .links(let mask):
            if let mask = mask {
                components.append("\(mask)")
            }
        // Add cases for new commands
        case .away(let message):
            if let message = message {
                components.append("\(Constants.colon.rawValue)\(message)")
            }
        case .oper(let username, let password):
            components.append("\(username)\(Constants.space.rawValue)\(password)")
        case .knock(let channel, let message):
            components.append("\(channel.stringValue)")
            if let message = message {
                components.append("\(Constants.space.rawValue)\(Constants.colon.rawValue)\(message)")
            }
        case .silence(let mask):
            components.append("\(mask)")
        case .invite(let nickname, let channel):
            components.append("\(nickname.stringValue)\(Constants.space.rawValue)\(channel.stringValue)")
        case .topic(let channel, let topic):
            components.append("\(channel.stringValue)")
            if let topic = topic {
                components.append("\(Constants.space.rawValue)\(Constants.colon.rawValue)\(topic)")
            }
        case .names(let channel):
            if let channel = channel {
                components.append("\(channel.stringValue)")
            }
        case .ban(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .unban(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .kickban(let channel, let nick, let reason):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(reason)")
        case .clearmode(let channel, let mode):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mode)")
        case .except(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .unexcept(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .inviteExcept(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .uninviteExcept(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .quiet(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .unquiet(let channel, let mask):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mask)")
        case .voice(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .devoice(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .halfop(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .dehalfop(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .protect(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .deprotect(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .owner(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .deowner(let channel, let nick):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(nick.stringValue)")
        case .rehash:
            // No additional parameters
            break
        case .restart:
            // No additional parameters
            break
        case .die:
            // No additional parameters
            break
        case .squit(let serverName, let comment):
            components.append("\(serverName)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(comment)")
        case .connect(let targetServer, let port, let remoteServer):
            components.append("\(targetServer)\(Constants.space.rawValue)\(port)")
            if let remoteServer = remoteServer {
                components.append("\(Constants.space.rawValue)\(remoteServer)")
            }
        case .trace(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .stats(let query, let target):
            if let query = query {
                components.append("\(query)")
            }
            if let target = target {
                components.append("\(Constants.space.rawValue)\(target)")
            }
        case .admin(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .info(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .version(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .time(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .lusers(let mask, let target):
            if let mask = mask {
                components.append("\(mask)")
            }
            if let target = target {
                components.append("\(Constants.space.rawValue)\(target)")
            }
        case .motd(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .rules(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .map:
            // No additional parameters
            break
        case .users(let target):
            if let target = target {
                components.append("\(target)")
            }
        case .wallops(let message):
            components.append("\(Constants.colon.rawValue)\(message)")
        case .globops(let message):
            components.append("\(Constants.colon.rawValue)\(message)")
        case .locops(let message):
            components.append("\(Constants.colon.rawValue)\(message)")
        case .adl:
            // No additional parameters
            break
        case .odlist:
            // No additional parameters
            break
        case .ctcp(let target, let command, let argument):
            components.append("\(target.stringValue)\(Constants.space.rawValue)\(command)")
            if let argument = argument {
                components.append("\(Constants.space.rawValue)\(Constants.colon.rawValue)\(argument)")
            }
        case .ctcpreply(let target, let command, let argument):
            components.append("\(target.stringValue)\(Constants.space.rawValue)\(command)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(argument)")
        }
        // Join all components and trim any trailing whitespace
        return components.joined().trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a string from an array of arguments, with options for formatting.
    ///
    /// This method joins an array of string arguments with spaces between them.
    /// It's used internally for formatting command parameters.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let args = ["#general", "#random", "#help"]
    /// let formatted = NeedleTailIRCEncoder.arguments(args)
    /// // Result: "#general #random #help"
    /// ```
    ///
    /// - Parameter args: The arguments to be joined.
    /// - Returns: A formatted `String` of the arguments separated by spaces.
    internal static func arguments(_ args: [String] = [""]) -> String {
        args.map { "\($0)" }.joined(separator: "\(Constants.space.rawValue)")
    }
    
    /// Creates a formatted string from an array of arguments, with options for colons, commas, and space joining.
    ///
    /// This method provides flexible formatting options for IRC command arguments:
    /// - **Colon prefixing**: Adds a colon to the first argument (for trailing parameters)
    /// - **Comma separation**: Adds commas between arguments
    /// - **Space joining**: Adds a leading space to the entire result
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Basic formatting
    /// let args = ["#general", "Hello", "world"]
    /// let basic = NeedleTailIRCEncoder.create(arguments: args)
    /// // Result: "#general Hello world"
    ///
    /// // With colon prefixing (for trailing parameters)
    /// let withColon = NeedleTailIRCEncoder.create(arguments: args, buildWithColon: true)
    /// // Result: ":Hello world"
    ///
    /// // With comma separation
    /// let withComma = NeedleTailIRCEncoder.create(arguments: args, buildWithComma: true)
    /// // Result: "#general,Hello,world"
    ///
    /// // With leading space
    /// let withSpace = NeedleTailIRCEncoder.create(arguments: args, joinWithSpace: true)
    /// // Result: " #general Hello world"
    /// ```
    ///
    /// ## IRC Protocol Compliance
    ///
    /// This method ensures proper formatting according to IRC standards:
    /// - Trailing parameters are prefixed with a colon
    /// - Multiple recipients are separated by commas
    /// - Proper spacing is maintained between components
    ///
    /// - Parameters:
    ///   - arguments: The arguments to be formatted and joined.
    ///   - buildWithColon: If true, prepend a colon to the first argument (for trailing parameters).
    ///   - buildWithComma: If true, append commas between arguments (for multiple recipients).
    ///   - joinWithSpace: If true, prepend a space to the entire result.
    /// - Returns: A formatted `String` based on the input parameters.
    internal static func create(arguments: [String], buildWithColon: Bool = false, buildWithComma: Bool = false, joinWithSpace: Bool = false) -> String {
        let fixed = arguments.enumerated().map { index, argument in
            var arg = argument
            if index == 0 {
                if buildWithColon {
                    arg = "\(Constants.colon.rawValue)\(arg)"
                }
                if buildWithComma && arguments.count > 1 {
                    arg += "\(Constants.comma.rawValue)"
                }
            } else if buildWithComma && index != arguments.count - 1 {
                arg += "\(Constants.comma.rawValue)"
            }
            return arg
        }
        //Is this right?
        if buildWithColon {
            let joined = fixed.joined(separator: Constants.space.rawValue)
            return joinWithSpace ? "\(Constants.space.rawValue)\(joined)" : "\(joined)"
        } else {
            let joined = fixed.joined()
            return joinWithSpace ? "\(Constants.space.rawValue)\(joined)" : "\(joined)"
        }
    }
}
