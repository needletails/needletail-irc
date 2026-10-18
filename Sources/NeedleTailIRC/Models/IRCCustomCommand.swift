//
//  IRCCustomCommand.swift
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

/// The name of a command your application defines on top of IRC.
///
/// Declare each command once, then send it with ``IRCCommand/custom(_:_:)`` and match it in a
/// `switch` over a parsed ``IRCCommand/otherCommand(_:_:)``:
///
/// ```swift
/// extension IRCCustomCommand {
///     static let badgeUpdate: IRCCustomCommand = "BADGEUPDATE"
/// }
///
/// try await writer.transportMessage(command: .custom(.badgeUpdate, ["3"]))
///
/// switch message.command {
/// case .otherCommand(IRCCustomCommand.badgeUpdate, let arguments):
///     handleBadge(arguments)
/// default:
///     break
/// }
/// ```
///
/// A name is ASCII letters only, as RFC 2812 requires of a command, and is stored uppercased.
/// Matching ignores case, as IRC does.
public struct IRCCustomCommand: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {

    /// The uppercased command name written on the wire.
    public let rawValue: String

    /// Returns `nil` unless `rawValue` is one or more ASCII letters.
    public init?(rawValue: String) {
        guard !rawValue.isEmpty,
              rawValue.unicodeScalars.allSatisfy({ ("A"..."Z").contains($0) || ("a"..."z").contains($0) }) else {
            return nil
        }
        self.rawValue = rawValue.uppercased()
    }

    /// Creates a name from a literal. The literal must be ASCII letters only.
    public init(stringLiteral value: String) {
        guard let command = IRCCustomCommand(rawValue: value) else {
            preconditionFailure("IRCCustomCommand \"\(value)\" must be ASCII letters only")
        }
        self = command
    }

    public var description: String { rawValue }
}

extension IRCCommand {
    /// An application command, written as `NAME :argument` for one argument and as RFC
    /// parameters for several. It arrives on the other side as ``otherCommand(_:_:)``.
    public static func custom(_ command: IRCCustomCommand, _ arguments: [String] = []) -> IRCCommand {
        .otherCommand(command.rawValue, arguments)
    }
}

/// Lets a custom command match the name in `case .otherCommand(IRCCustomCommand.x, let arguments)`.
public func ~= (pattern: IRCCustomCommand, value: String) -> Bool {
    pattern.rawValue == value.uppercased()
}
