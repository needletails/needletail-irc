//
//  StandardIRCCorpusTests.swift
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

/// Whole-session transcripts pushed through every layer of the standard IRC support.
///
/// These are hand-written in the style of each server family (numerics, token sets, tag usage
/// and quirks such as `JOIN :#chan`), not packet captures. Replace or extend them with real
/// captures when available.
struct ServerTranscript: CustomTestStringConvertible, Sendable {
    let name: String
    let lines: [String]
    let sasl: Bool
    let expectedNetwork: String
    let expectedNickLength: Int
    let expectedCaseMapping: IRCCaseMapping
    var testDescription: String { name }
}

@Suite struct StandardIRCCorpusTests {

    static let transcripts: [ServerTranscript] = [
        ServerTranscript(name: "Solanum (Libera.Chat style)", lines: [
            ":tungsten.libera.chat NOTICE * :*** Checking Ident",
            ":tungsten.libera.chat NOTICE * :*** Looking up your hostname...",
            ":tungsten.libera.chat CAP * LS * :account-notify away-notify chghost extended-join multi-prefix sasl=PLAIN,ECDSA-NIST256P-CHALLENGE,EXTERNAL tls account-tag cap-notify echo-message server-time solanum.chat/identify-msg",
            ":tungsten.libera.chat CAP * LS :solanum.chat/oper solanum.chat/realhost batch labeled-response message-tags invite-notify setname userhost-in-names",
            ":tungsten.libera.chat CAP * ACK :account-tag away-notify batch cap-notify message-tags multi-prefix sasl server-time",
            "AUTHENTICATE +",
            ":tungsten.libera.chat 900 alice alice!~alice@host.example alice :You are now logged in as alice",
            ":tungsten.libera.chat 903 alice :SASL authentication successful",
            ":tungsten.libera.chat 001 alice :Welcome to the Libera.Chat Internet Relay Chat Network alice",
            ":tungsten.libera.chat 002 alice :Your host is tungsten.libera.chat[1.2.3.4/6697], running version solanum-1.0-dev",
            ":tungsten.libera.chat 003 alice :This server was created Sat Jan 1 2024 at 00:00:00 UTC",
            ":tungsten.libera.chat 004 alice tungsten.libera.chat solanum-1.0-dev DGIMQRSZaghilopsuwz CFILMPQRSTbcefgijklmnopqrstuvz bkloveqjfI",
            ":tungsten.libera.chat 005 alice ACCOUNTEXTBAN=a WHOX KNOCK MONITOR=100 ETRACE FNC SAFELIST ELIST=CMNTU CALLERID=g CHANTYPES=# EXCEPTS INVEX :are supported by this server",
            ":tungsten.libera.chat 005 alice CHANMODES=eIbq,k,flj,CFLMPQRSTcgimnprstuz CHANLIMIT=#:250 PREFIX=(ov)@+ MAXLIST=bqeI:100 MODES=4 NETWORK=Libera.Chat STATUSMSG=@+ CASEMAPPING=rfc1459 NICKLEN=16 MAXNICKLEN=16 CHANNELLEN=50 TOPICLEN=390 :are supported by this server",
            ":tungsten.libera.chat 005 alice DEAF=D TARGMAX=NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR: EXTBAN=$,agjrxz :are supported by this server",
            ":tungsten.libera.chat 251 alice :There are 66 users and 33000 invisible on 28 servers",
            ":tungsten.libera.chat 252 alice 40 :IRC Operators online",
            ":tungsten.libera.chat 265 alice 2000 2500 :Current local users 2000, max 2500",
            ":tungsten.libera.chat 375 alice :- tungsten.libera.chat Message of the Day -",
            ":tungsten.libera.chat 372 alice :- Welcome to Libera Chat, the IRC network for",
            ":tungsten.libera.chat 376 alice :End of /MOTD command.",
            ":alice MODE alice :+Ziw",
            "@time=2024-01-01T00:00:01.000Z :alice!~alice@user/alice JOIN #libera",
            "@time=2024-01-01T00:00:01.000Z :tungsten.libera.chat 332 alice #libera :Welcome to #libera | https://libera.chat",
            ":tungsten.libera.chat 333 alice #libera ChanServ!ChanServ@services.libera.chat 1700000000",
            ":tungsten.libera.chat 353 alice @ #libera :alice @ChanServ +bob_ carol|away [dan] e-f g^h",
            ":tungsten.libera.chat 366 alice #libera :End of /NAMES list.",
            "@time=2024-01-01T00:00:02.123Z;account=bob_;msgid=x1 :bob_!~bob@user/bob PRIVMSG #libera :hi alice, how's it going? :)",
            "@account=carol :carol|away!~c@user/carol PRIVMSG #libera :\u{1}ACTION waves\u{1}",
            "PING :tungsten.libera.chat",
            ":bob_!~bob@user/bob NICK :bob",
            ":carol|away!~c@user/carol QUIT :Quit: Leaving",
            ":dan!d@host PART #libera :bye, all",
            ":op!o@staff/op MODE #libera +o-v alice bob",
            ":op!o@staff/op KICK #libera e-f",
            "ERROR :Closing Link: host.example (Quit: alice)",
        ], sasl: true, expectedNetwork: "Libera.Chat", expectedNickLength: 16, expectedCaseMapping: .rfc1459),

        ServerTranscript(name: "InspIRCd style", lines: [
            ":irc.inspircd.test NOTICE * :*** Looking up your hostname...",
            ":irc.inspircd.test CAP * LS :account-tag away-notify cap-notify extended-join message-tags multi-prefix sasl=PLAIN server-time setname",
            ":irc.inspircd.test CAP * ACK :account-tag away-notify cap-notify message-tags multi-prefix server-time",
            ":irc.inspircd.test 001 alice :Welcome to the InspIRCd IRC Network alice!alice@127.0.0.1",
            ":irc.inspircd.test 004 alice irc.inspircd.test InspIRCd-4 BIRSWcghikorswxz ABCDEFIJKLMNOPQRSTXYZabcdefhijklmnopqrstuvwz :FIJLXYabdefhjkloqvw",
            ":irc.inspircd.test 005 alice AWAYLEN=200 CASEMAPPING=ascii CHANLIMIT=#:20 CHANMODES=IXbeg,k,FJLfjl,ACDKMNOPQRSTcimnprstuz CHANNELLEN=60 CHANTYPES=# ELIST=CMNTU EXCEPTS=e :are supported by this server",
            ":irc.inspircd.test 005 alice HOSTLEN=64 INVEX=I KEYLEN=32 LINELEN=512 MAXTARGETS=20 MODES=20 NETWORK=InspIRCd NICKLEN=30 PREFIX=(qaohv)~&@%+ :are supported by this server",
            ":irc.inspircd.test 375 alice :irc.inspircd.test message of the day",
            ":irc.inspircd.test 376 alice :End of message of the day.",
            ":alice!alice@127.0.0.1 JOIN :#test",
            ":irc.inspircd.test 353 alice = #test :~@alice",
            ":irc.inspircd.test 366 alice #test :End of /NAMES list.",
            ":alice!alice@127.0.0.1 MODE #test +nt",
            ":irc.inspircd.test 324 alice #test +ntk secret",
            ":irc.inspircd.test 329 alice #test 1700000000",
            ":bob!bob@127.0.0.1 NICK :bob_away",
            ":op!op@127.0.0.1 MODE #test +qh-v alice bob carol",
            ":irc.inspircd.test 433 alice bob :Nickname is already in use.",
            ":irc.inspircd.test 482 alice #test :You must be a channel operator",
            "PING :irc.inspircd.test",
        ], sasl: false, expectedNetwork: "InspIRCd", expectedNickLength: 30, expectedCaseMapping: .ascii),

        ServerTranscript(name: "UnrealIRCd style", lines: [
            ":irc.unreal.test NOTICE * :*** Looking up your hostname...",
            ":irc.unreal.test CAP * LS :account-notify away-notify invite-notify extended-join userhost-in-names multi-prefix cap-notify sasl=PLAIN,EXTERNAL setname tls chghost account-tag batch server-time message-tags echo-message labeled-response draft/chathistory",
            ":irc.unreal.test CAP * ACK :account-tag away-notify batch cap-notify message-tags multi-prefix server-time",
            ":irc.unreal.test 001 alice :Welcome to the UnrealIRCd-Net IRC Network alice!alice@host",
            ":irc.unreal.test 005 alice AWAYLEN=307 BOT=B CASEMAPPING=ascii CHANLIMIT=#:10 CHANMODES=beI,fkL,lFH,cdimnprstzCDGKMNOPQRSTVZ CHANNELLEN=32 CHANTYPES=# CHATHISTORY=50 CLIENTTAGDENY=*,-draft/typing,-typing,-draft/reply DEAF=d EXCEPTS :are supported by this server",
            ":irc.unreal.test 005 alice EXTBAN=~,acfjmnpqrtCGIOST INVEX KICKLEN=307 KNOCK MAP MAXCHANNELS=10 MODES=12 NAMESX NETWORK=UnrealIRCd-Net NICKLEN=30 PREFIX=(qaohv)~&@%+ :are supported by this server",
            ":irc.unreal.test 396 alice Clk-1234.example :is now your displayed host",
            ":irc.unreal.test BATCH +hist1 chathistory #test",
            "@batch=hist1;time=2024-01-01T00:00:00.000Z;msgid=m1 :bob!b@h PRIVMSG #test :older message",
            "@batch=hist1;time=2024-01-01T00:00:01.000Z;msgid=m2 :carol!c@h PRIVMSG #test :another one",
            ":irc.unreal.test BATCH -hist1",
            "@+typing=active :bob!b@h TAGMSG #test",
            ":bob!b@h SETNAME :Bob the Builder",
            ":bob!b@h CHGHOST newident new.host",
            ":irc.unreal.test FAIL CHATHISTORY INVALID_TARGET #nope :Messages could not be retrieved",
            ":op!o@h MODE #test +qo alice bob",
            "PING :irc.unreal.test",
        ], sasl: false, expectedNetwork: "UnrealIRCd-Net", expectedNickLength: 30, expectedCaseMapping: .ascii),

        ServerTranscript(name: "Ergo style", lines: [
            ":ergo.test CAP * LS * :account-notify account-tag away-notify batch cap-notify chghost draft/channel-rename draft/chathistory draft/event-playback draft/languages=2,en,~bs draft/multiline=max-bytes=4096,max-lines=100",
            ":ergo.test CAP * LS :draft/persistence draft/read-marker echo-message extended-join invite-notify labeled-response message-tags multi-prefix sasl=PLAIN,EXTERNAL,SCRAM-SHA-256 server-time setname standard-replies userhost-in-names",
            ":ergo.test CAP * ACK :account-tag away-notify batch cap-notify message-tags multi-prefix sasl server-time",
            "AUTHENTICATE +",
            ":ergo.test 900 alice alice!~u@host alice :You are now logged in as alice",
            ":ergo.test 903 alice :Authentication successful",
            ":ergo.test 001 alice :Welcome to the ErgoTest IRC Network alice",
            ":ergo.test 005 alice AWAYLEN=390 BOT=B CASEMAPPING=ascii CHANLIMIT=#:100 CHANMODES=Ibe,k,fl,CEMRUimnstu CHANNELLEN=64 CHANTYPES=# CHATHISTORY=1000 ELIST=U EXCEPTS EXTBAN=,m FORWARD=f INVEX :are supported by this server",
            ":ergo.test 005 alice KICKLEN=390 MAXLIST=beI:100 MAXTARGETS=4 MODES MONITOR=100 NETWORK=ErgoTest NICKLEN=32 PREFIX=(qaohv)~&@%+ STATUSMSG=~&@%+ TARGMAX=NAMES:1,LIST:1,KICK:,WHOIS:1,USERHOST:10,PRIVMSG:4,TAGMSG:4,NOTICE:4,MONITOR:100 TOPICLEN=390 UTF8ONLY WHOX :are supported by this server",
            ":ergo.test 422 alice :MOTD File is missing",
            "@label=L1;msgid=abc;time=2024-01-01T00:00:00.000Z :alice!~u@host PRIVMSG #ergo :echoed",
            ":ergo.test BATCH +b1 draft/multiline #ergo",
            "@batch=b1 :bob!b@h PRIVMSG #ergo :line one",
            "@batch=b1;draft/multiline-concat :bob!b@h PRIVMSG #ergo :continued",
            ":ergo.test BATCH -b1",
            ":ergo.test 354 alice 152 #ergo ~u host ergo.test alice H 0 :Alice",
            ":ergo.test 315 alice #ergo :End of WHO list",
            ":ergo.test WARN REHASH CERTS_EXPIRED :Certificate has expired",
            "PING :ergo.test",
        ], sasl: true, expectedNetwork: "ErgoTest", expectedNickLength: 32, expectedCaseMapping: .ascii),

        ServerTranscript(name: "ngIRCd style", lines: [
            ":irc.ngircd.test NOTICE * :*** Looking up your hostname",
            ":irc.ngircd.test CAP * LS :multi-prefix",
            ":irc.ngircd.test CAP * ACK :multi-prefix",
            ":irc.ngircd.test 001 alice :Welcome to the Internet Relay Network alice!~alice@localhost",
            ":irc.ngircd.test 002 alice :Your host is irc.ngircd.test, running version ngircd-26 (x86_64/pc/linux-gnu)",
            ":irc.ngircd.test 004 alice irc.ngircd.test ngircd-26 abBcCFiIoqrRswx abehiIklmMnoOPqQrRstvVz",
            ":irc.ngircd.test 005 alice RFC2812 IRCD=ngIRCd CHARSET=UTF-8 CASEMAPPING=ascii PREFIX=(qaohv)~&@%+ CHANTYPES=#&+ CHANMODES=beI,k,l,imMnOPQRstVz CHANLIMIT=#&+:10 :are supported on this server",
            ":irc.ngircd.test 005 alice CHANNELLEN=50 NICKLEN=9 TOPICLEN=490 AWAYLEN=127 KICKLEN=400 MODES=5 MAXLIST=beI:50 EXCEPTS=e INVEX=I PENALTY FNC NETWORK=ngTest :are supported on this server",
            ":irc.ngircd.test 422 alice :MOTD file is missing",
            ":alice!~alice@localhost JOIN :#test",
            ":irc.ngircd.test MODE #test +o alice",
            ":irc.ngircd.test 353 alice = #test :@alice",
            ":irc.ngircd.test 366 alice #test :End of NAMES list",
            "PING :irc.ngircd.test",
            "ERROR :Closing connection",
        ], sasl: false, expectedNetwork: "ngTest", expectedNickLength: 9, expectedCaseMapping: .ascii),
    ]

