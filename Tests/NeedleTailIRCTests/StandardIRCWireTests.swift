//
//  StandardIRCWireTests.swift
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

import NIOCore
import NIOEmbedded
import Testing
import NeedleTailIRC

@Suite struct StandardIRCRawMessageParsingTests {

    @Test func parsesCommandOnly() throws {
        let raw = try IRCRawMessage.parse("CAP END")
        #expect(raw.tags.isEmpty)
        #expect(raw.source == nil)
        #expect(raw.command == "CAP")
        #expect(raw.parameters == ["END"])
    }

    @Test func parsesSourceMiddlesAndTrailing() throws {
        let raw = try IRCRawMessage.parse(":irc.example.net 433 * alice :Nickname is already in use")
        #expect(raw.source == "irc.example.net")
        #expect(raw.command == "433")
        #expect(raw.numeric == 433)
        #expect(raw.parameters == ["*", "alice", "Nickname is already in use"])
    }

    @Test func trailingIsOneParameterEvenWithCommasAndColons() throws {
        let raw = try IRCRawMessage.parse(":srv 001 alice :Welcome to the Network, alice!a@h :)")
        #expect(raw.parameters == ["alice", "Welcome to the Network, alice!a@h :)"])
    }

    @Test func trailingWhitespaceIsPreservedVerbatim() throws {
        let raw = try IRCRawMessage.parse(":a!a@h PRIVMSG #chan :  indented  ")
        #expect(raw.parameters == ["#chan", "  indented  "])
    }

    @Test func emptyTrailingIsAnEmptyParameter() throws {
        let raw = try IRCRawMessage.parse("TOPIC #chan :")
        #expect(raw.parameters == ["#chan", ""])
    }

    @Test func colonInsideMiddleParameterIsNotTrailing() throws {
        let raw = try IRCRawMessage.parse("PRIVMSG a:b c")
        #expect(raw.parameters == ["a:b", "c"])
    }

    @Test func toleratesRepeatedSpacesBetweenMiddles() throws {
        let raw = try IRCRawMessage.parse(":srv  PONG   srv   :tok en")
        #expect(raw.source == "srv")
        #expect(raw.command == "PONG")
        #expect(raw.parameters == ["srv", "tok en"])
    }

    @Test func commandIsUppercased() throws {
        #expect(try IRCRawMessage.parse("privmsg #c :x").command == "PRIVMSG")
    }

    @Test func stripsLineTerminatorIfPresent() throws {
        #expect(try IRCRawMessage.parse("PING :abc\r\n").parameters == ["abc"])
    }

    @Test func parsesNamesReply() throws {
        let raw = try IRCRawMessage.parse(":srv 353 alice = #chan :@op +v plain")
        #expect(raw.parameters == ["alice", "=", "#chan", "@op +v plain"])
    }

    @Test func parsesCapabilityListWithContinuation() throws {
        let raw = try IRCRawMessage.parse(":srv CAP * LS * :multi-prefix sasl=PLAIN,EXTERNAL")
        #expect(raw.parameters == ["*", "LS", "*", "multi-prefix sasl=PLAIN,EXTERNAL"])
    }

