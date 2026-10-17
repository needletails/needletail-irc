//
//  StandardIRCSessionTests.swift
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

private func raw(_ line: String) -> IRCRawMessage {
    try! IRCRawMessage.parse(line)
}

private func lines(_ messages: [IRCRawMessage]) -> [String] {
    messages.map { (try? $0.wireLine()) ?? "<invalid>" }
}

// MARK: - CAP

@Suite struct IRCCapabilityNegotiatorTests {

    @Test func requestsIntersectionAndEnds() {
        var cap = IRCCapabilityNegotiator(requesting: ["server-time", "multi-prefix", "not-offered"])
        #expect(lines(cap.start()) == ["CAP LS 302"])
        #expect(lines(cap.handle(raw(":srv CAP * LS :multi-prefix server-time sasl=PLAIN"))) == ["CAP REQ :multi-prefix server-time"])
        #expect(cap.available["sasl"] == "PLAIN")
        #expect(cap.available["multi-prefix"] == "")
        #expect(lines(cap.handle(raw(":srv CAP * ACK :multi-prefix server-time"))) == ["CAP END"])
        #expect(cap.enabled == ["multi-prefix", "server-time"])
        #expect(cap.isFinished)
    }

    @Test func waitsForMultilineLS() {
        var cap = IRCCapabilityNegotiator(requesting: ["a", "z"])
        _ = cap.start()
        #expect(cap.handle(raw(":srv CAP * LS * :a b c")).isEmpty)
        #expect(lines(cap.handle(raw(":srv CAP * LS :x y z"))) == ["CAP REQ :a z"])
        #expect(Set(cap.available.keys) == ["a", "b", "c", "x", "y", "z"])
    }

    @Test func endsImmediatelyWhenNothingWanted() {
        var cap = IRCCapabilityNegotiator(requesting: ["missing"])
        _ = cap.start()
        #expect(lines(cap.handle(raw(":srv CAP * LS :a b"))) == ["CAP END"])
        #expect(cap.isFinished)
    }

    @Test func nakStillEnds() {
        var cap = IRCCapabilityNegotiator(requesting: ["a"])
        _ = cap.start()
        _ = cap.handle(raw(":srv CAP * LS :a"))
        #expect(lines(cap.handle(raw(":srv CAP * NAK :a"))) == ["CAP END"])
        #expect(cap.enabled.isEmpty)
    }

    @Test func holdsForSASLUntilFinished() {
        var cap = IRCCapabilityNegotiator(requesting: ["sasl"], holdsForSASL: true)
        _ = cap.start()
        _ = cap.handle(raw(":srv CAP * LS :sasl"))
        #expect(cap.handle(raw(":srv CAP * ACK :sasl")).isEmpty)
        #expect(cap.isWaitingForSASL)
        #expect(!cap.isFinished)
        #expect(lines(cap.finish()) == ["CAP END"])
        #expect(cap.isFinished)
        #expect(cap.finish().isEmpty)
    }

    @Test func capNotifyNewAndDel() {
        var cap = IRCCapabilityNegotiator(requesting: ["a", "away-notify"])
        _ = cap.start()
        _ = cap.handle(raw(":srv CAP * LS :a"))
        _ = cap.handle(raw(":srv CAP me ACK :a"))
        #expect(lines(cap.handle(raw(":srv CAP me NEW :away-notify other"))) == ["CAP REQ :away-notify"])
        _ = cap.handle(raw(":srv CAP me ACK :away-notify"))
        #expect(cap.enabled == ["a", "away-notify"])
        #expect(cap.handle(raw(":srv CAP me DEL :a")).isEmpty)
        #expect(cap.enabled == ["away-notify"])
        #expect(cap.available["a"] == nil)
    }

    @Test func splitsLongRequestsUnder510Bytes() {
        let wanted = Set((0..<120).map { "vendor.example/capability-\($0)" })
        var cap = IRCCapabilityNegotiator(requesting: wanted)
        _ = cap.start()
        let requests = cap.handle(raw(":srv CAP * LS :" + wanted.sorted().joined(separator: " ")))
        #expect(requests.count > 1)
        for line in lines(requests) {
            #expect(line.utf8.count <= 510)
            #expect(line.hasPrefix("CAP REQ :"))
        }
        let requested = requests.flatMap { $0.parameters.last!.split(separator: " ").map(String.init) }
        #expect(Set(requested) == wanted)
    }

