//
//  RFCComplianceTests.swift
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
import NeedleTailLogger
import Testing
@testable import NeedleTailIRC

/// Lines as standard servers send them. Each test states what RFC 2812 (or IRCv3 CAP) requires.
@Suite struct RFCComplianceTests {
    func p(_ s: String) throws -> IRCMessage { try NeedleTailIRCParser.parseMessage(s) }
    func wire(_ c: IRCCommand) throws -> String { try IRCMessage(command: c).wireLine() }

    // MARK: NeedleTail forms that must keep working
    @Test func control_privmsgChannel() throws {
        let m = try p(":alice!a@h PRIVMSG #general :Hello, world!")
        guard case .privMsg(_, let text) = m.command else { Issue.record("not privMsg"); return }
        #expect(text == "Hello, world!")
    }
    @Test func control_motdTrailingOnly() throws {
        #expect(try p(":srv 372 alice :- MOTD line").command.arguments == ["- MOTD line"])
    }
    @Test func control_targetlessNumericKeepsCommaArguments() throws {
        let m = try p(":srv 465 :DEVICE_REVOKED, 12345678-1234-1234-1234-123456789ABC")
        #expect(m.target == nil)
        #expect(m.command.arguments == ["DEVICE_REVOKED", "12345678-1234-1234-1234-123456789ABC"])
    }
    @Test func control_nickWithDevice() throws {
        let m = try p("NICK alice_12345678-1234-1234-1234-123456789ABC")
        guard case .nick(let n) = m.command else { Issue.record("not nick"); return }
        #expect(n.name == "alice" && n.deviceId != nil)
    }

    // MARK: Inbound — RFC 2812 §2.3.1: params = *14( SPACE middle ) [ SPACE ":" trailing ]
    @Test func c01_capReplyHasTargetParam() throws {          // IRCv3: CAP <nick|*> <sub> :<caps>
        let m = try p(":irc.example.net CAP * LS :multi-prefix sasl")
        guard case .cap(.ls, let caps) = m.command else { Issue.record("\(m.command)"); return }
        #expect(caps == ["multi-prefix", "sasl"])
    }
    @Test func c02_numericMiddleThenTrailing() throws {       // 433 <target> <nick> :<text>
        let m = try p(":irc.example.net 433 * alice :Nickname is already in use")
        #expect(m.command.arguments == ["alice", "Nickname is already in use"])
    }
    @Test func c03_numericTrailingWithComma() throws {        // trailing is ONE param
        let m = try p(":irc.example.net 001 alice :Welcome to the Network, alice")
        #expect(m.command.arguments == ["Welcome to the Network, alice"])
    }
    @Test func c04_namesReply() throws {                      // 353 <target> <sym> <chan> :<names>
        let m = try p(":irc.example.net 353 alice = #chan :@op +v plain")
        #expect(m.command.arguments == ["=", "#chan", "@op +v plain"])
    }
    @Test func c05_nickContainingUnderscore() throws {        // RFC 2812 special = "[]\`_^{|}"
        _ = try p(":alice!a@h PRIVMSG bob_ :hi")
    }
    @Test func c06_singleCharNick() throws {                  // nickname = ( letter / special ) *8(...)
        _ = try p(":x!a@h PRIVMSG a :hi")
    }
    @Test func c07_nickAsTrailing() throws {                  // trailing form is a valid encoding of a param
        let m = try p(":alice!a@h NICK :alice2")
        guard case .nick(let n) = m.command else { Issue.record("\(m.command)"); return }
        #expect(n.name == "alice2")
    }
    @Test func c08_joinAsTrailing() throws {
        _ = try p(":alice!a@h JOIN :#chan")
    }
    @Test func c09_pingTrailingToken() throws {
        let m = try p("PING :irc.example.net")
        guard case .ping(let server, _) = m.command else { Issue.record("\(m.command)"); return }
        #expect(server == "irc.example.net")
    }
    @Test func c10_kickWithoutComment() throws {              // KICK <chan> <user> [<comment>]
        _ = try p(":op!a@h KICK #chan bob")
    }
    @Test func c11_modeMixedSigns() throws {                  // MODE <chan> *( ( "-" / "+" ) *<modes> *<modeparams> )
        _ = try p(":op!a@h MODE #chan -o+v bob carol")
    }
    @Test func c12_modeTwoParams() throws {
        let m = try p(":op!a@h MODE #chan +ov bob carol")
        guard case .channelMode(_, _, let addParams, _, _) = m.command else { Issue.record("\(m.command)"); return }
        #expect(addParams == ["bob", "carol"])
    }
    @Test func c13_trailingWhitespacePreserved() throws {
        let m = try p(":alice!a@h PRIVMSG #chan :  indented")
        guard case .privMsg(_, let text) = m.command else { Issue.record("\(m.command)"); return }
        #expect(text == "  indented")
    }
    @Test func c14_userRealnameWithColon() throws {           // USER <user> <mode> <unused> :<realname>
        let m = try p("USER guest 0 * :Real Name: x")
        guard case .user(let d) = m.command else { Issue.record("\(m.command)"); return }
        #expect(d.realname == "Real Name: x")
    }

    // MARK: Outbound
    @Test func o01_pongSingleSpace() throws {                 // SPACE = %x20 (one)
        #expect(try wire(.pong(server: "irc.example.net", server2: nil)) == "PONG irc.example.net")
    }
    @Test func o02_otherCommandMultiParam() throws {
        let w = try wire(.otherCommand("WHOWAS", ["bob", "5"]))
        #expect(w == "WHOWAS bob 5" || w == "WHOWAS bob :5")
    }
    @Test func o03_numericWithTargetIsWrittenAsRFCParameters() throws {
        let deviceId = "12345678-1234-1234-1234-123456789ABC"
        let w = try IRCMessage(origin: "srv", target: "alice", command: .numeric(.errorYouReBannedCreep, ["DEVICE_REVOKED", deviceId])).wireLine()
        #expect(w == ":srv 465 alice DEVICE_REVOKED \(deviceId)")
        let back = try p(w)
        #expect(back.target == "alice")
        #expect(back.command.arguments == ["DEVICE_REVOKED", deviceId])
    }
    @Test func o04_numericWithoutTargetKeepsNeedleTailForm() throws {
        #expect(try wire(.numeric(.errorUnknownCommand, ["DCC", "DCC is not supported."])) == "421 :DCC, DCC is not supported.")
    }
    @Test func o05_createMessagesCarriesTarget() async throws {
        let generator = IRCMessageGenerator(executor: TestableExecutor(queue: .init(label: "rfc-compliance")))
        let stream = await generator.createMessages(
            origin: "srv",
            target: "alice",
            command: .numeric(.errorNicknameInUse, ["bob", "Nickname is already in use"]),
            logger: NeedleTailLogger()
        )
        var lines: [String] = []
        for try await message in stream { lines.append(try message.wireLine()) }
        #expect(lines.count == 1)
        #expect(lines.first?.hasSuffix(":srv 433 alice bob :Nickname is already in use") == true)
    }
}
