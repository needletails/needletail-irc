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
/// let encoded = NeedleTailIRCEncoder.encode(value: message)
/// // Result: "PRIVMSG #general :Hello!"
///
/// // Encode a message with tags
/// let taggedMessage = IRCMessage(
///     origin: "alice",
///     command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
/// )
/// let encodedTagged = NeedleTailIRCEncoder.encode(value: taggedMessage)
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
    /// let encoded = NeedleTailIRCEncoder.encode(value: message)
    /// // Result: "PRIVMSG #general :Hello!"
    ///
    /// // Message with origin and tags
    /// let message = IRCMessage(
    ///     origin: "alice!alice@localhost",
    ///     command: .privMsg([.channel(channel)], "Hello!"),
    ///     tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
    /// )
    /// let encoded = NeedleTailIRCEncoder.encode(value: message)
    /// // Result: "@time=2023-01-01T12:00:00Z :alice!alice@localhost PRIVMSG #general :Hello!"
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe and can be called concurrently.
    ///
    /// - Parameter value: The `IRCMessage` to be encoded.
    /// - Returns: A properly formatted IRC protocol string.
    public static func encode(value: IRCMessage) -> String {
        var components = [String]()
        let command = value.command.commandAsString
        
        // Encode message tags, if any
        if let tags = value.tags, !tags.isEmpty {
            // IRCv3 tags are encoded with a single leading '@' and ';' separators:
            //   @k1=v1;k2=v2 <command> ...
            // Historically this SDK emitted '@' before every tag; the parser now tolerates both,
            // but we encode the standard format going forward.
            let tagString = Constants.atString.rawValue
                + tags
                    .map { "\($0.key)\(Constants.equalsString.rawValue)\(IRCTag.ircv3EscapeTagValue($0.value))" }
                    .joined(separator: Constants.semiColon.rawValue)
            components.append(tagString + Constants.space.rawValue)
        }
        
        // Encode the origin of the message
        if let origin = value.origin, !origin.isEmpty {
            components.append("\(Constants.colon.rawValue)\(origin)\(Constants.space.rawValue)")
        }
        
        // Append the command to the components
        components.append(command)
        let parametersStart = components.count

        // Encode the target of the message (numeric replies and server CAP replies).
        // RFC 2812 §2.4: a numeric reply consists of the prefix, the numeric and the target.
        // IRCv3: a server's CAP reply carries the client's nick, or `*`.
        if let target = value.target, carriesTarget(value.command) {
            components.append("\(Constants.space.rawValue)\(target)\(Constants.space.rawValue)")
        } else {
            components.append("\(Constants.space.rawValue)")
        }
        
        // Handle different IRC commands and encode their respective parameters
        switch value.command {
        case .nick(let v), .modeGet(let v):
            components.append("\(v.stringValue)")
        case .user(let userInfo):
            if let modes = userInfo.userModeFlags {
                // RFC 2812 §3.1.3: `USER <user> <mode> <unused> <realname>`, mode bit 2 = w, bit 3 = i.
                components.append("\(userInfo.username)\(Constants.space.rawValue)\(userModeBitmask(modes))\(Constants.space.rawValue)\(Constants.star.rawValue)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(userInfo.realname)")
            } else {
                components.append("\(userInfo.username)\(Constants.space.rawValue)\(userInfo.hostname ?? "")\(Constants.space.rawValue)\(userInfo.servername ?? "*")\(Constants.space.rawValue)\(Constants.colon.rawValue)\(userInfo.realname)")
            }
        case .isOn(let nicks):
            // At most 15 parameters: past the 14th, the rest of the list is one trailing parameter.
            let names = nicks.map { $0.stringValue }
            if names.count > 15 {
                components.append("\(arguments(Array(names.prefix(14))))\(Constants.space.rawValue)\(Constants.colon.rawValue)\(arguments(Array(names.dropFirst(14))))")
            } else {
                components.append(arguments(names))
            }
        case .quit(let value):
            if let value = value {
                components.append("\(Constants.colon.rawValue)\(value)")
            }
        case .ping(let server, let server2):
            components.append(parameters([server, server2].compactMap { $0 }))
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
        case .partMessage(let channels, let message):
            components.append(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true))
            components.append("\(Constants.space.rawValue)\(Constants.colon.rawValue)\(message)")
        case .list(let channels, let target):
            // A bare `LIST` asks for every channel. `*` only stands in when a target must follow.
            if let channels = channels, !channels.isEmpty {
                components.append(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true))
            } else if target != nil {
                components.append("\(Constants.star.rawValue)")
            }
            if let target = target {
                components.append("\(Constants.space.rawValue)\(target)")
            }
        case .privMsg(let recipients, let message), .notice(let recipients, let message):
            components.append(create(arguments: recipients.lazy.map { $0.stringValue }, buildWithComma: true))
            components.append("\(Constants.space.rawValue)\(Constants.colon.rawValue)\(message)")
        case .mode(let nick, add: let add, remove: let remove):
            // RFC 2812 §3.1.5: one mode string, `+iw-o`.
            components.append("\(nick.stringValue)")
            var modes = ""
            if let adds = add?.stringValue, !adds.isEmpty {
                modes += "\(Constants.plus.rawValue)\(adds)"
            }
            if let removes = remove?.stringValue, !removes.isEmpty {
                modes += "\(Constants.minus.rawValue)\(removes)"
            }
            if !modes.isEmpty {
                components.append("\(Constants.space.rawValue)\(modes)")
            }
        case .channelMode(let channel, addMode: let add, addParameters: let addParameters, removeMode: let remove, removeParameters: let removeParameters):
            // RFC 2812 §3.2.3: each `+`/`-` group is followed by its own parameters, one per mode.
            components.append("\(channel.stringValue)")
            if let adds = add?.stringValue, !adds.isEmpty {
                components.append(modeGroup(Constants.plus.rawValue, adds, addParameters ?? [], adding: true))
            }
            if let removes = remove?.stringValue, !removes.isEmpty {
                components.append(modeGroup(Constants.minus.rawValue, removes, removeParameters ?? [], adding: false))
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
            } else if onlyOperators {
                components.append(Constants.oString.rawValue)
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
        case .numeric(_, let args), .otherNumeric(_, let args):
            if value.target != nil {
                // RFC 2812 form: `<numeric> <target> <param> ... [:<trailing>]`.
                components.append(parameters(args))
            } else {
                // Legacy NeedleTail form, no target: `<numeric> :<arg>, <arg>`. The parser still
                // reads it, so clients built before targets were sent keep working.
                components.append(create(arguments: args, buildWithColon: true, buildWithComma: true))
            }
        case .otherCommand(let name, let args) where isCapReply(name, value.target):
            // CAP replies the `.cap` case can't hold (`LS *` continuations, `NEW`, `DEL`): the
            // capability list is always the trailing parameter, as `.cap` writes it.
            components.append(parameters(Array(args.dropLast())) + (args.count > 1 ? Constants.space.rawValue : "") + "\(Constants.colon.rawValue)\(args.last ?? "")")
        case .otherCommand(_, let args):
            // One argument stays `CMD :value`. Several are separate RFC parameters, which
            // older NeedleTail parsers also read correctly.
            components.append(args.count > 1 ? parameters(args) : create(arguments: args, buildWithColon: true, buildWithComma: true))
        case .cap(let subCommand, let capabilityIds):
            components.append("\(subCommand.commandAsString)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(capabilityIds.joined(separator: Constants.space.rawValue))")
        case .pong(server: let server, server2: let server2):
            components.append(parameters([server, server2].compactMap { $0 }))
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
            // The password is the last parameter, so it may hold spaces as a trailing one.
            components.append(parameters([username, password]))
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
        case .clearmode(let channel, let mode):
            components.append("\(channel.stringValue)\(Constants.space.rawValue)\(mode)")
        case .rehash:
            // No additional parameters
            break
        case .restart:
            // No additional parameters
            break
        case .die:
            // No additional parameters
            break
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
        case .pass(let password):
            components.append(parameters([password]))
        case .service(let nickname, let distribution, let type, let info):
            components.append("\(nickname)\(Constants.space.rawValue)\(Constants.star.rawValue)\(Constants.space.rawValue)\(distribution)\(Constants.space.rawValue)\(type)\(Constants.space.rawValue)0\(Constants.space.rawValue)\(Constants.colon.rawValue)\(info)")
        case .servlist(let mask, let type):
            // A type needs a mask in front of it; `*` matches every service.
            let values = type.map { [mask ?? Constants.star.rawValue, $0] } ?? [mask].compactMap { $0 }
            components.append(parameters(values))
        case .squery(let serviceName, let text):
            components.append("\(serviceName)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(text)")
        case .whowas(let nicks, let count, let target):
            var values = [nicks.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)]
            if let count {
                values.append(String(count))
                if let target { values.append(target) }
            }
            components.append(parameters(values))
        case .error(let message):
            components.append("\(Constants.colon.rawValue)\(message)")
        case .summon(let user, let target, let channel):
            var values = [user]
            if let target {
                values.append(target)
                if let channel { values.append(channel.stringValue) }
            }
            components.append(parameters(values))
        case .userhost(let nicks):
            components.append(arguments(nicks.map { $0.stringValue }))
        }
        // Drop the separator spaces a case leaves when it writes no parameters. A trailing
        // parameter ends the line and is kept verbatim, spaces included (RFC 2812 §2.3.1).
        var line = components.joined()
        if !components[parametersStart...].joined().contains("\(Constants.space.rawValue)\(Constants.colon.rawValue)") {
            while line.last == Character(Constants.space.rawValue) { line.removeLast() }
        }
        return line
    }

    /// RFC 2812 §3.1.3 `USER` mode: bit 2 asks for `w`, bit 3 for `i`. Other modes can't be set here.
    static func userModeBitmask(_ modes: IRCUserModeFlags) -> Int {
        (modes.contains(.wallOps) ? 4 : 0) | (modes.contains(.invisible) ? 8 : 0)
    }
    
    // MARK: - Helper Methods
    
    /// Commands whose `IRCMessage.target` is written as their first parameter.
    static func carriesTarget(_ command: IRCCommand) -> Bool {
        switch command {
        case .numeric, .otherNumeric, .cap:
            return true
        case .otherCommand(let name, _):
            return name.uppercased() == Constants.cap.rawValue
        default:
            return false
        }
    }
    
    /// A server CAP reply that arrived as `.otherCommand` because `.cap` has no form for it.
    static func isCapReply(_ name: String, _ target: String?) -> Bool {
        target != nil && name.uppercased() == Constants.cap.rawValue
    }
    
    /// One `+`/`-` group and its parameters. Each parameter needs its own mode letter, so a
    /// list mode with several parameters is repeated: `+b` with two masks is `+bb mask1 mask2`.
    static func modeGroup(_ sign: String, _ letters: String, _ parameters: [String], adding: Bool) -> String {
        var modes = letters
        let takers = letters.filter { NeedleTailIRCCommandParser.channelModeTakesParameter($0, adding: adding) }
        if let last = takers.last, parameters.count > takers.count {
            modes += String(repeating: last, count: parameters.count - takers.count)
        }
        return ([sign + modes] + parameters).map { " \($0)" }.joined()
    }
    
    /// RFC 2812 §2.3.1 parameters: space-separated middles, and a `:` on the last one only
    /// when it is empty, contains a space or starts with `:`.
    static func parameters(_ values: [String]) -> String {
        values.enumerated().map { index, value in
            let isLast = index == values.count - 1
            let needsTrailing = value.isEmpty || value.contains(Constants.space.rawValue) || value.hasPrefix(Constants.colon.rawValue)
            return isLast && needsTrailing ? "\(Constants.colon.rawValue)\(value)" : value
        }.joined(separator: Constants.space.rawValue)
    }
    
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
