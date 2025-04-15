//
//  IRCEventProtocol.swift
//
//
//  Created by Cole M on 9/28/22.
//

/// A protocol that defines the events and commands for handling IRC operations.
public protocol IRCEventProtocol: AnyObject, Sendable {
    
    // MARK: - Core IRC Methods
    
    /// Sends a PING message to the specified source.
    /// - Parameters:
    ///   - source: The origin of the PING request.
    ///   - secondarySource: An optional second source.
    func doPing(source: String, secondarySource: String?) async throws
    
    /// Sends a PONG message in response to a PING.
    /// - Parameters:
    ///   - source: The origin of the PONG response.
    ///   - secondarySource: An optional second source.
    func doPong(source: String, secondarySource: String?) async throws
    
    /// Handles CAP commands for client capabilities.
    /// - Parameters:
    ///   - command: The CAP sub-command to execute.
    ///   - capabilities: An array of capability identifiers.
    func doCAP(command: IRCCommand.CAPSubCommand, capabilities: [String]) async throws
    
    /// Changes the nickname of the sender.
    /// - Parameters:
    ///   - senderID: The user ID of the sender.
    ///   - nick: The new nickname to set.
    ///   - associatedTags: Optional tags associated with the nickname change.
    func doNick(senderID: IRCUserIdentifier?, nick: NeedleTailNick, associatedTags: [IRCTag]?) async throws
    
    /// Sends user information.
    /// - Parameters:
    ///   - info: The user information to send.
    ///   - associatedTags: Optional tags associated with the user information.
    func doUserInfo(info: IRCUserDetails, associatedTags: [IRCTag]?) async throws
    
    /// Retrieves the mode of a specified user.
    /// - Parameter nick: The nickname of the user.
    func doModeGet(for nick: NeedleTailNick) async throws
    
    /// Retrieves the mode of a specified channel.
    /// - Parameter channel: The name of the channel.
    func doModeGet(for channel: NeedleTailChannel) async throws
    
    /// Sets the mode for a specified user.
    /// - Parameters:
    ///   - nick: The nickname of the user.
    ///   - addMode: The user mode to add.
    ///   - removeMode: The user mode to remove.
    func doMode(nick: NeedleTailNick, addMode: IRCUserModeFlags?, removeMode: IRCUserModeFlags?) async throws
    
    /// Sets the mode for a specified channel.
    /// - Parameters:
    ///   - channel: The name of the channel.
    ///   - addMode: The channel mode to add.
    ///   - addParameters: Optional parameters for the added mode.
    ///   - removeMode: The channel mode to remove.
    ///   - removeParameters: Optional parameters for the removed mode.
    func doMode(
        channel: NeedleTailChannel,
        addMode: IRCChannelPermissions?,
        addParameters: [String]?,
        removeMode: IRCChannelPermissions?,
        removeParameters: [String]?) async throws
    
    /// Requests information about a user.
    /// - Parameters:
    ///   - server: An optional server to query.
    ///   - usermasks: An array of user masks to look up.
    func doWhoIs(server: String?, usermasks: [String]) async throws
    
    /// Retrieves information about users matching a specified mask.
    /// - Parameters:
    ///   - mask: An optional mask to filter users.
    ///   - operatorsOnly: A flag indicating whether to return only operator users.
    func doWho(mask: String?, operatorsOnly: Bool) async throws
    
    /// Joins one or more channels.
    /// - Parameters:
    ///   - channels: An array of channel names to join.
    ///   - keys: Optional keys for the channels.
    ///   - associatedTags: Optional tags associated with the join action.
    func doJoin(channels: [NeedleTailChannel], keys: [String]?, associatedTags: [IRCTag]?) async throws
    
    /// Parts from one or more channels.
    /// - Parameters:
    ///   - channels: An array of channel names to part from.
    ///   - associatedTags: Optional tags associated with the part action.
    func doPart(channels: [NeedleTailChannel], associatedTags: [IRCTag]?) async throws
    
    /// Parts from all channels.
    /// - Parameter associatedTags: Optional tags associated with the part action.
    func doPartAll(associatedTags: [IRCTag]?) async throws
    
