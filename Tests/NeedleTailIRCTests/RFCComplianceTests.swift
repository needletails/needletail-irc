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
    @Test func c15_isonAsTrailingList() throws {               // ISON <nickname> *( SPACE <nickname> )
        let m = try p("ISON :alice bob")
        guard case .isOn(let nicks) = m.command else { Issue.record("\(m.command)"); return }
        #expect(nicks.map(\.stringValue) == ["alice", "bob"])
    }
    @Test func c16_bareList() throws {                        // LIST [ <channel> *( "," <channel> ) [ <target> ] ]
        let m = try p("LIST")
        guard case .list(let channels, let target) = m.command else { Issue.record("\(m.command)"); return }
        #expect(channels == nil && target == nil)
    }
    @Test func c17_userModeIsRFCBitmask() throws {            // RFC 2812 §3.1.3: bit 2 = w, bit 3 = i
        func flags(_ mode: String) throws -> IRCUserModeFlags? {
            guard case .user(let d) = try p("USER guest \(mode) * :Real").command else { return nil }
            return d.userModeFlags
        }
        #expect(try flags("0") == [])
        #expect(try flags("8") == [.invisible])
        #expect(try flags("4") == [.wallOps])
        #expect(try flags("12") == [.invisible, .wallOps])
    }

    @Test func c18_nickCaseIsKept() throws {                   // RFC 2812 §2.2: compare without case, keep it
        for line in [":NeedleBot!bot@host PRIVMSG Bob :hi", ":NeedleBot!bot@host NICK Robo[t]", "ISON Alice Bob"] {
            #expect(try p(line).wireLine() == line)
        }
        #expect(NeedleTailNick(wireValue: "Bob") == NeedleTailNick(wireValue: "bob"))
        #expect(NeedleTailNick(wireValue: "Robo[t]") == NeedleTailNick(wireValue: "robo{t}"))
        #expect(NeedleTailNick(wireValue: "Bob") != NeedleTailNick(wireValue: "Rob"))
        // A NeedleTail `name_UUID` nick is an account identity and stays lowercased.
        #expect(NeedleTailNick(wireValue: "Alice_12345678-1234-1234-1234-123456789ABC")?.name == "alice")
    }
    @Test func c19_partMessageIsKept() throws {                // PART <channel> *( "," <channel> ) [ <Part Message> ]
        let line = ":alice!a@h PART #room,#ops :see you later"
        let m = try p(line)
        guard case .partMessage(let channels, let message) = m.command else { Issue.record("\(m.command)"); return }
        #expect(channels.map(\.stringValue) == ["#room", "#ops"])
        #expect(message == "see you later")
        #expect(try m.wireLine() == line)
        guard case .part(let bare) = try p("PART #room").command else { Issue.record("bare part"); return }
        #expect(bare.map(\.stringValue) == ["#room"])
    }
    @Test func c20_capRepliesKeepTheirTarget() throws {        // IRCv3: CAP <nick|*> <sub> [*] :<caps>
        for line in [":srv CAP * LS * :multi-prefix sasl", ":srv CAP alice NEW :batch", ":srv CAP alice DEL :sasl away-notify", ":srv CAP * LS :sasl"] {
            #expect(try p(line).wireLine() == line)
        }
    }

    @Test func c21_maskAndAddressTargets() throws {            // RFC 2812 §3.3.1 msgto
        let targets = ["$*.example.net", "bob!bob@example.com", "bob%example.com@irc.example.net", "bob%example.com", "bob@irc.example.net"]
        for target in targets {
            let line = ":oper!o@host NOTICE \(target) :Server restarting"
            let m = try p(line)
            guard case .notice(let recipients, _) = m.command else { Issue.record("\(m.command)"); continue }
            #expect(recipients == [.mask(target)])
            #expect(try m.wireLine() == line)
        }
        guard case .privMsg(let mixed, _) = try p("PRIVMSG #room,bob,$*.fi :hi").command else { Issue.record("mixed"); return }
        #expect(mixed.map(\.stringValue) == ["#room", "bob", "$*.fi"])
        for notAnAddress in ["@#room", "$", "bob!", "bob!@host", "bob!user@", "%host", "user@"] {
            #expect(IRCMessageRecipient(notAnAddress) == nil, "\(notAnAddress)")
        }
        #expect(throws: (any Error).self) { try p("MODE $*.fi +i") }
    }

    // MARK: Outbound
    @Test func o12_maskTargetsAreSingleWords() throws {
        for bad in ["", "a b", "a,b", ":a"] {
            #expect(throws: IRCMessageGeneratorError.invalidParameter) { try wire(.privMsg([.mask(bad)], "x")) }
        }
        #expect(try wire(.notice([.mask("$*.example.net")], "Maintenance")) == "NOTICE $*.example.net :Maintenance")
    }
    @Test func o11_lastParameterMayHoldSpaces() throws {      // the last param can always be trailing
        #expect(try wire(.oper("boss", "correct horse")) == "OPER boss :correct horse")
        #expect(try wire(.oper("boss", "pw")) == "OPER boss pw")
        guard case .oper(_, let password) = try p("OPER boss :correct horse").command else { Issue.record("oper"); return }
        #expect(password == "correct horse")
        #expect(throws: IRCMessageGeneratorError.emptyCommandRejected) { try wire(.partMessage(channels: [], message: "bye")) }
    }
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
    @Test func o06_isonPastFourteenNicksFoldsIntoTrailing() throws {   // at most 15 params
        let nicks = (0..<20).map { NeedleTailNick(name: "n\($0)x", deviceId: nil)! }
        let w = try wire(.isOn(nicks))
        #expect(try NeedleTailIRCParser.tokenize(w).parameters.count == 15)
        guard case .isOn(let back) = try p(w).command else { Issue.record("\(w)"); return }
        #expect(back.map(\.stringValue) == nicks.map(\.stringValue))
        #expect(try wire(.isOn(Array(nicks.prefix(15)))) == "ISON " + nicks.prefix(15).map(\.stringValue).joined(separator: " "))
    }
    @Test func o07_listWithoutChannelsHasNoParameters() throws {
        #expect(try wire(.list(channels: nil, target: nil)) == "LIST")
        #expect(try wire(.list(channels: [], target: nil)) == "LIST")
    }
    @Test func o08_userModeChangeIsOneModeString() throws {   // MODE <nick> *( ( "+" / "-" ) *<modes> )
        let nick = NeedleTailNick(name: "alice", deviceId: nil)!
        #expect(try wire(.mode(nick, add: [.invisible, .wallOps], remove: [.operatorMode])) == "MODE alice +iw-o")
        #expect(try wire(.mode(nick, add: [.invisible], remove: nil)) == "MODE alice +i")
        #expect(try wire(.mode(nick, add: nil, remove: [.wallOps])) == "MODE alice -w")
        guard case .mode(_, let add, let remove) = try p("MODE alice +iw-o").command else { Issue.record("mode"); return }
        #expect(add == [.invisible, .wallOps] && remove == [.operatorMode])
    }
    @Test func o09_trailingKeepsItsSpaces() throws {          // trailing is taken verbatim
        let bob = NeedleTailNick(name: "bob", deviceId: nil)!
        #expect(try wire(.privMsg([.nick(bob)], "hello ")) == "PRIVMSG bob :hello ")
        #expect(try wire(.quit("Bye  ")) == "QUIT :Bye  ")
        #expect(try wire(.topic(NeedleTailChannel("#travel")!, " ")) == "TOPIC #travel : ")
    }
    @Test func o10_userWithModesWritesRFCBitmask() throws {   // USER <user> <mode> <unused> :<realname>
        let w = try wire(.user(IRCUserDetails(username: "guest", userModeFlags: [.invisible], realname: "Real Name")))
        #expect(w == "USER guest 8 * :Real Name")
        guard case .user(let d) = try p(w).command else { Issue.record("\(w)"); return }
        #expect(d.userModeFlags == [.invisible])
        // The hostname form NeedleTail sends is unchanged.
        #expect(try wire(.user(IRCUserDetails(username: "alice", hostname: "10.0.0.2", servername: "srv", realname: "Real"))) == "USER alice 10.0.0.2 srv :Real")
    }
}
