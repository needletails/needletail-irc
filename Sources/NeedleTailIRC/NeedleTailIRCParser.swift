//
//  NeedleTailIRCParser.swift
//
//
//  Created by Cole M on 9/28/22.
//

import Foundation
import NIOConcurrencyHelpers
import NeedleTailLogger
import NeedleTailStructures

public enum MessageParsingErrors: Error, Sendable {
    case invalidArguments(String), invalidCAPCommand(String), invalidTag
}

/// A parser for IRC messages conforming to the IRC message syntax.
public struct NeedleTailIRCParser: Sendable {
    static let logger = NeedleTailLogger(.init(label: "[MessageParser]"))
    
    public init() {}
    
    enum IRCCommandKey {
        case int(Int)
        case string(String)
    }
    
    /// Parses an IRC message string into an `IRCMessage` object.
    /// - Parameter message: The raw IRC message string to parse.
    /// - Throws: `MessageParsingErrors` for invalid message formats.
    /// - Returns: An `IRCMessage` representing the parsed message.
    public static func parseMessage(_ message: String) throws -> IRCMessage {
        var origin: String?
        var tags: [String] = []
        var command = ""
        var argumentString = ""
        var taglessMessage = ""
        
        // Log the start of the parsing process
        self.logger.log(level: .trace, message: "Parsing Message....")
        
        // 1. Separate Tags
        if message.contains(Constants.atString.rawValue) {
            guard let firstSpaceIndex = message.firstIndex(of: Character(Constants.space.rawValue)) else { throw MessageParsingErrors.invalidTag }
            let tagString = String(message[..<firstSpaceIndex])
            // 2. Set Tagless Message
            taglessMessage = String(message[message.index(after: firstSpaceIndex)...])
            
            let seperateTags = tagString.split(separator: Constants.semiColonSpace.rawValue).map { $0.trimmingCharacters(in: .whitespaces) }
            tags.append(contentsOf: seperateTags)
        } else {
            // 2. Set Tagless Message
            taglessMessage = message
        }
        
        // 3. Split the tagless message into components
        let messageComponents = taglessMessage.components(separatedBy: Constants.space.rawValue).map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 4. Extract Origin and Command
        if let firstComponent = messageComponents.first, firstComponent.hasPrefix(Constants.colon.rawValue) {
            origin = String(firstComponent.dropFirst())
            command = messageComponents[1].uppercased()
            // Extract message and non-message parts
            let messagePart = extractMessage(from: Array(messageComponents.dropFirst(2))).joined(separator: Constants.space.rawValue)
            let nonMessages = extractNonMessages(from: Array(messageComponents.dropFirst(2)))
            argumentString = nonMessages.joined(separator: Constants.space.rawValue) + (messagePart.isEmpty ? "" : " " + messagePart)
        } else {
            command = messageComponents[0].uppercased()
            argumentString = messageComponents.dropFirst().joined(separator: Constants.space.rawValue)
        }
        
        // 5. Parse Tags
        let parsedTags = !tags.isEmpty ? try parseTags(tags: tags[0]) : nil
        
        // 6. Parse Arguments
        let (arguments, target) = try parseArgument(command: command, argumentString: argumentString)
        
        // 7. Create IRCCommand
        let builtCommand: IRCCommand
        if let numericCommand = Int(command) {
            builtCommand = try IRCCommand(numeric: numericCommand, arguments: arguments)
        } else {
            builtCommand = try IRCCommand(command: command, arguments: arguments)
        }
        
        // 8. Return the constructed IRCMessage
        return IRCMessage(origin: origin, target: target, command: builtCommand, arguments: arguments, tags: parsedTags)
    }
    
    
    /// Extracts the message part from the given array of strings.
    /// - Parameter array: The array of strings to search for the message part.
    /// - Returns: An array containing the message part.
    private static func extractMessage(from array: [String]) -> [String] {
        // Find the index of the last colon
        if let lastColonIndex = array.lastIndex(where: { $0.hasPrefix(":") }) {
            return Array(array[lastColonIndex...])
        }
        return []
    }
    
    /// Extracts non-message parts from the given array of strings.
    /// - Parameter array: The array of strings to search for non-message parts.
    /// - Returns: An array containing the non-message parts.
    private static func extractNonMessages(from array: [String]) -> [String] {
        // Find the index of the last colon
        if let lastColonIndex = array.lastIndex(where: { $0.hasPrefix(":") }) {
            return Array(array[0..<lastColonIndex])
        }
        return array
    }
    