    @Test func serverWithoutCAPFinishesOnWelcomeOrUnknownCommand() {
        var a = IRCCapabilityNegotiator(requesting: ["x"])
        _ = a.start()
        #expect(a.handle(raw(":srv 001 me :Welcome")).isEmpty)
        #expect(a.isFinished)
        var b = IRCCapabilityNegotiator(requesting: ["x"])
        _ = b.start()
        #expect(b.handle(raw(":srv 421 * CAP :Unknown command")).isEmpty)
        #expect(b.isFinished)
    }

    @Test func listReplyReplacesEnabledSet() {
        var cap = IRCCapabilityNegotiator(requesting: [])
        _ = cap.start()
        _ = cap.handle(raw(":srv CAP * LS :a b"))
        _ = cap.handle(raw(":srv CAP me LIST * :a"))
        _ = cap.handle(raw(":srv CAP me LIST :b"))
        #expect(cap.enabled == ["a", "b"])
    }
}

// MARK: - SASL

@Suite struct IRCSASLTests {

    @Test func plainFlow() {
        var sasl = IRCSASLAuthenticator(credentials: .plain(username: "alice", password: "s3cret"))
        #expect(lines(sasl.start()) == ["AUTHENTICATE PLAIN"])
        let expected = Data("\u{0}alice\u{0}s3cret".utf8).base64EncodedString()
        #expect(lines(sasl.handle(raw("AUTHENTICATE +"))) == ["AUTHENTICATE \(expected)"])
        #expect(sasl.handle(raw(":srv 900 me me!u@h alice :You are now logged in as alice")).isEmpty)
        #expect(sasl.account == "alice")
        _ = sasl.handle(raw(":srv 903 me :SASL authentication successful"))
        #expect(sasl.isFinished && sasl.succeeded)
    }

    @Test func plainWithAuthorizationIdentity() {
        var sasl = IRCSASLAuthenticator(credentials: .plain(username: "alice", password: "pw", authorizationIdentity: "admin"))
        _ = sasl.start()
        let expected = Data("admin\u{0}alice\u{0}pw".utf8).base64EncodedString()
        #expect(lines(sasl.handle(raw("AUTHENTICATE +"))) == ["AUTHENTICATE \(expected)"])
    }

    @Test func externalSendsEmptyResponse() {
        var sasl = IRCSASLAuthenticator(credentials: .external())
        #expect(lines(sasl.start()) == ["AUTHENTICATE EXTERNAL"])
        #expect(lines(sasl.handle(raw("AUTHENTICATE +"))) == ["AUTHENTICATE +"])
    }

    @Test func chunksAt400BytesAndTerminatesExactMultiples() {
        // 300 payload bytes -> exactly 400 base64 characters -> needs a trailing "+".
        let password = String(repeating: "p", count: 300 - "\u{0}u\u{0}".utf8.count)
        var sasl = IRCSASLAuthenticator(credentials: .plain(username: "u", password: password))
        _ = sasl.start()
        let replies = lines(sasl.handle(raw("AUTHENTICATE +")))
        #expect(replies.count == 2)
        #expect(replies[0].count == "AUTHENTICATE ".count + 400)
        #expect(replies[1] == "AUTHENTICATE +")

        let longer = String(repeating: "p", count: 500)
        var second = IRCSASLAuthenticator(credentials: .plain(username: "u", password: longer))
        _ = second.start()
        let chunks = second.handle(raw("AUTHENTICATE +"))
        #expect(chunks.count == 2)
        #expect(chunks.allSatisfy { $0.parameters[0].count <= 400 })
        #expect(chunks.map { $0.parameters[0] }.joined() == Data("\u{0}u\u{0}\(longer)".utf8).base64EncodedString())
    }

