//
//  NeedleTailIRCEncoder.swift
//
//
//  Created by Cole M on 9/28/22.
//

import NIOCore
import DequeModule
import NeedleTailAsyncSequence

/// A struct that provides encoding functionality for IRC messages.
public struct NeedleTailIRCEncoder: Sendable {
    
    /// A static instance of PacketDerivation used for packet handling.
    static let packetDerivation = PacketDerivation()
    
    /// Encodes an `IRCMessage` into a string representation compatible with IRC protocol.
    /// - Parameter value: The `IRCMessage` to be encoded.
    /// - Returns: A `String` representing the encoded IRC message.
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
        
        // Encode the target of the message
        if let target = value.target {
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
            components.append(create(arguments: [server, server2].compactMap { $0 }, buildWithComma: true))
        case .join(let channels, let keys):
            components.append("\(create(arguments: channels.lazy.map { $0.stringValue }, buildWithComma: true).replacingOccurrences(of: Constants.space.rawValue, with: Constants.none.rawValue))")
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
            components.append("\(server != nil ? "\(server!)" : "")\(create(arguments: usermasks, buildWithColon: true, buildWithComma: true))")
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
            components.append("\(nickname)\(Constants.space.rawValue)\(filename)\(Constants.space.rawValue)\(filesize)\(Constants.space.rawValue)\(address)\(Constants.space.rawValue)\(port)\(Constants.space.rawValue)\(offset)")
        case .numeric(_, let args), .otherCommand(_, let args), .otherNumeric(_, let args):
            components.append(create(arguments: args, buildWithColon: true, buildWithComma: true))
        case .cap(let subCommand, let capabilityIds):
            components.append("\(subCommand.commandAsString)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(capabilityIds.joined(separator: Constants.space.rawValue))")
        case .pong(server: let server, server2: let server2):
            components.append(create(arguments: [server, server2].compactMap { $0 }, buildWithComma: true))
        case .join0:
            components.append("\(Constants.star.rawValue)")
        case .sQuit(let serverName, let reason):
            components.append("\(serverName)\(Constants.space.rawValue)\(Constants.colon.rawValue)\(reason)")
        case .server(let serverName, let version, let hopCount, let info):
            components.append("\(serverName)\(Constants.space.rawValue)\(version)\(Constants.space.rawValue)\(String(hopCount))\(Constants.space.rawValue)\(Constants.colon.rawValue)\(info)")
        case .links(let mask):
            if let mask = mask {
                components.append("\(mask)")
            }
        }
        print(components)
        // Join all components and trim any trailing whitespace
        return components.joined().trimmingCharacters(in: .whitespaces)
    }
    
    /// Creates a string from an array of arguments, with options for formatting.
    /// - Parameter args: The arguments to be joined.
    /// - Returns: A formatted `String` of the arguments.
    internal static func arguments(_ args: [String] = [""]) -> String {
        args.map { "\($0)" }.joined(separator: "\(Constants.space.rawValue)")
    }
    
    /// Creates a formatted string from an array of arguments, with options for colons, commas, and space joining.
    /// - Parameters:
    ///   - arguments: The arguments to be formatted and joined.
    ///   - buildWithColon: If true, prepend a colon to the first argument.
    ///   - buildWithComma: If true, append commas between arguments.
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
