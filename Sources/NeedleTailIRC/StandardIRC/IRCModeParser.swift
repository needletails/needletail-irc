//
//  IRCModeParser.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

/// One mode letter being set or unset, with its parameter if it takes one.
public struct IRCModeChange: Hashable, Sendable {
    public var isAdding: Bool
    public var mode: Character
    public var parameter: String?

    public init(isAdding: Bool, mode: Character, parameter: String? = nil) {
        self.isAdding = isAdding
        self.mode = mode
        self.parameter = parameter
    }
}

/// Splits mode strings into individual changes using the server's advertised mode types.
///
/// Unlike `IRCCommand.channelMode`, this handles any mix of `+`/`-`, any mode letters,
/// and keeps every parameter paired with its letter.
public enum IRCModeParser {

    /// Parses a channel mode string such as `+ov-b` with its parameters.
    ///
    /// Membership modes (`PREFIX`) and `CHANMODES` types A and B always consume a parameter,
    /// type C only when set, type D and unknown letters never. A list mode with no parameter
    /// left (`+b`) yields `parameter == nil`, meaning "show the list".
    public static func channelModeChanges(
        _ modeString: String,
        parameters: [String],
        isupport: IRCISupport = IRCISupport()
    ) -> [IRCModeChange] {
        let membershipModes = Set(isupport.membershipPrefixes.map(\.mode))
        let types = isupport.channelModes
        var remaining = parameters[...]
        var adding = true
        var changes: [IRCModeChange] = []

        for character in modeString {
            switch character {
            case "+": adding = true
            case "-": adding = false
            default:
                let takesParameter: Bool
                if membershipModes.contains(character) || types.list.contains(character) || types.alwaysParameter.contains(character) {
                    takesParameter = true
                } else if types.parameterWhenSet.contains(character) {
                    takesParameter = adding
                } else {
                    takesParameter = false
                }
                changes.append(IRCModeChange(
                    isAdding: adding,
                    mode: character,
                    parameter: takesParameter ? remaining.popFirst() : nil
                ))
            }
        }
        return changes
    }

    /// Parses a user mode string such as `+iw-x`. User modes take no parameters.
    public static func userModeChanges(_ modeString: String) -> [IRCModeChange] {
        channelModeChanges(modeString, parameters: [], isupport: noParameterSupport)
    }

    /// Reads the channel and changes from a channel `MODE` message or a 324 (`RPL_CHANNELMODEIS`)
    /// reply. Returns `nil` for anything else, including user mode changes.
    public static func channelModeChanges(
        from message: IRCRawMessage,
        isupport: IRCISupport = IRCISupport()
    ) -> (channel: String, changes: [IRCModeChange])? {
        let p = message.parameters
        if message.command == "MODE", p.count >= 2, isupport.isChannelName(p[0]) {
            return (p[0], channelModeChanges(p[1], parameters: Array(p.dropFirst(2)), isupport: isupport))
        }
        if message.numeric == 324, p.count >= 3 {
            return (p[1], channelModeChanges(p[2], parameters: Array(p.dropFirst(3)), isupport: isupport))
        }
        return nil
    }

    private static let noParameterSupport: IRCISupport = {
        var support = IRCISupport()
        support.apply(tokens: ["PREFIX=", "CHANMODES=,,,"])
        return support
    }()
}
