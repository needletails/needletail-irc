import NIOCore

public struct NeedleTailIRCEncoder: Sendable {
    
    static let packetDerivation = PacketDerivation()
    
    //    [':' SOURCE]? ' ' COMMAND [' ' ARGS]? [' :' LAST-ARG]?
    public static func encode(
        value: IRCMessage
    ) async -> String {
        var newTag = ""
        var newOrigin = ""
        var newTarget = ""
        var newString = ""
        let command = value.command.commandAsString
        
        if value.tags != [], value.tags != nil {
            for tag in value.tags ?? [] {
                newTag += Constants.atString.rawValue + tag.key + Constants.equalsString.rawValue + tag.value + Constants.semiColon.rawValue
            }
            newTag = newTag + Constants.space.rawValue
        }
        
        if let origin = value.origin, !origin.isEmpty {
            newOrigin = Constants.colon.rawValue + origin + Constants.space.rawValue
        }
        
        if let target = value.target {
            newTarget = Constants.space.rawValue + target
        }
        
        let base = newTag + newOrigin + command + newTarget
        
        switch value.command {
            
        case .NICK(let v), .MODEGET(let v):
            newString = base + Constants.space.rawValue + v.stringValue
            
        case .USER(let userInfo):
            let userBase = base + Constants.space.rawValue + userInfo.username
            if let mask = userInfo.usermask {
                newString = userBase + Constants.space.rawValue + String(mask.maskValue) + Constants.space.rawValue + Constants.star.rawValue
            } else {
                newString = userBase + Constants.space.rawValue + (userInfo.hostname ?? Constants.star.rawValue) + Constants.space.rawValue + (userInfo.servername ?? Constants.star.rawValue)
            }
            newString += Constants.space.rawValue + Constants.colon.rawValue + userInfo.realname
        case .ISON(let nicks):
            newString += base + arguments(nicks.lazy.map({ $0.stringValue }))
        case .QUIT(.none):
            break
        case .QUIT(.some(let value)):
            newString = base + Constants.space.rawValue + Constants.colon.rawValue + value
            
        case .PING(server: let server, server2: let server2),
                .PONG(server: let server, server2: let server2):
            var servers = [String]()
             if let server2 = server2 {
                 servers.append(contentsOf: [server, server2])
             } else {
                 servers.append(server)
             }
            newString = base + create(
                arguments: servers,
                buildWithComma: true
            )
        case .JOIN(channels: let channels, keys: let keys):
            newString = base + Constants.space.rawValue
            newString += create(
                arguments: channels.lazy.map({ $0.stringValue }),
                buildWithComma: true
            ).replacingOccurrences(of: Constants.space.rawValue, with: Constants.none.rawValue)
            if let keys = keys {
                newString += create(
                    arguments: keys,
                    buildWithComma: true
                )
            }
        case .JOIN0:
            newString = base + Constants.space.rawValue + Constants.star.rawValue
            
        case .PART(channels: let channels):
            newString = base + create(
                arguments: channels.lazy.map({ $0.stringValue }),
                buildWithComma: true
            )
            
        case .LIST(channels: let channels, target: let target):
            if let channels = channels {
                newString = base + create(
                    arguments: channels.lazy.map({ $0.stringValue }),
                    buildWithComma: true
                )
            } else {
                newString = base + Constants.space.rawValue + Constants.star.rawValue
            }
            if let target = target {
                newString += Constants.space.rawValue + target
            }
            
        case .PRIVMSG(let recipients, let message),
                .NOTICE(let recipients, let message):
            newString = base + create(
                arguments: recipients.lazy.map({ $0.stringValue }),
                buildWithComma: true
            )
            newString += Constants.space.rawValue + Constants.colon.rawValue + message
        case .MODE(let nick, add: let add, remove: let remove):
            newString = base + Constants.space.rawValue + nick.stringValue
            if let adds = add?.stringValue.map({ "\(Constants.plus.rawValue)\($0)" }) {
                newString += arguments(adds)
            }
            if let removes = remove?.stringValue.map({ "\(Constants.minus.rawValue)\($0)" }) {
                newString += arguments(removes)
            }
            if (add == nil) && (remove == nil) {
                newString += Constants.space.rawValue + Constants.colon.rawValue
            }
        case .CHANNELMODE(let channel, add: let add, addParameters: let addParameters, remove: let remove, removeParameters: let removeParameters):
            newString = base + Constants.space.rawValue + channel.stringValue
            if let adds = add?.stringValue.map({ "\(Constants.plus.rawValue)\($0)" }) {
                newString += arguments(adds) + Constants.space.rawValue
                if let addParameters = addParameters {
                    newString += addParameters.joined(separator: Constants.comma.rawValue)
                }
            }
            if let removes = remove?.stringValue.map({ "\(Constants.minus.rawValue)\($0)" }) {
                newString += arguments(removes) + Constants.space.rawValue
                if let removeParameters = removeParameters {
                    newString += removeParameters.joined(separator: Constants.comma.rawValue)
                }
            }
        case .CHANNELMODE_GET(let value):
            newString = base + Constants.space.rawValue + value.stringValue
            
        case .CHANNELMODE_GET_BANMASK(let value):
            newString = base + Constants.space.rawValue + value.stringValue + Constants.space.rawValue + Constants.plus.rawValue + Constants.bString.rawValue
        case .WHOIS(server: let server, usermasks: let usermasks):
            newString = base
            if let target = server {
                newString += Constants.space.rawValue + target
            }
            newString += create(
                arguments: usermasks,
                buildWithColon: true,
                buildWithComma: true
            )
        case .WHO(usermask: let usermask, onlyOperators: let onlyOperators):
            newString += base
            if let mask = usermask {
                newString += Constants.space.rawValue + mask
                if onlyOperators {
                    newString += Constants.space.rawValue + Constants.oString.rawValue
                }
            }
        case .KICK(let channels, let users, let comments):
            newString = base
            newString += create(
                arguments: channels.lazy.map({ $0.stringValue }),
                buildWithComma: true
            )
            newString += create(
                arguments: users.lazy.map({ $0.stringValue }),
                buildWithComma: true
            )
            newString += create(
                arguments: comments.lazy.map({ $0 }),
                buildWithColon: true,
                joinWithSpace: true
            )
        case .KILL(let nick, let comment):
            newString = base + Constants.space.rawValue + nick.stringValue + Constants.space.rawValue + Constants.colon.rawValue + comment
        case .numeric(_, let args),
                .otherCommand(_, let args),
                .otherNumeric(_, let args):
            newString = base + create(
                arguments: args,
                buildWithColon: true,
                buildWithComma: true
            )
        case .CAP(let subCommand, let capabilityIds):
            newString = base + Constants.space.rawValue + subCommand.commandAsString + Constants.space.rawValue + Constants.colon.rawValue
            newString += capabilityIds.joined(separator: Constants.space.rawValue)
        }
        if newString.last == Character(Constants.space.rawValue) {
            newString = String(newString.dropLast())
        }
        return newString
    }
    