    @Test(arguments: [
        ":srv 904 me :SASL authentication failed",
        ":srv 905 me :SASL message too long",
        ":srv 906 me :SASL authentication aborted",
        ":srv 907 me :You have already authenticated",
        ":srv 902 me :You must use a nick assigned to you",
    ])
    func failures(_ line: String) {
        var sasl = IRCSASLAuthenticator(credentials: .plain(username: "a", password: "b"))
        _ = sasl.start()
        _ = sasl.handle(raw(line))
        #expect(sasl.isFinished)
        #expect(!sasl.succeeded)
        #expect(sasl.failureReason == raw(line).parameters.last)
    }

    @Test func recordsAdvertisedMechanisms() {
        var sasl = IRCSASLAuthenticator(credentials: .plain(username: "a", password: "b"))
        _ = sasl.start()
        _ = sasl.handle(raw(":srv 908 me EXTERNAL,SCRAM-SHA-256 :are available SASL mechanisms"))
        #expect(sasl.serverMechanisms == ["EXTERNAL", "SCRAM-SHA-256"])
    }

    @Test func credentialsNeverAppearInDescriptions() {
        let credentials = IRCSASLCredentials.plain(username: "alice", password: "hunter2")
        #expect(!credentials.description.contains("hunter2"))
        #expect(credentials.mechanism == "PLAIN")
        var sasl = IRCSASLAuthenticator(credentials: credentials)
        _ = sasl.start()
        let reply = sasl.handle(raw("AUTHENTICATE +"))
        #expect(!reply.map(\.description).joined().contains(reply[0].parameters[0]))
        let configuration = IRCRegistrationConfiguration(nick: "a", username: "a", realname: "a", password: "serverpw", sasl: credentials)
        #expect(!configuration.description.contains("serverpw"))
        #expect(!configuration.description.contains("hunter2"))
    }
}

// MARK: - Registration

@Suite struct IRCRegistrationTests {

    @Test func startsWithCapThenPassNickUser() {
        var registration = IRCRegistration(configuration: .init(
            nick: "alice", username: "al", realname: "Alice Liddell", password: "pw", capabilities: ["server-time"]
        ))
        #expect(lines(registration.start()) == ["CAP LS 302", "PASS pw", "NICK alice", "USER al 0 * :Alice Liddell"])
    }

    @Test func fullFlowWithSASL() {
        var registration = IRCRegistration(configuration: .init(
            nick: "alice", username: "al", realname: "Alice", capabilities: ["server-time"],
            sasl: .plain(username: "alice", password: "pw")
        ))
        _ = registration.start()
        #expect(lines(registration.handle(raw(":srv CAP * LS :server-time sasl"))) == ["CAP REQ :sasl server-time"])
        #expect(lines(registration.handle(raw(":srv CAP * ACK :sasl server-time"))) == ["AUTHENTICATE PLAIN"])
        #expect(registration.handle(raw("AUTHENTICATE +")).count == 1)
        _ = registration.handle(raw(":srv 900 alice alice!al@h alice :You are now logged in as alice"))
        #expect(lines(registration.handle(raw(":srv 903 alice :SASL authentication successful"))) == ["CAP END"])
        #expect(registration.account == "alice")
        _ = registration.handle(raw(":srv 001 alice :Welcome"))
        _ = registration.handle(raw(":srv 005 alice NICKLEN=16 :are supported"))
        #expect(registration.isRegistered)
        #expect(registration.isupport.nickLength == 16)
        #expect(registration.enabledCapabilities == ["sasl", "server-time"])
        #expect(registration.failure == nil)
    }

    @Test func saslFailureStillEndsNegotiationWhenOptional() {
        var registration = IRCRegistration(configuration: .init(
            nick: "a1", username: "a", realname: "a", capabilities: [], sasl: .plain(username: "a", password: "b")
        ))
        _ = registration.start()
        _ = registration.handle(raw(":srv CAP * LS :sasl"))
        _ = registration.handle(raw(":srv CAP * ACK :sasl"))
        _ = registration.handle(raw("AUTHENTICATE +"))
        #expect(lines(registration.handle(raw(":srv 904 a1 :SASL authentication failed"))) == ["CAP END"])
        #expect(registration.failure == nil)
    }

