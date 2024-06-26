//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio-irc open source project
//
// Copyright (c) 2018-2021 ZeeZide GmbH. and the swift-nio-irc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIOIRC project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Data

public enum IRCCommand: Codable, Sendable {

    /// The NICK message is used to change the user's nickname on the IRC network.
    case NICK(NeedleTailNick)
    /// The USER message is part of the initial registration process when a user connects to an IRC server.
    case USER(IRCUserInfo)
    /// The ISON message is used to query the server about the online status of a list of nicknames.
    case ISON([NeedleTailNick])
    /// The QUIT message is used to gracefully disconnect from the IRC network.
    case QUIT(String?)
    /// The PING message is sent by the server to the client to verify that the client is still connected and responsive.
    case PING(server: String, server2: String?)
    /// The PONG message is used to respond to a PING message sent by the server to check the client's connection status.
    case PONG(server: String, server2: String?)
    /// The JOIN command is used by IRC clients to join a specific channel on the IRC network. Keys are passwords for a Channel.
    case JOIN(channels: [IRCChannelName], keys: [String]?)
    /// JOIN-0 is actually "unsubscribe all channels"
    case JOIN0
    /// The PART message is a way for users to indicate their intention to depart from a channel without abruptly disconnecting from the server.
    case PART(channels: [IRCChannelName])
    /// The LIST command helps users discover and identify channels of interest for communication and interaction within the IRC network.
    case LIST(channels: [IRCChannelName]?, target: String?)
    /// PRIVMSG is used for regular chat messages, private conversations, and group discussions, with messages displayed prominently and often prompting responses.
    case PRIVMSG([IRCMessageRecipient], String)
    /// NOTICE is used for sending important messages, notifications, or alerts that are displayed less prominently, do not trigger automatic responses, and are intended for informational purposes rather than ongoing conversation.
    case NOTICE ([IRCMessageRecipient], String)
    /// MODE is designed to set specific modes for a given needletail nick. See **IRCUserMode** for more details
    case MODE(
        NeedleTailNick,
        add: IRCUserMode?,
        remove: IRCUserMode?
    )
    /// MODE_GET gets the IRCUserModes for a given NeedleTailNick
    case MODEGET(NeedleTailNick)
    /// When a Channel Mode is ban and a member is listed they can no long join the channel until further notice. This is more severe than a simple KICK message
    ///  CHANNELMODE is designed to set specific modes for a given channel. See **IRCChannelMode** for more details
    case CHANNELMODE(
        IRCChannelName,
        add: IRCChannelMode?,
        addParameters: [String]?,
        remove: IRCChannelMode?,
        removeParameters: [String]?
    )
    /// CHANNELMODE_GET gets the Channel Modes for a given IRCChannelName
    case CHANNELMODE_GET(IRCChannelName)
    /// CHANNELMODE_GET_BANMASK gets the banned users for a give IRCChannelName
    case CHANNELMODE_GET_BANMASK(IRCChannelName)
    /// The WHOIS command provides comprehensive information about the specified user, including their nickname, username, hostname, server, real name, and other details.
    case WHOIS(server: String?, usermasks: [String])
    /// The WHO command typically returns basic information about users, such as their nickname, username, hostname, server, and other relevant details.
    case WHO(usermask: String?, onlyOperators: Bool)
    /// KICK is less severe than Channel Ban. Kicked members can rejoin a channel right away.
    case KICK([IRCChannelName], [NeedleTailNick], [String])
    /// KILL is used to disconnect a user from the entire IRC network, requiring them to reconnect to regain access.
    case KILL(NeedleTailNick, String)
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
    case numeric(IRCCommandCode, [String])
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
    case otherCommand(String, [String])
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
    case otherNumeric(Int, [String])
    /// The CAP message is used to negotiate and manage capabilities between the client and the server during the IRC session.
    case CAP(CAPSubCommand, [String])
    
    // MARK: - IRCv3.net
    public enum CAPSubCommand: String, Sendable, Codable {
        case LS, LIST, REQ, ACK, NAK, END
        public var commandAsString : String { return rawValue }
    }
}



// MARK: - Description

extension IRCCommand: CustomStringConvertible {
    