    @Test func parsesTagsWithEscapesAndValuelessKeys() throws {
        let raw = try IRCRawMessage.parse(#"@time=2023-01-01T12:00:00.000Z;+draft/reply=abc;flag;note=a\sb\:c\\d :n!u@h TAGMSG #chan"#)
        #expect(raw.tags.map(\.key) == ["time", "+draft/reply", "flag", "note"])
        #expect(raw.tags.map(\.value) == ["2023-01-01T12:00:00.000Z", "abc", "", "a b;c\\d"])
        #expect(raw.command == "TAGMSG")
        #expect(raw.parameters == ["#chan"])
    }

    @Test func toleratesTrailingSemicolonInTags() throws {
        #expect(try IRCRawMessage.parse("@a=1; PING x").tags.map(\.key) == ["a"])
    }

    @Test func enforcesTagLimits() {
        let limits = IRCParserLimits(maxTagSectionBytes: 16, maxTagCount: 2, maxTagKeyBytes: 8, maxTagValueBytes: 8)
        #expect(throws: IRCStandardError.self) { try IRCRawMessage.parse("@a=1;b=2;c=3 PING x", limits: limits) }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage.parse("@abcdefghij=1 PING x", limits: limits) }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage.parse("@a=123456789 PING x", limits: limits) }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage.parse("@a=1234;b=12345678 PING x", limits: limits) }
    }

    @Test(arguments: [
        "",
        "   ",
        ":onlysource",
        ":src ",
        "@tags-only",
        "@a=1 :src",
        ": PING x",
        "12 x",
        "PRIV-MSG x",
        "PING x\u{0}y",
        "PING x\ry",
    ])
    func rejectsMalformedLines(_ line: String) {
        #expect(throws: IRCStandardError.self) { try IRCRawMessage.parse(line) }
    }

    @Test func acceptsMoreThanFifteenParametersInboundButNotOutbound() throws {
        let line = "X " + (1...16).map(String.init).joined(separator: " ")
        let raw = try IRCRawMessage.parse(line)
        #expect(raw.parameters.count == 16)
        #expect(throws: IRCStandardError(.tooManyParameters, "16 parameters")) { try raw.wireLine() }
    }

    @Test func numericIsNilForWordCommands() throws {
        #expect(try IRCRawMessage.parse("PING x").numeric == nil)
        #expect(try IRCRawMessage.parse(":s 005 a :x").numeric == 5)
    }
}

@Suite struct StandardIRCRawMessageSerializationTests {

    @Test func usesTrailingOnlyWhenNeeded() throws {
        #expect(try IRCRawMessage(command: "PONG", parameters: ["irc.example.net"]).wireLine() == "PONG irc.example.net")
        #expect(try IRCRawMessage(command: "WHOWAS", parameters: ["bob", "5"]).wireLine() == "WHOWAS bob 5")
        #expect(try IRCRawMessage(command: "PRIVMSG", parameters: ["#c", "hi there"]).wireLine() == "PRIVMSG #c :hi there")
        #expect(try IRCRawMessage(command: "PRIVMSG", parameters: ["#c", ":)"]).wireLine() == "PRIVMSG #c ::)")
        #expect(try IRCRawMessage(command: "TOPIC", parameters: ["#c", ""]).wireLine() == "TOPIC #c :")
        #expect(try IRCRawMessage(command: "CAP", parameters: ["END"]).wireLine() == "CAP END")
    }

    @Test func forcedTrailingIsRecordedByParserAndIgnoredByEquality() throws {
        let parsed = try IRCRawMessage.parse("PRIVMSG #c :hi")
        #expect(parsed.forcesTrailingParameter)
        #expect(try parsed.wireLine() == "PRIVMSG #c :hi")
        let minimal = IRCRawMessage(command: "PRIVMSG", parameters: ["#c", "hi"])
        #expect(!minimal.forcesTrailingParameter)
        #expect(try minimal.wireLine() == "PRIVMSG #c hi")
        #expect(parsed == minimal)
        #expect(!(try IRCRawMessage.parse("PING x")).forcesTrailingParameter)
        let forced = IRCRawMessage(command: "PART", parameters: ["#c", "bye"], forcesTrailingParameter: true)
        #expect(try forced.wireLine() == "PART #c :bye")
        #expect(try IRCRawMessage(command: "QUIT", forcesTrailingParameter: true).wireLine() == "QUIT")
    }

    @Test func writesTagsAndSource() throws {
        let raw = IRCRawMessage(
            tags: [IRCTag(key: "+typing", value: "active"), IRCTag(key: "flag", value: ""), IRCTag(key: "note", value: "a b;c\\")],
            source: "n!u@h",
            command: "TAGMSG",
            parameters: ["#chan"]
        )
        #expect(try raw.wireLine() == #"@+typing=active;flag;note=a\sb\:c\\ :n!u@h TAGMSG #chan"#)
    }

