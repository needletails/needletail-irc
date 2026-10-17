//
//  NeedleTailUnchangedTests.swift
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
@testable import NeedleTailIRC

/// Golden snapshot of the NeedleTail-dialect parser, encoder and frame decoder.
///
/// The opt-in standard IRC support must never change these outputs. If a snapshot needs to be
/// regenerated on purpose, run with `NTIRC_CAPTURE_GOLDEN=1` and paste the printed literals.
@Suite struct NeedleTailUnchangedTests {

    static let parserCorpus: [String] = [
        ":alice!alice@localhost PRIVMSG #general :Hello, world!",
        "@time=2023-01-01T12:00:00Z :alice PRIVMSG #general :Hello!",
        ":server 001 alice :Welcome to the server!",
        "NICK alice_12345678-1234-1234-1234-123456789ABC",
        "USER alice 0 * :Alice Smith",
        "JOIN #general,#random key1,key2",
        "JOIN 0",
        "PART #general",
        "PING server1 server2",
        "PONG server1",
        "CAP LS :multi-prefix sasl",
        "CAP REQ :sasl",
        "CAP END",
        "MODE #chan +o bob",
        "MODE alice +i",
        "KICK #chan bob :spam",
        "WHOIS bob",
        "WHO #chan o",
        "ISON alice bob",
        "QUIT :bye",
        "TOPIC #chan :new topic",
        "INVITE alice #chan",
        "AWAY :gone",
        "PASS :secret",
        ":srv 464 alice :Sorry, but your password is incorrect.",
        ":srv 372 alice :- MOTD line",
        ":srv 465 :marker, 12345678-1234-1234-1234-123456789ABC",
        ":irc.example.net 001 alice :Welcome to the Example IRC Network, alice!alice@host",
        ":irc.example.net 005 alice CHANTYPES=# PREFIX=(ov)@+ :are supported by this server",
        ":irc.example.net 353 alice = #chan :@op +voiced plain",
        ":irc.example.net 433 * alice :Nickname is already in use",
        "PING :irc.example.net",
        ":alice!a@h NICK :alice_",
        ":alice!a@h PRIVMSG bob_ :hi",
        ":alice!a@h JOIN :#chan",
        ":irc.example.net CAP * LS :multi-prefix sasl",
        ":op!a@h KICK #chan bob",
        ":op!a@h MODE #chan -o+v bob carol",
        "USER guest 0 * :Real Name: with colon",
        ":alice!a@h PRIVMSG #chan :  two leading spaces",
        "@+draft/reply=abc :alice!a@h TAGMSG #chan",
        "ERROR :Closing Link: host (Quit: bye)",
    ]

    static let encoderCorpus: [IRCMessage] = {
        let chan = NeedleTailChannel("#chan")!
        let bob = NeedleTailNick(name: "bob", deviceId: nil)!
        return [
            IRCMessage(command: .pong(server: "irc.example.net", server2: nil)),
            IRCMessage(command: .ping(server: "abc", server2: "def")),
            IRCMessage(command: .user(IRCUserDetails(username: "guest", userModeFlags: nil, realname: "Real Name"))),
            IRCMessage(command: .cap(.req, ["sasl", "server-time"])),
            IRCMessage(command: .cap(.end, [])),
            IRCMessage(command: .otherCommand("PASS", ["secret"])),
            IRCMessage(command: .otherCommand("WHOWAS", ["bob", "5"])),
            IRCMessage(origin: "srv", target: "alice", command: .numeric(.errorPasswordMismatch, ["Sorry, wrong"])),
            IRCMessage(command: .numeric(.errorUnknownCommand, ["DCC", "DCC is not supported."])),
            IRCMessage(command: .channelMode(chan, addMode: .channelOperator, addParameters: ["bob"], removeMode: nil, removeParameters: nil)),
            IRCMessage(command: .kick([chan], [bob], ["spam"])),
            IRCMessage(command: .privMsg([.channel(chan), .nick(bob)], "hi there")),
            IRCMessage(origin: "alice", command: .notice([.nick(bob)], "psst"), tags: [IRCTag(key: "time", value: "a b;c")]),
            IRCMessage(command: .join(channels: [chan], keys: ["k"])),
            IRCMessage(command: .join0),
            IRCMessage(command: .quit("bye now")),
            IRCMessage(command: .topic(chan, "")),
            IRCMessage(command: .list(channels: nil, target: nil)),
            IRCMessage(command: .who(usermask: nil, onlyOperators: true)),
            IRCMessage(command: .ctcp(bob, "VERSION", nil)),
            IRCMessage(command: .dccChat(bob, "127.0.0.1", 6000)),
        ]
    }()