    public var commandAsString: String {
        switch self {
        case .NICK:
            return Constants.nick.rawValue
        case .USER:
            return Constants.user.rawValue
        case .ISON:
            return Constants.isOn.rawValue
        case .QUIT:
            return Constants.quit.rawValue
        case .PING:
            return Constants.ping.rawValue
        case .PONG:
            return Constants.pong.rawValue
        case .JOIN:
            return Constants.join.rawValue
        case.JOIN0:
            return Constants.join0.rawValue
        case .PART:
            return Constants.part.rawValue
        case .LIST:
            return Constants.list.rawValue
        case .PRIVMSG:
            return Constants.privMsg.rawValue
        case .NOTICE:
            return Constants.notice.rawValue
        case .CAP:
            return Constants.cap.rawValue
        case .MODE, .MODEGET:
            return Constants.mode.rawValue
        case .WHOIS:
            return Constants.whoIs.rawValue
        case .WHO:
            return Constants.who.rawValue
        case .CHANNELMODE:
            return Constants.mode.rawValue
        case .CHANNELMODE_GET, .CHANNELMODE_GET_BANMASK:
            return Constants.mode.rawValue
        case .KICK:
            return Constants.kick.rawValue
        case .KILL:
            return Constants.kill.rawValue
        case .otherCommand(let cmd, _):
            return cmd
        case .otherNumeric(let cmd, _):
            let s = String(cmd)
            if s.count >= 3 { return s }
            return String(repeating: "0", count: 3 - s.count) + s
        case .numeric(let cmd, _):
            let s = String(cmd.rawValue)
            if s.count >= 3 { return s }
            return String(repeating: "0", count: 3 - s.count) + s
        }
    }
    
    public var arguments : [String] {
        switch self {
        case .NICK(let nick):
            return [ nick.stringValue ]
        case .USER(let info):
            if let usermask = info.usermask {
                return [ info.username, usermask.stringValue, Constants.star.rawValue, info.realname ]
            } else {
                return [ info.username,
                         info.hostname ?? info.usermask?.stringValue ?? Constants.star.rawValue,
                         info.servername ?? Constants.star.rawValue,
                         info.realname ]
            }
            
        case .ISON(let nicks): return nicks.map { $0.stringValue }
            
        case .QUIT(.none):                          return []
        case .QUIT(.some(let message)):             return [ message ]
        case .PING(let server, .none):              return [ server ]
        case .PONG(let server, .none):              return [ server ]
        case .PING(let server, .some(let server2)): return [ server, server2 ]
        case .PONG(let server, .some(let server2)): return [ server, server2 ]
            
        case .JOIN(let channels, .none):
            return [ channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue) ]
        case .JOIN(let channels, .some(let keys)):
            return [ channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue),
                     keys.joined(separator: Constants.comma.rawValue)]
            
        case .JOIN0: return [ "0" ]
            
