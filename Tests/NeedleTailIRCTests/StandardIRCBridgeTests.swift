//
//  StandardIRCBridgeTests.swift
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

import Foundation
import NIOCore
import NIOEmbedded
import Testing
import NeedleTailIRC

/// Enum case label of a command with a payload (`privMsg`, `otherCommand`, ...).
private func caseName(_ command: IRCCommand) -> String {
    Mirror(reflecting: command).children.first?.label ?? "\(command)"
}

private func typed(_ line: String) throws -> IRCMessage {
    IRCMessage(standardIRC: try IRCRawMessage.parse(line))
}

private func wire(_ message: IRCMessage) throws -> String {
    try IRCRawMessage(standardIRC: message).wireLine()
}

private func wire(_ command: IRCCommand) throws -> String {
    try wire(IRCMessage(command: command))
}

struct InboundCase: CustomTestStringConvertible, Sendable {
    let line: String
    let caseName: String
    let arguments: [String]
    var target: String? = nil
    var testDescription: String { line }
}

@Suite struct StandardIRCInboundTranslationTests {

    static let cases: [InboundCase] = [
        .init(line: ":srv CAP * LS :multi-prefix sasl", caseName: "cap", arguments: ["CAP", "LS", "multi-prefix", "sasl"], target: "*"),
        .init(line: ":srv CAP me ACK :sasl server-time", caseName: "cap", arguments: ["CAP", "ACK", "sasl", "server-time"], target: "me"),
        .init(line: ":srv CAP * LS * :a b", caseName: "otherCommand", arguments: ["*", "LS", "*", "a b"]),
        .init(line: ":srv CAP me NEW :away-notify", caseName: "otherCommand", arguments: ["me", "NEW", "away-notify"]),
        .init(line: "CAP LS 302", caseName: "cap", arguments: ["CAP", "LS", "302"]),
        .init(line: "CAP END", caseName: "cap", arguments: ["CAP", "END"]),
        .init(line: ":srv 433 * alice :Nickname is already in use", caseName: "numeric", arguments: ["alice", "Nickname is already in use"], target: "*"),
        .init(line: ":srv 001 alice :Welcome, alice", caseName: "numeric", arguments: ["Welcome, alice"], target: "alice"),
        .init(line: ":srv 005 me CHANTYPES=# PREFIX=(ov)@+ :are supported by this server", caseName: "numeric", arguments: ["CHANTYPES=#", "PREFIX=(ov)@+", "are supported by this server"], target: "me"),
        .init(line: ":srv 900 me me!u@h me :You are now logged in as me", caseName: "otherNumeric", arguments: ["me!u@h", "me", "You are now logged in as me"], target: "me"),
        .init(line: ":a!a@h PRIVMSG bob_ :hi", caseName: "privMsg", arguments: ["bob_", "hi"]),
        .init(line: ":a!a@h PRIVMSG Bob :hi", caseName: "privMsg", arguments: ["Bob", "hi"]),
        .init(line: ":a!a@h PRIVMSG #chan,bob_ :hi there", caseName: "privMsg", arguments: ["#chan,bob_", "hi there"]),
        .init(line: ":a!a@h PRIVMSG #chan :  indented  ", caseName: "privMsg", arguments: ["#chan", "  indented  "]),
        .init(line: ":a!a@h PRIVMSG #chan :\u{1}ACTION waves\u{1}", caseName: "privMsg", arguments: ["#chan", "\u{1}ACTION waves\u{1}"]),
        .init(line: ":a!a@h PRIVMSG a :hi", caseName: "otherCommand", arguments: ["a", "hi"]),
        .init(line: ":srv NOTICE * :*** Looking up", caseName: "notice", arguments: ["*", "*** Looking up"]),
        .init(line: ":a!a@h NOTICE @#chan :ops only", caseName: "otherCommand", arguments: ["@#chan", "ops only"]),
        .init(line: ":a!a@h NICK :alice2", caseName: "nick", arguments: ["alice2"]),
        .init(line: ":a!a@h NICK Alice_", caseName: "nick", arguments: ["Alice_"]),
        .init(line: ":a!a@h JOIN :#chan", caseName: "join", arguments: ["#chan"]),
        .init(line: "JOIN #a,#b k1,k2", caseName: "join", arguments: ["#a,#b", "k1,k2"]),
        .init(line: ":n!u@h JOIN #chan account :Real Name", caseName: "join", arguments: ["#chan"]),
        .init(line: ":a!a@h PART #chan :Leaving now", caseName: "part", arguments: ["#chan"]),
        .init(line: ":op!a@h KICK #chan bob", caseName: "kick", arguments: ["#chan", "bob", ""]),
        .init(line: ":op!a@h KICK #chan bob :spam reason", caseName: "kick", arguments: ["#chan", "bob", "spam reason"]),
        .init(line: "PING :irc.example.net", caseName: "ping", arguments: ["irc.example.net", ""]),
        .init(line: "PING :token with space", caseName: "ping", arguments: ["token with space", ""]),
        .init(line: ":srv PONG srv :abc", caseName: "pong", arguments: ["srv", "abc"]),
        .init(line: ":a!a@h QUIT :Quit: bye", caseName: "quit", arguments: ["Quit: bye"]),
        .init(line: ":op!a@h TOPIC #chan :new topic", caseName: "topic", arguments: ["#chan", "new topic"]),
        .init(line: ":op!a@h INVITE alice_ :#chan", caseName: "invite", arguments: ["alice_", "#chan"]),
        .init(line: ":a!a@h AWAY :gone", caseName: "away", arguments: ["gone"]),
        .init(line: "MODE #chan", caseName: "channelModeGet", arguments: ["#chan"]),
        .init(line: "MODE #chan +b", caseName: "channelModeGetBanMask", arguments: ["#chan"]),
        .init(line: ":op!a@h MODE #chan +h bob", caseName: "otherCommand", arguments: ["#chan", "+h", "bob"]),
        .init(line: ":op!a@h MODE #chan +k", caseName: "otherCommand", arguments: ["#chan", "+k"]),
        .init(line: ":me MODE me :+i", caseName: "mode", arguments: ["me", "+i"]),
        .init(line: "MODE alice", caseName: "modeGet", arguments: ["alice"]),
        .init(line: "ERROR :Closing Link", caseName: "otherCommand", arguments: ["Closing Link"]),
        .init(line: "USER guest 0 * :Real Name: x", caseName: "user", arguments: ["guest", "0", "*", "Real Name: x"]),
        .init(line: "ISON alice bob_", caseName: "isOn", arguments: ["alice", "bob_"]),
        .init(line: "WHOIS bob", caseName: "whois", arguments: ["", "bob"]),
        .init(line: "WHO #chan o", caseName: "who", arguments: ["#chan", "o"]),
        .init(line: ":a!a@h TAGMSG #chan", caseName: "otherCommand", arguments: ["#chan"]),
        .init(line: "AUTHENTICATE +", caseName: "otherCommand", arguments: ["+"]),
        .init(line: ":srv FOO bar :baz qux", caseName: "otherCommand", arguments: ["bar", "baz qux"]),
    ]