    @Test(arguments: transcripts)
    func everyLineParsesAndReproducesItsWireForm(_ transcript: ServerTranscript) throws {
        for line in transcript.lines {
            let raw = try IRCRawMessage.parse(line)
            #expect(try raw.wireLine() == line, "\(transcript.name): \(line)")
            #expect(try IRCRawMessage.parse(raw.wireLine()) == raw)
        }
    }

    @Test(arguments: transcripts)
    func everyLineSurvivesTheTypedModelBothWays(_ transcript: ServerTranscript) throws {
        for line in transcript.lines {
            let typed = IRCMessage(standardIRC: try IRCRawMessage.parse(line))
            let back = try IRCRawMessage(standardIRC: typed)
            #expect(back.command == (try IRCRawMessage.parse(line)).command, "\(transcript.name): \(line)")
        }
    }

    @Test(arguments: transcripts)
    func pipelineDeliversEveryLineAsAFrame(_ transcript: ServerTranscript) throws {
        final class Box: @unchecked Sendable { var unparsable: [String] = [] }
        let box = Box()
        let channel = EmbeddedChannel()
        try channel.pipeline.syncOperations.addStandardIRCHandlers(configuration: .init(
            unparsableLineHandler: { line, _ in box.unparsable.append(line) }
        ))
        var buffer = channel.allocator.buffer(capacity: 8192)
        buffer.writeString(transcript.lines.joined(separator: "\r\n") + "\r\n")
        try channel.writeInbound(buffer)
        var frames = 0
        while try channel.readInbound(as: IRCFrame.self) != nil { frames += 1 }
        #expect(frames == transcript.lines.count)
        #expect(box.unparsable.isEmpty)
        _ = try channel.finish()
    }