    @Test func requiredSASLFailureQuits() {
        var registration = IRCRegistration(configuration: .init(
            nick: "a1", username: "a", realname: "a", capabilities: [], sasl: .plain(username: "a", password: "b"), requiresSASL: true
        ))
        _ = registration.start()
        _ = registration.handle(raw(":srv CAP * LS :sasl"))
        _ = registration.handle(raw(":srv CAP * ACK :sasl"))
        _ = registration.handle(raw("AUTHENTICATE +"))
        let out = lines(registration.handle(raw(":srv 904 a1 :SASL authentication failed")))
        #expect(out.first?.hasPrefix("QUIT") == true)
        #expect(registration.failure?.code == .saslFailed)
    }

    @Test func requiredSASLMissingQuits() {
        var registration = IRCRegistration(configuration: .init(
            nick: "a1", username: "a", realname: "a", capabilities: [], sasl: .plain(username: "a", password: "b"), requiresSASL: true
        ))
        _ = registration.start()
        let out = lines(registration.handle(raw(":srv CAP * LS :server-time")))
        #expect(out.contains { $0.hasPrefix("QUIT") })
        #expect(registration.failure?.code == .saslFailed)
    }

    @Test func nickInUseTriesAlternativesThenUnderscores() {
        var registration = IRCRegistration(configuration: .init(
            nick: "alice", username: "al", realname: "A", alternativeNicks: ["alice2"], capabilities: []
        ))
        _ = registration.start()
        #expect(lines(registration.handle(raw(":srv 433 * alice :Nickname is already in use"))) == ["NICK alice2"])
        #expect(lines(registration.handle(raw(":srv 433 * alice2 :Nickname is already in use"))) == ["NICK alice2_"])
        #expect(lines(registration.handle(raw(":srv 432 * alice2_ :Erroneous nickname"))) == ["NICK alice2__"])
        #expect(registration.currentNick == "alice2__")
        _ = registration.handle(raw(":srv 001 alice2__ :Welcome"))
        #expect(registration.isRegistered)
        #expect(registration.handle(raw(":srv 433 alice2__ bob :Nickname is already in use")).isEmpty)
    }

    @Test func givesUpWhenNicknameCannotGrow() {
        var registration = IRCRegistration(configuration: .init(nick: "abcdefghi", username: "a", realname: "a", capabilities: []))
        _ = registration.start()
        _ = registration.handle(raw(":srv 005 * NICKLEN=9 :are supported"))
        _ = registration.handle(raw(":srv 433 * abcdefghi :Nickname is already in use"))
        #expect(registration.failure?.code == .registrationFailed)
    }

    @Test func answersPingAtAnyTime() {
        var registration = IRCRegistration(configuration: .init(nick: "a1", username: "a", realname: "a", capabilities: []))
        _ = registration.start()
        #expect(lines(registration.handle(raw("PING :irc.example.net"))) == ["PONG irc.example.net"])
    }

    @Test func tracksOwnNickChanges() {
        var registration = IRCRegistration(configuration: .init(nick: "Alice", username: "a", realname: "a", capabilities: []))
        _ = registration.start()
        _ = registration.handle(raw(":srv 001 Alice :Welcome"))
        _ = registration.handle(raw(":alice!a@h NICK :Alicia"))
        #expect(registration.currentNick == "Alicia")
        _ = registration.handle(raw(":bob!b@h NICK :robert"))
        #expect(registration.currentNick == "Alicia")
    }

    @Test(arguments: [
        ("ERROR :Closing Link: banned", "Closing Link: banned"),
        (":srv 464 * :Password incorrect", "Password incorrect"),
        (":srv 465 * :You are banned from this server", "You are banned from this server"),
    ])
    func recordsFatalErrors(_ input: (String, String)) {
        var registration = IRCRegistration(configuration: .init(nick: "a1", username: "a", realname: "a", capabilities: []))
        _ = registration.start()
        _ = registration.handle(raw(input.0))
        #expect(registration.failure?.code == .registrationFailed)
        #expect(registration.failure?.detail == input.1)
    }
}

