//
//  IRCUserModeFlags.swift
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

/// Represents the various user mode flags in the IRC (Internet Relay Chat) protocol.
/// 
/// This implementation follows IETF RFC 2811 and RFC 1459 specifications for IRC user modes.
public struct IRCUserModeFlags: Codable, OptionSet, Sendable {
  
  /// The raw value representing the combined user modes.
  public let rawValue: UInt32
  
  /// Initializes a new instance with a raw value.
  /// - Parameter rawValue: A `UInt32` representing the combined user modes.
  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  // MARK: - Standard IRC User Modes (RFC 2811, RFC 1459)
  
  /// i: Invisible to other users (cannot be seen in user lists)
  public static let invisible = IRCUserModeFlags(rawValue: 1 << 0)
  
  /// w: Receives wallops (messages sent to all users)
  public static let wallOps = IRCUserModeFlags(rawValue: 1 << 1)
  
  /// o: IRC operator (has administrative privileges)
  public static let operatorMode = IRCUserModeFlags(rawValue: 1 << 2)
  
  /// O: Local operator (similar to an IRC operator but limited to the local server)
  public static let localOperator = IRCUserModeFlags(rawValue: 1 << 3)
  
  /// r: Restricted connection (limits access for the user)
  public static let restricted = IRCUserModeFlags(rawValue: 1 << 4)
  
  /// a: Away from keyboard (indicates the user is not actively present)
  public static let away = IRCUserModeFlags(rawValue: 1 << 5)
  
  /// s: Receives server notices (system messages from the server)
  public static let serverNotices = IRCUserModeFlags(rawValue: 1 << 6)
  
  // MARK: - Extended User Modes (Modern IRC)
  
  /// g: Ignores unknown users (does not receive messages from unknown users)
  public static let ignoreUnknown = IRCUserModeFlags(rawValue: 1 << 7)
  
  /// Q: Disables message forwarding (prevents messages from being forwarded)
  public static let disableForwarding = IRCUserModeFlags(rawValue: 1 << 8)
  
  /// R: Blocks unidentified users (prevents interaction with users without a valid identity)
  public static let blockUnidentified = IRCUserModeFlags(rawValue: 1 << 9)
  
  /// Z: Connected securely (indicates a secure connection)
  public static let secureConnection = IRCUserModeFlags(rawValue: 1 << 10)
  
  /// x: Hides hostname (prevents other users from seeing the hostname)
  public static let hideHostname = IRCUserModeFlags(rawValue: 1 << 11)
  
  /// d: Receives debug messages
  public static let receiveDebug = IRCUserModeFlags(rawValue: 1 << 12)
  
  /// h: Receives help messages
  public static let receiveHelp = IRCUserModeFlags(rawValue: 1 << 13)
  
  /// I: Receives info messages
  public static let receiveInfo = IRCUserModeFlags(rawValue: 1 << 14)
  
  /// l: Receives local operator messages
  public static let receiveLocops = IRCUserModeFlags(rawValue: 1 << 15)
  
  /// L: Receives links messages
  public static let receiveLinks = IRCUserModeFlags(rawValue: 1 << 16)
  
  /// M: Receives map messages
  public static let receiveMap = IRCUserModeFlags(rawValue: 1 << 17)
  
  /// m: Receives MOTD messages
  public static let receiveMotd = IRCUserModeFlags(rawValue: 1 << 18)
  
  /// t: Receives stats messages
  public static let receiveStats = IRCUserModeFlags(rawValue: 1 << 19)
  
  /// T: Receives time messages
  public static let receiveTime = IRCUserModeFlags(rawValue: 1 << 20)
  
  /// u: Receives users messages
  public static let receiveUsers = IRCUserModeFlags(rawValue: 1 << 21)
  
  /// v: Receives version messages
  public static let receiveVersion = IRCUserModeFlags(rawValue: 1 << 22)
  
  /// W: Receives WHOIS messages
  public static let receiveWhois = IRCUserModeFlags(rawValue: 1 << 23)
  
  /// A: Receives admin messages
  public static let receiveAdmin = IRCUserModeFlags(rawValue: 1 << 24)
  
  /// B: Receives ban messages
  public static let receiveBan = IRCUserModeFlags(rawValue: 1 << 25)
  
  /// C: Receives channel messages
  public static let receiveChannel = IRCUserModeFlags(rawValue: 1 << 26)
  
  /// D: Receives debug messages (alternative)
  public static let receiveDebugAlt = IRCUserModeFlags(rawValue: 1 << 27)
  
  /// E: Receives error messages
  public static let receiveError = IRCUserModeFlags(rawValue: 1 << 28)
  
  /// F: Receives flood messages
  public static let receiveFlood = IRCUserModeFlags(rawValue: 1 << 29)
  
  /// G: Receives global messages
  public static let receiveGlobal = IRCUserModeFlags(rawValue: 1 << 30)
  
  /// H: Receives help messages (alternative)
  public static let receiveHelpAlt = IRCUserModeFlags(rawValue: 1 << 31)