    @Test(arguments: cases)
    func mapsToTypedCommand(_ testCase: InboundCase) throws {
        let message = try typed(testCase.line)
        #expect(caseName(message.command) == testCase.caseName)
        #expect(message.command.arguments == testCase.arguments)
        #expect(message.target == testCase.target)
    }

    @Test func keepsOriginAndTags() throws {
        let message = try typed("@time=2023-01-01T12:00:00.000Z;+typing=active :a!b@c PRIVMSG #c :x")
        #expect(message.origin == "a!b@c")
        #expect(message.tags?.map(\.key) == ["time", "+typing"])
        #expect(message.tags?.map(\.value) == ["2023-01-01T12:00:00.000Z", "active"])
        #expect(try typed("PING x").tags == nil)
    }

    @Test func nicksKeepCaseAndHaveNoDevice() throws {
        guard case .privMsg(let recipients, _) = try typed(":a!a@h PRIVMSG Bob_ :hi").command,
              case .nick(let nick) = recipients.first
        else { Issue.record("expected privMsg to nick"); return }
        #expect(nick.name == "Bob_")
        #expect(nick.deviceId == nil)
    }

    @Test func payloadlessCases() throws {
        guard case .join0 = try typed("JOIN 0").command else { Issue.record("expected join0"); return }
        guard case .quit(nil) = try typed(":a!a@h QUIT").command else { Issue.record("expected quit(nil)"); return }
        guard case .away(nil) = try typed(":a!a@h AWAY").command else { Issue.record("expected away(nil)"); return }
    }

