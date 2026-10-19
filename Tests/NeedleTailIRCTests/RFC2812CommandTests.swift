//
//  RFC2812CommandTests.swift
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
import Testing
@testable import NeedleTailIRC

/// The RFC 2812 commands that had no typed case: each is written as the RFC's own examples show,
/// and each line parses back to the same command.
@Suite struct RFC2812CommandTests {
    func wire(_ command: IRCCommand) throws -> String { try IRCMessage(command: command).wireLine() }
    func roundTrip(_ line: String) throws -> String { try NeedleTailIRCParser.parseMessage(line).wireLine() }
    func nick(_ name: String) -> NeedleTailNick { NeedleTailNick(wireValue: name)! }

    @Test func pass() throws {                                     // §3.1.1 PASS <password>
        #expect(try wire(.pass("connectionvalue")) == "PASS connectionvalue")
        #expect(try wire(.pass("two words")) == "PASS :two words")
        guard case .pass(let password) = try NeedleTailIRCParser.parseMessage("PASS :connectionvalue").command else { Issue.record("not .pass"); return }
        #expect(password == "connectionvalue")
        // NeedleTail's legacy form, a bare PASS with its value in packet-metadata, still parses.
        guard case .otherCommand("PASS", let arguments) = try NeedleTailIRCParser.parseMessage("PASS").command else { Issue.record("legacy PASS"); return }
        #expect(arguments.isEmpty)
    }

    @Test func service() throws {                                  // §3.1.6
        let line = "SERVICE dict * *.fr 0 0 :French Dictionary"
        #expect(try wire(.service(nickname: "dict", distribution: "*.fr", type: "0", info: "French Dictionary")) == line)
        #expect(try roundTrip(line) == line)
    }

