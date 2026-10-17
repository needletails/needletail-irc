//
//  StandardIRCServerSupportTests.swift
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
import NeedleTailIRC

@Suite struct IRCCaseMappingTests {

    @Test func asciiFoldsOnlyASCIILetters() {
        #expect(IRCCaseMapping.ascii.fold("NiCK[A]\\~Ä") == "nick[a]\\~Ä")
    }

    @Test func rfc1459FoldsBracketsBackslashAndTilde() {
        #expect(IRCCaseMapping.rfc1459.fold("Nick[A]\\~") == "nick{a}|^")
    }

    @Test func strictDoesNotFoldTilde() {
        #expect(IRCCaseMapping.rfc1459Strict.fold("[A]\\~") == "{a}|~")
    }

    @Test func unknownMappingsFallBackToUnicodeLowercasing() {
        #expect(IRCCaseMapping(rawValue: "rfc7613").fold("ÄB") == "äb")
    }

    @Test func comparesUsingTheMapping() {
        #expect(IRCCaseMapping.rfc1459.equals("Bob[1]", "bob{1}"))
        #expect(!IRCCaseMapping.ascii.equals("Bob[1]", "bob{1}"))
        #expect(IRCCaseMapping.ascii.equals("BOB", "bob"))
    }

    @Test func rawValues() {
        #expect(IRCCaseMapping.ascii.rawValue == "ascii")
        #expect(IRCCaseMapping.rfc1459.rawValue == "rfc1459")
        #expect(IRCCaseMapping.rfc1459Strict.rawValue == "rfc1459-strict")
    }
}

@Suite struct IRCISupportTests {

    func isupport(_ lines: String...) throws -> IRCISupport {
        var support = IRCISupport()
        for line in lines { support.apply(try IRCRawMessage.parse(line)) }
        return support
    }

    @Test func defaultsFollowRFC() {
        let support = IRCISupport()
        #expect(support.caseMapping == .rfc1459)
        #expect(support.channelTypes == ["#", "&"])
        #expect(support.membershipPrefixes == [IRCMembershipPrefix(mode: "o", symbol: "@"), IRCMembershipPrefix(mode: "v", symbol: "+")])
        #expect(support.channelModes.list == ["b", "e", "I"])
        #expect(support.channelModes.alwaysParameter == ["k"])
        #expect(support.channelModes.parameterWhenSet == ["l"])
        #expect(support.channelModes.noParameter == ["i", "m", "n", "p", "s", "t"])
        #expect(support.nickLength == nil)
        #expect(support.network == nil)
    }

    @Test func readsTokensFrom005() throws {
        let support = try isupport(
            ":srv 005 me CHANTYPES=#& PREFIX=(qaohv)~&@%+ CHANMODES=beIq,k,flj,Cimnpstz CASEMAPPING=ascii NICKLEN=30 CHANNELLEN=64 TOPICLEN=390 NETWORK=My\\x20Net EXCEPTS :are supported by this server"
        )
        #expect(support.channelTypes == ["#", "&"])
        #expect(support.membershipPrefixes.map(\.mode) == ["q", "a", "o", "h", "v"])
        #expect(support.membershipPrefixes.map(\.symbol) == ["~", "&", "@", "%", "+"])
        #expect(support.channelModes.list == ["b", "e", "I", "q"])
        #expect(support.channelModes.parameterWhenSet == ["f", "l", "j"])
        #expect(support.caseMapping == .ascii)
        #expect(support.nickLength == 30)
        #expect(support.channelLength == 64)
        #expect(support.topicLength == 390)
        #expect(support.network == "My Net")
        #expect(support.contains("EXCEPTS"))
        #expect(support.value(for: "EXCEPTS") == "")
        #expect(!support.contains("are supported by this server"))
    }

    @Test func laterTokensOverrideAndNegationRemoves() throws {
        let support = try isupport(
            ":srv 005 me NICKLEN=30 TARGMAX=PRIVMSG:4,NOTICE:4,JOIN: :are supported",
            ":srv 005 me NICKLEN=31 :are supported",
            ":srv 005 me -TARGMAX :are supported"
        )
        #expect(support.nickLength == 31)
        #expect(support.maxTargets(for: "PRIVMSG") == nil)
        #expect(!support.contains("TARGMAX"))
    }

    @Test func targetLimits() throws {
        let support = try isupport(":srv 005 me TARGMAX=PRIVMSG:4,NOTICE:3,JOIN: :are supported")
        #expect(support.maxTargets(for: "privmsg") == 4)
        #expect(support.maxTargets(for: "NOTICE") == 3)
        #expect(support.maxTargets(for: "JOIN") == nil)
        #expect(support.maxTargets(for: "KICK") == nil)
    }