    @Test func channelModeAssignsParametersByRFC2811Rules() throws {
        guard case .channelMode(let channel, let add, let addParameters, let remove, let removeParameters)
            = try typed(":op!a@h MODE #chan +ov-b bob carol *!*@bad").command
        else { Issue.record("expected channelMode"); return }
        #expect(channel.stringValue == "#chan")
        #expect(add == [.channelOperator, .voice])
        #expect(addParameters == ["bob", "carol"])
        #expect(remove == .banMask)
        #expect(removeParameters == ["*!*@bad"])
    }

    @Test func channelModeMixedSigns() throws {
        guard case .channelMode(_, let add, let addParameters, let remove, let removeParameters)
            = try typed(":op!a@h MODE #chan -o+v bob carol").command
        else { Issue.record("expected channelMode"); return }
        #expect(add == .voice)
        #expect(addParameters == ["carol"])
        #expect(remove == .channelOperator)
        #expect(removeParameters == ["bob"])
    }

    @Test func channelModeLimitTakesParameterOnlyWhenAdding() throws {
        guard case .channelMode(_, let add, let addParameters, _, _) = try typed("MODE #chan +l 10").command
        else { Issue.record("expected channelMode +l"); return }
        #expect(add == .userLimit && addParameters == ["10"])
        guard case .channelMode(_, let add2, _, let remove, let removeParameters) = try typed("MODE #chan -lk key").command
        else { Issue.record("expected channelMode -lk"); return }
        #expect(add2 == nil)
        #expect(remove == [.userLimit, .key] && removeParameters == ["key"])
        guard case .otherCommand = try typed("MODE #chan +o-o bob bob").command
        else { Issue.record("same mode added and removed must fall back"); return }
    }

    @Test func channelModeWithoutParameters() throws {
        guard case .channelMode(_, let add, let addParameters, let remove, let removeParameters)
            = try typed("MODE #chan +nt").command
        else { Issue.record("expected channelMode"); return }
        #expect(add == [.noExternalMessages, .topicProtection])
        #expect(addParameters == nil)
        #expect(remove == nil && removeParameters == nil)
    }

    @Test func userModeChanges() throws {
        guard case .mode(let nick, let add, let remove) = try typed(":me MODE me -x+iw").command
        else { Issue.record("expected mode"); return }
        #expect(nick.name == "me")
        #expect(add == [.invisible, .wallOps])
        #expect(remove == .hideHostname)
    }

    @Test func userDetailsKeepRFCFieldsVerbatim() throws {
        guard case .user(let details) = try typed("USER guest 8 * :Real Name").command
        else { Issue.record("expected user"); return }
        #expect(details.username == "guest")
        #expect(details.hostname == "8")
        #expect(details.servername == "*")
        #expect(details.realname == "Real Name")
        #expect(details.userModeFlags == nil)
    }

    @Test func standardNameRulesAllowUnderscores() {
        #expect(NeedleTailNick(name: "john_doe", deviceId: nil, nameRules: .standardIRC)?.name == "john_doe")
        #expect(NeedleTailNick(name: "John", deviceId: nil, nameRules: .standardIRC)?.name == "John")
        #expect(NeedleTailNick(name: "bad nick", deviceId: nil, nameRules: .standardIRC) == nil)
    }
}