// MARK: - Batches

@Suite struct IRCBatchCollectorTests {

    @Test func collectsMessagesUntilBatchEnds() {
        var collector = IRCBatchCollector()
        #expect(collector.process(raw(":srv BATCH +b1 chathistory #chan")).isEmpty)
        #expect(collector.process(raw("@batch=b1 :a!b@c PRIVMSG #chan :one")).isEmpty)
        #expect(collector.process(raw("@batch=b1 :a!b@c PRIVMSG #chan :two")).isEmpty)
        let passthrough = collector.process(raw(":a!b@c PRIVMSG #chan :live"))
        #expect(passthrough.message?.parameters.last == "live")
        let done = collector.process(raw(":srv BATCH -b1"))
        let batch = done.completedBatch
        #expect(batch?.reference == "b1")
        #expect(batch?.type == "chathistory")
        #expect(batch?.parameters == ["#chan"])
        #expect(batch?.messages.map { $0.parameters.last! } == ["one", "two"])
        #expect(collector.openBatchReferences.isEmpty)
    }

    @Test func nestedBatchesReportTheirParent() {
        var collector = IRCBatchCollector()
        _ = collector.process(raw(":srv BATCH +outer netsplit a.net b.net"))
        _ = collector.process(raw("@batch=outer :srv BATCH +inner chathistory #c"))
        _ = collector.process(raw("@batch=inner :a!b@c PRIVMSG #c :x"))
        let inner = collector.process(raw("@batch=outer :srv BATCH -inner")).completedBatch
        #expect(inner?.parentReference == "outer")
        #expect(inner?.messages.count == 1)
        #expect(collector.openBatchReferences == ["outer"])
        #expect(collector.process(raw(":srv BATCH -outer")).completedBatch?.parentReference == nil)
    }

    @Test func unknownReferencesPassThrough() {
        var collector = IRCBatchCollector()
        #expect(collector.process(raw("@batch=zzz PRIVMSG #c :x")).message != nil)
        #expect(collector.process(raw(":srv BATCH -zzz")).message != nil)
    }
}

// MARK: - Text splitting

@Suite struct IRCStandardTextSplitterTests {

    @Test func shortTextIsOneMessage() throws {
        let messages = IRCStandardTextSplitter.split("hello", target: "#c")
        #expect(lines(messages) == ["PRIVMSG #c :hello"])
    }

    @Test func splitsOnNewlinesAndSkipsBlankLines() {
        #expect(lines(IRCStandardTextSplitter.split("one\r\ntwo\n\nthree\r", command: "NOTICE", target: "bob")) ==
            ["NOTICE bob :one", "NOTICE bob :two", "NOTICE bob :three"])
        #expect(IRCStandardTextSplitter.split("\n\n", target: "#c").isEmpty)
    }

    @Test func keepsEachLineWithinTheLimit() {
        let text = String(repeating: "a", count: 1000)
        let source = "nick!user@some.host.example"
        let messages = IRCStandardTextSplitter.split(text, target: "#chan", source: source, preferWordBoundaries: false)
        #expect(messages.count == 3)
        for message in messages {
            var withSource = message
            withSource.source = source
            #expect(try! withSource.wireLine().utf8.count + 2 <= 512)
        }
        #expect(messages.map { $0.parameters[1] }.joined() == text)
    }

    @Test func reservesRoomForAnUnknownPrefix() {
        let messages = IRCStandardTextSplitter.split(String(repeating: "b", count: 900), target: "#c")
        for line in lines(messages) {
            #expect(line.utf8.count <= 512 - 2 - IRCStandardTextSplitter.defaultPrefixReserve)
        }
    }

    @Test func prefersWordBoundaries() {
        let text = Array(repeating: "word", count: 200).joined(separator: " ")
        let chunks = IRCStandardTextSplitter.split(text, target: "#c").map { $0.parameters[1] }
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { !$0.hasPrefix(" ") && !$0.hasSuffix(" ") })
        #expect(chunks.joined(separator: " ") == text)
    }

    @Test func neverSplitsCharacters() {
        let text = String(repeating: "é👨‍👩‍👧", count: 120)
        let chunks = IRCStandardTextSplitter.split(text, target: "#c", preferWordBoundaries: false).map { $0.parameters[1] }
        #expect(chunks.count > 1)
        #expect(chunks.joined() == text)
        for chunk in chunks {
            #expect(chunk.unicodeScalars.first != "\u{200D}")
        }
    }

    @Test func carriesTags() {
        let messages = IRCStandardTextSplitter.split("hi", target: "#c", tags: [IRCTag(key: "+draft/reply", value: "abc")])
        #expect(lines(messages) == ["@+draft/reply=abc PRIVMSG #c :hi"])
    }
}

