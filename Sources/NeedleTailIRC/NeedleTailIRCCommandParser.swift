import Logging
import NeedleTailLogger
import CypherProtocol


struct IRCCommandParser {

    enum CommandParserErrors: Error, Sendable {
        case invalidNick(String), invalidInfo, invalidArgument, invalidChannelName(String), missingRecipient, invalidMessageTarget(String), missingArgument, unexpectedArguments(String)
    }
    
    static func parse(command: String, arguments: [String]) throws -> IRCCommand {
        switch command.uppercased() {
            // <nickname> [ <hopcount> ]
        case Constants.nick.rawValue:
            guard arguments.count == 1 else { throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.invalidNick(arguments.first ?? "") }
            let splitNick = first.components(separatedBy: Constants.underScore.rawValue)
            guard let name = splitNick.first else { throw CommandParserErrors.invalidNick(arguments.first ?? "") }
            guard let id = splitNick.last else { throw CommandParserErrors.invalidNick(arguments.first ?? "") }
            let deviceId = DeviceId(id)
            guard let nick = NeedleTailNick(name: name, deviceId: deviceId) else {
                throw CommandParserErrors.invalidNick("\(name)\(deviceId)")
            }
            return .NICK(nick)
            // RFC 1459 <username> <hostname> <servername> <realname>
            // RFC 2812 <username> <mode> <mask> <realname>
        case Constants.user.rawValue:
            guard arguments.count == 4 else { throw CommandParserErrors.unexpectedArguments("Expected: 4 Found: \(arguments.count)") }
            var info: IRCUserInfo?
            let username = arguments[0]
            let realname = arguments[3]
            if let mask = UInt16(arguments[1]) {
                info = IRCUserInfo(
                    username: username,
                    usermask: .init(rawValue: mask),
                    realname: realname
                )
            } else {
                let hostname = arguments[1]
                let servername = arguments[2]
               
                info = IRCUserInfo(
                    username: username,
                    hostname: hostname,
                    servername: servername,
                    realname: realname
                )
            }
            guard let info = info else { throw CommandParserErrors.invalidInfo }
            return .USER(info)
            // [<Quit message>]
        case Constants.quit.rawValue:
            guard arguments.count == 1 else { throw CommandParserErrors.unexpectedArguments("Expected: 1 Found: \(arguments.count)") }
            return .QUIT(arguments.first)
            // <channel>{,<channel>} [<key>{,<key>}]
        case Constants.join.rawValue:
            guard arguments.count >= 1 && arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)") }
            guard arguments.count == 1, arguments.first != "0" else {
                let (channels, keys, _) = try getChannels(arguments)
                return .JOIN(channels: channels, keys: keys)
            }
            return .JOIN0
            // <channel>{,<channel>}
        case Constants.part.rawValue:
            guard arguments.count >= 1 && arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments \(arguments.count)") }
            let (channels, _, _) = try getChannels(arguments)
            return .PART(channels: channels)
        case Constants.mode.rawValue:
            guard arguments.count >= 1 else { throw CommandParserErrors.unexpectedArguments("Expected at least 1 arguments Found: \(arguments.count)") }
            guard let recipientString = arguments.first else { throw CommandParserErrors.missingRecipient }
            guard let recipient = IRCMessageRecipient(recipientString) else {
                throw CommandParserErrors.invalidMessageTarget(recipientString)
            }
            switch recipient {
                // <channel> {[+|-]|o|p|s|i|t|n|b|v} [<limit>] [<user>]
                //               [<ban mask>]
            case .channel(let channelName):
                if arguments.count > 1 {
                    var add = IRCChannelMode()
                    var remove = IRCChannelMode()
                    for arg in arguments.dropFirst() {
                        var isAdd = true
                        for c in arg {
                            if c == Character(Constants.plus.rawValue) {
                                isAdd = true
                            } else if c == Character(Constants.minus.rawValue) {
                                isAdd = false
                            } else if let mode = IRCChannelMode(String(c)) {
                                if isAdd {
                                    add.insert(mode)
                                } else {
                                    remove.insert(mode)
                                }
                            } else {
                                NeedleTailLogger(.init(label: "[IRCCommand]")).log(level: .warning, message: "IRCParser: unexpected IRC mode: \(c) \(arg)")
                            }
                        }
                    }
                    
                    if add == IRCChannelMode.banMask && remove.isEmpty {
                        return.CHANNELMODE_GET_BANMASK(channelName)
                    } else {
                        return.CHANNELMODE(channelName, add: add, remove: remove)
                    }
                } else {
                    return .CHANNELMODE_GET(channelName)
                }
                
            case .nick(let nick):
                if arguments.count > 1 {
                    var add = IRCUserMode()
                    var remove = IRCUserMode()
                    for arg in arguments.dropFirst() {
                        var isAdd = true
                        for c in arg {
                            if c == Character(Constants.plus.rawValue) {
                                isAdd = true
                            } else if c == Character(Constants.minus.rawValue) {
                                isAdd = false
                            } else if let mode = IRCUserMode(String(c)) {
                                if isAdd {
                                    add.insert(mode)
                                } else {
                                    remove.insert(mode)
                                }
                            } else {
                                NeedleTailLogger(.init(label: "[IRCCommand]")).log(level: .warning, message: "IRCParser: unexpected IRC mode: \(c) \(arg)")
                            }
                        }
                    }
                    return .MODE(nick, add: add, remove: remove)
                } else {
                    return .MODEGET(nick)
                }
            case .everything:
                guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
                throw CommandParserErrors.invalidMessageTarget(first)
            }
            // [<channel>{,<channel>} [<server>]]
        case Constants.list.rawValue:
            guard arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected at max 2 arguments Found: \(arguments.count)") }
            let (channels, serverList, _) = try getChannels(arguments)
            let server = serverList?.first
            return .LIST(channels: channels, target: server)
            // <channel> <user> [<comment>]
        case Constants.kick.rawValue:
            guard arguments.count == 3 else { throw CommandParserErrors.unexpectedArguments("Expected: 3 Found: \(arguments.count)") }
            let (channels, users, message) = try getChannels(arguments)
            var nicks = [NeedleTailNick]()
            for user in users ?? [] {
                if let constructedNick = user.constructedNick {
                    nicks.append(constructedNick)
                } else {
                    throw CommandParserErrors.invalidNick(user)
                }
            }
            return .KICK(channels, nicks, message)
            // <receiver>{,<receiver>} <text to be sent>
        case Constants.privMsg.rawValue, Constants.notice.rawValue:
            guard arguments.count == 2 else { throw CommandParserErrors.unexpectedArguments("Expected: 2 Found: \(arguments.count)") }
            guard let recipientString = arguments.first else { throw CommandParserErrors.missingRecipient }
            let recipients = recipientString
                .components(separatedBy: Constants.comma.rawValue)
                .compactMap{ IRCMessageRecipient(String($0.trimmingCharacters(in: .whitespacesAndNewlines))) }
            guard let message = arguments.last else { throw CommandParserErrors.missingArgument }
            if command.uppercased() == Constants.privMsg.rawValue {
                return .PRIVMSG(recipients, message)
            } else {
                return .NOTICE(recipients, message)
            }
            // [<name> [<o>]]
        case Constants.who.rawValue:
            guard arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected less than or equal to: 2 Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
            guard let last = arguments.last else { throw CommandParserErrors.missingArgument }
            switch arguments.count {
            case 0: return .WHO(usermask: nil, onlyOperators: false)
            case 1: return .WHO(usermask: first, onlyOperators: false)
            case 2: return .WHO(usermask: first,
                                onlyOperators: last == Constants.oString.rawValue)
            default: fatalError("unexpected argument count \(arguments.count)")
            }
            // [<server>] <nickmask>[,<nickmask>[,...]]
        case Constants.whoIs.rawValue:
            guard arguments.count >= 1 && arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
            guard let last = arguments.last else { throw CommandParserErrors.missingArgument }
            let maskArg = arguments.count == 1 ? first : last
            let masks   = maskArg.split(separator: Character(Constants.comma.rawValue)).map(String.init)
            return .WHOIS(server: arguments.count == 1 ? nil : first,
                          usermasks: Array(masks))
            // <nickname> <comment>
        case Constants.kill.rawValue:
            guard arguments.count == 2 else { throw CommandParserErrors.unexpectedArguments("Expected 2 arguments Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
            guard let last = arguments.last else { throw CommandParserErrors.missingArgument }
            guard let nick = first
                .components(separatedBy: Constants.comma.rawValue)
                .compactMap({ String($0.trimmingCharacters(in: .whitespacesAndNewlines)).constructedNick }).first else {
                throw CommandParserErrors.invalidNick(first)
            }
            return .KILL(nick, last)
            // <server1> [<server2>]
        case Constants.ping.rawValue:
            guard arguments.count >= 1 && arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
            guard let last = arguments.last else { throw CommandParserErrors.missingArgument }
            return .PING(server: first,
                         server2: arguments.count > 1 ? last : nil)
            // <daemon> [<daemon2>]
        case Constants.pong.rawValue:
            guard arguments.count >= 1 && arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
            guard let last = arguments.last else { throw CommandParserErrors.missingArgument }
            return .PONG(server: first,
                         server2: arguments.count > 1 ? last : nil)
            // <nickname>{<space><nickname>}
        case Constants.isOn.rawValue:
            guard arguments.count >= 1 else { throw CommandParserErrors.unexpectedArguments("Expected at least 1 arguments Found: \(arguments.count)") }
            var nicks = [NeedleTailNick]()
            for arg in arguments {
                guard let nick = arg.constructedNick else { throw CommandParserErrors.invalidNick(arg) }
                nicks.append(nick)
            }
                return .ISON(nicks)
        case Constants.cap.rawValue:
            guard arguments.count >= 1 && arguments.count <= 2 else { throw CommandParserErrors.unexpectedArguments("Expected between 1 and 2 arguments Found: \(arguments.count)") }
            guard let first = arguments.first else { throw CommandParserErrors.missingArgument }
            guard let last = arguments.last else { throw CommandParserErrors.missingArgument }
            guard let subcmd = IRCCommand.CAPSubCommand(rawValue: first) else {
                throw MessageParsingErrors.invalidCAPCommand(first)
            }
            let capIDs = arguments.count > 1
            ? last.components(separatedBy: Constants.space.rawValue)
            : []
            return .CAP(subcmd, capIDs)
        default:
            return .otherCommand(command.uppercased(), arguments)
        }
    }
    
    
    //All arguments should follow a pattern, this pattern, #channelOne,#channelTwo userOne,userTwo, :some message to send
    static func getChannels(_ arguments: [String]) throws -> ([IRCChannelName], [String]?, [String]) {
     
        var arguments = arguments
        var verifiedChannels = [IRCChannelName]()
        var metadataList = [String]()
        var messageList = [String]()
        if arguments.count == 1 {
            arguments = arguments.joined().components(separatedBy: Constants.space.rawValue)
        }
        guard let channelStrings = arguments.first else { throw CommandParserErrors.invalidArgument }
        for channelName in channelStrings.components(separatedBy: Constants.comma.rawValue) {
            guard let verified = IRCChannelName(channelName) else { throw CommandParserErrors.invalidChannelName(channelName)
            }
            verifiedChannels.append(verified)
        }
        if arguments.indices.contains(1) {
            let metadata = arguments[1]
            for item in metadata.components(separatedBy: Constants.comma
                .rawValue) {
                metadataList.append(item)
            }
            return (verifiedChannels, metadataList, [])
        } else if arguments.indices.contains(2) {
            let message = arguments[2]
            for item in message.components(separatedBy: Constants.comma
                .rawValue) {
                messageList.append(item)
            }
            return (verifiedChannels, metadataList, messageList)
        } else {
            return (verifiedChannels, nil, [])
        }
    }
}


public extension IRCCommand {
    
    init(_ command: String, arguments: [String]) throws {
        self = try IRCCommandParser.parse(command: command, arguments: arguments)
    }
 
    init(_ v: Int, arguments: [String]) throws {
        if let code = IRCCommandCode(rawValue: v) {
            self = .numeric(code, arguments)
        }
        else {
            self = .otherNumeric(v, arguments)
        }
    }
}