    @Test func ignoresOtherMessages() throws {
        let support = try isupport(":srv 001 me :Welcome NICKLEN=5", "PRIVMSG #c :NICKLEN=5")
        #expect(support.nickLength == nil)
    }

    @Test func invalidPrefixKeepsDefault() throws {
        let support = try isupport(":srv 005 me PREFIX=(ov)@ :are supported")
        #expect(support.membershipPrefixes.map(\.mode) == ["o", "v"])
    }

    @Test func emptyPrefixMeansNoMembershipModes() throws {
        let support = try isupport(":srv 005 me PREFIX= :are supported")
        #expect(support.membershipPrefixes.isEmpty)
    }

    @Test func splitsMultiPrefixNames() throws {
        let support = try isupport(":srv 005 me PREFIX=(qaohv)~&@%+ :are supported")
        let split = support.splitMembershipPrefixes("~@bob_")
        #expect(split.prefixes.map(\.mode) == ["q", "o"])
        #expect(split.nick == "bob_")
        #expect(support.splitMembershipPrefixes("plain").prefixes.isEmpty)
    }

    @Test func recognisesChannelNames() throws {
        let support = try isupport(":srv 005 me CHANTYPES=# :are supported")
        #expect(support.isChannelName("#chan"))
        #expect(!support.isChannelName("&chan"))
        #expect(!support.isChannelName("bob"))
        #expect(!support.isChannelName(""))
    }

    @Test func foldsWithAdvertisedCaseMapping() throws {
        let support = try isupport(":srv 005 me CASEMAPPING=rfc1459 :are supported")
        #expect(support.caseMapping.equals("Nick[]", "nick{}"))
    }
}

@Suite struct IRCModeParserTests {

    @Test func usesRFCDefaults() {
        let changes = IRCModeParser.channelModeChanges("+ov-b+l", parameters: ["bob", "carol", "*!*@bad", "10"])
        #expect(changes == [
            IRCModeChange(isAdding: true, mode: "o", parameter: "bob"),
            IRCModeChange(isAdding: true, mode: "v", parameter: "carol"),
            IRCModeChange(isAdding: false, mode: "b", parameter: "*!*@bad"),
            IRCModeChange(isAdding: true, mode: "l", parameter: "10"),
        ])
    }

    @Test func parameterWhenSetIsNotConsumedOnRemoval() {
        let changes = IRCModeParser.channelModeChanges("-l+k", parameters: ["key"])
        #expect(changes == [
            IRCModeChange(isAdding: false, mode: "l", parameter: nil),
            IRCModeChange(isAdding: true, mode: "k", parameter: "key"),
        ])
    }

    @Test func listModeWithoutParameterIsAQuery() {
        #expect(IRCModeParser.channelModeChanges("+b", parameters: []) == [IRCModeChange(isAdding: true, mode: "b", parameter: nil)])
    }

    @Test func usesAdvertisedModes() throws {
        var support = IRCISupport()
        support.apply(try IRCRawMessage.parse(":srv 005 me PREFIX=(qaohv)~&@%+ CHANMODES=beI,k,flj,CimnpstzQ :are supported"))
        let changes = IRCModeParser.channelModeChanges("+qhf-Q", parameters: ["alice", "bob", "[5:5]"], isupport: support)
        #expect(changes == [
            IRCModeChange(isAdding: true, mode: "q", parameter: "alice"),
            IRCModeChange(isAdding: true, mode: "h", parameter: "bob"),
            IRCModeChange(isAdding: true, mode: "f", parameter: "[5:5]"),
            IRCModeChange(isAdding: false, mode: "Q", parameter: nil),
        ])
    }

    @Test func modesBeforeAnySignAreTreatedAsAdding() {
        #expect(IRCModeParser.channelModeChanges("nt", parameters: []).map(\.isAdding) == [true, true])
    }

    @Test func userModes() {
        #expect(IRCModeParser.userModeChanges("+iw-x") == [
            IRCModeChange(isAdding: true, mode: "i", parameter: nil),
            IRCModeChange(isAdding: true, mode: "w", parameter: nil),
            IRCModeChange(isAdding: false, mode: "x", parameter: nil),
        ])
    }

    @Test func fromModeMessage() throws {
        let result = IRCModeParser.channelModeChanges(from: try IRCRawMessage.parse(":op!u@h MODE #chan +o-v bob carol"))
        #expect(result?.channel == "#chan")
        #expect(result?.changes.count == 2)
        #expect(result?.changes.last == IRCModeChange(isAdding: false, mode: "v", parameter: "carol"))
    }

    @Test func fromChannelModeIsReply() throws {
        let result = IRCModeParser.channelModeChanges(from: try IRCRawMessage.parse(":srv 324 me #chan +ntk secret"))
        #expect(result?.channel == "#chan")
        #expect(result?.changes.last == IRCModeChange(isAdding: true, mode: "k", parameter: "secret"))
    }

    @Test func userModeMessageIsNotAChannelChange() throws {
        #expect(IRCModeParser.channelModeChanges(from: try IRCRawMessage.parse(":me MODE me :+i")) == nil)
        #expect(IRCModeParser.channelModeChanges(from: try IRCRawMessage.parse("PRIVMSG #chan :+o bob")) == nil)
    }
}