    @Test func rejectsLineBreaksAndNulInAnyField() {
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "PRIVMSG", parameters: ["#c", "a\r\nQUIT"]).wireLine() }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "PRIVMSG", parameters: ["#c", "a\u{0}"]).wireLine() }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(source: "a b", command: "PING", parameters: ["x"]).wireLine() }
    }

    @Test func rejectsInvalidMiddleParameters() {
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "PRIVMSG", parameters: ["#a b", "x"]).wireLine() }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "PRIVMSG", parameters: ["", "x"]).wireLine() }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "PRIVMSG", parameters: [":x", "x"]).wireLine() }
    }

    @Test func rejectsInvalidCommandsAndTooManyParameters() {
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "", parameters: []).wireLine() }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "PRIV MSG", parameters: []).wireLine() }
        #expect(throws: IRCStandardError.self) { try IRCRawMessage(command: "12", parameters: []).wireLine() }
        #expect(throws: IRCStandardError.self) {
            try IRCRawMessage(command: "X", parameters: (0..<16).map(String.init)).wireLine()
        }
        #expect(throws: IRCStandardError.self) {
            try IRCRawMessage(tags: [IRCTag(key: "bad key", value: "")], command: "PING", parameters: ["x"]).wireLine()
        }
    }

    @Test(arguments: [
        ":irc.example.net 433 * alice :Nickname is already in use",
        "@time=2023-01-01T12:00:00.000Z;account=alice :alice!a@h PRIVMSG #chan :hello :) world",
        "CAP REQ :sasl server-time",
        ":srv CAP * LS * :multi-prefix sasl",
        "PRIVMSG #c ::)",
        "TOPIC #c :",
        ":n!u@h JOIN #chan account :Real Name",
        "PING abc",
    ])
    func roundTrips(_ line: String) throws {
        let raw = try IRCRawMessage.parse(line)
        #expect(try raw.wireLine() == line)
        #expect(try IRCRawMessage.parse(raw.wireLine()) == raw)
    }

    @Test func encodesIntoBufferWithCRLF() throws {
        var buffer = ByteBuffer()
        try IRCRawMessage(command: "PING", parameters: ["x"]).encode(into: &buffer)
        #expect(buffer.readString(length: buffer.readableBytes) == "PING x\r\n")
    }

    @Test func descriptionRedactsCredentials() {
        let auth = IRCRawMessage(command: "AUTHENTICATE", parameters: ["c2VjcmV0"])
        let pass = IRCRawMessage(command: "PASS", parameters: ["hunter2"])
        let oper = IRCRawMessage(command: "OPER", parameters: ["admin", "hunter2"])
        #expect(!auth.description.contains("c2VjcmV0"))
        #expect(!pass.description.contains("hunter2"))
        #expect(!oper.description.contains("hunter2"))
        #expect(IRCRawMessage(command: "PING", parameters: ["visible"]).description.contains("visible"))
    }

    @Test func equalityComparesTagValues() {
        let a = IRCRawMessage(tags: [IRCTag(key: "k", value: "1")], command: "PING", parameters: ["x"])
        let b = IRCRawMessage(tags: [IRCTag(key: "k", value: "2")], command: "PING", parameters: ["x"])
        #expect(a != b)
        #expect(a == IRCRawMessage(tags: [IRCTag(key: "k", value: "1")], command: "PING", parameters: ["x"]))
    }
}

@Suite struct StandardIRCSourceTests {

    @Test func parsesFullUserMask() {
        let source = IRCSource("alice_!~al@host.example")
        #expect(source?.nick == "alice_")
        #expect(source?.user == "~al")
        #expect(source?.host == "host.example")
        #expect(source?.isServer == false)
        #expect(source?.stringValue == "alice_!~al@host.example")
    }

    @Test func parsesServerName() {
        let source = IRCSource("irc.example.net")
        #expect(source?.nick == "irc.example.net")
        #expect(source?.user == nil)
        #expect(source?.host == nil)
        #expect(source?.isServer == true)
    }

    @Test func parsesNickAtHost() {
        let source = IRCSource("Bob@host")
        #expect(source?.nick == "Bob")
        #expect(source?.user == nil)
        #expect(source?.host == "host")
    }

    @Test func keepsCaseAndSingleCharacterNicks() {
        #expect(IRCSource("A!u@h")?.nick == "A")
    }