    /// Parses IRC tags from a given tag string.
    /// - Parameter tags: The string containing tags.
    /// - Throws: `MessageParsingErrors` for invalid tag formats.
    /// - Returns: An array of `IRCTag` if successful, otherwise `nil`.
    static func parseTags(tags: String = "") throws -> [IRCTag]? {
        guard tags.hasPrefix(Constants.atString.rawValue) else { return nil }
        
        var tagArray: [IRCTag] = []
        let seperatedTags = tags.components(separatedBy: Constants.semiColon.rawValue + Constants.atString.rawValue)
        
        for tag in seperatedTags {
            let cleanedTag = tag.replacingOccurrences(of: Constants.atString.rawValue, with: "")
            let kvpArray = cleanedTag.split(separator: Character(Constants.equalsString.rawValue), maxSplits: 1)
            guard let key = kvpArray.first, let value = kvpArray.last else {
                throw MessageParsingErrors.invalidArguments("Invalid tag format.")
            }
            tagArray.append(IRCTag(key: String(key), value: String(value)))
        }
        
        self.logger.log(level: .trace, message: "Parsing Tags")
        return tagArray
    }
    
    /// Parses command arguments based on the command type.
    /// - Parameters:
    ///   - command: The command string.
    ///   - argumentString: The arguments string.
    /// - Throws: `MessageParsingErrors` for invalid argument formats.
    /// - Returns: A tuple containing an array of arguments and an optional target string.
    static func parseArgument(command: String, argumentString: String) throws -> ([String], String?) {
        var arguments: [String] = []
        var target: String? = nil
        
        /// Splits the argument string at the first occurrence of a colon.
        /// - Parameter argumentString: The string to split.
        /// - Returns: A tuple containing the part before the colon and the part after the colon (including the colon).
        func splitArguments(_ argumentString: String) -> (String, String) {
            // Find the first occurrence of the colon
            if let colonIndex = argumentString.firstIndex(of: ":") {
                // Extract the part before the colon and trim whitespace
                let beforeColon = String(argumentString[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                // Extract the part after the colon (including the colon) and trim whitespace
                let afterColon = String(argumentString[colonIndex...]).trimmingCharacters(in: .whitespaces)
                return (beforeColon, afterColon)
            } else {
                // If no colon is found, return the entire string as the first part and an empty string as the second part
                return (argumentString.trimmingCharacters(in: .whitespaces), "")
            }
        }
        
        // Parse the command
        switch try parseCommand(command: command) {
        case .string(let cmd):
            switch cmd {
            case Constants.nick.rawValue:
                // For the NICK command, the entire argument string is treated as a single argument
                arguments.append(argumentString)
            case Constants.user.rawValue:
                // For the USER command, split the arguments based on the colon
                let components = argumentString.components(separatedBy: Constants.colon.rawValue)
                guard let initialArgs = components.first?.components(separatedBy: Constants.space.rawValue) else {
                    throw MessageParsingErrors.invalidArguments("Invalid arguments for user command.")
                }
                // Append non-empty initial arguments
                arguments.append(contentsOf: initialArgs.filter { !$0.isEmpty })
                // Append the real name if present
                if let realName = components.last {
                    arguments.append(realName)
                }
            default:
                // For other commands, handle arguments based on the presence of a colon
                if argumentString.contains(Constants.colon.rawValue) {
                    let splitArgs = splitArguments(argumentString)
                    // Split the part before the colon into space-separated arguments
                    let initialArgs = splitArgs.0.components(separatedBy: Constants.space.rawValue)
                    arguments.append(contentsOf: initialArgs.filter { !$0.isEmpty }) // Filter out empty strings
                    // Append the part after the colon
                    arguments.append(splitArgs.1)
                } else {
                    // If no colon is present, split the entire argument string by spaces
                    arguments.append(contentsOf: argumentString.components(separatedBy: Constants.space.rawValue).filter { !$0.isEmpty })
                }
            }
        case .int(_):
            // For numeric commands, handle the target and arguments differently
            let components = argumentString.components(separatedBy: Constants.colon.rawValue)
            target = components.first?.trimmingCharacters(in: .whitespaces) // Trim whitespace from the target
            if let lastMessage = components.last {
                // Split the last message by commas and append to arguments
                arguments.append(contentsOf: lastMessage.components(separatedBy: Constants.comma.rawValue).filter { !$0.isEmpty })
            }
        }
        return (arguments, target)
    }
    
    /// Parses the command into a numeric or string key.
    /// - Parameter command: The command string to parse.
    /// - Throws: `MessageParsingErrors` for invalid command formats.
    /// - Returns: An `IRCCommandKey` representing the command type.
    static func parseCommand(command: String) throws -> IRCCommandKey {
        precondition(!command.isEmpty)
        
        if let firstChar = command.first, firstChar.isLetter {
            return .string(command)
        } else {
            let numericCommand = command.components(separatedBy: .decimalDigits.inverted).compactMap(Int.init).first
            guard let validNumeric = numericCommand else {
                throw MessageParsingErrors.invalidArguments("Invalid command format.")
            }
            return .int(validNumeric)
        }
    }
}