        case .PART(let channels):
            return [ channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue) ]
            
        case .LIST(let channels, .none):
            guard let channels = channels else { return [] }
            return [ channels.map { $0.stringValue }.joined(separator: Constants.comma.rawValue) ]
        case .LIST(let channels, .some(let target)):
            return [ (channels ?? []).map { $0.stringValue }.joined(separator: Constants.comma.rawValue),
                     target ]
            
        case .PRIVMSG(let recipients, let m), .NOTICE (let recipients, let m):
            return [ recipients.map { $0.stringValue }.joined(separator: Constants.comma.rawValue), m ]
            
        case .MODE(let name, let add, let remove):
            var additionParamaters = ""
            if let add = add, !add.isEmpty {
                additionParamaters += Constants.space.rawValue + Constants.plus.rawValue + add.stringValue + Constants.space.rawValue
            }
            var removalParamaters = ""
            if let remove = remove, !remove.isEmpty {
                removalParamaters += Constants.space.rawValue + Constants.minus.rawValue + remove.stringValue + Constants.space.rawValue
            }
            return [name.stringValue, additionParamaters + removalParamaters]
        case .CHANNELMODE(let name, let add, let addParameters, let remove, let removeParameters):
            var additionParamaters = ""
            if let add = add, !add.isEmpty {
                additionParamaters += Constants.space.rawValue + Constants.plus.rawValue + add.stringValue + Constants.space.rawValue
                if let addParameters = addParameters {
                    additionParamaters += addParameters.joined(separator: Constants.comma.rawValue)
                }
            }
            var removalParamaters = ""
            if let remove = remove, !remove.isEmpty {
                removalParamaters += Constants.space.rawValue + Constants.minus.rawValue + remove.stringValue + Constants.space.rawValue
                if let removeParameters = removeParameters {
                    removalParamaters += removeParameters.joined(separator: Constants.comma.rawValue)
                }
            }
            return [name.stringValue, additionParamaters + removalParamaters]
        case .MODEGET(let name):
            return [ name.stringValue ]
        case .CHANNELMODE_GET(let name), .CHANNELMODE_GET_BANMASK(let name):
            return [ name.stringValue ]
        case .WHOIS(.some(let server), let usermasks):
            return [ server, usermasks.joined(separator: Constants.comma.rawValue)]
        case .WHOIS(.none, let usermasks):
            return [ usermasks.joined(separator: Constants.comma.rawValue) ]
        case .WHO(.none, _):
            return []
        case .WHO(.some(let usermask), false):
            return [ usermask ]
        case .WHO(.some(let usermask), true):
            return [ usermask, Constants.oString.rawValue ]
        case .KICK(let channelNames, let users, let comments):
            if channelNames.count == users.count {
                return [
                    channelNames.map { $0.stringValue }.joined(separator: Constants.comma.rawValue),
                    users.map { $0.stringValue }.joined(separator: Constants.comma.rawValue),
                    comments.map { $0 }.joined(separator: Constants.comma.rawValue)
                ]
            } else {
                guard let firstChannel = channelNames.first else { return [] }
                guard let firstUser = users.first else { return [] }
                return [
                    firstChannel.stringValue,
                    firstUser.stringValue,
                    comments.map { $0 }.joined(separator: Constants.comma.rawValue)
                ]
            }
        case .KILL(let nick, let comment):
            return [nick.stringValue, comment]
        case .numeric     (_, let args),
                .otherCommand(_, let args),
                .otherNumeric(_, let args):
            return args
            
        default: // TBD: which case do we miss???
            fatalError("unexpected case \(self)")
        }
    }
    
    public var description : String {
        switch self {
        case .PING(let server, let server2), .PONG(let server, let server2):
            if let server2 = server2 {
                return "\(commandAsString) '\(server)' '\(server2)'"
            }
            else {
                return "\(commandAsString) '\(server)'"
            }
        case .QUIT(.some(let v)):
            return Constants.quit.rawValue + Constants.space.rawValue + "'\(v)'"
        case .QUIT(.none):
            return Constants.quit.rawValue
        case .NICK(let v):
            return Constants.nick.rawValue + Constants.space.rawValue + "\(v)"
        case .USER(let v):
            return Constants.user.rawValue + Constants.space.rawValue + "\(v)"
        case .ISON(let v):
            let nicks = v.map { $0.stringValue}
            return Constants.isOn.rawValue + Constants.space.rawValue + nicks.joined(separator: Constants.comma.rawValue)
        case .MODEGET(let nick):
            return Constants.mode.rawValue + Constants.space.rawValue + "\(nick)"
        case .MODE(let nick, let add, let remove):
            var s = Constants.mode.rawValue + Constants.space.rawValue + "\(nick)"
            if let add = add, !add.isEmpty {
                s += Constants.space.rawValue + Constants.plus.rawValue + add.stringValue + Constants.space.rawValue
            }
            if let remove = remove, !remove.isEmpty {
                s += Constants.space.rawValue + Constants.minus.rawValue + remove.stringValue + Constants.space.rawValue
            }
            return s
        case .CHANNELMODE_GET(let v):
            return Constants.mode.rawValue + Constants.space.rawValue + "\(v)"
        case .CHANNELMODE_GET_BANMASK(let v):
            return Constants.mode.rawValue + Constants.space.rawValue + "\(v)" + Constants.space.rawValue + Constants.plus.rawValue + Constants.bString.rawValue
        case .CHANNELMODE(let nick, let add, let addParameters, let remove, let removeParameters):
            var s = Constants.mode.rawValue + Constants.space.rawValue + "\(nick)"
            if let add = add, !add.isEmpty {
                s += Constants.space.rawValue + Constants.plus.rawValue + add.stringValue + Constants.space.rawValue
                if let addParameters = addParameters {
                     s += addParameters.joined(separator: Constants.comma.rawValue)
                }
            }
            if let remove = remove, !remove.isEmpty {
                s += Constants.space.rawValue + Constants.minus.rawValue + remove.stringValue + Constants.space.rawValue
                if let removeParameters = removeParameters {
                     s += removeParameters.joined(separator: Constants.comma.rawValue)
                }
            }
            return s
        case .JOIN0:
            return Constants.join0.rawValue
        case .JOIN(let channels, .none):
            let names = channels.map { $0.stringValue}
            return Constants.join.rawValue + Constants.space.rawValue + names.joined(separator: Constants.comma.rawValue)
        case .JOIN(let channels, .some(let keys)):
            let names = channels.map { $0.stringValue}
            return Constants.join.rawValue + Constants.space.rawValue + names.joined(separator: Constants.comma.rawValue)
            + Constants.space.rawValue + Constants.keys.rawValue + Constants.space.rawValue + keys.joined(separator: Constants.comma.rawValue)
        case .PART(let channels):
            let names = channels.map { $0.stringValue}
            return Constants.part.rawValue + Constants.space.rawValue + names.joined(separator: Constants.comma.rawValue +  Constants.space.rawValue)
        case .LIST(.none, .none):
            return Constants.list.rawValue + Constants.space.rawValue + Constants.star.rawValue
        case .LIST(.none, .some(let target)):
            return Constants.list.rawValue + Constants.space.rawValue + Constants.star.rawValue + Constants.space.rawValue + target
        case .LIST(.some(let channels), .none):
            let names = channels.map { $0.stringValue}
            return Constants.list.rawValue + Constants.space.rawValue + names.joined(separator: Constants.comma.rawValue)
        case .LIST(.some(let channels), .some(let target)):
            let names = channels.map { $0.stringValue}
            return Constants.list.rawValue + Constants.space.rawValue + target + Constants.space.rawValue + names.joined(separator: Constants.comma.rawValue)
        case .PRIVMSG(let recipients, let message):
            let to = recipients.map { $0.description }
            return Constants.privMsg.rawValue + Constants.space.rawValue + to.joined(separator: Constants.comma.rawValue) + Constants.space.rawValue + "'\(message)'"
        case .NOTICE (let recipients, let message):
            let to = recipients.map { $0.description }
            return Constants.notice.rawValue + Constants.space.rawValue + to.joined(separator: Constants.comma.rawValue) + Constants.space.rawValue + "'\(message)'"
        case .CAP(let subcmd, let capIDs):
            return Constants.cap.rawValue + Constants.space.rawValue + "\(subcmd)" + capIDs.joined(separator: Constants.comma.rawValue)
        case .WHOIS(.none, let masks):
            return Constants.whoIs.rawValue + Constants.space.rawValue + masks.joined(separator: Constants.comma.rawValue) + Constants.space.rawValue
        case .WHOIS(.some(let target), let masks):
            return Constants.whoIs.rawValue + Constants.space.rawValue + target + Constants.space.rawValue + masks.joined(separator: Constants.comma.rawValue) + Constants.space.rawValue
        case .WHO(.none, _):
            return Constants.who.rawValue
        case .WHO(.some(let mask), let opOnly):
            let opertorOnly = opOnly ? Constants.space.rawValue + Constants.oString.rawValue : Constants.none.rawValue
            return Constants.who.rawValue + Constants.space.rawValue + mask + opertorOnly;
        case .KICK(let channels, let users, let comments):
            let channels = channels.map { $0.stringValue}
            let users = users.map { $0.stringValue}
            let comments = comments.map { $0}
            return Constants.kick.rawValue + Constants.space.rawValue + channels.joined(separator: Constants.comma.rawValue) + Constants.space.rawValue + users.joined(separator: Constants.comma.rawValue) + Constants.space.rawValue + comments.joined(separator: Constants.comma.rawValue)
        case .KILL(let nick, let comment):
            return Constants.kill.rawValue + Constants.space.rawValue + "\(nick)" + Constants.space.rawValue + "\(comment)"
        case .otherCommand(let cmd, let args):
            return "<IRCCmd: \(cmd) args=\(args.joined(separator: Constants.comma.rawValue))>"
        case .otherNumeric(let cmd, let args):
            return "<IRCCmd: \(cmd) args=\(args.joined(separator: Constants.comma.rawValue))>"
        case .numeric(let cmd, let args):
            return "<IRCCmd: \(cmd.rawValue) args=\(args.joined(separator: Constants.comma.rawValue))>"
        }
    }
}
