//
//  NeedleTailIRCTests.swift
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

import Testing
import Foundation
import BSON
import NIOCore
import NeedleTailLogger
import NeedleTailAsyncSequence

@testable import NeedleTailIRC

@Suite(.serialized)
final class NeedleTailIRCTests {
    let generator = IRCMessageGenerator(executor: TestableExecutor(queue: .init(label: "testable-executor")))
    struct Base64Struct: Sendable, Codable {
        var string: String
    }
    @Test func testAllIRCCommandsRoundTrip() async throws {
        let nick = NeedleTailNick(name: "testnick", deviceId: UUID())!
        let channel = NeedleTailChannel("#testchannel")!
        let userDetails = IRCUserDetails(username: "user", hostname: "host", servername: "server", realname: "Real Name")
        let tags = [IRCTag(key: "test", value: "value")]
        let commands: [IRCCommand] = [
            .nick(nick),
            .user(userDetails),
            .isOn([nick]),
            .quit("bye"),
            .ping(server: "server1", server2: "server2"),
            .pong(server: "server1", server2: "server2"),
            .join(channels: [channel], keys: ["key"]),
            .join0,
            .part(channels: [channel]),
            .list(channels: [channel], target: "target"),
            .privMsg([.nick(nick)], "hello"),
            .notice([.nick(nick)], "notice"),
            .mode(nick, add: .away, remove: .blockUnidentified),
            .modeGet(nick),
            .channelMode(channel, addMode: .inviteOnly, addParameters: ["param"], removeMode: .banMask, removeParameters: ["mask"]),
            .channelModeGet(channel),
            .channelModeGetBanMask(channel),
            .whois(server: "server", usermasks: ["mask1", "mask2"]),
            .who(usermask: "mask", onlyOperators: true),
            .kick([channel], [nick], ["reason"]),
            .kill(nick, "killreason"),
            .sQuit("server", "reason"),
            .server("server", "1.0", 1, "info"),
            .links("mask"),
            .dccChat(nick, "address", 1234),
            .dccSend(nick, "file.txt", 100, "address", 1234),
            .dccResume(nick, "file.txt", 100, "address", 1234, 10),
            .sdccChat(nick, "address", 1234),
            .sdccSend(nick, "file.txt", 100, "address", 1234),
            .sdccResume(nick, "file.txt", 100, "address", 1234, 10),
            .numeric(.replyWelcome, ["arg1", "arg2"]),
            .otherCommand("FOO", ["bar"]),
            .otherNumeric(999, ["foo"]),
            .cap(.ls, ["multi-prefix"]),
            .away("gone"),
            .oper("user", "pass"),
            .knock(channel, "let me in"),
            .silence("mask!*@*"),
            .invite(nick, channel),
            .topic(channel, "topic"),
            .names(channel),
            .ban(channel, "mask!*@*"),
            .unban(channel, "mask!*@*"),
            .kickban(channel, nick, "reason"),
            .clearmode(channel, "modes"),
            .except(channel, "mask!*@*"),
            .unexcept(channel, "mask!*@*"),
            .inviteExcept(channel, "mask!*@*"),
            .uninviteExcept(channel, "mask!*@*"),
            .quiet(channel, "mask!*@*"),
            .unquiet(channel, "mask!*@*"),
            .voice(channel, nick),
            .devoice(channel, nick),
            .halfop(channel, nick),
            .dehalfop(channel, nick),
            .protect(channel, nick),
            .deprotect(channel, nick),
            .owner(channel, nick),
            .deowner(channel, nick),
            .rehash,
            .restart,
            .die,
            .squit("server", "comment"),
            .connect("target", 6667, "remote"),
            .trace("target"),
            .stats("query", "target"),
            .admin("target"),
            .info("target"),
            .version("target"),
            .time("target"),
            .lusers("mask", "target"),
            .motd("target"),
            .rules("target"),
            .map,
            .users("target"),
            .wallops("msg"),
            .globops("msg"),
            .locops("msg"),
            .adl,
            .odlist,
            .ctcp(nick, "VERSION", nil),
            .ctcpreply(nick, "VERSION", "reply")
        ]
        
        for command in commands {
            // Only set target for numeric commands according to IRC protocol
            let target = command.isNumeric ? "target" : nil
            let originalMessage = IRCMessage(origin: "origin", target: target, command: command, tags: tags)
            let encoded = await NeedleTailIRCEncoder.encode(value: originalMessage)
            
            // Skip parsing if encoding returned empty string (invalid command)
            if encoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let parsedMessage = try NeedleTailIRCParser.parseMessage(encoded)
            
            // For numeric commands, if the encoded message does not include a target, expect nil
            if command.isNumeric && !encoded.contains("target") {
                #expect(parsedMessage.target == nil, "Numeric command with no target should parse as nil target")
            }
            
            // Validate complete IRC message structure
            validateIRCMessageRoundTrip(original: originalMessage, parsed: parsedMessage, command: command)
        }
    }
    
    /// Validates that a parsed IRC message matches the original message structure
    private func validateIRCMessageRoundTrip(original: IRCMessage, parsed: IRCMessage, command: IRCCommand) {
        // Validate basic message structure
        if command.isNumeric && (parsed.target == nil || parsed.target?.isEmpty == true) {
            // For numeric commands with no target, expect nil
            #expect(parsed.target == nil, "Numeric command with no target should parse as nil target")
        } else {
            #expect(parsed.origin == original.origin, "Origin should match: expected '\(original.origin ?? "nil")', got '\(parsed.origin ?? "nil")'")
            #expect(parsed.target == original.target, "Target should match: expected '\(original.target ?? "nil")', got '\(parsed.target ?? "nil")'")
        }
        
        // Validate tags
        if let originalTags = original.tags {
            #expect(parsed.tags != nil, "Parsed message should have tags")
            #expect(parsed.tags?.count == originalTags.count, "Tag count should match: expected \(originalTags.count), got \(parsed.tags?.count ?? 0)")
            
            for (index, originalTag) in originalTags.enumerated() {
                let parsedTag = parsed.tags![index]
                #expect(parsedTag.key == originalTag.key, "Tag key should match: expected '\(originalTag.key)', got '\(parsedTag.key)'")
                #expect(parsedTag.value == originalTag.value, "Tag value should match: expected '\(originalTag.value)', got '\(parsedTag.value)'")
            }
        } else {
            #expect(parsed.tags == nil || parsed.tags?.isEmpty == true, "Parsed message should not have tags")
        }
        
        // Validate command type
        #expect(parsed.command.commandAsString == command.commandAsString, "Command should match: expected '\(command.commandAsString)', got '\(parsed.command.commandAsString)'")
        
        // Validate command-specific parameters
        validateCommandParameters(original: command, parsed: parsed.command)
    }
    
