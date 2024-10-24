//
//  IRCChannelPermissions.swift
//
//
//  Created by Cole M on 9/28/22.
//

import Foundation

/// Represents various modes that can be set on an IRC channel, conforming to Codable, OptionSet,
/// Sendable, and Hashable protocols. Each mode grants specific privileges or restrictions to channel users.
public struct IRCChannelPermissions: Codable, OptionSet, Sendable, Hashable {
    
    public let rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    // MARK: - Channel Modes
    
    /// Admin over all other permissions
    public static let channelOperatorAdmin = IRCChannelPermissions(rawValue: 1 << 0)
    
    /*
     Channel operators have various privileges, including:
     The ability to kick or ban users from the channel.
     The ability to change channel modes.
     The ability to invite users to the channel.
     The ability to set and remove channel operator status from other users.
     There may be multiple Channel Operators for a given channel and therefore a list needs to be kept. When Listing operators characters such as @ or % are used to identify operators.
     */
    
    public static let channelOperator = IRCChannelPermissions(rawValue: 1 << 1)
    
    /*
     This mode enhances the privacy and security of the channel by making it invite-only, meaning that only users who have been explicitly invited by a channel operator can join and participate in the channel. Private message can be listed and known to those outside of the channel if they know the channel name. They are not in a public list of channels.
     */
    public static let `private` = IRCChannelPermissions(rawValue: 1 << 2)
    
    /*
     The secret channel mode, often represented by the *s* flag, is used to create channels that are not listed in the channel list and are not visible to users who are not already in the channel. The secret mode enhances privacy and confidentiality by making the channel effectively invisible and accessible only to users who have been explicitly invited or are already members of the channel. To join a secret channel you must be invited.
     */
    public static let secret = IRCChannelPermissions(rawValue: 1 << 3)
    
    /*
     The invite-only channel mode, often represented by the +i flag, is used to create channels where users can only join if they have been explicitly invited by a channel operator or another user with the authority to invite. The invite-only mode enhances control over channel access by requiring users to have an invitation to join the channel, thereby ensuring that only selected individuals can participate in the discussions. If Invite Only Mode is used alone it can be listed and seen by public sources, but it cannot be joined without the invitation.
     */
    public static let inviteOnly = IRCChannelPermissions(rawValue: 1 << 4)
    
    /*
     TopicOnlyByOperator: Only channel operators (ops) have the ability to set or change the channel topic. This mode restricts the modification of the channel topic to operators, ensuring that only authorized users can update the topic displayed to all users in the channel.
     */
    
    public static let topicOnlyByOperator = IRCChannelPermissions(rawValue: 1 << 5)
    
    /*
     No Outside Clients is used to restrict messages from users who are not in the channel. When the n mode is set on a channel, users who are not currently in the channel are prevented from sending messages to the channel. This mode helps maintain the channel's focus on internal discussions among the channel members and prevents external users from disrupting the conversation. Basically allows users to see the conversation, but they cannot participate.
     */
    public static let noOutsideClients = IRCChannelPermissions(rawValue: 1 << 6)
    
    /*
     The Moderated Mode, often represented by the +m flag, is a channel mode that allows channel operators (ops) to control who can send messages in the channel. When the moderated mode is enabled, only channel operators and users with voice (+v) or other specific privileges can send messages, while regular users are restricted from sending messages to the channel. This mode helps maintain order, control discussions, and prevent spam or disruptive behavior within the channel. Basically even if we are a member we can only participate if we are an operator or a voice(speakControl) permissions.
     */
    public static let moderated = IRCChannelPermissions(rawValue: 1 << 7)
    
    /*
     The UserLimit Mode, often represented by the +l flag, is used to set a limit on the maximum number of users allowed in a channel. When the userLimit mode is enabled with a specific limit, additional users attempting to join the channel beyond the set limit will be prevented from entering the channel. This mode helps control the number of users in a channel, manage channel capacity, and maintain a certain level of activity within the channel.
     */
    public static let userLimit = IRCChannelPermissions(rawValue: 1 << 8)
    
