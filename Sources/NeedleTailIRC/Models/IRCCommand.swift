//
//  IRCCommand.swift
//
//
//  Created by Cole M on 9/23/22.
//

import Foundation
import NeedleTailStructures

/// Represents a command in the IRC (Internet Relay Chat) protocol.
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
    /// CHANNELMODE sets specific modes for a channel.
    case channelMode(NeedleTailChannel, addMode: IRCChannelPermissions?, addParameters: [String]?, removeMode: IRCChannelPermissions?, removeParameters: [String]?)
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
        case .join0: return Constants.join0.rawValue
        case .part: return Constants.part.rawValue
        case .list: return Constants.list.rawValue
        case .privMsg: return Constants.privMsg.rawValue
        case .notice: return Constants.notice.rawValue
        case .cap: return Constants.cap.rawValue
        case .mode, .modeGet: return Constants.mode.rawValue
        case .whois: return Constants.whoIs.rawValue
        case .who: return Constants.who.rawValue
        case .channelMode: return Constants.mode.rawValue
        case .channelModeGet, .channelModeGetBanMask: return Constants.mode.rawValue
        case .kick: return Constants.kick.rawValue
        case .kill: return Constants.kill.rawValue
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
        case .modeGet(let name):
            return [name.stringValue]
        case .channelModeGet(let name), .channelModeGetBanMask(let name):
            return [name.stringValue]
        case .whois(let server, let usermasks):
            return [server ?? "", usermasks.joined(separator: Constants.comma.rawValue)]
        case .who(let usermask, let onlyOperators):
            return usermask != nil ? [usermask!, onlyOperators ? Constants.oString.rawValue : ""] : []
        case .kick(let channels, let users, let comments):
            let channelList = channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)
            let userList = users.map { $0.stringValue }.joined(separator: Constants.comma.rawValue)
            return [channelList, userList, comments.joined(separator: Constants.comma.rawValue)]
        case .kill(let nick, let comment):
            return [nick.stringValue, comment]
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
        }
    }

    
    // MARK: - CustomStringConvertible Conformance
    
    /// Provides a string representation of the IRCMessage.
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
        case .otherCommand(let cmd, let args): return "<IRCMessage: \(cmd) args=\(args.joined(separator: Constants.comma.rawValue))>"
        case .otherNumeric(let cmd, let args): return "<IRCMessage: \(cmd) args=\(args.joined(separator: Constants.comma.rawValue))>"
        case .numeric(let cmd, let args): return "<IRCMessage: \(cmd.rawValue) args=\(args.joined(separator: Constants.comma.rawValue))>"
        default: return "<Unknown Command>"
        }
    }
}