struct OutboundCase: CustomTestStringConvertible, Sendable {
    let label: String
    let message: IRCMessage
    let expected: String
    var testDescription: String { label }
}

@Suite struct StandardIRCOutboundTranslationTests {

    static let chan = NeedleTailChannel("#chan")!
    static let bob = NeedleTailNick(name: "bob", deviceId: nil)!
    static let alice = NeedleTailNick(name: "alice", deviceId: nil)!

    static let cases: [OutboundCase] = [
        .init(label: "pong", message: .init(command: .pong(server: "irc.example.net", server2: nil)), expected: "PONG irc.example.net"),
        .init(label: "pong with space", message: .init(command: .pong(server: "token with space", server2: nil)), expected: "PONG :token with space"),
        .init(label: "ping two", message: .init(command: .ping(server: "a", server2: "b")), expected: "PING a b"),
        .init(label: "user", message: .init(command: .user(IRCUserDetails(username: "guest", userModeFlags: nil, realname: "Real Name"))), expected: "USER guest 0 * :Real Name"),
        .init(label: "cap req", message: .init(command: .cap(.req, ["sasl", "server-time"])), expected: "CAP REQ :sasl server-time"),
        .init(label: "cap end", message: .init(command: .cap(.end, [])), expected: "CAP END"),
        .init(label: "cap ls", message: .init(command: .cap(.ls, ["302"])), expected: "CAP LS 302"),
        .init(label: "cap server reply", message: .init(origin: "srv", target: "me", command: .cap(.ack, ["sasl"])), expected: ":srv CAP me ACK :sasl"),
        .init(label: "otherCommand", message: .init(command: .otherCommand("WHOWAS", ["bob", "5"])), expected: "WHOWAS bob 5"),
        .init(label: "otherCommand trailing", message: .init(command: .otherCommand("PRIVMSG", ["#chan", "hi there"])), expected: "PRIVMSG #chan :hi there"),
        .init(label: "authenticate", message: .init(command: .otherCommand("AUTHENTICATE", ["PLAIN"])), expected: "AUTHENTICATE PLAIN"),
        .init(label: "numeric", message: .init(origin: "srv", target: "*", command: .numeric(.errorNicknameInUse, ["alice", "Nickname is already in use"])), expected: ":srv 433 * alice :Nickname is already in use"),
        .init(label: "otherNumeric", message: .init(origin: "srv", target: "me", command: .otherNumeric(903, ["SASL authentication successful"])), expected: ":srv 903 me :SASL authentication successful"),
        .init(label: "privmsg", message: .init(command: .privMsg([.channel(chan), .nick(bob)], "hi there")), expected: "PRIVMSG #chan,bob :hi there"),
        .init(label: "notice tagged", message: .init(origin: "a!b@c", command: .notice([.nick(bob)], "psst"), tags: [IRCTag(key: "+typing", value: "active")]), expected: "@+typing=active :a!b@c NOTICE bob :psst"),
        .init(label: "nick", message: .init(command: .nick(alice)), expected: "NICK alice"),
        .init(label: "join keys", message: .init(command: .join(channels: [chan, NeedleTailChannel("#b")!], keys: ["k1", "k2"])), expected: "JOIN #chan,#b k1,k2"),
        .init(label: "join empty keys", message: .init(command: .join(channels: [chan], keys: [])), expected: "JOIN #chan"),
        .init(label: "join0", message: .init(command: .join0), expected: "JOIN 0"),
        .init(label: "part", message: .init(command: .part(channels: [chan])), expected: "PART #chan"),
        .init(label: "quit", message: .init(command: .quit(nil)), expected: "QUIT"),
        .init(label: "quit msg", message: .init(command: .quit("bye now")), expected: "QUIT :bye now"),
        .init(label: "topic clear", message: .init(command: .topic(chan, "")), expected: "TOPIC #chan :"),
        .init(label: "topic get", message: .init(command: .topic(chan, nil)), expected: "TOPIC #chan"),
        .init(label: "list", message: .init(command: .list(channels: nil, target: nil)), expected: "LIST"),
        .init(label: "list chans", message: .init(command: .list(channels: [chan], target: "srv")), expected: "LIST #chan srv"),
        .init(label: "who ops", message: .init(command: .who(usermask: nil, onlyOperators: true)), expected: "WHO 0 o"),
        .init(label: "who mask", message: .init(command: .who(usermask: "#chan", onlyOperators: false)), expected: "WHO #chan"),
        .init(label: "whois", message: .init(command: .whois(server: nil, usermasks: ["bob", "alice"])), expected: "WHOIS bob,alice"),
        .init(label: "ison", message: .init(command: .isOn([alice, bob])), expected: "ISON alice bob"),
        .init(label: "kick", message: .init(command: .kick([chan], [bob], [])), expected: "KICK #chan bob"),
        .init(label: "kick reason", message: .init(command: .kick([chan], [bob], ["no spam please"])), expected: "KICK #chan bob :no spam please"),
        .init(label: "kill", message: .init(command: .kill(bob, "bye bye")), expected: "KILL bob :bye bye"),
        .init(label: "mode user", message: .init(command: .mode(alice, add: .invisible, remove: .wallOps)), expected: "MODE alice +i-w"),
        .init(label: "mode get", message: .init(command: .modeGet(alice)), expected: "MODE alice"),
        .init(label: "channel mode", message: .init(command: .channelMode(chan, addMode: [.channelOperator, .voice], addParameters: ["bob", "carol"], removeMode: .banMask, removeParameters: ["*!*@bad"])), expected: "MODE #chan +ov-b bob carol *!*@bad"),
        .init(label: "channel mode get", message: .init(command: .channelModeGet(chan)), expected: "MODE #chan"),
        .init(label: "ban list", message: .init(command: .channelModeGetBanMask(chan)), expected: "MODE #chan +b"),
        .init(label: "ban", message: .init(command: .ban(chan, "*!*@bad")), expected: "MODE #chan +b *!*@bad"),
        .init(label: "unban", message: .init(command: .unban(chan, "*!*@bad")), expected: "MODE #chan -b *!*@bad"),
        .init(label: "except", message: .init(command: .except(chan, "*!*@ok")), expected: "MODE #chan +e *!*@ok"),
        .init(label: "invex", message: .init(command: .inviteExcept(chan, "*!*@ok")), expected: "MODE #chan +I *!*@ok"),
        .init(label: "voice", message: .init(command: .voice(chan, bob)), expected: "MODE #chan +v bob"),
        .init(label: "devoice", message: .init(command: .devoice(chan, bob)), expected: "MODE #chan -v bob"),
        .init(label: "halfop", message: .init(command: .halfop(chan, bob)), expected: "MODE #chan +h bob"),
        .init(label: "invite", message: .init(command: .invite(bob, chan)), expected: "INVITE bob #chan"),
        .init(label: "away", message: .init(command: .away("brb")), expected: "AWAY :brb"),
        .init(label: "back", message: .init(command: .away(nil)), expected: "AWAY"),
        .init(label: "names", message: .init(command: .names(chan)), expected: "NAMES #chan"),
        .init(label: "motd", message: .init(command: .motd(nil)), expected: "MOTD"),
        .init(label: "version", message: .init(command: .version("srv")), expected: "VERSION srv"),
        .init(label: "lusers", message: .init(command: .lusers("*", nil)), expected: "LUSERS *"),
        .init(label: "stats", message: .init(command: .stats("u", "srv")), expected: "STATS u srv"),
        .init(label: "wallops", message: .init(command: .wallops("hello all")), expected: "WALLOPS :hello all"),
        .init(label: "oper", message: .init(command: .oper("admin", "pw")), expected: "OPER admin pw"),
        .init(label: "ctcp", message: .init(command: .ctcp(bob, "VERSION", nil)), expected: "PRIVMSG bob :\u{1}VERSION\u{1}"),
        .init(label: "ctcp action", message: .init(command: .ctcp(bob, "ACTION", "waves")), expected: "PRIVMSG bob :\u{1}ACTION waves\u{1}"),
        .init(label: "ctcp reply", message: .init(command: .ctcpreply(bob, "VERSION", "NeedleTail 2.1")), expected: "NOTICE bob :\u{1}VERSION NeedleTail 2.1\u{1}"),
    ]