    static let decoderInput = "PING :irc.example.net\r\n:srv 001 alice :Welcome, alice\r\n\r\n:a!a@h PRIVMSG bob_ :dropped\nCAP END\r\n"

    // MARK: - Rendering

    static func render(parsing line: String) -> String {
        do {
            let message = try NeedleTailIRCParser.parseMessage(line)
            var dumped = ""
            dump(message.command, to: &dumped)
            let wire = (try? message.wireLine()) ?? "<throws>"
            let tags = message.tags?.map { "\($0.key)=\($0.value)" }.joined(separator: ";") ?? "-"
            return "OK|\(message.origin ?? "-")|\(message.target ?? "-")|\(tags)|\(wire)|\(dumped)"
        } catch {
            return "ERR|\(error)"
        }
    }

    static func render(encoding message: IRCMessage) -> String {
        do {
            return "OK|\(try message.wireLine())"
        } catch {
            return "ERR|\(error)"
        }
    }

    static func renderDecoder() throws -> [String] {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCFrameDecoder()))
        var buffer = channel.allocator.buffer(capacity: 256)
        buffer.writeString(decoderInput)
        try channel.writeInbound(buffer)
        var frames: [String] = []
        while let frame = try channel.readInbound(as: IRCFrame.self) {
            frames.append(frame.description)
        }
        _ = try channel.finish()
        return frames
    }

    static var isCapturing: Bool {
        ProcessInfo.processInfo.environment["NTIRC_CAPTURE_GOLDEN"] == "1"
    }

    static func printLiterals(_ name: String, _ values: [String]) {
        print("    static let \(name): [String] = [")
        for value in values {
            print("        \(String(reflecting: value)),")
        }
        print("    ]")
    }

    // MARK: - Tests

    @Test func parserOutputUnchanged() {
        let actual = Self.parserCorpus.map(Self.render(parsing:))
        if Self.isCapturing { Self.printLiterals("expectedParser", actual) }
        #expect(actual.count == Self.expectedParser.count)
        for (index, pair) in zip(actual, Self.expectedParser).enumerated() {
            #expect(pair.0 == pair.1, "parser corpus line \(index): \(Self.parserCorpus[index])")
        }
    }

    @Test func encoderOutputUnchanged() {
        let actual = Self.encoderCorpus.map(Self.render(encoding:))
        if Self.isCapturing { Self.printLiterals("expectedEncoder", actual) }
        #expect(actual == Self.expectedEncoder)
    }

    @Test func frameDecoderOutputUnchanged() throws {
        let actual = try Self.renderDecoder()
        if Self.isCapturing { Self.printLiterals("expectedDecoder", actual) }
        #expect(actual == Self.expectedDecoder)
    }

    // MARK: - Golden values (captured from the NeedleTail dialect before standard IRC support was added)

    static let expectedParser: [String] = [
        "OK|alice!alice@localhost|-|-|:alice!alice@localhost PRIVMSG #general :Hello, world!|▿ NeedleTailIRC.IRCCommand.privMsg\n  ▿ privMsg: (2 elements)\n    ▿ .0: 1 element\n      ▿ Channel: #general\n        ▿ channel: #general #0\n          - original: \"#general\"\n          - canonical: \"#general\"\n    - .1: \"Hello, world!\"\n",
        "OK|alice|-|time=2023-01-01T12:00:00Z|@time=2023-01-01T12:00:00Z :alice PRIVMSG #general :Hello!|▿ NeedleTailIRC.IRCCommand.privMsg\n  ▿ privMsg: (2 elements)\n    ▿ .0: 1 element\n      ▿ Channel: #general\n        ▿ channel: #general #0\n          - original: \"#general\"\n          - canonical: \"#general\"\n    - .1: \"Hello!\"\n",
        "OK|server|alice|-|:server 001 alice :Welcome to the server!|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.replyWelcome\n    ▿ .1: 1 element\n      - \"Welcome to the server!\"\n",
        "OK|-|-|-|NICK alice_12345678-1234-1234-1234-123456789ABC|▿ NeedleTailIRC.IRCCommand.nick\n  ▿ nick: NeedleTailNick(name: alice, deviceId: 12345678-1234-1234-1234-123456789ABC)\n    - name: \"alice\"\n    ▿ deviceId: Optional(12345678-1234-1234-1234-123456789ABC)\n      - some: 12345678-1234-1234-1234-123456789ABC\n",
        "OK|-|-|-|USER alice localhost localhost :Alice Smith|▿ NeedleTailIRC.IRCCommand.user\n  ▿ user: Username: alice\nReal Name: \'Alice Smith\'\nUser Mode: IRCUserModeFlags(rawValue: 0)\nHostname: localhost\nServer Name: localhost\n    - username: \"alice\"\n    ▿ userModeFlags: Optional(NeedleTailIRC.IRCUserModeFlags(rawValue: 0))\n      ▿ some: NeedleTailIRC.IRCUserModeFlags\n        - rawValue: 0\n    ▿ hostname: Optional(\"localhost\")\n      - some: \"localhost\"\n    ▿ servername: Optional(\"localhost\")\n      - some: \"localhost\"\n    - realname: \"Alice Smith\"\n",
        "OK|-|-|-|JOIN #general,#random key1,key2|▿ NeedleTailIRC.IRCCommand.join\n  ▿ join: (2 elements)\n    ▿ channels: 2 elements\n      ▿ #general #0\n        - original: \"#general\"\n        - canonical: \"#general\"\n      ▿ #random #1\n        - original: \"#random\"\n        - canonical: \"#random\"\n    ▿ keys: Optional([\"key1\", \"key2\"])\n      ▿ some: 2 elements\n        - \"key1\"\n        - \"key2\"\n",
        "OK|-|-|-|JOIN 0|- NeedleTailIRC.IRCCommand.join0\n",
        "OK|-|-|-|PART #general|▿ NeedleTailIRC.IRCCommand.part\n  ▿ part: (1 element)\n    ▿ channels: 1 element\n      ▿ #general #0\n        - original: \"#general\"\n        - canonical: \"#general\"\n",
        "OK|-|-|-|PING  server1 server2|▿ NeedleTailIRC.IRCCommand.ping\n  ▿ ping: (2 elements)\n    - server: \"server1\"\n    ▿ server2: Optional(\"server2\")\n      - some: \"server2\"\n",
        "OK|-|-|-|PONG  server1|▿ NeedleTailIRC.IRCCommand.pong\n  ▿ pong: (2 elements)\n    - server: \"server1\"\n    - server2: nil\n",
        "OK|-|-|-|CAP LS :multi-prefix sasl|▿ NeedleTailIRC.IRCCommand.cap\n  ▿ cap: (2 elements)\n    - .0: NeedleTailIRC.IRCCommand.CAPSubCommand.ls\n    ▿ .1: 2 elements\n      - \"multi-prefix\"\n      - \"sasl\"\n",
        "OK|-|-|-|CAP REQ :sasl|▿ NeedleTailIRC.IRCCommand.cap\n  ▿ cap: (2 elements)\n    - .0: NeedleTailIRC.IRCCommand.CAPSubCommand.req\n    ▿ .1: 1 element\n      - \"sasl\"\n",
        "OK|-|-|-|CAP END :|▿ NeedleTailIRC.IRCCommand.cap\n  ▿ cap: (2 elements)\n    - .0: NeedleTailIRC.IRCCommand.CAPSubCommand.end\n    - .1: 0 elements\n",
        "OK|-|-|-|MODE #chan +o bob|▿ NeedleTailIRC.IRCCommand.channelMode\n  ▿ channelMode: (5 elements)\n    ▿ .0: #chan #0\n      - original: \"#chan\"\n      - canonical: \"#chan\"\n    ▿ addMode: Optional(NeedleTailIRC.IRCChannelPermissions(rawValue: 2))\n      ▿ some: NeedleTailIRC.IRCChannelPermissions\n        - rawValue: 2\n    ▿ addParameters: Optional([\"bob\"])\n      ▿ some: 1 element\n        - \"bob\"\n    ▿ removeMode: Optional(NeedleTailIRC.IRCChannelPermissions(rawValue: 0))\n      ▿ some: NeedleTailIRC.IRCChannelPermissions\n        - rawValue: 0\n    ▿ removeParameters: Optional([])\n      - some: 0 elements\n",
        "OK|-|-|-|MODE alice +i|▿ NeedleTailIRC.IRCCommand.mode\n  ▿ mode: (3 elements)\n    ▿ .0: NeedleTailNick(name: alice, deviceId: nil)\n      - name: \"alice\"\n      - deviceId: nil\n    ▿ add: Optional(NeedleTailIRC.IRCUserModeFlags(rawValue: 1))\n      ▿ some: NeedleTailIRC.IRCUserModeFlags\n        - rawValue: 1\n    ▿ remove: Optional(NeedleTailIRC.IRCUserModeFlags(rawValue: 0))\n      ▿ some: NeedleTailIRC.IRCUserModeFlags\n        - rawValue: 0\n",
        "OK|-|-|-|KICK #chan bob :spam|▿ NeedleTailIRC.IRCCommand.kick\n  ▿ kick: (3 elements)\n    ▿ .0: 1 element\n      ▿ #chan #0\n        - original: \"#chan\"\n        - canonical: \"#chan\"\n    ▿ .1: 1 element\n      ▿ NeedleTailNick(name: bob, deviceId: nil)\n        - name: \"bob\"\n        - deviceId: nil\n    ▿ .2: 1 element\n      - \"spam\"\n",
        "OK|-|-|-|WHOIS bob|▿ NeedleTailIRC.IRCCommand.whois\n  ▿ whois: (2 elements)\n    - server: nil\n    ▿ usermasks: 1 element\n      - \"bob\"\n",
        "OK|-|-|-|WHO #chan o|▿ NeedleTailIRC.IRCCommand.who\n  ▿ who: (2 elements)\n    ▿ usermask: Optional(\"#chan\")\n      - some: \"#chan\"\n    - onlyOperators: true\n",
        "OK|-|-|-|ISON alice bob|▿ NeedleTailIRC.IRCCommand.isOn\n  ▿ isOn: 2 elements\n    ▿ NeedleTailNick(name: alice, deviceId: nil)\n      - name: \"alice\"\n      - deviceId: nil\n    ▿ NeedleTailNick(name: bob, deviceId: nil)\n      - name: \"bob\"\n      - deviceId: nil\n",
        "OK|-|-|-|QUIT :bye|▿ NeedleTailIRC.IRCCommand.quit\n  ▿ quit: Optional(\"bye\")\n    - some: \"bye\"\n",
        "OK|-|-|-|TOPIC #chan :new topic|▿ NeedleTailIRC.IRCCommand.topic\n  ▿ topic: (2 elements)\n    ▿ .0: #chan #0\n      - original: \"#chan\"\n      - canonical: \"#chan\"\n    ▿ .1: Optional(\"new topic\")\n      - some: \"new topic\"\n",
        "OK|-|-|-|INVITE alice #chan|▿ NeedleTailIRC.IRCCommand.invite\n  ▿ invite: (2 elements)\n    ▿ .0: NeedleTailNick(name: alice, deviceId: nil)\n      - name: \"alice\"\n      - deviceId: nil\n    ▿ .1: #chan #0\n      - original: \"#chan\"\n      - canonical: \"#chan\"\n",
        "OK|-|-|-|AWAY :gone|▿ NeedleTailIRC.IRCCommand.away\n  ▿ away: Optional(\"gone\")\n    - some: \"gone\"\n",
        "OK|-|-|-|PASS :secret|▿ NeedleTailIRC.IRCCommand.otherCommand\n  ▿ otherCommand: (2 elements)\n    - .0: \"PASS\"\n    ▿ .1: 1 element\n      - \"secret\"\n",
        "OK|srv|alice|-|:srv 464 alice :Sorry, but your password is incorrect.|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.errorPasswordMismatch\n    ▿ .1: 2 elements\n      - \"Sorry\"\n      - \"but your password is incorrect.\"\n",
        "OK|srv|alice|-|:srv 372 alice :- MOTD line|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.replyMotD\n    ▿ .1: 1 element\n      - \"- MOTD line\"\n",
        "OK|srv|-|-|:srv 465 :marker, 12345678-1234-1234-1234-123456789ABC|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.errorYouReBannedCreep\n    ▿ .1: 2 elements\n      - \"marker\"\n      - \"12345678-1234-1234-1234-123456789ABC\"\n",
        "OK|irc.example.net|alice|-|:irc.example.net 001 alice :Welcome to the Example IRC Network, alice!alice@host|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.replyWelcome\n    ▿ .1: 2 elements\n      - \"Welcome to the Example IRC Network\"\n      - \"alice!alice@host\"\n",
        "OK|irc.example.net|alice|-|:irc.example.net 005 alice :CHANTYPES=#, PREFIX=(ov)@+, :are, supported, by, this, server|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.replyBounce\n    ▿ .1: 7 elements\n      - \"CHANTYPES=#\"\n      - \"PREFIX=(ov)@+\"\n      - \":are\"\n      - \"supported\"\n      - \"by\"\n      - \"this\"\n      - \"server\"\n",
        "OK|irc.example.net|alice|-|:irc.example.net 353 alice :=, #chan, :@op, +voiced, plain|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.replyNameReply\n    ▿ .1: 5 elements\n      - \"=\"\n      - \"#chan\"\n      - \":@op\"\n      - \"+voiced\"\n      - \"plain\"\n",
        "OK|irc.example.net|*|-|:irc.example.net 433 * :alice, :Nickname, is, already, in, use|▿ NeedleTailIRC.IRCCommand.numeric\n  ▿ numeric: (2 elements)\n    - .0: NeedleTailIRC.IRCCommandCode.errorNicknameInUse\n    ▿ .1: 6 elements\n      - \"alice\"\n      - \":Nickname\"\n      - \"is\"\n      - \"already\"\n      - \"in\"\n      - \"use\"\n",
        "OK|-|-|-|PING  :irc.example.net|▿ NeedleTailIRC.IRCCommand.ping\n  ▿ ping: (2 elements)\n    - server: \":irc.example.net\"\n    - server2: nil\n",
        "ERR|invalidNick(\" :alice_\")",
        "ERR|invalidMessageTarget(\"bob_\")",
        "ERR|invalidChannelName(\":#chan\")",
        "ERR|unexpectedArguments(\"Expected between 1 and 2 arguments Found: 3\")",
        "ERR|unexpectedArguments(\"Expected: 3 Found: 2\")",
        "ERR|invalidArgument(\"-o+v\")",
        "OK|-|-|-|USER guest localhost localhost : with colon|▿ NeedleTailIRC.IRCCommand.user\n  ▿ user: Username: guest\nReal Name: \' with colon\'\nUser Mode: IRCUserModeFlags(rawValue: 0)\nHostname: localhost\nServer Name: localhost\n    - username: \"guest\"\n    ▿ userModeFlags: Optional(NeedleTailIRC.IRCUserModeFlags(rawValue: 0))\n      ▿ some: NeedleTailIRC.IRCUserModeFlags\n        - rawValue: 0\n    ▿ hostname: Optional(\"localhost\")\n      - some: \"localhost\"\n    ▿ servername: Optional(\"localhost\")\n      - some: \"localhost\"\n    - realname: \" with colon\"\n",
        "OK|alice!a@h|-|-|:alice!a@h PRIVMSG #chan :two leading spaces|▿ NeedleTailIRC.IRCCommand.privMsg\n  ▿ privMsg: (2 elements)\n    ▿ .0: 1 element\n      ▿ Channel: #chan\n        ▿ channel: #chan #0\n          - original: \"#chan\"\n          - canonical: \"#chan\"\n    - .1: \"two leading spaces\"\n",
        "OK|alice!a@h|-|+draft/reply=abc|@+draft/reply=abc :alice!a@h TAGMSG :#chan|▿ NeedleTailIRC.IRCCommand.otherCommand\n  ▿ otherCommand: (2 elements)\n    - .0: \"TAGMSG\"\n    ▿ .1: 1 element\n      - \"#chan\"\n",
        "OK|-|-|-|ERROR :Closing Link: host (Quit: bye)|▿ NeedleTailIRC.IRCCommand.otherCommand\n  ▿ otherCommand: (2 elements)\n    - .0: \"ERROR\"\n    ▿ .1: 1 element\n      - \"Closing Link: host (Quit: bye)\"\n",
    ]
    static let expectedEncoder: [String] = [
        "OK|PONG  irc.example.net",
        "OK|PING  abc def",
        "OK|USER guest localhost localhost :Real Name",
        "OK|CAP REQ :sasl server-time",
        "OK|CAP END :",
        "OK|PASS :secret",
        "OK|WHOWAS :bob, 5",
        "OK|:srv 464 alice :Sorry, wrong",
        "OK|421 :DCC, DCC is not supported.",
        "OK|MODE #chan +o bob",
        "OK|KICK #chan bob :spam",
        "OK|PRIVMSG #chan,bob :hi there",
        "OK|@time=a\\sb\\:c :alice NOTICE bob :psst",
        "OK|JOIN #chan k",
        "OK|JOIN 0",
        "OK|QUIT :bye now",
        "OK|TOPIC #chan :",
        "OK|LIST *",
        "OK|WHO o",
        "OK|CTCP bob VERSION",
        "OK|DCCCHAT bob 127.0.0.1 6000",
    ]
    static let expectedDecoder: [String] = [
        "<IRCMessage: command=PING \':irc.example.net\'>",
        "<IRCMessage: from=srv to=alice command=<IRCCommand: 1 args=Welcome,alice>>",
        "<IRCMessage: command=CAP>",
    ]
}
