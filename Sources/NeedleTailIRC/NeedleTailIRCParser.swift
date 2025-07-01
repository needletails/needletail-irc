//
//  NeedleTailIRCParser.swift
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

import NeedleTailLogger

/// Errors that can occur during IRC message parsing.
public enum MessageParsingErrors: Error, Sendable {
    /// Invalid arguments provided for a command.
    case invalidArguments(String)
    /// Invalid CAP (capability) command format.
    case invalidCAPCommand(String)
    /// Invalid message tag format.
    case invalidTag
}

/// A comprehensive parser for IRC messages that conforms to RFC 2812 and RFC 1459 standards.
/// 
/// This parser implements the IRC message format as specified in the IRC protocol:
/// ['@' <tags> SPACE] [':' <source> SPACE] <command> <parameters> <crlf>
/// 
/// For numeric replies, the target is extracted as the first parameter according to the protocol.
///
/// The `NeedleTailIRCParser` provides functionality to parse raw IRC message strings into structured
/// `IRCMessage` objects. It supports all standard IRC commands, IRCv3 message tags, and handles
/// both numeric and string-based commands.
///
/// ## Usage
///
/// ```swift
/// // Parse a simple IRC message
/// let message = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello, world!")
///
/// // Parse a message with IRCv3 tags
/// let taggedMessage = try NeedleTailIRCParser.parseMessage("@time=2023-01-01T12:00:00Z :alice!alice@localhost PRIVMSG #general :Hello!")
/// ```
///
/// ## Message Format
///
/// The parser supports the standard IRC message format:
/// ```
/// [@tags] [:prefix] command [parameters] [:trailing]
/// ```
///
/// - **Tags**: IRCv3 message tags (optional)
/// - **Prefix**: Message origin (optional)
/// - **Command**: IRC command or numeric code
/// - **Parameters**: Command arguments
/// - **Trailing**: Final parameter (can contain spaces)
///
/// ## Thread Safety
///
/// This parser is thread-safe and can be used concurrently from multiple threads.
public struct NeedleTailIRCParser: Sendable {
    static let logger = NeedleTailLogger(.init(label: "[ com.needletails.irc.message.parser ]"))
    
    public init() {}
    
    enum IRCCommandKey {
        case int(Int)
        case string(String)
    }
    
    /// Parses a raw IRC message string into a structured `IRCMessage` object.
    ///
    /// This method handles the complete parsing of IRC messages, including:
    /// - IRCv3 message tags
    /// - Message prefixes (origin)
    /// - Command parsing (both string and numeric)
    /// - Parameter extraction
    /// - Trailing parameter handling
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Parse a simple message
    /// let message = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello!")
    ///
    /// // Parse a message with tags
    /// let taggedMessage = try NeedleTailIRCParser.parseMessage("@time=2023-01-01T12:00:00Z :alice PRIVMSG #general :Hello!")
    ///
    /// // Parse a numeric response
    /// let numericMessage = try NeedleTailIRCParser.parseMessage(":server 001 alice :Welcome to the server!")
    /// ```
    ///
    /// ## Message Format Support
    ///
    /// The parser supports all standard IRC message formats:
    /// - Messages with and without tags
    /// - Messages with and without prefixes
    /// - String commands (PRIVMSG, JOIN, etc.)
    /// - Numeric commands (001, 433, etc.)
    /// - Messages with trailing parameters
    ///
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
//        self.logger.log(level: .trace, message: "Parsing Message....")
        
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
        return IRCMessage(origin: origin, target: target, command: builtCommand, tags: parsedTags)
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
                // For the NICK command, according to IRC protocol: NICK <nickname>
                // The entire argument string is the nickname
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
            case Constants.join.rawValue:
                // Special handling for JOIN 0 (leave all channels)
                let parts = argumentString.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
                if parts.count == 1 && parts[0].trimmingCharacters(in: .whitespacesAndNewlines) == "0" {
                    // Add "0" as argument for join0
                    arguments.append("0")
                } else {
                    // Normal JOIN: parse channels and keys
                    arguments.append(contentsOf: parts)
                }
            case Constants.ping.rawValue, Constants.pong.rawValue:
                // PING and PONG: split by spaces, up to 2 parameters
                let params = argumentString.split(separator: " ", maxSplits: 1).map { String($0) }
                if !params.isEmpty {
                    arguments.append(params[0])
                }
                if params.count > 1 {
                    arguments.append(params[1])
                }
            default:
                // For other commands, handle arguments based on the presence of a colon
                if argumentString.contains(Constants.colon.rawValue) {
                    var splitArgs = splitArguments(argumentString)
                    // Split the part before the colon into space-separated arguments
                    let initialArgs = splitArgs.0.components(separatedBy: Constants.space.rawValue)
                    arguments.append(contentsOf: initialArgs.filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) }) // Filter out empty strings and trim whitespace
                    // Append the part after the colon
                    if splitArgs.1.first == Constants.colon.rawValue.first {
                        splitArgs.1.removeFirst()
                    }
                    arguments.append(splitArgs.1.trimmingCharacters(in: .whitespaces))
                } else {
                    // If no colon is present, split the entire argument string by spaces
                    arguments.append(contentsOf: argumentString.components(separatedBy: Constants.space.rawValue).filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) })
                }
                if let firstArgument = arguments.first, !firstArgument.isEmpty {
                    // Check if the first character of the first argument matches the constant
                    if firstArgument.first == Constants.colon.rawValue.first {
                        var firstItem = arguments[0]
                        if firstItem.count > 0 {
                            firstItem.remove(at: firstItem.startIndex)
                            arguments[0] = firstItem
                        }
                    }
                }
            }
        case .int(_):
            // For numeric commands, handle the target and arguments according to IRC protocol
            // Numeric replies SHOULD contain the target as the first parameter
            let trimmedArg = argumentString.trimmingCharacters(in: .whitespaces)
            if trimmedArg.hasPrefix(Constants.colon.rawValue) {
                // No target, just message
                let message = String(trimmedArg.dropFirst())
                arguments.append(contentsOf: message.components(separatedBy: Constants.comma.rawValue).filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) })
            } else {
                // Target is the first space-separated part
                let spaceSeparated = trimmedArg.components(separatedBy: Constants.space.rawValue).filter { !$0.isEmpty }
                if !spaceSeparated.isEmpty {
                    target = spaceSeparated[0]
                    // The rest is the argument string
                    let rest = spaceSeparated.dropFirst().joined(separator: Constants.space.rawValue)
                    if rest.hasPrefix(Constants.colon.rawValue) {
                        let message = String(rest.dropFirst())
                        arguments.append(contentsOf: message.components(separatedBy: Constants.comma.rawValue).filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) })
                    } else if !rest.isEmpty {
                        arguments.append(contentsOf: rest.components(separatedBy: Constants.space.rawValue).filter { !$0.isEmpty }.map { $0.trimmingCharacters(in: .whitespaces) })
                    }
                }
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