@Suite struct IRCv3TagAccessTests {

    let raw = try! IRCRawMessage.parse(
        "@time=2023-01-01T12:00:00.123Z;msgid=abc;account=alice;label=L1;batch=B1;+typing=active;+draft/reply=xyz;msgid=def :a!b@c PRIVMSG #c :x"
    )

    @Test func readsWellKnownTags() throws {
        let expected = try #require(ISO8601DateFormatter.fractional.date(from: "2023-01-01T12:00:00.123Z"))
        #expect(raw.serverTime == expected)
        #expect(raw.messageID == "def")
        #expect(raw.account == "alice")
        #expect(raw.label == "L1")
        #expect(raw.batchReference == "B1")
        #expect(raw.clientOnlyTags.map(\.key) == ["+typing", "+draft/reply"])
        #expect(raw.tagValue("+typing") == "active")
        #expect(raw.tagValue("missing") == nil)
    }

    @Test func serverTimeWithoutFraction() throws {
        let message = try IRCRawMessage.parse("@time=2023-01-01T12:00:00Z PING x")
        #expect(message.serverTime == ISO8601DateFormatter().date(from: "2023-01-01T12:00:00Z"))
        #expect(try IRCRawMessage.parse("@time=yesterday PING x").serverTime == nil)
    }

    @Test func sameAccessorsOnIRCMessage() {
        let message = IRCMessage(standardIRC: raw)
        #expect(message.messageID == "def")
        #expect(message.account == "alice")
        #expect(message.serverTime == raw.serverTime)
        #expect(message.clientOnlyTags.count == 2)
        #expect(IRCMessage(command: .quit(nil)).serverTime == nil)
    }

    @Test func buildsTags() throws {
        let date = try #require(ISO8601DateFormatter.fractional.date(from: "2023-01-01T12:00:00.123Z"))
        #expect(IRCTag.serverTime(date).key == "time")
        #expect(IRCTag.serverTime(date).value == "2023-01-01T12:00:00.123Z")
        #expect(IRCTag.label("L2").key == "label")
        #expect(IRCTag.label("L2").value == "L2")
    }
}

extension ISO8601DateFormatter {
    static var fractional: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

@Suite struct IRCCTCPTests {

    @Test func parsesCTCP() {
        #expect(IRCCTCPMessage(text: "\u{1}ACTION waves hello\u{1}") == IRCCTCPMessage(command: "ACTION", argument: "waves hello"))
        #expect(IRCCTCPMessage(text: "\u{1}VERSION\u{1}") == IRCCTCPMessage(command: "VERSION", argument: nil))
        #expect(IRCCTCPMessage(text: "\u{1}ping 123") == IRCCTCPMessage(command: "PING", argument: "123"))
        #expect(IRCCTCPMessage(text: "hello") == nil)
        #expect(IRCCTCPMessage(text: "\u{1}\u{1}") == nil)
        #expect(IRCCTCPMessage(text: "\u{1} x\u{1}") == nil)
    }

    @Test func buildsText() {
        #expect(IRCCTCPMessage.action("waves").text == "\u{1}ACTION waves\u{1}")
        #expect(IRCCTCPMessage(command: "version", argument: nil).text == "\u{1}VERSION\u{1}")
    }

    @Test func readsFromRawMessages() throws {
        let privmsg = try IRCRawMessage.parse(":a!b@c PRIVMSG #chan :\u{1}ACTION waves\u{1}")
        #expect(privmsg.ctcp == .action("waves"))
        #expect(!privmsg.isCTCPReply)
        let notice = try IRCRawMessage.parse(":a!b@c NOTICE me :\u{1}VERSION NeedleTail\u{1}")
        #expect(notice.ctcp?.argument == "NeedleTail")
        #expect(notice.isCTCPReply)
        #expect(try IRCRawMessage.parse("PRIVMSG #c :plain").ctcp == nil)
    }

    @Test func writesRawMessages() throws {
        #expect(try IRCRawMessage.ctcp(.action("waves"), to: "#chan").wireLine() == "PRIVMSG #chan :\u{1}ACTION waves\u{1}")
        #expect(try IRCRawMessage.ctcpReply(IRCCTCPMessage(command: "VERSION", argument: "x 1"), to: "bob").wireLine() == "NOTICE bob :\u{1}VERSION x 1\u{1}")
    }
}