    @Test(arguments: transcripts)
    func registrationCompletes(_ transcript: ServerTranscript) throws {
        var registration = IRCRegistration(configuration: .init(
            nick: "alice", username: "alice", realname: "Alice",
            sasl: transcript.sasl ? .plain(username: "alice", password: "pw") : nil
        ))
        var sent = registration.start()
        var batches = IRCBatchCollector()
        var completedBatches: [IRCBatch] = []
        for line in transcript.lines {
            let raw = try IRCRawMessage.parse(line)
            sent += registration.handle(raw)
            if let batch = batches.process(raw).completedBatch { completedBatches.append(batch) }
        }
        let sentLines = sent.map { (try? $0.wireLine()) ?? "<invalid>" }
        #expect(registration.isRegistered, "\(transcript.name)")
        #expect(registration.isupport.network == transcript.expectedNetwork)
        #expect(registration.isupport.nickLength == transcript.expectedNickLength)
        #expect(registration.isupport.caseMapping == transcript.expectedCaseMapping)
        #expect(sentLines.contains("CAP END"))
        #expect(sentLines.filter { $0.hasPrefix("PONG ") }.count == transcript.lines.filter { $0.hasPrefix("PING ") }.count)
        if transcript.sasl {
            #expect(registration.account == "alice")
            #expect(sentLines.contains("AUTHENTICATE PLAIN"))
            #expect(sentLines.firstIndex(of: "CAP END")! > sentLines.firstIndex(of: "AUTHENTICATE PLAIN")!)
        }
        #expect(batches.openBatchReferences.isEmpty)
        for batch in completedBatches {
            #expect(batch.messages.count == 2)
        }
    }

    @Test func namesRepliesSplitWithAdvertisedPrefixes() throws {
        var isupport = IRCISupport()
        isupport.apply(try IRCRawMessage.parse(":irc.inspircd.test 005 alice PREFIX=(qaohv)~&@%+ :are supported by this server"))
        let names = try IRCRawMessage.parse(":irc.inspircd.test 353 alice = #test :~@alice &bob +carol dave")
        let entries = names.parameters.last!.split(separator: " ").map { isupport.splitMembershipPrefixes(String($0)) }
        #expect(entries.map(\.nick) == ["alice", "bob", "carol", "dave"])
        #expect(entries.map { $0.prefixes.map(\.mode) } == [["q", "o"], ["a"], ["v"], []])
    }
}
