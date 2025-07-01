//
//  IRCChannelPermissions.swift
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

/// Represents various modes that can be set on an IRC channel, conforming to Codable, OptionSet,
/// Sendable, and Hashable protocols. Each mode grants specific privileges or restrictions to channel users.
/// 
/// This implementation follows IETF RFC 2811 and RFC 1459 specifications for IRC channel modes.
public struct IRCChannelPermissions: Codable, OptionSet, Sendable, Hashable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    // MARK: - Standard IRC Channel Modes (RFC 2811, RFC 1459)
    
    /// O: Channel founder/creator (highest level of channel operator)
    public static let founder = IRCChannelPermissions(rawValue: 1 << 0)
    
    /// o: Channel operator (can manage channel)
    public static let channelOperator = IRCChannelPermissions(rawValue: 1 << 1)
    
    /// p: Private channel (not shown in channel list)
    public static let `private` = IRCChannelPermissions(rawValue: 1 << 2)
    
    /// s: Secret channel (not shown in channel list or WHOIS)
    public static let secret = IRCChannelPermissions(rawValue: 1 << 3)
    
    /// i: Invite-only channel (requires invitation to join)
    public static let inviteOnly = IRCChannelPermissions(rawValue: 1 << 4)
    
    /// t: Topic protection (only operators can change topic)
    public static let topicProtection = IRCChannelPermissions(rawValue: 1 << 5)
    
    /// n: No external messages (only channel members can send messages)
    public static let noExternalMessages = IRCChannelPermissions(rawValue: 1 << 6)
    
    /// m: Moderated channel (only operators and voiced users can speak)
    public static let moderated = IRCChannelPermissions(rawValue: 1 << 7)
    
    /// l: User limit (sets maximum number of users)
    public static let userLimit = IRCChannelPermissions(rawValue: 1 << 8)
    
    /// b: Ban mask (bans users matching the mask)
    public static let banMask = IRCChannelPermissions(rawValue: 1 << 9)
    
    /// v: Voice (allows speaking in moderated channels)
    public static let voice = IRCChannelPermissions(rawValue: 1 << 10)
    
    /// k: Channel key/password (requires password to join)
    public static let key = IRCChannelPermissions(rawValue: 1 << 11)
    
    /// e: Exception list (exempts users from ban masks)
    public static let exceptionList = IRCChannelPermissions(rawValue: 1 << 12)
    
    /// I: Invite exception list (exempts users from invite-only)
    public static let inviteExceptionList = IRCChannelPermissions(rawValue: 1 << 13)
    
    // MARK: - Extended Channel Modes (Modern IRC)
    
    /// L: Channel redirect (redirects users to another channel when limit is reached)
    public static let redirect = IRCChannelPermissions(rawValue: 1 << 14)
    
    /// q: Quiet list (silences users without banning them)
    public static let quietList = IRCChannelPermissions(rawValue: 1 << 15)
    
    /// f: Forward (forwards users to another channel)
    public static let forward = IRCChannelPermissions(rawValue: 1 << 16)
    
    /// j: Join throttle (limits join frequency)
    public static let joinThrottle = IRCChannelPermissions(rawValue: 1 << 17)
    
    /// J: Join delay (delays join messages)
    public static let joinDelay = IRCChannelPermissions(rawValue: 1 << 18)
    
    /// c: Block color codes
    public static let blockColor = IRCChannelPermissions(rawValue: 1 << 19)
    
    /// C: Block caps (block excessive capitalization)
    public static let blockCaps = IRCChannelPermissions(rawValue: 1 << 20)
    
    /// E: Block repeated messages
    public static let blockRepeated = IRCChannelPermissions(rawValue: 1 << 21)
    
    /// F: Flood protection
    public static let floodProtection = IRCChannelPermissions(rawValue: 1 << 22)
    
    /// S: Strip color codes
    public static let stripColor = IRCChannelPermissions(rawValue: 1 << 23)
    
    /// T: Block CTCP messages
    public static let blockCTCP = IRCChannelPermissions(rawValue: 1 << 24)
    
    /// N: Block notices
    public static let blockNotices = IRCChannelPermissions(rawValue: 1 << 25)
    
    /// V: Block invites
    public static let blockInvites = IRCChannelPermissions(rawValue: 1 << 26)
    
    /// K: Block kicks
    public static let blockKicks = IRCChannelPermissions(rawValue: 1 << 27)
    
    /// M: Block nick changes
    public static let blockNickChange = IRCChannelPermissions(rawValue: 1 << 28)
    
    /// R: Registered users only
    public static let registeredOnly = IRCChannelPermissions(rawValue: 1 << 29)
    
    /// D: Delay join (delays join messages)
    public static let delayJoin = IRCChannelPermissions(rawValue: 1 << 30)
    
    /// W: Block WHO requests
    public static let blockWHO = IRCChannelPermissions(rawValue: 1 << 31)
    
    /// The mask value representing the combined modes.
    public var maskValue: UInt32 { return rawValue }
    
    /// Initializes a new IRCChannelPermissions from a string representation of modes.
    /// - Parameter string: A string containing channel mode characters.
    /// - Returns: An optional IRCChannelPermissions instance; returns nil if invalid.
    public init?(_ string: String) {
        var mask: UInt32 = 0
        for c in string {
            switch c {
            case "O": mask |= IRCChannelPermissions.founder.rawValue
            case "o": mask |= IRCChannelPermissions.channelOperator.rawValue
            case "p": mask |= IRCChannelPermissions.`private`.rawValue
            case "s": mask |= IRCChannelPermissions.secret.rawValue
            case "i": mask |= IRCChannelPermissions.inviteOnly.rawValue
            case "t": mask |= IRCChannelPermissions.topicProtection.rawValue
            case "n": mask |= IRCChannelPermissions.noExternalMessages.rawValue
            case "m": mask |= IRCChannelPermissions.moderated.rawValue
            case "l": mask |= IRCChannelPermissions.userLimit.rawValue
            case "b": mask |= IRCChannelPermissions.banMask.rawValue
            case "v": mask |= IRCChannelPermissions.voice.rawValue
            case "k": mask |= IRCChannelPermissions.key.rawValue
            case "e": mask |= IRCChannelPermissions.exceptionList.rawValue
            case "I": mask |= IRCChannelPermissions.inviteExceptionList.rawValue
            case "L": mask |= IRCChannelPermissions.redirect.rawValue
            case "q": mask |= IRCChannelPermissions.quietList.rawValue
            case "f": mask |= IRCChannelPermissions.forward.rawValue
            case "j": mask |= IRCChannelPermissions.joinThrottle.rawValue
            case "J": mask |= IRCChannelPermissions.joinDelay.rawValue
            case "c": mask |= IRCChannelPermissions.blockColor.rawValue
            case "C": mask |= IRCChannelPermissions.blockCaps.rawValue
            case "E": mask |= IRCChannelPermissions.blockRepeated.rawValue
            case "F": mask |= IRCChannelPermissions.floodProtection.rawValue
            case "S": mask |= IRCChannelPermissions.stripColor.rawValue
            case "T": mask |= IRCChannelPermissions.blockCTCP.rawValue
            case "N": mask |= IRCChannelPermissions.blockNotices.rawValue
            case "V": mask |= IRCChannelPermissions.blockInvites.rawValue
            case "K": mask |= IRCChannelPermissions.blockKicks.rawValue
            case "M": mask |= IRCChannelPermissions.blockNickChange.rawValue
            case "R": mask |= IRCChannelPermissions.registeredOnly.rawValue
            case "D": mask |= IRCChannelPermissions.delayJoin.rawValue
            case "W": mask |= IRCChannelPermissions.blockWHO.rawValue
            default: return nil
            }
        }
        
        self.init(rawValue: mask)
    }
    
    /// Returns the string representation of the channel modes.
    public var stringValue: String {
        var mode = ""
        if contains(.founder) { mode += "O" }
        if contains(.channelOperator) { mode += "o" }
        if contains(.`private`) { mode += "p" }
        if contains(.secret) { mode += "s" }
        if contains(.inviteOnly) { mode += "i" }
        if contains(.topicProtection) { mode += "t" }
        if contains(.noExternalMessages) { mode += "n" }
        if contains(.moderated) { mode += "m" }
        if contains(.userLimit) { mode += "l" }
        if contains(.banMask) { mode += "b" }
        if contains(.voice) { mode += "v" }
        if contains(.key) { mode += "k" }
        if contains(.exceptionList) { mode += "e" }
        if contains(.inviteExceptionList) { mode += "I" }
        if contains(.redirect) { mode += "L" }
        if contains(.quietList) { mode += "q" }
        if contains(.forward) { mode += "f" }
        if contains(.joinThrottle) { mode += "j" }
        if contains(.joinDelay) { mode += "J" }
        if contains(.blockColor) { mode += "c" }
        if contains(.blockCaps) { mode += "C" }
        if contains(.blockRepeated) { mode += "E" }
        if contains(.floodProtection) { mode += "F" }
        if contains(.stripColor) { mode += "S" }
        if contains(.blockCTCP) { mode += "T" }
        if contains(.blockNotices) { mode += "N" }
        if contains(.blockInvites) { mode += "V" }
        if contains(.blockKicks) { mode += "K" }
        if contains(.blockNickChange) { mode += "M" }
        if contains(.registeredOnly) { mode += "R" }
        if contains(.delayJoin) { mode += "D" }
        if contains(.blockWHO) { mode += "W" }
        return mode
    }
}
