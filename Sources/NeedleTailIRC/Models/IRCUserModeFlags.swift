//
//  IRCUserModeFlags.swift
//
//
//  Created by Cole M on 9/28/22.
//

/// Represents the various user mode flags in the IRC (Internet Relay Chat) protocol.
public struct IRCUserModeFlags: Codable, OptionSet, Sendable {
  
  /// The raw value representing the combined user modes.
  public let rawValue: UInt16
  
  /// Initializes a new instance with a raw value.
  /// - Parameter rawValue: A `UInt16` representing the combined user modes.
  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  // Standard user modes as per IRC specifications
  /// w: Receives wallops (messages sent to all users).
  public static let wallOps                = IRCUserModeFlags(rawValue: 1 << 2)
  /// i: Invisible to other users (cannot be seen in user lists).
  public static let invisible              = IRCUserModeFlags(rawValue: 1 << 3)
  /// a: Away from keyboard (indicates the user is not actively present).
  public static let away                   = IRCUserModeFlags(rawValue: 1 << 4)
  /// r: Restricted connection (limits access for the user).
  public static let restricted             = IRCUserModeFlags(rawValue: 1 << 5)
  /// o: IRC operator (has administrative privileges).
  public static let operatorMode           = IRCUserModeFlags(rawValue: 1 << 6)
  /// O: Local operator (similar to an IRC operator but limited to the local server).
  public static let localOperator          = IRCUserModeFlags(rawValue: 1 << 7)
  /// s: Receives server notices (system messages from the server).
  public static let serverNotices          = IRCUserModeFlags(rawValue: 1 << 8)
  /// g: Ignores unknown users (does not receive messages from unknown users).
  public static let ignoreUnknown          = IRCUserModeFlags(rawValue: 1 << 9)
  /// Q: Disables message forwarding (prevents messages from being forwarded).
  public static let disableForwarding      = IRCUserModeFlags(rawValue: 1 << 10)
  /// R: Blocks unidentified users (prevents interaction with users without a valid identity).
  public static let blockUnidentified      = IRCUserModeFlags(rawValue: 1 << 11)
  /// Z: Connected securely (indicates a secure connection).
  public static let secureConnection        = IRCUserModeFlags(rawValue: 1 << 12)
  /// x: Hides hostname (prevents other users from seeing the hostname).
  public static let hideHostname           = IRCUserModeFlags(rawValue: 1 << 13)

  /// The raw mask value of the user modes.
  public var maskValue: UInt16 { return rawValue }
  
  /// Initializes a new instance from a string representation of modes.
  /// - Parameter modeString: A string containing user mode characters (e.g., "wiar").
  /// - Returns: An optional `IRCUserModeFlags` instance, or `nil` if the string is invalid.
  public init?(_ modeString: String) {
    var mask: UInt16 = 0
    for character in modeString {
      switch character {
        case "w": mask |= IRCUserModeFlags.wallOps.rawValue
        case "i": mask |= IRCUserModeFlags.invisible.rawValue
        case "a": mask |= IRCUserModeFlags.away.rawValue
        case "r": mask |= IRCUserModeFlags.restricted.rawValue
        case "o": mask |= IRCUserModeFlags.operatorMode.rawValue
        case "O": mask |= IRCUserModeFlags.localOperator.rawValue
        case "s": mask |= IRCUserModeFlags.serverNotices.rawValue
        case "g": mask |= IRCUserModeFlags.ignoreUnknown.rawValue
        case "Q": mask |= IRCUserModeFlags.disableForwarding.rawValue
        case "R": mask |= IRCUserModeFlags.blockUnidentified.rawValue
        case "Z": mask |= IRCUserModeFlags.secureConnection.rawValue
        case "x": mask |= IRCUserModeFlags.hideHostname.rawValue
        default: return nil
      }
    }
    self.init(rawValue: mask)
  }

  /// Returns a string representation of the active user modes.
  /// - Returns: A string of mode characters (e.g., "wiar").
  public var stringValue: String {
    var modes = ""
    modes.reserveCapacity(8)
    if contains(.wallOps)               { modes += "w" }
    if contains(.invisible)              { modes += "i" }
    if contains(.away)                   { modes += "a" }
    if contains(.restricted)             { modes += "r" }
    if contains(.operatorMode)           { modes += "o" }
    if contains(.localOperator)          { modes += "O" }
    if contains(.serverNotices)          { modes += "s" }
    if contains(.ignoreUnknown)          { modes += "g" }
    if contains(.disableForwarding)      { modes += "Q" }
    if contains(.blockUnidentified)      { modes += "R" }
    if contains(.secureConnection)        { modes += "Z" }
    if contains(.hideHostname)           { modes += "x" }
    return modes
  }
}