    @Test(arguments: ["", "!u@h", "@h", "n!@h", "n!u@"])
    func rejectsEmptyComponents(_ value: String) {
        #expect(IRCSource(value) == nil)
    }

    @Test func rawMessageExposesParsedSource() throws {
        #expect(try IRCRawMessage.parse(":n!u@h PING x").sourceComponents?.host == "h")
        #expect(try IRCRawMessage.parse("PING x").sourceComponents == nil)
    }
}

@Suite struct StandardIRCLineCodecTests {

    func decode(_ input: String, maxLineLength: Int = IRCStandardLineDecoder.defaultMaxLineLength, onUnparsable: (@Sendable (String, any Error) -> Void)? = nil) throws -> [IRCRawMessage] {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(
            IRCStandardLineDecoder(maxLineLength: maxLineLength, unparsableLineHandler: onUnparsable)
        ))
        var buffer = channel.allocator.buffer(capacity: input.utf8.count)
        buffer.writeString(input)
        try channel.writeInbound(buffer)
        var messages: [IRCRawMessage] = []
        while let message = try channel.readInbound(as: IRCRawMessage.self) {
            messages.append(message)
        }
        _ = try channel.finish()
        return messages
    }

    @Test func framesCRLFAndBareLFAndSkipsBlankLines() throws {
        let messages = try decode("PING :a\r\n\r\n   \r\n:s 001 me :hi, there\nCAP END\r\n")
        #expect(messages.map(\.command) == ["PING", "001", "CAP"])
        #expect(messages[1].parameters == ["me", "hi, there"])
    }

    @Test func waitsForTerminator() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCStandardLineDecoder()))
        var first = channel.allocator.buffer(capacity: 8)
        first.writeString("PING :ab")
        try channel.writeInbound(first)
        #expect(try channel.readInbound(as: IRCRawMessage.self) == nil)
        var second = channel.allocator.buffer(capacity: 8)
        second.writeString("c\r\n")
        try channel.writeInbound(second)
        #expect(try channel.readInbound(as: IRCRawMessage.self)?.parameters == ["abc"])
        _ = try channel.finish()
    }

    @Test func reportsAndSkipsUnparsableLinesWithoutStalling() throws {
        final class Box: @unchecked Sendable { var lines: [String] = [] }
        let box = Box()
        let messages = try decode(": bad\r\nPING :ok\r\n") { line, _ in box.lines.append(line) }
        #expect(messages.map(\.command) == ["PING"])
        #expect(box.lines == [": bad"])
    }

    @Test func replacesInvalidUTF8InsteadOfDropping() throws {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCStandardLineDecoder()))
        var buffer = channel.allocator.buffer(capacity: 32)
        buffer.writeString("PRIVMSG #c :caf")
        buffer.writeBytes([0xE9])
        buffer.writeString("\r\n")
        try channel.writeInbound(buffer)
        let message = try #require(try channel.readInbound(as: IRCRawMessage.self))
        #expect(message.parameters.last == "caf\u{FFFD}")
        _ = try channel.finish()
    }

    @Test func rejectsOverlongLines() {
        #expect(throws: IRCStandardError.self) { _ = try decode(String(repeating: "A", count: 64), maxLineLength: 32) }
        #expect(throws: IRCStandardError.self) { _ = try decode("PRIVMSG #c :" + String(repeating: "A", count: 64) + "\r\n", maxLineLength: 32) }
    }

    @Test func defaultMaxLineLengthCoversIRCv3Tags() {
        #expect(IRCStandardLineDecoder.defaultMaxLineLength == 8191 + 512)
    }

    @Test func rawMessageEncoderWritesLines() throws {
        let channel = EmbeddedChannel(handler: MessageToByteHandler(IRCRawMessageEncoder()))
        try channel.writeOutbound(IRCRawMessage(command: "PRIVMSG", parameters: ["#c", "hi there"]))
        var out = try #require(try channel.readOutbound(as: ByteBuffer.self))
        #expect(out.readString(length: out.readableBytes) == "PRIVMSG #c :hi there\r\n")
        _ = try channel.finish()
    }
}