    @Test(arguments: cases)
    func writesStandardLine(_ testCase: OutboundCase) throws {
        #expect(try wire(testCase.message) == testCase.expected)
    }

    static let unsupported: [IRCCommand] = [
        .dccChat(bob, "127.0.0.1", 6000),
        .sdccSend(bob, "f", 1, "127.0.0.1", 6000),
        .quiet(chan, "*!*@x"),
        .owner(chan, bob),
        .kickban(chan, bob, "bye"),
        .clearmode(chan, "b"),
        .adl,
        .odlist,
    ]

    @Test func rejectsCommandsWithoutAStandardForm() {
        for command in Self.unsupported {
            do {
                _ = try wire(command)
                Issue.record("expected \(caseName(command)) to be rejected")
            } catch let error as IRCStandardError {
                #expect(error.code == .unsupportedOnStandardIRC)
            } catch {
                Issue.record("unexpected error \(error)")
            }
        }
    }

    @Test func rejectsCommandsWithNoTarget() {
        for command: IRCCommand in [.privMsg([], "x"), .notice([], "x"), .join(channels: [], keys: nil), .part(channels: [])] {
            #expect(throws: IRCStandardError(.missingTarget, "\(command.commandAsString) needs at least one target")) {
                try wire(command)
            }
        }
    }

    @Test func rejectsLineBreakInjection() {
        #expect(throws: IRCStandardError.self) {
            try wire(.privMsg([.channel(Self.chan)], "hi\r\nQUIT :pwned"))
        }
    }

    @Test(arguments: [
        "PRIVMSG #chan :hello world",
        ":srv 433 * alice :Nickname is already in use",
        "JOIN #a,#b k1,k2",
        ":op!a@h KICK #chan bob :spam reason",
        "CAP REQ :a b",
        ":srv CAP * LS :multi-prefix sasl",
        ":srv CAP * LS * :multi-prefix sasl",
        "@time=2023-01-01T12:00:00.000Z :n!u@h NOTICE Bob_ :hi",
        "MODE #chan +ov-b bob carol *!*@bad",
        ":srv 005 me CHANTYPES=# :are supported",
        "TAGMSG #chan",
        "PING :token with space",
    ])
    func roundTripsThroughTypedModel(_ line: String) throws {
        #expect(try wire(typed(line)) == line)
    }

    @Test func messageConvenienceProducesStandardWireLine() throws {
        #expect(try IRCMessage(command: .otherCommand("WHOWAS", ["bob", "5"])).standardIRCWireLine() == "WHOWAS bob 5")
    }
}

