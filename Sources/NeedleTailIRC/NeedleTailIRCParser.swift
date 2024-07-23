import Foundation
import NIOConcurrencyHelpers
import NeedleTailLogger

public enum MessageParsingErrors: Error, Sendable {
    case invalidArguments(String), invalidCAPCommand(String)
}

public struct NeedleTailIRCParser: Sendable {
    static let logger = NeedleTailLogger(.init(label: "[MessageParser]"))
    
    public init() {}
    
    enum IRCCommandKey {
        case int(Int)
        case string(String)
    }
    
    /// IRCMessage sytax
    /// ::= ['@' <tags> SPACE] [':' <source> SPACE] <command> <parameters> <crlf>
    public static func parseMessage(_ message: String) throws -> IRCMessage {
        var origin: String?
        var seperatedTags: [String] = []
        var taglessMessage: String = ""
        var command = ""
        var argumentString = ""
        
        self.logger.log(level: .trace, message: "Parsing Message....")
        
        //1. Separate Tags
        if message.contains(Constants.atString.rawValue) && message.contains(Constants.semiColonSpace.rawValue) {
            seperatedTags.append(contentsOf: message.components(separatedBy: Constants.semiColonSpace.rawValue))
            taglessMessage = seperatedTags[1]
        } else {
            taglessMessage = message
        }
        
        //2. Get message Origin
        if taglessMessage.first == Character(Constants.colon.rawValue) {
            let seperatedMessage = taglessMessage.components(separatedBy: Constants.space.rawValue)
            origin = String(seperatedMessage[0].dropFirst())
            command = seperatedMessage[1].uppercased()
            argumentString = seperatedMessage.dropFirst(2).joined(separator: Constants.space.rawValue)
        } else {
            let seperatedMessage = taglessMessage.components(separatedBy: Constants.space.rawValue)
            command = seperatedMessage[0].uppercased()
            argumentString = seperatedMessage.dropFirst().joined(separator: Constants.space.rawValue)
        }
        
        //Create Tags
        var tags: [IRCTags]?
        if seperatedTags != [] {
            tags = try parseTags(
                tags: seperatedTags[0]
            )
        }
        
        let (arguments, target) = try parseArgument(
            command: command,
            argumentString: argumentString
        )
        if let command = Int(command) {
            let builtCommand = try IRCCommand(numeric: command, arguments: arguments)
            return IRCMessage(origin: origin,
                              target: target,
                              command: builtCommand,
                              arguments: arguments,
                              tags: tags)
        } else {
            let builtCommand = try IRCCommand(command: command, arguments: arguments)
            return IRCMessage(origin: origin,
                              target: target,
                              command: builtCommand,
                              arguments: arguments,
                              tags: tags)
        }
    }
    
    // https://ircv3.net/specs/extensions/message-tags.html#format
    static func parseTags(
        tags: String = ""
    ) throws -> [IRCTags]? {
        if tags.hasPrefix(Constants.atString.rawValue) {
            var tagArray: [IRCTags] = []
            let seperatedTags = tags.components(separatedBy: Constants.semiColon.rawValue + Constants.atString.rawValue)
            for tag in seperatedTags {
                var tag = tag
                tag.removeAll(where: { $0 == Character(Constants.atString.rawValue) })
                let kvpArray = tag.split(separator: Character(Constants.equalsString.rawValue), maxSplits: 1)
                guard let key = kvpArray.first else { return nil }
                guard let value = kvpArray.last else { return nil }
                tagArray.append(
                    IRCTags(key: String(key), value: String(value))
                )
            }
            self.logger.log(level: .trace, message: "Parsing Tags")
            return tagArray
        }
        return nil
    }
    