    /*
     The BanMask Channel Mode, often represented by the +b flag, is used to ban users from a channel based on a specified ban mask. A ban mask is a pattern that matches a user's hostname, IP address, or nickname, allowing channel operators to prevent specific users or groups of users from joining the channel. When the banMask mode is set with a ban mask, users matching the ban mask are prohibited from entering the channel.
     */
    public static let banMask = IRCChannelPermissions(rawValue: 1 << 9)
    
    /*
     The SpeakControl Mode refers to the voice mode in a channel. When a user is given the voice mode (denoted by the "+" symbol), they are allowed to speak in a channel that is set to moderated mode.
     In a moderated channel, only users with voice mode (+V) or operator status (@) are allowed to send messages. Users without voice mode or operator status can listen to the conversation but cannot actively participate by sending messages.
     Voice mode is often used in larger channels or during events where there is a need to control the flow of conversation and prevent chaos or spam. By granting voice mode to trusted users, channel operators can ensure that meaningful discussions can take place while maintaining order within the channel.
     */
    public static let speakControl = IRCChannelPermissions(rawValue: 1 << 10)
    
    /*
     The Password Mode allows channel operators to set a password for a specific channel. Users who want to join the channel must provide the correct password to gain access.
     Setting a password for a channel can help control who can join the channel and maintain privacy or exclusivity within the channel. It is commonly used for private or restricted channels where only invited users should have access.
     When the password mode is enabled on a channel, users attempting to join the channel will be prompted to enter the correct password. If the password is entered correctly, the user will be granted access to the channel. If the password is incorrect or not provided, the user will be unable to join the channel.
     Channel operators can change the password at any time to maintain security and control over who can access the channel.
     */
    public static let password = IRCChannelPermissions(rawValue: 1 << 11)
    
    /// The mask value representing the combined modes.
    public var maskValue: UInt16 { return rawValue }
    
    /// Initializes a new IRCChannelPermissions from a string representation of modes.
    /// - Parameter string: A string containing channel mode characters.
    /// - Returns: An optional IRCChannelPermissions instance; returns nil if invalid.
    public init?(_ string: String) {
        var mask: UInt16 = 0
        for c in string {
            switch c {
            case "O": mask |= IRCChannelPermissions.channelOperatorAdmin.rawValue
            case "o": mask |= IRCChannelPermissions.channelOperator.rawValue
            case "p": mask |= IRCChannelPermissions.`private`.rawValue
            case "s": mask |= IRCChannelPermissions.secret.rawValue
            case "i": mask |= IRCChannelPermissions.inviteOnly.rawValue
            case "t": mask |= IRCChannelPermissions.topicOnlyByOperator.rawValue
            case "n": mask |= IRCChannelPermissions.noOutsideClients.rawValue
            case "m": mask |= IRCChannelPermissions.moderated.rawValue
            case "l": mask |= IRCChannelPermissions.userLimit.rawValue
            case "b": mask |= IRCChannelPermissions.banMask.rawValue
            case "v": mask |= IRCChannelPermissions.speakControl.rawValue
            case "k": mask |= IRCChannelPermissions.password.rawValue
            default: return nil
            }
        }
        
        self.init(rawValue: mask)
    }
    
    /// Returns the string representation of the channel modes.
    public var stringValue: String {
        var mode = ""
        if contains(.channelOperatorAdmin) { mode += "O" }
        if contains(.channelOperator) { mode += "o" }
        if contains(.`private`) { mode += "p" }
        if contains(.secret) { mode += "s" }
        if contains(.inviteOnly) { mode += "i" }
        if contains(.topicOnlyByOperator) { mode += "t" }
        if contains(.noOutsideClients) { mode += "n" }
        if contains(.moderated) { mode += "m" }
        if contains(.userLimit) { mode += "l" }
        if contains(.banMask) { mode += "b" }
        if contains(.speakControl) { mode += "v" }
        if contains(.password) { mode += "k" }
        return mode
    }
}