@Suite struct StandardIRCPipelineTests {

    /// Stand-in for existing application code: it only knows `IRCFrame` / `IRCMessage`.
    final class ExistingAppHandler: ChannelInboundHandler, @unchecked Sendable {
        typealias InboundIn = IRCFrame
        typealias OutboundOut = IRCFrame
        var received: [IRCMessage] = []

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            guard case .text(let message) = unwrapInboundIn(data) else { return }
            received.append(message)
            if case .ping(let server, _) = message.command {
                context.writeAndFlush(wrapOutboundOut(.text(IRCMessage(command: .pong(server: server, server2: nil)))), promise: nil)
            }
        }
    }

    func makeChannel(configuration: IRCStandardConfiguration = .init(), app: ExistingAppHandler? = nil) throws -> EmbeddedChannel {
        let channel = EmbeddedChannel()
        try channel.pipeline.syncOperations.addStandardIRCHandlers(configuration: configuration)
        if let app { try channel.pipeline.syncOperations.addHandler(app) }
        return channel
    }

    func feed(_ channel: EmbeddedChannel, _ text: String) throws {
        var buffer = channel.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        try channel.writeInbound(buffer)
    }

    func outbound(_ channel: EmbeddedChannel) throws -> String {
        var text = ""
        while var buffer = try channel.readOutbound(as: ByteBuffer.self) {
            text += buffer.readString(length: buffer.readableBytes) ?? ""
        }
        return text
    }

    @Test func deliversIRCFramesToExistingHandlers() throws {
        let channel = try makeChannel()
        try feed(channel, ":srv 433 * alice :Nickname is already in use\r\n:a!a@h PRIVMSG bob_ :hi\r\n")
        let first = try #require(try channel.readInbound(as: IRCFrame.self))
        let second = try #require(try channel.readInbound(as: IRCFrame.self))
        guard case .text(let numeric) = first, case .text(let privmsg) = second else {
            Issue.record("expected text frames"); return
        }
        #expect(numeric.command.arguments == ["alice", "Nickname is already in use"])
        #expect(caseName(privmsg.command) == "privMsg")
        _ = try channel.finish()
    }

    @Test func existingHandlerAnswersPingThroughStandardEncoder() throws {
        let app = ExistingAppHandler()
        let channel = try makeChannel(app: app)
        try feed(channel, "PING :irc.example.net\r\n")
        #expect(try outbound(channel) == "PONG irc.example.net\r\n")
        #expect(app.received.count == 1)
        _ = try channel.finish()
    }

    @Test func writesFramesAsStandardLines() throws {
        let channel = try makeChannel()
        try channel.writeOutbound(IRCFrame.text(IRCMessage(command: .cap(.ls, ["302"]))))
        try channel.writeOutbound(IRCFrame.text(IRCMessage(command: .otherCommand("WHOWAS", ["bob", "5"]))))
        #expect(try outbound(channel) == "CAP LS 302\r\nWHOWAS bob 5\r\n")
        _ = try channel.finish()
    }

    @Test func rejectsBinaryAndDCCFrames() throws {
        let channel = try makeChannel()
        let binary = IRCBinaryMessage(recipients: [.all], payload: Data([1, 2, 3]))
        #expect(throws: IRCStandardError(.unsupportedFrame, "binary frames cannot be sent to a standard IRC server")) {
            try channel.writeOutbound(IRCFrame.binary(binary))
        }
        _ = try? channel.finish()
    }

    @Test func rawObserverSeesLosslessMessageAlongsideTypedOne() throws {
        final class Box: @unchecked Sendable { var pairs: [(IRCRawMessage, IRCMessage)] = [] }
        let box = Box()
        var configuration = IRCStandardConfiguration()
        configuration.rawObserver = { raw, message in box.pairs.append((raw, message)) }
        let channel = try makeChannel(configuration: configuration)
        try feed(channel, ":a!a@h PART #chan :Leaving now\r\n")
        #expect(box.pairs.count == 1)
        #expect(box.pairs.first?.0.parameters == ["#chan", "Leaving now"])
        #expect(caseName(box.pairs.first!.1.command) == "part")
        _ = try channel.readInbound(as: IRCFrame.self)
        _ = try channel.finish()
    }

    @Test func unparsableLinesAreReportedNotFatal() throws {
        final class Box: @unchecked Sendable { var lines: [String] = [] }
        let box = Box()
        var configuration = IRCStandardConfiguration()
        configuration.unparsableLineHandler = { line, _ in box.lines.append(line) }
        let channel = try makeChannel(configuration: configuration)
        try feed(channel, ": junk\r\nPING x\r\n")
        #expect(box.lines == [": junk"])
        #expect(try channel.readInbound(as: IRCFrame.self) != nil)
        _ = try channel.finish()
    }

    @Test func configurationDefaults() {
        let configuration = IRCStandardConfiguration()
        #expect(configuration.maxLineLength == IRCStandardLineDecoder.defaultMaxLineLength)
        #expect(configuration.parserLimits == .standardIRC)
        #expect(configuration.rawObserver == nil)
        #expect(configuration.unparsableLineHandler == nil)
    }
}