    static func parseArgument(
        command: String,
        argumentString: String
    ) throws -> ([String], String?) {
        var arguments = [String]()
        var target: String? = nil
        switch try parseCommand(command: command) {
        case .string(let command):
            //3. Get Command
            switch command {
            case Constants.nick.rawValue:
                arguments.append(argumentString)
            case Constants.user.rawValue:
                let seperatedByLastMessage = argumentString.components(separatedBy: Constants.colon.rawValue)
                guard var initialArugments = seperatedByLastMessage.first?.components(separatedBy: Constants.space.rawValue) else { throw MessageParsingErrors.invalidArguments("From Command: \(command)")}
                initialArugments = initialArugments.filter { !$0.isEmpty && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                guard let realNameArguemnt = seperatedByLastMessage.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                arguments.append(contentsOf: initialArugments)
                arguments.append(realNameArguemnt)
            case Constants.quit.rawValue:
                let quitMessage = String(argumentString.dropFirst())
                arguments.append(quitMessage)
            case Constants.join.rawValue:
                let seperatedComponents = argumentString.components(separatedBy: Constants.space.rawValue)
                guard let channelsComponent = seperatedComponents.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                arguments.append(channelsComponent)
                if seperatedComponents.count == 2 {
                    guard let keysComponent = seperatedComponents.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                    arguments.append(keysComponent)
                }
            case Constants.part.rawValue:
                let seperatedComponents = argumentString.components(separatedBy: Constants.space.rawValue)
                guard let channelsComponent = seperatedComponents.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                let channels = channelsComponent.components(separatedBy: Constants.comma.rawValue)
                arguments.append(contentsOf: channels)
            case Constants.list.rawValue:
                let seperatedComponents = argumentString.components(separatedBy: Constants.space.rawValue)
                guard let channelsComponent = seperatedComponents.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                arguments.append(channelsComponent)
                if seperatedComponents.count == 2 {
                    guard let targetComponent = seperatedComponents.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                    arguments.append(targetComponent)
                }
            case Constants.kick.rawValue:
                let seperatedByLastMessage = argumentString.components(separatedBy: Constants.colon.rawValue)
                guard let initialComponent = seperatedByLastMessage.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                var seperatedComponents = initialComponent.components(separatedBy: Constants.space.rawValue)
                seperatedComponents = seperatedComponents.filter { !$0.isEmpty && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                guard let channelsComponent = seperatedComponents.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                arguments.append(channelsComponent)
                
                if seperatedComponents.count == 2 {
                    guard let kickedUser = seperatedComponents.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                    arguments.append(kickedUser)
                }
                if seperatedByLastMessage.count == 2 {
                    guard let messageArgument = seperatedByLastMessage.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                    arguments.append(messageArgument)
                }
                
                // <receiver>{,<receiver>} <text to be sent>
            case Constants.privMsg.rawValue, Constants.notice.rawValue:
                let seperatedByLastMessage = argumentString.components(separatedBy: Constants.colon.rawValue)
                guard let messageArgument = seperatedByLastMessage.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                guard let initialComponent = seperatedByLastMessage.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                
                let seperatedComponents = initialComponent.components(separatedBy: Constants.space.rawValue)
                guard let recipientComponent = seperatedComponents.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                let recipients = recipientComponent.components(separatedBy: Constants.comma.rawValue)
                
                arguments.append(contentsOf: recipients)
                arguments.append(messageArgument)
            case Constants.whoIs.rawValue:
                let seperatedByLastMessage = argumentString.components(separatedBy: Constants.colon.rawValue)
                
                guard let initialComponent = seperatedByLastMessage.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                let seperatedComponents = initialComponent.components(separatedBy: Constants.space.rawValue)
                
                guard let serverComponent = seperatedComponents.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                guard let messageArgument = seperatedByLastMessage.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                
                arguments.append(serverComponent)
                arguments.append(messageArgument)
                // <nickname> <comment>
            case Constants.kill.rawValue:
                let seperatedByLastMessage = argumentString.components(separatedBy: Constants.colon.rawValue)
                guard let messageArgument = seperatedByLastMessage.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                guard let nickArgument = seperatedByLastMessage.first else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                arguments.append(nickArgument.trimmingCharacters(in: .whitespaces))
                arguments.append(messageArgument)
            case Constants.ping.rawValue, Constants.pong.rawValue:
                let seperated = argumentString.components(separatedBy: Constants.comma.rawValue)
                arguments.append(contentsOf: seperated)
            case Constants.cap.rawValue:
                let seperatedByLastMessage = argumentString
                    .components(separatedBy: Constants.colon.rawValue)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                arguments.append(contentsOf: seperatedByLastMessage)
            case Constants.mode.rawValue:
                let separated = argumentString.components(separatedBy: Constants.space.rawValue)
                let rejoined = String(separated.dropFirst().joined(by: Constants.space.rawValue))
                let components = rejoined.components(separatedBy: Constants.space.rawValue)
                if let modeType = separated.first {
                    arguments.append(modeType)
                }
                if let addIndex = components.firstIndex(where: { $0.contains(String(Constants.plus.rawValue)) }) {
                    arguments.append(components[addIndex])
                    if components.count >= 2, !components[1].contains(Constants.minus.rawValue) {
                        arguments.append(contentsOf: components[1].components(separatedBy: Constants.comma.rawValue))
                    }
                }
                
                if let removeIndex = components.firstIndex(where: { $0.contains(String(Constants.minus.rawValue)) }) {
                    arguments.append(components[removeIndex])
                    if components.count >= 2, let lastArg = components.last, !lastArg.contains(Constants.minus.rawValue) {
                        arguments.append(contentsOf: components[1].components(separatedBy: Constants.comma.rawValue))
                    }
                }
            default:
                if command.isOtherCommand, command == Constants.multipartMediaUpload.rawValue || command == Constants.requestMediaDeletion.rawValue {
                    let multipartUploadArguments = argumentString.dropFirst().components(separatedBy: Constants.comma.rawValue)
                    arguments.append(contentsOf: multipartUploadArguments)
                } else if command.isOtherCommand {
                    let otherCommandArgument = String(argumentString.dropFirst())
                    arguments.append(otherCommandArgument)
                } else {
                    let modeArguments = argumentString.components(separatedBy: Constants.space.rawValue)
                    arguments.append(contentsOf: modeArguments)
                }
            }
        case .int(_):
            let seperatedByLastMessage = argumentString.components(separatedBy: Constants.colon.rawValue)
            target = seperatedByLastMessage.first
            guard let lastMessage = seperatedByLastMessage.last else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
            if lastMessage.contains(Constants.comma.rawValue) == true {
                guard let args = seperatedByLastMessage.last?.components(separatedBy: Constants.comma.rawValue) else { throw MessageParsingErrors.invalidArguments("From Command: \(command)") }
                arguments.append(contentsOf: args)
            } else {
                arguments.append(lastMessage)
            }
        }
        return (arguments, target)
    }
    
    
    static func parseCommand(command: String) throws -> IRCCommandKey {
        precondition(!command.isEmpty)
        var commandKey: IRCCommandKey = .string("")
        if command.first?.isLetter == true {
            commandKey = .string(command)
        } else {
            let command = command.components(separatedBy: .decimalDigits.inverted)
            for c in command {
                if !c.isEmpty{
                    commandKey = .int(Int(c) ?? 0)
                }
            }
        }
        self.logger.log(level: .trace, message: "Parsing CommandKey")
        return commandKey
    }
}

extension String: Sendable {
    var isInt: Bool {
        return Int(self) != nil
    }
}

extension Int {
    var argumentIsArray: Bool {
        self == 303 ? true : false
    }
}


extension String {
    var isChannel: Bool {
        hasPrefix(Constants.ampersand.rawValue) || hasPrefix(Constants.hashTag.rawValue) || hasPrefix(Constants.plus.rawValue) || hasPrefix(Constants.exclamation.rawValue)
    }
    
    var isOtherCommand: Bool {
        self == Constants.badgeUpdate.rawValue || self == Constants.multipartMediaDownload.rawValue || self == Constants.multipartMediaUpload.rawValue || self == Constants.listBucket.rawValue || self == Constants.publishBlob.rawValue || self == Constants.readPublishedBlob.rawValue || self == Constants.readKeyBundle.rawValue || self == Constants.pass.rawValue || self == Constants.deleteOfflineMessage.rawValue || self == Constants.offlineMessages.rawValue || self == Constants.requestMediaDeletion.rawValue || self == Constants.destoryUser.rawValue || self == Constants.newDevice.rawValue || self == Constants.registryRequest.rawValue
    }
    
    var isNumeric: Bool {
        self.isInt
    }
}