    /// Retrieves the ban mask for a specified channel.
    /// - Parameter channel: The name of the channel.
    func doGetBanMask(for channel: NeedleTailChannel) async throws
    
    /// Sends a notice to specified recipients.
    /// - Parameters:
    ///   - recipients: An array of message recipients.
    ///   - message: The notice message to send.
    func doNotice(recipients: [IRCMessageRecipient], message: String) async throws
    
    /// Sends a message to specified recipients.
    /// - Parameters:
    ///   - senderID: The user ID of the sender.
    ///   - recipients: An array of message recipients.
    ///   - message: The message content to send.
    ///   - associatedTags: Optional tags associated with the message.
    func doMessage(senderID: IRCUserIdentifier?, recipients: [IRCMessageRecipient], message: String, associatedTags: [IRCTag]?) async throws
    
    /// Checks if specified nicknames are online.
    /// - Parameter nicks: An array of nicknames to check.
    func doIsOnline(nicks: [NeedleTailNick]) async throws
    
    /// Lists channels or users.
    /// - Parameters:
    ///   - channels: An optional array of channel names to list.
    ///   - target: An optional target for the list command.
    func doList(channels: [NeedleTailChannel]?, target: String?) async throws
    
    /// Sends a QUIT message to the server.
    /// - Parameter message: An optional message to include with the quit.
    func doQuit(message: String?) async throws
    
    // MARK: - DCC Methods
    
    /// Sends a file to a specified recipient using DCC.
    /// - Parameters:
    ///   - packet: The DCCPacket.
    func doDCCSend(with packet: DCCMetadata, sender: String) async throws
    
    /// Initiates a DCC chat with a specified recipient.
    /// - Parameter packet: The DCCPacket.
    func doDCCChat(with packet: DCCMetadata, sender: String) async throws
    
    /// Resumes a DCC file transfer to a specified recipient.
    /// - Parameters:
    ///   - packet: The DCCPacket
    func doDCCResume(with packet: DCCMetadata, sender: String) async throws
    
    /// Disconnects a DCC session with a specified recipient.
    func doDCCDisconnect() async throws
    
    // MARK: - Additional Methods
    
    /// Publishes a key bundle.
    /// - Parameter keyBundle: An array of keys to publish.
    func doPublishUserConfiguration(packet: [String]) async throws
    
    /// Reads a key bundle.
    /// - Parameter keyBundle: An array of keys to read.
    func doFindUserConfiguration(packet: [String]) async throws
    
    /// Registers an APN token for push notifications.
    /// - Parameter token: An array containing the APN token.
    func doRegisterAPN(token: [String]) async throws
    
    /// Sets a password for the user.
    /// - Parameter password: An array containing the password.
    func doPassword(password: [String], associatedTags: [IRCTag]) async throws
    
    /// Registers a new device.
    /// - Parameter info: An array containing device information.
    func doNewDevice(info: [String]) async throws
    
    /// Publishes a blob of data.
    /// - Parameter blob: An array containing the blob data.
    func doPublishBlob(packet: [String]) async throws
    
    /// Reads a blob of data.
    /// - Parameter blob: An array containing the blob data.
    func doReadBlob(packet: [String]) async throws
    
    /// Retrieves offline messages for a specified user.
    /// - Parameter nick: The nickname of the user to retrieve messages for.
    func doOfflineMessages(for nick: NeedleTailNick) async throws
    
    /// Deletes offline messages from a specified contact.
    /// - Parameter contact: The contact from whom to delete messages.
    func doDeleteOfflineMessages(from contact: String) async throws
    
    /// Kicks users from specified channels.
    /// - Parameters:
    ///   - channels: An array of channel names.
    ///   - users: An array of user nicknames to kick.
    ///   - comments: Optional comments to include with the kick.
    func doKick(channels: [NeedleTailChannel], users: [String], comments: [String]?) async throws

    /// Kills a specified user.
    /// - Parameters:
    ///   - nick: The nickname of the user to kill.
    ///   - comment: A comment explaining the reason for the kill.
    func doKill(nick: NeedleTailNick, comment: String) async throws
    
    /// Downloads a multipart message.
    /// - Parameter packet: An array containing the multipart message data.
    func doMultipartMessageDownload(packet: [String]) async
    