  /// The raw mask value of the user modes.
  public var maskValue: UInt32 { return rawValue }
  
  /// Initializes a new instance from a string representation of modes.
  /// - Parameter modeString: A string containing user mode characters (e.g., "wiar").
  /// - Returns: An optional `IRCUserModeFlags` instance, or `nil` if the string is invalid.
  public init?(_ modeString: String) {
    var mask: UInt32 = 0
    for character in modeString {
      switch character {
        case "i": mask |= IRCUserModeFlags.invisible.rawValue
        case "w": mask |= IRCUserModeFlags.wallOps.rawValue
        case "o": mask |= IRCUserModeFlags.operatorMode.rawValue
        case "O": mask |= IRCUserModeFlags.localOperator.rawValue
        case "r": mask |= IRCUserModeFlags.restricted.rawValue
        case "a": mask |= IRCUserModeFlags.away.rawValue
        case "s": mask |= IRCUserModeFlags.serverNotices.rawValue
        case "g": mask |= IRCUserModeFlags.ignoreUnknown.rawValue
        case "Q": mask |= IRCUserModeFlags.disableForwarding.rawValue
        case "R": mask |= IRCUserModeFlags.blockUnidentified.rawValue
        case "Z": mask |= IRCUserModeFlags.secureConnection.rawValue
        case "x": mask |= IRCUserModeFlags.hideHostname.rawValue
        case "d": mask |= IRCUserModeFlags.receiveDebug.rawValue
        case "h": mask |= IRCUserModeFlags.receiveHelp.rawValue
        case "I": mask |= IRCUserModeFlags.receiveInfo.rawValue
        case "l": mask |= IRCUserModeFlags.receiveLocops.rawValue
        case "L": mask |= IRCUserModeFlags.receiveLinks.rawValue
        case "M": mask |= IRCUserModeFlags.receiveMap.rawValue
        case "m": mask |= IRCUserModeFlags.receiveMotd.rawValue
        case "t": mask |= IRCUserModeFlags.receiveStats.rawValue
        case "T": mask |= IRCUserModeFlags.receiveTime.rawValue
        case "u": mask |= IRCUserModeFlags.receiveUsers.rawValue
        case "v": mask |= IRCUserModeFlags.receiveVersion.rawValue
        case "W": mask |= IRCUserModeFlags.receiveWhois.rawValue
        case "A": mask |= IRCUserModeFlags.receiveAdmin.rawValue
        case "B": mask |= IRCUserModeFlags.receiveBan.rawValue
        case "C": mask |= IRCUserModeFlags.receiveChannel.rawValue
        case "D": mask |= IRCUserModeFlags.receiveDebugAlt.rawValue
        case "E": mask |= IRCUserModeFlags.receiveError.rawValue
        case "F": mask |= IRCUserModeFlags.receiveFlood.rawValue
        case "G": mask |= IRCUserModeFlags.receiveGlobal.rawValue
        case "H": mask |= IRCUserModeFlags.receiveHelpAlt.rawValue
        default: return nil
      }
    }
    self.init(rawValue: mask)
  }

  /// Returns a string representation of the active user modes.
  /// - Returns: A string of mode characters (e.g., "wiar").
  public var stringValue: String {
    var modes = ""
    modes.reserveCapacity(32)
    if contains(.invisible) { modes += "i" }
    if contains(.wallOps) { modes += "w" }
    if contains(.operatorMode) { modes += "o" }
    if contains(.localOperator) { modes += "O" }
    if contains(.restricted) { modes += "r" }
    if contains(.away) { modes += "a" }
    if contains(.serverNotices) { modes += "s" }
    if contains(.ignoreUnknown) { modes += "g" }
    if contains(.disableForwarding) { modes += "Q" }
    if contains(.blockUnidentified) { modes += "R" }
    if contains(.secureConnection) { modes += "Z" }
    if contains(.hideHostname) { modes += "x" }
    if contains(.receiveDebug) { modes += "d" }
    if contains(.receiveHelp) { modes += "h" }
    if contains(.receiveInfo) { modes += "I" }
    if contains(.receiveLocops) { modes += "l" }
    if contains(.receiveLinks) { modes += "L" }
    if contains(.receiveMap) { modes += "M" }
    if contains(.receiveMotd) { modes += "m" }
    if contains(.receiveStats) { modes += "t" }
    if contains(.receiveTime) { modes += "T" }
    if contains(.receiveUsers) { modes += "u" }
    if contains(.receiveVersion) { modes += "v" }
    if contains(.receiveWhois) { modes += "W" }
    if contains(.receiveAdmin) { modes += "A" }
    if contains(.receiveBan) { modes += "B" }
    if contains(.receiveChannel) { modes += "C" }
    if contains(.receiveDebugAlt) { modes += "D" }
    if contains(.receiveError) { modes += "E" }
    if contains(.receiveFlood) { modes += "F" }
    if contains(.receiveGlobal) { modes += "G" }
    if contains(.receiveHelpAlt) { modes += "H" }
    return modes
  }
}