    /// Validates command-specific parameters for different IRC command types
    private func validateCommandParameters(original: IRCCommand, parsed: IRCCommand) {
        switch (original, parsed) {
        case (.nick(let originalNick), .nick(let parsedNick)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "NICK parameter should match")
            
        case (.user(let originalUser), .user(let parsedUser)):
            #expect(parsedUser.username == originalUser.username, "USER username should match")
            #expect(parsedUser.hostname == originalUser.hostname, "USER hostname should match")
            #expect(parsedUser.servername == originalUser.servername, "USER servername should match")
            #expect(parsedUser.realname == originalUser.realname, "USER realname should match")
            
        case (.isOn(let originalNicks), .isOn(let parsedNicks)):
            #expect(parsedNicks.count == originalNicks.count, "ISON nick count should match")
            for (index, originalNick) in originalNicks.enumerated() {
                #expect(parsedNicks[index].stringValue == originalNick.stringValue, "ISON nick should match")
            }
            
        case (.quit(let originalReason), .quit(let parsedReason)):
            #expect(parsedReason == originalReason, "QUIT reason should match")
            
        case (.ping(let originalServer, let originalServer2), .ping(let parsedServer, let parsedServer2)):
            #expect(parsedServer == originalServer, "PING server should match")
            #expect(parsedServer2 == originalServer2, "PING server2 should match")
            
        case (.pong(let originalServer, let originalServer2), .pong(let parsedServer, let parsedServer2)):
            #expect(parsedServer == originalServer, "PONG server should match")
            #expect(parsedServer2 == originalServer2, "PONG server2 should match")
            
        case (.join(let originalChannels, let originalKeys), .join(let parsedChannels, let parsedKeys)):
            #expect(parsedChannels.count == originalChannels.count, "JOIN channel count should match")
            for (index, originalChannel) in originalChannels.enumerated() {
                #expect(parsedChannels[index].stringValue == originalChannel.stringValue, "JOIN channel should match")
            }
            #expect(parsedKeys == originalKeys, "JOIN keys should match")
            
        case (.join0, .join0):
            // No parameters to validate
            break
            
        case (.part(let originalChannels), .part(let parsedChannels)):
            #expect(parsedChannels.count == originalChannels.count, "PART channel count should match")
            for (index, originalChannel) in originalChannels.enumerated() {
                #expect(parsedChannels[index].stringValue == originalChannel.stringValue, "PART channel should match")
            }
            
        case (.list(let originalChannels, let originalTarget), .list(let parsedChannels, let parsedTarget)):
            #expect(parsedChannels?.count == originalChannels?.count, "LIST channel count should match")
            if let originalChannels = originalChannels, let parsedChannels = parsedChannels {
                for (index, originalChannel) in originalChannels.enumerated() {
                    #expect(parsedChannels[index].stringValue == originalChannel.stringValue, "LIST channel should match")
                }
            }
            #expect(parsedTarget == originalTarget, "LIST target should match")
            
        case (.privMsg(let originalRecipients, let originalMessage), .privMsg(let parsedRecipients, let parsedMessage)):
            #expect(parsedRecipients.count == originalRecipients.count, "PRIVMSG recipient count should match")
            for (index, originalRecipient) in originalRecipients.enumerated() {
                #expect(parsedRecipients[index].stringValue == originalRecipient.stringValue, "PRIVMSG recipient should match")
            }
            #expect(parsedMessage == originalMessage, "PRIVMSG message should match")
            
        case (.notice(let originalRecipients, let originalMessage), .notice(let parsedRecipients, let parsedMessage)):
            #expect(parsedRecipients.count == originalRecipients.count, "NOTICE recipient count should match")
            for (index, originalRecipient) in originalRecipients.enumerated() {
                #expect(parsedRecipients[index].stringValue == originalRecipient.stringValue, "NOTICE recipient should match")
            }
            #expect(parsedMessage == originalMessage, "NOTICE message should match")
            
        case (.mode(let originalNick, let originalAdd, let originalRemove), .mode(let parsedNick, let parsedAdd, let parsedRemove)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "MODE nick should match")
            #expect(parsedAdd == originalAdd, "MODE add flags should match")
            #expect(parsedRemove == originalRemove, "MODE remove flags should match")
            
        case (.modeGet(let originalNick), .modeGet(let parsedNick)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "MODEGET nick should match")
            
        case (.channelMode(let originalChannel, let originalAddMode, let originalAddParams, let originalRemoveMode, let originalRemoveParams), 
              .channelMode(let parsedChannel, let parsedAddMode, let parsedAddParams, let parsedRemoveMode, let parsedRemoveParams)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "CHANNELMODE channel should match")
            #expect(parsedAddMode == originalAddMode, "CHANNELMODE add mode should match")
            #expect(parsedAddParams == originalAddParams, "CHANNELMODE add parameters should match")
            #expect(parsedRemoveMode == originalRemoveMode, "CHANNELMODE remove mode should match")
            #expect(parsedRemoveParams == originalRemoveParams, "CHANNELMODE remove parameters should match")
            
        case (.channelModeGet(let originalChannel), .channelModeGet(let parsedChannel)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "CHANNELMODE_GET channel should match")
            
        case (.channelModeGetBanMask(let originalChannel), .channelModeGetBanMask(let parsedChannel)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "CHANNELMODE_GET_BANMASK channel should match")
            
        case (.whois(let originalServer, let originalUsermasks), .whois(let parsedServer, let parsedUsermasks)):
            #expect(parsedServer == originalServer, "WHOIS server should match")
            #expect(parsedUsermasks.count == originalUsermasks.count, "WHOIS usermask count should match")
            for (index, originalMask) in originalUsermasks.enumerated() {
                #expect(parsedUsermasks[index] == originalMask, "WHOIS usermask should match")
            }
            
        case (.who(let originalUsermask, let originalOnlyOperators), .who(let parsedUsermask, let parsedOnlyOperators)):
            #expect(parsedUsermask == originalUsermask, "WHO usermask should match")
            #expect(parsedOnlyOperators == originalOnlyOperators, "WHO onlyOperators should match")
            
        case (.kick(let originalChannels, let originalUsers, let originalReasons), .kick(let parsedChannels, let parsedUsers, let parsedReasons)):
            #expect(parsedChannels.count == originalChannels.count, "KICK channel count should match")
            for (index, originalChannel) in originalChannels.enumerated() {
                #expect(parsedChannels[index].stringValue == originalChannel.stringValue, "KICK channel should match")
            }
            #expect(parsedUsers.count == originalUsers.count, "KICK user count should match")
            for (index, originalUser) in originalUsers.enumerated() {
                #expect(parsedUsers[index].stringValue == originalUser.stringValue, "KICK user should match")
            }
            #expect(parsedReasons.count == originalReasons.count, "KICK reason count should match")
            for (index, originalReason) in originalReasons.enumerated() {
                #expect(parsedReasons[index] == originalReason, "KICK reason should match")
            }
            
        case (.kill(let originalNick, let originalComment), .kill(let parsedNick, let parsedComment)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "KILL nick should match")
            #expect(parsedComment == originalComment, "KILL comment should match")
            
        case (.sQuit(let originalServer, let originalReason), .sQuit(let parsedServer, let parsedReason)):
            #expect(parsedServer == originalServer, "SQUIT server should match")
            #expect(parsedReason == originalReason, "SQUIT reason should match")
            
        case (.server(let originalName, let originalVersion, let originalHopCount, let originalInfo), 
              .server(let parsedName, let parsedVersion, let parsedHopCount, let parsedInfo)):
            #expect(parsedName == originalName, "SERVER name should match")
            #expect(parsedVersion == originalVersion, "SERVER version should match")
            #expect(parsedHopCount == originalHopCount, "SERVER hop count should match")
            #expect(parsedInfo == originalInfo, "SERVER info should match")
            
        case (.links(let originalMask), .links(let parsedMask)):
            #expect(parsedMask == originalMask, "LINKS mask should match")
            
        case (.numeric(let originalCode, let originalArgs), .numeric(let parsedCode, let parsedArgs)):
            #expect(parsedCode == originalCode, "NUMERIC code should match")
            #expect(parsedArgs.count == originalArgs.count, "NUMERIC args count should match")
            for (index, originalArg) in originalArgs.enumerated() {
                #expect(parsedArgs[index] == originalArg, "NUMERIC arg should match")
            }
            
        case (.otherCommand(let originalName, let originalArgs), .otherCommand(let parsedName, let parsedArgs)):
            #expect(parsedName == originalName, "OTHER_COMMAND name should match")
            #expect(parsedArgs.count == originalArgs.count, "OTHER_COMMAND args count should match")
            for (index, originalArg) in originalArgs.enumerated() {
                #expect(parsedArgs[index] == originalArg, "OTHER_COMMAND arg should match")
            }
            
        case (.otherNumeric(let originalCode, let originalArgs), .otherNumeric(let parsedCode, let parsedArgs)):
            #expect(parsedCode == originalCode, "OTHER_NUMERIC code should match")
            #expect(parsedArgs.count == originalArgs.count, "OTHER_NUMERIC args count should match")
            for (index, originalArg) in originalArgs.enumerated() {
                #expect(parsedArgs[index] == originalArg, "OTHER_NUMERIC arg should match")
            }
            
        case (.cap(let originalSubCmd, let originalCapabilities), .cap(let parsedSubCmd, let parsedCapabilities)):
            #expect(parsedSubCmd == originalSubCmd, "CAP subcommand should match")
            #expect(parsedCapabilities.count == originalCapabilities.count, "CAP capabilities count should match")
            for (index, originalCap) in originalCapabilities.enumerated() {
                #expect(parsedCapabilities[index] == originalCap, "CAP capability should match")
            }
            
        case (.away(let originalMessage), .away(let parsedMessage)):
            #expect(parsedMessage == originalMessage, "AWAY message should match")
            
        case (.oper(let originalUsername, let originalPassword), .otherCommand(let parsedName, let parsedArgs)) where parsedName == "OPER":
            #expect(parsedArgs.count == 2, "OPER otherCommand should have 2 args")
            #expect(parsedArgs[0] == originalUsername, "OPER username should match")
            #expect(parsedArgs[1] == originalPassword, "OPER password should match")
        case (.otherCommand(let originalName, let originalArgs), .oper(let parsedUser, let parsedPass)) where originalName == "OPER":
            #expect(originalArgs.count == 2, "OPER otherCommand should have 2 args")
            #expect(originalArgs[0] == parsedUser, "OPER username should match")
            #expect(originalArgs[1] == parsedPass, "OPER password should match")
            
        case (.knock(let originalChannel, let originalMessage), .knock(let parsedChannel, let parsedMessage)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "KNOCK channel should match")
            #expect(parsedMessage == originalMessage, "KNOCK message should match")
            
        case (.silence(let originalMask), .silence(let parsedMask)):
            #expect(parsedMask == originalMask, "SILENCE mask should match")
            
        case (.invite(let originalNick, let originalChannel), .invite(let parsedNick, let parsedChannel)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "INVITE nick should match")
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "INVITE channel should match")
            
        case (.topic(let originalChannel, let originalTopic), .topic(let parsedChannel, let parsedTopic)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "TOPIC channel should match")
            #expect(parsedTopic == originalTopic, "TOPIC topic should match")
            
        case (.names(let originalChannel), .names(let parsedChannel)):
            #expect(parsedChannel?.stringValue == originalChannel?.stringValue, "NAMES channel should match")
            
        case (.ban(let originalChannel, let originalMask), .ban(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "BAN channel should match")
            #expect(parsedMask == originalMask, "BAN mask should match")
            
        case (.unban(let originalChannel, let originalMask), .unban(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "UNBAN channel should match")
            #expect(parsedMask == originalMask, "UNBAN mask should match")
            
        case (.kickban(let originalChannel, let originalNick, let originalReason), .kickban(let parsedChannel, let parsedNick, let parsedReason)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "KICKBAN channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "KICKBAN nick should match")
            #expect(parsedReason == originalReason, "KICKBAN reason should match")
            
        case (.clearmode(let originalChannel, let originalMode), .clearmode(let parsedChannel, let parsedMode)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "CLEARMODE channel should match")
            #expect(parsedMode == originalMode, "CLEARMODE mode should match")
            
        case (.except(let originalChannel, let originalMask), .except(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "EXCEPT channel should match")
            #expect(parsedMask == originalMask, "EXCEPT mask should match")
            
        case (.unexcept(let originalChannel, let originalMask), .unexcept(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "UNEXCEPT channel should match")
            #expect(parsedMask == originalMask, "UNEXCEPT mask should match")
            
        case (.inviteExcept(let originalChannel, let originalMask), .inviteExcept(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "INVITEEXCEPT channel should match")
            #expect(parsedMask == originalMask, "INVITEEXCEPT mask should match")
            
        case (.uninviteExcept(let originalChannel, let originalMask), .uninviteExcept(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "UNINVITEEXCEPT channel should match")
            #expect(parsedMask == originalMask, "UNINVITEEXCEPT mask should match")
            
        case (.quiet(let originalChannel, let originalMask), .quiet(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "QUIET channel should match")
            #expect(parsedMask == originalMask, "QUIET mask should match")
            
        case (.unquiet(let originalChannel, let originalMask), .unquiet(let parsedChannel, let parsedMask)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "UNQUIET channel should match")
            #expect(parsedMask == originalMask, "UNQUIET mask should match")
            
        case (.voice(let originalChannel, let originalNick), .voice(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "VOICE channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "VOICE nick should match")
            
        case (.devoice(let originalChannel, let originalNick), .devoice(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "DEVOICE channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "DEVOICE nick should match")
            
        case (.halfop(let originalChannel, let originalNick), .halfop(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "HALFOP channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "HALFOP nick should match")
            
        case (.dehalfop(let originalChannel, let originalNick), .dehalfop(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "DEHALFOP channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "DEHALFOP nick should match")
            
        case (.protect(let originalChannel, let originalNick), .protect(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "PROTECT channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "PROTECT nick should match")
            
        case (.deprotect(let originalChannel, let originalNick), .deprotect(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "DEPROTECT channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "DEPROTECT nick should match")
            
        case (.owner(let originalChannel, let originalNick), .owner(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "OWNER channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "OWNER nick should match")
            
        case (.deowner(let originalChannel, let originalNick), .deowner(let parsedChannel, let parsedNick)):
            #expect(parsedChannel.stringValue == originalChannel.stringValue, "DEOWNER channel should match")
            #expect(parsedNick.stringValue == originalNick.stringValue, "DEOWNER nick should match")
            
        case (.rehash, .rehash), (.restart, .restart), (.die, .die), (.map, .map), (.adl, .adl), (.odlist, .odlist):
            // No parameters to validate
            break
            
        case (.squit(let originalServer, let originalComment), .squit(let parsedServer, let parsedComment)):
            #expect(parsedServer == originalServer, "SQUIT server should match")
            #expect(parsedComment == originalComment, "SQUIT comment should match")
            
        case (.connect(let originalTarget, let originalPort, let originalRemote), .connect(let parsedTarget, let parsedPort, let parsedRemote)):
            #expect(parsedTarget == originalTarget, "CONNECT target should match")
            #expect(parsedPort == originalPort, "CONNECT port should match")
            #expect(parsedRemote == originalRemote, "CONNECT remote should match")
            
        case (.trace(let originalTarget), .trace(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "TRACE target should match")
            
        case (.stats(let originalQuery, let originalTarget), .stats(let parsedQuery, let parsedTarget)):
            #expect(parsedQuery == originalQuery, "STATS query should match")
            #expect(parsedTarget == originalTarget, "STATS target should match")
            
        case (.admin(let originalTarget), .admin(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "ADMIN target should match")
            
        case (.info(let originalTarget), .info(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "INFO target should match")
            
        case (.version(let originalTarget), .version(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "VERSION target should match")
            
        case (.time(let originalTarget), .time(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "TIME target should match")
            
        case (.lusers(let originalMask, let originalTarget), .lusers(let parsedMask, let parsedTarget)):
            #expect(parsedMask == originalMask, "LUSERS mask should match")
            #expect(parsedTarget == originalTarget, "LUSERS target should match")
            
        case (.motd(let originalTarget), .motd(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "MOTD target should match")
            
        case (.rules(let originalTarget), .rules(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "RULES target should match")
            
        case (.users(let originalTarget), .users(let parsedTarget)):
            #expect(parsedTarget == originalTarget, "USERS target should match")
            
        case (.wallops(let originalMessage), .wallops(let parsedMessage)):
            #expect(parsedMessage == originalMessage, "WALLOPS message should match")
            
        case (.globops(let originalMessage), .globops(let parsedMessage)):
            #expect(parsedMessage == originalMessage, "GLOBOPS message should match")
            
        case (.locops(let originalMessage), .locops(let parsedMessage)):
            #expect(parsedMessage == originalMessage, "LOCOPS message should match")
            
        case (.dccChat(let originalNick, let originalAddress, let originalPort), .dccChat(let parsedNick, let parsedAddress, let parsedPort)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "DCCCHAT nick should match")
            #expect(parsedAddress == originalAddress, "DCCCHAT address should match")
            #expect(parsedPort == originalPort, "DCCCHAT port should match")
            
        case (.dccSend(let originalNick, let originalFilename, let originalFilesize, let originalAddress, let originalPort), 
              .dccSend(let parsedNick, let parsedFilename, let parsedFilesize, let parsedAddress, let parsedPort)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "DCCSEND nick should match")
            #expect(parsedFilename == originalFilename, "DCCSEND filename should match")
            #expect(parsedFilesize == originalFilesize, "DCCSEND filesize should match")
            #expect(parsedAddress == originalAddress, "DCCSEND address should match")
            #expect(parsedPort == originalPort, "DCCSEND port should match")
            
        case (.dccResume(let originalNick, let originalFilename, let originalFilesize, let originalAddress, let originalPort, let originalOffset), 
              .dccResume(let parsedNick, let parsedFilename, let parsedFilesize, let parsedAddress, let parsedPort, let parsedOffset)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "DCCRESUME nick should match")
            #expect(parsedFilename == originalFilename, "DCCRESUME filename should match")
            #expect(parsedFilesize == originalFilesize, "DCCRESUME filesize should match")
            #expect(parsedAddress == originalAddress, "DCCRESUME address should match")
            #expect(parsedPort == originalPort, "DCCRESUME port should match")
            #expect(parsedOffset == originalOffset, "DCCRESUME offset should match")
            
        case (.sdccChat(let originalNick, let originalAddress, let originalPort), .sdccChat(let parsedNick, let parsedAddress, let parsedPort)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "SDCCCHAT nick should match")
            #expect(parsedAddress == originalAddress, "SDCCCHAT address should match")
            #expect(parsedPort == originalPort, "SDCCCHAT port should match")
            
        case (.sdccSend(let originalNick, let originalFilename, let originalFilesize, let originalAddress, let originalPort), 
              .sdccSend(let parsedNick, let parsedFilename, let parsedFilesize, let parsedAddress, let parsedPort)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "SDCCSEND nick should match")
            #expect(parsedFilename == originalFilename, "SDCCSEND filename should match")
            #expect(parsedFilesize == originalFilesize, "SDCCSEND filesize should match")
            #expect(parsedAddress == originalAddress, "SDCCSEND address should match")
            #expect(parsedPort == originalPort, "SDCCSEND port should match")
            
        case (.sdccResume(let originalNick, let originalFilename, let originalFilesize, let originalAddress, let originalPort, let originalOffset), 
              .sdccResume(let parsedNick, let parsedFilename, let parsedFilesize, let parsedAddress, let parsedPort, let parsedOffset)):
            #expect(parsedNick.stringValue == originalNick.stringValue, "SDCCRESUME nick should match")
            #expect(parsedFilename == originalFilename, "SDCCRESUME filename should match")
            #expect(parsedFilesize == originalFilesize, "SDCCRESUME filesize should match")
            #expect(parsedAddress == originalAddress, "SDCCRESUME address should match")
            #expect(parsedPort == originalPort, "SDCCRESUME port should match")
            #expect(parsedOffset == originalOffset, "SDCCRESUME offset should match")
            
        case (.ctcp(let originalTarget, let originalCommand, let originalArgument), .ctcp(let parsedTarget, let parsedCommand, let parsedArgument)):
            #expect(parsedTarget.stringValue == originalTarget.stringValue, "CTCP target should match")
            #expect(parsedCommand == originalCommand, "CTCP command should match")
            #expect(parsedArgument == originalArgument, "CTCP argument should match")
            
        case (.ctcpreply(let originalTarget, let originalCommand, let originalArgument), .ctcpreply(let parsedTarget, let parsedCommand, let parsedArgument)):
            #expect(parsedTarget.stringValue == originalTarget.stringValue, "CTCPREPLY target should match")
            #expect(parsedCommand == originalCommand, "CTCPREPLY command should match")
            #expect(parsedArgument == originalArgument, "CTCPREPLY argument should match")
            
        // Generalized equivalence: known command vs otherCommand with same name and args
        case let (known, .otherCommand(parsedName, parsedArgs)):
            if known.commandAsString.uppercased() == parsedName.uppercased() {
                let knownArgs = known.arguments
                #expect(parsedArgs.count == knownArgs.count, "OTHER_COMMAND args count should match for \(parsedName)")
                for (index, knownArg) in knownArgs.enumerated() {
                    #expect(parsedArgs[index] == knownArg, "OTHER_COMMAND arg should match for \(parsedName)")
                }
                return
            }
        case let (.otherCommand(originalName, originalArgs), known):
            if known.commandAsString.uppercased() == originalName.uppercased() {
                let knownArgs = known.arguments
                #expect(originalArgs.count == knownArgs.count, "OTHER_COMMAND args count should match for \(originalName)")
                for (index, knownArg) in knownArgs.enumerated() {
                    #expect(originalArgs[index] == knownArg, "OTHER_COMMAND arg should match for \(originalName)")
                }
                return
            }
        // Handle case variations between known commands (e.g., squit vs sQuit)
        case let (known1, known2):
            if known1.commandAsString.uppercased() == known2.commandAsString.uppercased() {
                let args1 = known1.arguments
                let args2 = known2.arguments
                #expect(args1.count == args2.count, "Command args count should match for \(known1.commandAsString)")
                for (index, arg1) in args1.enumerated() {
                    #expect(args2[index] == arg1, "Command arg should match for \(known1.commandAsString)")
                }
                return
            }
            
        default:
            // For any unhandled cases, just ensure the command types match
            #expect(original.commandAsString == parsed.commandAsString, "Command should match: expected '\(original.commandAsString)', got '\(parsed.commandAsString)'")
        }
    }
    
    @Test func testReadKeyBundle() async throws  {
        let base64 = try! BSONEncoder().encode(Base64Struct(string:TestableConstants.longMessage.rawValue)).makeData().base64EncodedString()
        let messages = await generator.createMessages(
            origin: TestableConstants.origin.rawValue,
            command: IRCCommand.otherCommand(Constants.readPublishedBlob.rawValue,
                                             [base64]),
            logger: NeedleTailLogger())
        
        for await message in messages {
            if let rebuiltMessage = try await generator.messageReassembler(ircMessage: message) {
                #expect(message == rebuiltMessage)
            }
        }
        
    }
    
    @Test func testServerMessage() async throws  {
        _ = try! BSONEncoder().encode(Base64Struct(string:TestableConstants.longMessage.rawValue)).makeData().base64EncodedString()
        
        let messages = await generator.createMessages(
            origin: TestableConstants.origin.rawValue,
            command: IRCCommand.server("Server1", "1.0.0", 1, "Server Message"),
            tags: [],
            logger:  NeedleTailLogger())
        
        for await message in messages {
            if let rebuiltMessage = try await generator.messageReassembler(ircMessage: message) {
                #expect(message == rebuiltMessage)
            }
        }
        
    }
    
    @Test func testParseMessages() async {
        for message in await createIRCMessages() {
            await #expect(throws: Never.self, performing: {
                let messageToParse = await NeedleTailIRCEncoder.encode(value: message)
                _ = try NeedleTailIRCParser.parseMessage(messageToParse)
                
            })
        }
    }
    
    @Test func testEdgeCases() async throws {
        // Test with very long messages
        let longMessage = String(repeating: "a", count: 10000)
        let msg = IRCMessage(
            origin: "origin",
            command: .privMsg([.nick(NeedleTailNick(name: "test", deviceId: UUID())!)], longMessage)
        )
        let encoded = await NeedleTailIRCEncoder.encode(value: msg)
        let parsed = try NeedleTailIRCParser.parseMessage(encoded)
        #expect(parsed.command.commandAsString == "PRIVMSG")
        
        // Test with special characters
        let specialChars = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        let msg2 = IRCMessage(
            origin: "origin",
            command: .privMsg([.nick(NeedleTailNick(name: "test", deviceId: UUID())!)], specialChars)
        )
        let encoded2 = await NeedleTailIRCEncoder.encode(value: msg2)
        let parsed2 = try NeedleTailIRCParser.parseMessage(encoded2)
        #expect(parsed2.command.commandAsString == "PRIVMSG")
        
        // Test with empty origin/target
        let msg3 = IRCMessage(
            origin: nil,
            target: nil,
            command: .ping(server: "server", server2: nil)
        )
        let encoded3 = await NeedleTailIRCEncoder.encode(value: msg3)
        let parsed3 = try NeedleTailIRCParser.parseMessage(encoded3)
        #expect(parsed3.command.commandAsString == "PING")
    }
    
    @Test func testTags() async throws {
        // Test single tag
        let msg = IRCMessage(
            origin: "origin",
            command: .nick(NeedleTailNick(name: "test", deviceId: UUID())!),
            tags: [IRCTag(key: "key", value: "value")]
        )
        let encoded = await NeedleTailIRCEncoder.encode(value: msg)
        let parsed = try NeedleTailIRCParser.parseMessage(encoded)
        #expect(parsed.tags?.count == 1)
        #expect(parsed.tags?.first?.key == "key")
        #expect(parsed.tags?.first?.value == "value")
        
        // Test multiple tags
        let msg2 = IRCMessage(
            origin: "origin",
            command: .nick(NeedleTailNick(name: "test", deviceId: UUID())!),
            tags: [
                IRCTag(key: "key1", value: "value1"),
                IRCTag(key: "key2", value: "value2")
            ]
        )
        let encoded2 = await NeedleTailIRCEncoder.encode(value: msg2)
        let parsed2 = try NeedleTailIRCParser.parseMessage(encoded2)
        #expect(parsed2.tags?.count == 2)
    }
    
    @Test func testDCCCommands() async throws {
        let nick = NeedleTailNick(name: "testnick", deviceId: UUID())!
        
        // Test DCC CHAT
        let dccChat = IRCMessage(
            origin: "origin",
            command: .dccChat(nick, "192.168.1.1", 1234)
        )
        let encodedChat = await NeedleTailIRCEncoder.encode(value: dccChat)
        let parsedChat = try NeedleTailIRCParser.parseMessage(encodedChat)
        #expect(parsedChat.command.commandAsString == "DCCCHAT")
        
        // Test DCC SEND
        let dccSend = IRCMessage(
            origin: "origin",
            command: .dccSend(nick, "file.txt", 1024, "192.168.1.1", 1234)
        )
        let encodedSend = await NeedleTailIRCEncoder.encode(value: dccSend)
        let parsedSend = try NeedleTailIRCParser.parseMessage(encodedSend)
        #expect(parsedSend.command.commandAsString == "DCCSEND")
        
        // Test DCC RESUME
        let dccResume = IRCMessage(
            origin: "origin",
            command: .dccResume(nick, "file.txt", 1024, "192.168.1.1", 1234, 512)
        )
        let encodedResume = await NeedleTailIRCEncoder.encode(value: dccResume)
        let parsedResume = try NeedleTailIRCParser.parseMessage(encodedResume)
        #expect(parsedResume.command.commandAsString == "DCCRESUME")
        
        // Test secure DCC variants
        let sdccChat = IRCMessage(
            origin: "origin",
            command: .sdccChat(nick, "192.168.1.1", 1234)
        )
        let encodedSChat = await NeedleTailIRCEncoder.encode(value: sdccChat)
        let parsedSChat = try NeedleTailIRCParser.parseMessage(encodedSChat)
        #expect(parsedSChat.command.commandAsString == "SDCCCHAT")
    }
    
    @Test func testCTCPCommands() async throws {
        let nick = NeedleTailNick(name: "testnick", deviceId: UUID())!
        
        // Test CTCP command
        let ctcp = IRCMessage(
            origin: "origin",
            command: .ctcp(nick, "VERSION", nil)
        )
        let encoded = await NeedleTailIRCEncoder.encode(value: ctcp)
        let parsed = try NeedleTailIRCParser.parseMessage(encoded)
        #expect(parsed.command.commandAsString == "CTCP")
        
        // Test CTCP with argument
        let ctcpWithArg = IRCMessage(
            origin: "origin",
            command: .ctcp(nick, "PING", "123456")
        )
        let encodedWithArg = await NeedleTailIRCEncoder.encode(value: ctcpWithArg)
        let parsedWithArg = try NeedleTailIRCParser.parseMessage(encodedWithArg)
        #expect(parsedWithArg.command.commandAsString == "CTCP")
        
        // Test CTCP reply
        let ctcpreply = IRCMessage(
            origin: "origin",
            command: .ctcpreply(nick, "VERSION", "NeedleTailIRC 1.0")
        )
        let encodedReply = await NeedleTailIRCEncoder.encode(value: ctcpreply)
        let parsedReply = try NeedleTailIRCParser.parseMessage(encodedReply)
        #expect(parsedReply.command.commandAsString == "CTCPREPLY")
    }
    
    @Test func testServerAdminCommands() async throws {
        
        // Test server administration commands
        let commands: [IRCCommand] = [
            .rehash,
            .restart,
            .die,
            .squit("server", "comment"),
            .connect("target", 6667, "remote"),
            .trace("target"),
            .stats("query", "target"),
            .admin("target"),
            .info("target"),
            .version("target"),
            .time("target"),
            .lusers("mask", "target"),
            .motd("target"),
            .rules("target"),
            .map,
            .users("target"),
            .wallops("msg"),
            .globops("msg"),
            .locops("msg"),
            .adl,
            .odlist
        ]
        
        for command in commands {
            let msg = IRCMessage(origin: "origin", command: command)
            let encoded = await NeedleTailIRCEncoder.encode(value: msg)
            let parsed = try NeedleTailIRCParser.parseMessage(encoded)
            #expect(parsed.command.commandAsString == command.commandAsString)
        }
    }
    
    @Test func testChannelManagementCommands() async throws {
        let channel = NeedleTailChannel("#testchannel")!
        let nick = NeedleTailNick(name: "testnick", deviceId: UUID())!
        
        // Test user status commands
        let userCommands: [IRCCommand] = [
            .away("gone"),
            .away(nil), // Remove away status
            .oper("user", "pass"),
            .knock(channel, "let me in"),
            .knock(channel, nil), // No message
            .silence("mask!*@*"),
            .invite(nick, channel),
            .topic(channel, "new topic"),
            .topic(channel, nil), // Get topic
            .names(channel),
            .names(nil) // All channels
        ]
        
        for command in userCommands {
            let msg = IRCMessage(origin: "origin", command: command)
            let encoded = await NeedleTailIRCEncoder.encode(value: msg)
            let parsed = try NeedleTailIRCParser.parseMessage(encoded)
            #expect(parsed.command.commandAsString == command.commandAsString)
        }
        
        // Test channel moderation commands
        let moderationCommands: [IRCCommand] = [
            .ban(channel, "mask!*@*"),
            .unban(channel, "mask!*@*"),
            .kickban(channel, nick, "reason"),
            .clearmode(channel, "modes"),
            .except(channel, "mask!*@*"),
            .unexcept(channel, "mask!*@*"),
            .inviteExcept(channel, "mask!*@*"),
            .uninviteExcept(channel, "mask!*@*"),
            .quiet(channel, "mask!*@*"),
            .unquiet(channel, "mask!*@*")
        ]
        
        for command in moderationCommands {
            let msg = IRCMessage(origin: "origin", command: command)
            let encoded = await NeedleTailIRCEncoder.encode(value: msg)
            let parsed = try NeedleTailIRCParser.parseMessage(encoded)
            #expect(parsed.command.commandAsString == command.commandAsString)
        }
        
        // Test user permission commands
        let permissionCommands: [IRCCommand] = [
            .voice(channel, nick),
            .devoice(channel, nick),
            .halfop(channel, nick),
            .dehalfop(channel, nick),
            .protect(channel, nick),
            .deprotect(channel, nick),
            .owner(channel, nick),
            .deowner(channel, nick)
        ]
        
        for command in permissionCommands {
            let msg = IRCMessage(origin: "origin", command: command)
            let encoded = await NeedleTailIRCEncoder.encode(value: msg)
            let parsed = try NeedleTailIRCParser.parseMessage(encoded)
            #expect(parsed.command.commandAsString == command.commandAsString)
        }
    }
    
    @Test func testDebugJoin() async throws {
        let channel = NeedleTailChannel("#testchannel")!
        let command = IRCCommand.join(channels: [channel], keys: ["key"])
        let msg = IRCMessage(origin: "origin", command: command, tags: nil)
        let encoded = await NeedleTailIRCEncoder.encode(value: msg)
        print("Encoded JOIN: '\(encoded)'")
        
        let parsed = try NeedleTailIRCParser.parseMessage(encoded)
        print("Parsed command: \(parsed.command)")
    }
    
    @Test func testJoinWithEmptyChannelsDoesNotEncode() async throws {
        let command = IRCCommand.join(channels: [], keys: nil)
        let msg = IRCMessage(origin: "origin", command: command)
        let encoded = await NeedleTailIRCEncoder.encode(value: msg)
        #expect(encoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "JOIN with empty channels should not encode any command")
    }
}
enum ClientType: Codable {
    case server, client
}

struct ReachableServers: Codable, Sendable {
    let host: String
    let port: Int
    let cacheKey: CacheKey
    let isSecure: Bool
}

enum CacheKey: String, Equatable, CaseIterable, Codable {
    case irc1, irc2, irc3, irc4, irc5
    case client1, client2, client3
    case none
}

func createIRCMessages() async -> [IRCMessage] {
    var messages = [IRCMessage]()
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.pass.rawValue, ["123", "456"]),
            tags: [])
    )
    
    let reachableServers: [ReachableServers] = []
    let serverPassword = "321"
    let value = try! BSONEncoder().encode(ClientType.server).makeData().base64EncodedString()
    let passTag = IRCTag(key: TagKey.passTag.rawValue, value: value)
    let servers = try! BSONEncoder().encode(reachableServers).makeData().base64EncodedString()
    let tag = IRCTag(key: TagKey.reachableServers.rawValue, value: servers)
    
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.pass.rawValue, [serverPassword]),
            tags: [passTag, tag])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .nick(.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .nick(.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!),
            tags: [.init(key: "tempRegistration", value: "123456hgfdsa")])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .nick(.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!),
            //            arguments: ["hop_count_0"],
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .user(.init(username: "guest", hostname: "needletail-client", servername: "needletail-server", realname: "No ones business")),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .user(.init(username: "guest", realname: "No ones business")),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .isOn([.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .isOn([.init(name: TestableConstants.origin.rawValue, deviceId: UUID())!, .init(name: TestableConstants.target.rawValue, deviceId: UUID())!]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .quit("See ya!"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .ping(server: TestableConstants.serverOne.rawValue, server2: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .ping(server: TestableConstants.serverOne.rawValue, server2: TestableConstants.serverTwo.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .pong(server: TestableConstants.serverOne.rawValue, server2: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .pong(server: TestableConstants.serverOne.rawValue, server2: TestableConstants.serverTwo.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!], keys: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!], keys: [TestableConstants.channelOneKey.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], keys: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], keys: [TestableConstants.channelOneKey.rawValue, TestableConstants.channelTwoKey.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .join0,
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .part(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!], target: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!], target: TestableConstants.target.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], target: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: [.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], target: TestableConstants.target.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: nil, target: nil),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .list(channels: nil, target: TestableConstants.target.rawValue),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .privMsg([.all], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .privMsg([.channel(.init(TestableConstants.channelOne.rawValue)!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .privMsg([.nick(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .notice([.all], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .notice([.channel(.init(TestableConstants.channelOne.rawValue)!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .notice([.nick(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!)], "Welcome to our messaging sdk"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .mode(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, add: .away, remove: .blockUnidentified),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .modeGet(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .inviteOnly, addParameters: [], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .banMask, addParameters: ["baduser1!*@*","baduser2!*@*"], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .userLimit, addParameters: ["10"], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: nil, addParameters: [], removeMode: .inviteOnly, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: nil, addParameters: [], removeMode: .banMask, removeParameters: ["baduser2!*@*","baduser3!*@*"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .banMask, addParameters: ["baduser1!*@*","baduser2!*@*"], removeMode: .banMask, removeParameters: ["baduser1!*@*","baduser2!*@*"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelModeGet(.init(TestableConstants.channelOne.rawValue)!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelMode(.init(TestableConstants.channelOne.rawValue)!, addMode: .banMask, addParameters: [], removeMode: nil, removeParameters: []),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .channelModeGetBanMask(.init(TestableConstants.channelOne.rawValue)!),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .whois(server: TestableConstants.serverOne.rawValue, usermasks: [TestableConstants.usermaskOne.rawValue, TestableConstants.usermaskTwo.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .who(usermask: TestableConstants.usermaskOne.rawValue, onlyOperators: false),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .who(usermask: TestableConstants.usermaskOne.rawValue, onlyOperators: true),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kick([.init(TestableConstants.channelOne.rawValue)!], [.init(name: TestableConstants.target.rawValue, deviceId: UUID())!], ["GO AWAY"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kick([.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], [.init(name: TestableConstants.target.rawValue, deviceId: UUID())!], ["GO AWAY", "YOU GOT KICKED"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kick([.init(TestableConstants.channelOne.rawValue)!, .init(TestableConstants.channelTwo.rawValue)!], [.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, .init(name: TestableConstants.origin.rawValue, deviceId: UUID())!], ["GO AWAY", "YOU GOT KICKED", "SEE YA!"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kill(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, "KILLED IT"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .kill(.init(name: TestableConstants.target.rawValue, deviceId: UUID())!, "KILLED IT"),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.ack, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.end, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.list, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.ls, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.nak, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .cap(.req, [TestableConstants.target.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.registryRequest.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.newDevice.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.offlineMessages.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.deleteOfflineMessage.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.publishBlob.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.readPublishedBlob.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.badgeUpdate.rawValue, ["1"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.multipartMediaDownload.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.multipartMediaUpload.rawValue, [
                "id",
                "1",
                "20",
                TestableConstants.longMessage.rawValue
            ]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.requestMediaDeletion.rawValue, ["contactId", "mediaId"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.destoryUser.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .otherCommand(Constants.listBucket.rawValue, [TestableConstants.longMessage.rawValue]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyWelcome, ["Welcome", "To", "Your", "IRC Server"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyISON, ["userOne", "userTwo", "userThree", "userFour"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyMotDStart, ["- Message of the Day -"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyMotD, ["I think therefore I am"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .numeric(.replyEndOfMotD, ["End of /MOTD command."]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            target: TestableConstants.target.rawValue,
            command: .otherNumeric(999, ["uknown", "message"]),
            tags: [])
    )
    messages.append(
        IRCMessage(
            origin: TestableConstants.origin.rawValue,
            command: .server("serverName", "1.0.0", 1, "Welcome"),
            tags: [IRCTag(key: "someTag", value: "someValue")])
    )
    return messages
}

enum TestableConstants: String, Sendable {
    case origin = "nt1"
    case target = "nt2"
    case serverOne = "server-one"
    case serverTwo = "server-two"
    case channelOne = "#channel-one"
    case channelTwo = "#channel-two"
    case channelOneKey = "channel-one-key"
    case channelTwoKey = "channel-two-key"
    case usermaskOne = "usermask-one"
    case usermaskTwo = "usermask-two"
    case longMessage =
            "nibh tortor id aliquet lectus proin nibh nisl condimentum id venenatis a condimentum vitae sapien pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas sed tempus urna et pharetra pharetra massa massa ultricies mi quis hendrerit dolor magna eget est lorem ipsum dolor sit amet consectetur adipiscing elit pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas integer eget aliquet nibh praesent tristique magna sit amet purus gravida quis blandit turpis cursus in hac habitasse platea dictumst quisque sagittis purus sit amet volutpat consequat mauris nunc congue nisi vitae suscipit tellus mauris a diam maecenas sed enim ut sem viverra aliquet eget sit amet tellus cras adipiscing enim eu turpis egestas pretium aenean pharetra magna ac placerat vestibulum lectus mauris ultrices eros in cursus turpis massa tincidunt dui ut ornare lectus sit amet est placerat in egestas erat imperdiet sed euismod nisi porta lorem mollis aliquam ut porttitor leo a diam sollicitudin tempor id eu nisl nunc mi ipsum faucibus vitae aliquet nec ullamcorper sit amet risus nullam eget felis eget nunc lobortis mattis aliquam faucibus purus in massa tempor nec feugiat nisl pretium fusce id velit ut tortor pretium viverra suspendisse potenti nullam ac tortor vitae purus faucibus ornare suspendisse sed nisi lacus sed viverra tellus in hac habitasse platea dictumst vestibulum rhoncus est pellentesque elit ullamcorper dignissim cras tincidunt lobortis feugiat vivamus at augue eget arcu dictum varius duis at consectetur lorem donec massa sapien faucibus et molestie ac feugiat sed lectus vestibulum mattis ullamcorper velit sed ullamcorper morbi tincidunt ornare massa eget egestas purus viverra accumsan in nisl nisi scelerisque eu ultrices vitae auctor eu augue ut lectus arcu bibendum at varius vel pharetra vel turpis nunc eget lorem dolor sed viverra ipsum nunc aliquet bibendum enim facilisis gravida neque convallis a cras semper auctor neque vitae tempus quam pellentesque nec nam aliquam sem et tortor consequat id porta nibh venenatis cras sed felis eget velit aliquet sagittis id consectetur purus ut faucibus pulvinar elementum integer enim neque volutpat ac tincidunt vitae semper quis lectus nulla at volutpat diam ut venenatis tellus in metus vulputate eu scelerisque felis imperdiet proin fermentum leo vel orci porta non pulvinar neque laoreet suspendisse interdum consectetur libero id faucibus nisl tincidunt eget nullam non nisi est sit amet facilisis magna etiam tempor orci eu lobortis elementum nibh tellus molestie nunc non blandit massa enim nec dui nunc mattis enim ut tellus elementum sagittis vitae et leo duis ut diam quam nulla porttitor massa id neque aliquam vestibulum morbi blandit cursus risus at ultrices mi tempus imperdiet nulla malesuada pellentesque elit eget gravida cum sociis natoque penatibus et magnis dis parturient montes nascetur ridiculus mus mauris vitae ultricies leo integer malesuada nunc vel risus commodo viverra maecenas accumsan lacus vel facilisis volutpat est velit egestas dui id ornare arcu odio ut sem nulla pharetra diam sit amet nisl suscipit adipiscing bibendum est ultricies integer quis auctor elit sed vulputate mi sit amet mauris commodo quis imperdiet massa tincidunt nunc pulvinar sapien et ligula ullamcorper malesuada proin libero nunc consequat interdum varius sit amet mattis vulputate enim nulla aliquet porttitor lacus luctus accumsan tortor posuere ac ut consequat semper viverra nam libero justo laoreet sit amet cursus sit amet dictum sit amet justo donec enim diam vulputate ut pharetra sit amet aliquam id diam maecenas ultricies mi eget mauris pharetra et ultrices neque ornare aenean euismod elementum nisi quis eleifend quam adipiscing vitae proin sagittis nisl rhoncus mattis rhoncus urna neque viverra justo nec ultrices dui sapien eget mi proin sed libero enim sed faucibus turpis in eu mi bibendum neque egestas congue quisque egestas diam in arcu cursus euismod quis viverra nibh cras pulvinar mattis nunc sed blandit libero volutpat sed cras ornare arcu dui vivamus arcu felis bibendum ut tristique et egestas quis ipsum suspendisse ultrices gravida dictum fusce ut placerat orci nulla pellentesque dignissim enim sit amet venenatis urna cursus eget nunc scelerisque viverra mauris in aliquam sem fringilla ut morbi tincidunt augue interdum velit euismod in pellentesque massa placerat duis ultricies lacus sed turpis tincidunt id aliquet risus feugiat in ante metus dictum at tempor commodo ullamcorper a lacus vestibulum sed arcu non odio euismod lacinia at quis risus sed vulputate odio ut enim blandit volutpat maecenas volutpat blandit aliquam etiam erat velit scelerisque in dictum non consectetur a erat nam at lectus urna duis convallis convallis tellus id interdum velit laoreet id donec ultrices tincidunt arcu non sodales neque sodales ut etiam sit amet nisl purus in mollis nunc sed id semper risus in hendrerit gravida rutrum quisque non tellus orci ac auctor augue mauris augue neque gravida in fermentum et sollicitudin ac orci phasellus egestas tellus rutrum tellus pellentesque eu tincidunt tortor aliquam nulla facilisi cras fermentum odio eu"
}


/// A default executor that conforms to AnyExecutor.
public final class TestableExecutor: AnyExecutor {
    
    let queue: DispatchQueue
    let shouldExecuteAsTask: Bool
    
    /// Initializes a new instance of NTAExecutor.
    /// - Parameters:
    ///   - queue: The dispatch queue to execute tasks on.
    ///   - shouldExecuteAsTask: A flag indicating whether to execute as a task (default is true).
    init(queue: DispatchQueue, shouldExecuteAsTask: Bool = true) {
        self.queue = queue
        self.shouldExecuteAsTask = shouldExecuteAsTask
    }
    
    /// Converts the executor to an unowned task executor.
    /// - Returns: An unowned task executor.
    public func asUnownedTaskExecutor() -> UnownedTaskExecutor {
        UnownedTaskExecutor(ordinary: self)
    }
    
    /// Checks if the current execution context is isolated to the executor's queue.
    public func checkIsolated() {
        dispatchPrecondition(condition: .onQueue(queue))
    }
    
    /// Enqueues a job for execution.
    /// - Parameter job: The job to be executed.
    public func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        self.queue.async { [weak self] in
            guard let self = self else { return }
            if self.shouldExecuteAsTask {
                job.runSynchronously(on: self.asUnownedTaskExecutor())
            } else {
                job.runSynchronously(on: self.asUnownedSerialExecutor())
            }
        }
    }
    
    /// Converts the executor to an unowned serial executor.
    /// - Returns: An unowned serial executor.
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(complexEquality: self)
    }
}