    /// Uploads a multipart message.
    /// - Parameter packet: An array containing the multipart message data.
    func doMultipartMessageUpload(packet: [String]) async
    
    /// Lists a bucket of data.
    /// - Parameter packet: An array containing the bucket data.
    func doListBucket(packet: [String]) async throws
    
    /// Updates the badge count for notifications.
    /// - Parameter count: The new badge count.
    func badgeCountUpdate(count: Int) async throws
    
    /// Notifies that a user is typing.
    /// - Parameter packet: An array containing typing notification data.
    func doIsTyping(packet: [String]) async throws
    
    /// Destroys a user account or session.
    /// - Parameter packet: An array containing the data needed to destroy the user.
    func doDestroyUser(packet: [String]) async throws
}

public extension IRCEventProtocol {
    func doPing(source: String, secondarySource: String?) async throws {}
    func doPong(source: String, secondarySource: String?) async throws {}
    func doCAP(command: IRCCommand.CAPSubCommand, capabilities: [String]) async throws {}
    func doNick(senderID: IRCUserIdentifier?, nick: NeedleTailNick, associatedTags: [IRCTag]?) async throws {}
    func doUserInfo(info: IRCUserDetails, associatedTags: [IRCTag]?) async throws {}
    func doModeGet(for nick: NeedleTailNick) async throws {}
    func doModeGet(for channel: NeedleTailChannel) async throws {}
    func doMode(nick: NeedleTailNick, addMode: IRCUserModeFlags?, removeMode: IRCUserModeFlags?) async throws {}
    func doMode(channel: NeedleTailChannel, addMode: IRCChannelPermissions?, addParameters: [String]?, removeMode: IRCChannelPermissions?, removeParameters: [String]?) async throws {}
    func doWhoIs(server: String?, usermasks: [String]) async throws {}
    func doWho(mask: String?, operatorsOnly: Bool) async throws {}
    func doJoin(channels: [NeedleTailChannel], keys: [String]?, associatedTags: [IRCTag]?) async throws {}
    func doPart(channels: [NeedleTailChannel], associatedTags: [IRCTag]?) async throws {}
    func doPartAll(associatedTags: [IRCTag]?) async throws {}
    func doGetBanMask(for channel: NeedleTailChannel) async throws {}
    func doNotice(recipients: [IRCMessageRecipient], message: String) async throws {}
    func doMessage(senderID: IRCUserIdentifier?, recipients: [IRCMessageRecipient], message: String, associatedTags: [IRCTag]?) async throws {}
    func doIsOnline(nicks: [NeedleTailNick]) async throws {}
    func doList(channels: [NeedleTailChannel]?, target: String?) async throws {}
    func doQuit(message: String?) async throws {}
    func doDCCSend(with packet: DCCMetadata, sender: String) async throws {}
    func doDCCChat(with packet: DCCMetadata, sender: String) async throws {}
    func doDCCResume(with packet: DCCMetadata, sender: String) async throws {}
    func doDCCDisconnect() async throws {}
    func doPublishUserConfiguration(packet: [String]) async throws {}
    func doFindUserConfiguration(packet: [String]) async throws {}
    func doRegisterAPN(token: [String]) async throws {}
    func doPassword(password: [String], associatedTags: [IRCTag]) async throws {}
    func doNewDevice(info: [String]) async throws {}
    func doPublishBlob(packet: [String]) async throws {}
    func doReadBlob(packet: [String]) async throws {}
    func doOfflineMessages(for nick: NeedleTailNick) async throws {}
    func doDeleteOfflineMessages(from contact: String) async throws {}
    func doKick(channels: [NeedleTailChannel], users: [String], comments: [String]?) async throws {}
    func doKill(nick: NeedleTailNick, comment: String) async throws {}
    func doMultipartMessageDownload(packet: [String]) async {}
    func doMultipartMessageUpload(packet: [String]) async {}
    func doListBucket(packet: [String]) async throws {}
    func badgeCountUpdate(count: Int) async throws {}
    func doIsTyping(packet: [String]) async throws {}
    func doDestroyUser(packet: [String]) async throws {}
}