// MARK: - Keepalive

@Suite struct IRCStandardKeepAliveTests {

    func makeChannel(_ keepAlive: IRCStandardKeepAliveConfiguration) throws -> EmbeddedChannel {
        let channel = EmbeddedChannel()
        var configuration = IRCStandardConfiguration()
        configuration.keepAlive = keepAlive
        try channel.pipeline.syncOperations.addStandardIRCHandlers(configuration: configuration)
        try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 6667)).wait()
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

    @Test func answersPingAndStillDeliversIt() throws {
        let channel = try makeChannel(.init(respondsToPing: true, idleInterval: nil))
        try feed(channel, "PING :tok\r\n")
        #expect(try outbound(channel) == "PONG tok\r\n")
        #expect(try channel.readInbound(as: IRCFrame.self) != nil)
        _ = try channel.finish()
    }

    @Test func doesNotAnswerWhenDisabled() throws {
        let channel = try makeChannel(.init(respondsToPing: false, idleInterval: nil))
        try feed(channel, "PING :tok\r\n")
        #expect(try outbound(channel).isEmpty)
        _ = try channel.finish()
    }

    @Test func pingsWhenIdleAndAcceptsPong() throws {
        let channel = try makeChannel(.init(respondsToPing: true, idleInterval: .seconds(10), timeout: .seconds(5)))
        channel.embeddedEventLoop.advanceTime(by: .seconds(9))
        #expect(try outbound(channel).isEmpty)
        channel.embeddedEventLoop.advanceTime(by: .seconds(1))
        #expect(try outbound(channel) == "PING \(IRCStandardKeepAliveHandler.pingToken)\r\n")
        try feed(channel, ":srv PONG srv :\(IRCStandardKeepAliveHandler.pingToken)\r\n")
        channel.embeddedEventLoop.advanceTime(by: .seconds(5))
        #expect(channel.isActive)
        _ = try channel.finish()
    }

    @Test func inboundTrafficResetsIdleTimer() throws {
        let channel = try makeChannel(.init(respondsToPing: true, idleInterval: .seconds(10), timeout: .seconds(5)))
        channel.embeddedEventLoop.advanceTime(by: .seconds(8))
        try feed(channel, ":a!b@c PRIVMSG #c :hi\r\n")
        channel.embeddedEventLoop.advanceTime(by: .seconds(8))
        #expect(try outbound(channel).isEmpty)
        _ = try channel.finish()
    }

    @Test func closesWhenServerStopsResponding() throws {
        let channel = try makeChannel(.init(respondsToPing: true, idleInterval: .seconds(10), timeout: .seconds(5)))
        channel.embeddedEventLoop.advanceTime(by: .seconds(10))
        _ = try outbound(channel)
        channel.embeddedEventLoop.advanceTime(by: .seconds(5))
        #expect(!channel.isActive)
        #expect(throws: IRCStandardError(.keepAliveTimeout, "no reply within the keepalive timeout")) {
            try channel.throwIfErrorCaught()
        }
    }

    @Test func configurationDefaults() {
        let configuration = IRCStandardKeepAliveConfiguration()
        #expect(configuration.respondsToPing)
        #expect(configuration.idleInterval == .seconds(90))
        #expect(configuration.timeout == .seconds(60))
        #expect(IRCStandardConfiguration().keepAlive == nil)
    }
}