    public static func derivePacket(ircMessage: String) async throws -> [ByteBuffer] {
        try await packetDerivation.calculateAndDispense(ircMessage: ircMessage)
    }
    
    internal static func arguments(_ args: [String] = [""]) -> String {
        var newString = ""
        for arg in args {
            newString += Constants.space.rawValue + arg
        }
        return newString
    }
    
    //This method is used to recreate the last arguement in order for it to start with a colon. This is according to IRC syntax design.
    internal static func create(
        arguments: [String],
        buildWithColon: Bool = false,
        buildWithComma: Bool = false,
        joinWithSpace: Bool = false
    ) -> String {
        let newString = ""
        var fixed = [String]()
        var currentIndex = 0
        for argument in arguments {
            if currentIndex == 0 {
                // append a colon to the front
                if buildWithColon && !buildWithComma {
                    fixed.append(Constants.colon.rawValue + argument)
                }
                if buildWithColon && buildWithComma {
                    if arguments.count > 1 {
                        fixed.append(Constants.colon.rawValue + argument + Constants.comma.rawValue)
                    } else {
                        fixed.append(Constants.colon.rawValue + argument)
                    }
                }
                if !buildWithColon && buildWithComma {
                    if arguments.count > 1 {
                        fixed.append(argument + Constants.comma.rawValue)
                    } else {
                        fixed.append(argument)
                    }
                }
                if !buildWithColon && !buildWithComma {
                    fixed.append(argument)
                }
            } else {
                if buildWithComma && currentIndex != (arguments.count - 1) {
                    fixed.append(argument + Constants.comma.rawValue)
                } else {
                    fixed.append(argument)
                }
            }
            currentIndex += 1
        }
        if joinWithSpace {
            return newString + Constants.space.rawValue + fixed.joined(separator: Constants.space.rawValue)
        } else {
            return newString + Constants.space.rawValue + fixed.joined(separator: Constants.none.rawValue)
        }
    }
}