    @Test func servlist() throws {                                 // §3.5.1 SERVLIST [ <mask> [ <type> ] ]
        #expect(try wire(.servlist(mask: nil, type: nil)) == "SERVLIST")
        #expect(try wire(.servlist(mask: "*.fr", type: "0")) == "SERVLIST *.fr 0")
        #expect(try wire(.servlist(mask: nil, type: "0")) == "SERVLIST * 0")
        for line in ["SERVLIST", "SERVLIST *.fr", "SERVLIST *.fr 0"] { #expect(try roundTrip(line) == line) }
    }

    @Test func squery() throws {                                   // §3.5.2
        let line = "SQUERY irchelp :HELP privmsg"
        #expect(try wire(.squery(serviceName: "irchelp", text: "HELP privmsg")) == line)
        #expect(try roundTrip(line) == line)
    }

    @Test func whowas() throws {                                   // §3.6.3
        #expect(try wire(.whowas([nick("Wiz")], count: nil, target: nil)) == "WHOWAS Wiz")
        #expect(try wire(.whowas([nick("Mermaid"), nick("Wiz")], count: 9, target: nil)) == "WHOWAS Mermaid,Wiz 9")
        #expect(try wire(.whowas([nick("Trillian")], count: 1, target: "*.edu")) == "WHOWAS Trillian 1 *.edu")
        for line in ["WHOWAS Wiz", "WHOWAS Mermaid,Wiz 9", "WHOWAS Trillian 1 *.edu"] { #expect(try roundTrip(line) == line) }
        // A target needs a count in front of it.
        #expect(throws: IRCMessageGeneratorError.invalidParameter) { try wire(.whowas([nick("Wiz")], count: nil, target: "*.edu")) }
        #expect(throws: IRCMessageGeneratorError.invalidParameter) { try wire(.whowas([], count: nil, target: nil)) }
    }

    @Test func error() throws {                                    // §3.7.4
        let line = "ERROR :Server *.fi already exists"
        #expect(try wire(.error("Server *.fi already exists")) == line)
        guard case .error(let text) = try NeedleTailIRCParser.parseMessage(line).command else { Issue.record("not .error"); return }
        #expect(text == "Server *.fi already exists")
    }

    @Test func summon() throws {                                   // §4.5 SUMMON <user> [ <target> [ <channel> ] ]
        #expect(try wire(.summon(user: "jto", target: nil, channel: nil)) == "SUMMON jto")
        #expect(try wire(.summon(user: "jto", target: "tolsun.oulu.fi", channel: nil)) == "SUMMON jto tolsun.oulu.fi")
        #expect(try wire(.summon(user: "jto", target: "tolsun.oulu.fi", channel: NeedleTailChannel("#finnish")!)) == "SUMMON jto tolsun.oulu.fi #finnish")
        for line in ["SUMMON jto", "SUMMON jto tolsun.oulu.fi", "SUMMON jto tolsun.oulu.fi #finnish"] { #expect(try roundTrip(line) == line) }
        #expect(throws: IRCMessageGeneratorError.invalidParameter) { try wire(.summon(user: "jto", target: nil, channel: NeedleTailChannel("#finnish")!)) }
    }

    @Test func userhost() throws {                                 // §4.8, up to five nicknames
        let line = "USERHOST Wiz Michael syrk"
        #expect(try wire(.userhost([nick("Wiz"), nick("Michael"), nick("syrk")])) == line)
        #expect(try roundTrip(line) == line)
        guard case .userhost(let nicks) = try NeedleTailIRCParser.parseMessage("USERHOST :Wiz Michael").command else { Issue.record("trailing form"); return }
        #expect(nicks.map(\.stringValue) == ["Wiz", "Michael"])
        #expect(throws: IRCMessageGeneratorError.invalidParameter) { try wire(.userhost((1...6).map { nick("n\($0)x") })) }
        #expect(throws: IRCMessageGeneratorError.invalidParameter) { try wire(.userhost([])) }
    }

    @Test func everyRFC2812CommandHasATypedCase() throws {
        let rfc2812 = ["PASS", "NICK", "USER", "OPER", "MODE", "SERVICE", "QUIT", "SQUIT", "JOIN", "PART", "TOPIC",
                       "NAMES", "LIST", "INVITE", "KICK", "PRIVMSG", "NOTICE", "MOTD", "LUSERS", "VERSION", "STATS",
                       "LINKS", "TIME", "CONNECT", "TRACE", "ADMIN", "INFO", "SERVLIST", "SQUERY", "WHO", "WHOIS",
                       "WHOWAS", "KILL", "PING", "PONG", "ERROR", "AWAY", "REHASH", "DIE", "RESTART", "SUMMON",
                       "USERS", "WALLOPS", "USERHOST", "ISON"]
        #expect(rfc2812.count == 45)
        let samples: [IRCCommand] = [
            .pass("x"), .nick(nick("a")), .user(IRCUserDetails(username: "u", userModeFlags: [], realname: "r")), .oper("u", "p"),
            .mode(nick("a"), add: [.invisible], remove: nil), .service(nickname: "s", distribution: "*", type: "0", info: "i"),
            .quit(nil), .sQuit("s", "r"), .join(channels: [NeedleTailChannel("#c")!], keys: nil), .part(channels: [NeedleTailChannel("#c")!]),
            .topic(NeedleTailChannel("#c")!, nil), .names(nil), .list(channels: nil, target: nil), .invite(nick("a"), NeedleTailChannel("#c")!),
            .kick([NeedleTailChannel("#c")!], [nick("a")], []), .privMsg([.nick(nick("a"))], "t"), .notice([.nick(nick("a"))], "t"),
            .motd(nil), .lusers(nil, nil), .version(nil), .stats(nil, nil), .links(nil), .time(nil), .connect("s", 6667, nil),
            .trace(nil), .admin(nil), .info(nil), .servlist(mask: nil, type: nil), .squery(serviceName: "s", text: "t"),
            .who(usermask: nil, onlyOperators: false), .whois(server: nil, usermasks: ["a"]), .whowas([nick("a")], count: nil, target: nil),
            .kill(nick("a"), "r"), .ping(server: "s", server2: nil), .pong(server: "s", server2: nil), .error("e"), .away(nil),
            .rehash, .die, .restart, .summon(user: "u", target: nil, channel: nil), .users(nil), .wallops("w"),
            .userhost([nick("a")]), .isOn([nick("a")]),
        ]
        #expect(Set(samples.map(\.commandAsString)) == Set(rfc2812))
        for command in samples {
            let line = try wire(command)
            let parsed = try NeedleTailIRCParser.parseMessage(line).command
            if case .otherCommand(let name, _) = parsed { Issue.record("\(name) parsed as .otherCommand from \(line)") }
        }
    }
}
