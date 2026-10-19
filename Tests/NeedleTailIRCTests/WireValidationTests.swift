//
//  WireValidationTests.swift
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
import NeedleTailLogger
import Testing
@testable import NeedleTailIRC

/// `wireLine()` never returns a line that breaks RFC 2812 §2.3.1 or IRCv3 message-tags.
@Suite struct WireValidationTests {
    static let alice = NeedleTailNick(name: "alice", deviceId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)!
    static let chan = NeedleTailChannel("#travel")!

    func rejects(_ error: IRCMessageGeneratorError, _ message: IRCMessage, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: error, sourceLocation: sourceLocation) { try message.validateWireLine() }
        #expect(throws: error, sourceLocation: sourceLocation) { try message.wireLine() }
    }

    // command = 1*letter / 3digit
    @Test func commandMustBeLettersOrThreeDigits() {
        rejects(.invalidCommand, IRCMessage(command: .otherCommand("MY_CMD", [])))
        rejects(.invalidCommand, IRCMessage(command: .otherCommand("", ["x"])))
        rejects(.invalidCommand, IRCMessage(command: .otherCommand("CMD2", [])))
        rejects(.invalidCommand, IRCMessage(command: .otherNumeric(1000, ["x"])))
        #expect(throws: Never.self) { try IRCMessage(command: .otherCommand("WHOWAS", ["bob"])).validateWireLine() }
        #expect(throws: Never.self) { try IRCMessage(command: .otherNumeric(5, ["x"])).validateWireLine() }
    }

    // prefix = servername / ( nickname [ [ "!" user ] "@" host ] ), no SPACE
    @Test func originMustNotContainSpace() {
        rejects(.invalidOrigin, IRCMessage(origin: "ali ce", command: .quit(nil)))
        #expect(throws: Never.self) { try IRCMessage(origin: "alice!a@host", command: .quit(nil)).validateWireLine() }
    }

    // IRCv3: key = [ '+' ] [ vendor '/' ] 1*( ALPHA / DIGIT / '-' )
    @Test func tagKeysFollowIRCv3Grammar() {
        for key in ["", "bad key", "a=b", "a;b", "+", "vendor/", "/name", "under_score", "a\u{1}"] {
            rejects(.invalidTagKey, IRCMessage(command: .quit(nil), tags: [IRCTag(key: key, value: "v")]))
        }
        for key in ["time", "packet-metadata", "privateMessage", "+typing", "example.com/foo-bar", "+draft.example/x1"] {
            #expect(throws: Never.self) { try IRCMessage(command: .quit(nil), tags: [IRCTag(key: key, value: "v")]).validateWireLine() }
        }
    }

    // middle = nospcrlfcl *( ":" / nospcrlfcl ): not empty, no SPACE, no leading ':'
    @Test func middleParametersMustBeSingleWords() {
        rejects(.invalidParameter, IRCMessage(command: .join(channels: [Self.chan], keys: ["a b"])))
        rejects(.invalidParameter, IRCMessage(command: .join(channels: [Self.chan], keys: [""])))
        rejects(.invalidParameter, IRCMessage(command: .oper("ad min", "pw")))
        rejects(.invalidParameter, IRCMessage(command: .otherCommand("FOO", ["a b", "c"])))
        rejects(.invalidParameter, IRCMessage(command: .otherCommand("FOO", [":a", "c"])))
        rejects(.invalidParameter, IRCMessage(command: .ping(server: "", server2: "b")))
        rejects(.invalidParameter, IRCMessage(origin: "srv", target: "ali ce", command: .numeric(.replyWelcome, ["Welcome"])))
        rejects(.invalidParameter, IRCMessage(origin: "srv", target: "alice", command: .numeric(.errorNicknameInUse, ["b ob", "In use"])))
        rejects(.invalidParameter, IRCMessage(command: .user(IRCUserDetails(username: "a b", hostname: "h", servername: "s", realname: "R"))))
        rejects(.invalidParameter, IRCMessage(command: .channelMode(Self.chan, addMode: [.channelOperator], addParameters: [""], removeMode: nil, removeParameters: nil)))
        rejects(.invalidParameter, IRCMessage(command: .dccSend(Self.alice, "my file.txt", 1, "10.0.0.3", 6100)))
        // The last parameter may be trailing, so spaces there are fine.
        #expect(throws: Never.self) { try IRCMessage(command: .otherCommand("FOO", ["a", "b c"])).validateWireLine() }
        #expect(throws: Never.self) { try IRCMessage(command: .ping(server: "a b", server2: nil)).validateWireLine() }
    }

    // params = *14( SPACE middle ) [ SPACE ":" trailing ]
    @Test func atMostFifteenParameters() {
        let fifteen = (1...15).map(String.init)
        #expect(throws: Never.self) { try IRCMessage(command: .otherCommand("FOO", fifteen)).validateWireLine() }
        rejects(.tooManyParameters, IRCMessage(command: .otherCommand("FOO", fifteen + ["16"])))
        rejects(.tooManyParameters, IRCMessage(origin: "srv", target: "alice", command: .numeric(.replyBounce, fifteen)))
    }

    // NUL, CR and LF may not appear anywhere in a message.
    @Test func controlCharactersAreStripped() throws {
        let bob = NeedleTailNick(name: "bob", deviceId: nil)!
        #expect(try IRCMessage(command: .privMsg([.nick(bob)], "a\u{0}b\r\nc")).wireLine() == "PRIVMSG bob :abc")
        #expect(try IRCMessage(command: .quit(nil), tags: [IRCTag(key: "k", value: "x\u{0}y")]).wireLine() == "@k=xy QUIT")
    }

    // Everything NeedleTail sends today still passes.
    @Test func needleTailTrafficStillValidates() throws {
        let base64 = Data("payload".utf8).base64EncodedString()
        let messages: [IRCMessage] = [
            IRCMessage(origin: Self.alice.stringValue, command: .otherCommand(Constants.pass.rawValue, ["value"]),
                       tags: [IRCTag(key: "pass-tag", value: base64), IRCTag(key: "transport-role", value: "irc")]),
            IRCMessage(origin: Self.alice.stringValue, command: .nick(Self.alice), tags: [IRCTag(key: "temporary-registration", value: "false")]),
            IRCMessage(origin: Self.alice.stringValue, command: .user(IRCUserDetails(username: "alice", hostname: "10.0.0.2", servername: "10.0.0.2", realname: "Real name"))),
            IRCMessage(origin: Self.alice.stringValue, command: .join(channels: [Self.chan], keys: nil), tags: [IRCTag(key: "channel-packet", value: base64)]),
            IRCMessage(origin: Self.alice.stringValue, command: .otherCommand("BADGEUPDATE", ["3"])),
            IRCMessage(origin: Self.alice.stringValue, command: .otherCommand("OFFLINEMESSAGES", [])),
            IRCMessage(origin: Self.alice.stringValue, command: .otherCommand("REQUESTMEDIADELETION", ["contact", "shared-1", "photo.jpg", "video.mp4"])),
            IRCMessage(origin: "nudge.server", command: .numeric(.errorYouReBannedCreep, ["DEVICE_REVOKED", UUID().uuidString])),
            IRCMessage(origin: "nudge.server", command: .numeric(.replyBounce, ["CHANTYPES=#", "CHANLIMIT=#:120", "are supported by this server"])),
            IRCMessage(origin: "nudge.server", command: .server("nudge.server", "1.0.0", 1, base64)),
            IRCMessage(origin: base64, command: .privMsg([.channel(Self.chan)], ""), tags: [IRCTag(key: "privateMessage", value: "")]),
            IRCMessage(origin: Self.alice.stringValue, command: .sdccChat(Self.alice, "10.0.0.3", 6100), tags: [IRCTag(key: "dcc-state", value: "offer")]),
        ]
        for message in messages {
            #expect(throws: Never.self) { try message.validateWireLine() }
        }
    }

    // Base64 (A-Z a-z 0-9 + / =) has no space, ';', ':', CR, LF or NUL, so it passes validation
    // and survives every position unchanged, padding included.
    @Test func base64RoundTripsAsTextArgumentsAndTags() async throws {
        let b64 = (Data([0xFB, 0xFF, 0xBF, 0x00]) + Data((0..<1_500).map { UInt8($0 % 256) })).base64EncodedString()
        #expect(b64.hasPrefix("+/+/") && b64.hasSuffix("="))
        let bob = NeedleTailNick(name: "bob", deviceId: nil)!
        let tag = IRCTag(key: "packet-metadata", value: b64)
        func roundTrip(_ message: IRCMessage) throws -> IRCMessage { try NeedleTailIRCParser.parseMessage(message.wireLine()) }

        let privMsg = try roundTrip(IRCMessage(origin: b64, command: .privMsg([.nick(bob)], b64), tags: [tag]))
        #expect(privMsg.origin == b64)
        #expect(privMsg.tags?.first?.value == b64)
        guard case .privMsg(_, let text) = privMsg.command else { Issue.record("\(privMsg.command)"); return }
        #expect(text == b64)

        #expect(try roundTrip(IRCMessage(command: .otherCommand("PUBLISHBLOB", [b64]))).command.arguments == [b64])
        #expect(try roundTrip(IRCMessage(command: .otherCommand("PUBLISHBLOB", [b64, b64, "last one"]))).command.arguments == [b64, b64, "last one"])
        #expect(try roundTrip(IRCMessage(command: .numeric(.errorYouReBannedCreep, [b64]))).command.arguments == [b64])
        let numeric = try roundTrip(IRCMessage(origin: "srv", target: "alice", command: .numeric(.replyBounce, [b64, "are supported"])))
        #expect(numeric.command.arguments == [b64, "are supported"])
        guard case .server(_, _, _, let info) = try roundTrip(IRCMessage(command: .server("srv", "1.0", 1, b64))).command else { Issue.record("server"); return }
        #expect(info == b64)

        // Through the generator: chunked into packet-metadata, then reassembled.
        let executor = TestableExecutor(queue: .init(label: "base64"))
        let sender = IRCMessageGenerator(executor: executor)
        let receiver = IRCMessageGenerator(executor: executor)
        var rebuilt: IRCMessage?
        var frames = 0
        for try await frame in await sender.createMessages(origin: "alice", command: .otherCommand("PUBLISHBLOB", [b64]), tags: [IRCTag(key: "pass-tag", value: b64)], logger: NeedleTailLogger()) {
            frames += 1
            if let done = try await receiver.messageReassembler(ircMessage: NeedleTailIRCParser.parseMessage(frame.wireLine())) { rebuilt = done }
        }
        #expect(frames > 1)
        #expect(rebuilt?.command.arguments == [b64])
        #expect(rebuilt?.tags?.first(where: { $0.key == "pass-tag" })?.value == b64)
    }

    // A rejected message never reaches the NIO pipeline, so the connection stays usable.
    @Test func sendAndFlushRejectsBeforeWriting() async throws {
        let delegate = ValidationWriterDelegate()
        let (writer, sink) = NIOAsyncChannelOutboundWriter<IRCFrame>.makeTestingWriter()
        await #expect(throws: IRCMessageGeneratorError.invalidCommand) {
            try await delegate.sendAndFlushMessage(writer: writer, message: IRCFrame.text(IRCMessage(command: .otherCommand("MY_CMD", []))))
        }
        try await delegate.sendAndFlushMessage(writer: writer, message: IRCFrame.text(IRCMessage(command: .otherCommand("OK", []))))
        writer.finish()
        var written: [String] = []
        for await frame in sink {
            if case .text(let message) = frame { written.append(try message.wireLine()) }
        }
        #expect(written == ["OK"])
    }
}

private final class ValidationWriterDelegate: NeedleTailWriterDelegate, @unchecked Sendable {}
