//
//  ChunkingTests.swift
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
import BinaryCodable
@testable import NeedleTailIRC

/// Multipart chunks are sized in UTF-8 bytes, so every generated frame has a known upper bound.
@Suite struct ChunkingTests {
    static let bob = NeedleTailNick(name: "bob", deviceId: nil)!

    func packets(_ text: String, chunkCount: Int = 512) async -> [MultipartPacket] {
        var packets: [MultipartPacket] = []
        for await packet in await PacketDerivation().calculateAndDispense(text: text, chunkCount: chunkCount) { packets.append(packet) }
        return packets
    }

    /// Sends `command` through a generator, checks each frame, and returns the reassembled message.
    func roundTrip(_ command: IRCCommand, auth: AuthPacket? = nil, check: (IRCMessage) throws -> Void = { _ in }) async throws -> (frames: Int, rebuilt: IRCMessage?) {
        let executor = TestableExecutor(queue: .init(label: "chunking"))
        let sender = IRCMessageGenerator(executor: executor)
        let receiver = IRCMessageGenerator(executor: executor)
        var frames = 0
        var rebuilt: IRCMessage?
        for try await frame in await sender.createMessages(origin: "alice", command: command, authPacket: auth, logger: NeedleTailLogger()) {
            frames += 1
            try check(frame)
            if let done = try await receiver.messageReassembler(ircMessage: NeedleTailIRCParser.parseMessage(frame.wireLine())) { rebuilt = done }
        }
        return (frames, rebuilt)
    }

    @Test func textChunksAreAtMost512UTF8Bytes() async {
        let ascii = String(repeating: "x", count: 1_200)
        #expect(await packets(ascii).map { $0.message?.utf8.count ?? 0 } == [512, 512, 176])

        // 12 800 bytes of four-scalar emoji: cut between scalars, never inside one.
        let family = String(repeating: "👨‍👩‍👧‍👦", count: 512)
        let parts = await packets(family)
        #expect(parts.count >= 25)
        #expect(parts.allSatisfy { ($0.message?.utf8.count ?? 0) <= 512 })
        #expect(parts.compactMap(\.message).joined() == family)
        #expect(parts.map(\.partNumber) == Array(1...parts.count) && parts.allSatisfy { $0.totalParts == parts.count })
    }

    @Test func aScalarWiderThanTheChunkStaysWhole() async {
        let parts = await packets("a😀b", chunkCount: 2)
        #expect(parts.compactMap(\.message) == ["a", "😀", "b"])
    }

    @Test func aChunkStartingWithAColonKeepsIt() async throws {
        let text = String(repeating: "a", count: 512) + ":kept"
        let result = try await roundTrip(.privMsg([.nick(Self.bob)], text))
        #expect(result.frames >= 2)
        guard case .privMsg(_, let rebuilt) = result.rebuilt?.command else { Issue.record("not rebuilt"); return }
        #expect(rebuilt == text)
    }

    // Each frame's text is in `packet-metadata`, so the line stays under RFC 2812's 512 bytes and
    // the tags under IRCv3's 4096-byte client limit, whatever the text is made of.
    @Test func everyGeneratedFrameFitsRFCLineAndIRCv3TagLimits() async throws {
        let auth = AuthPacket(jwt: String(repeating: "j", count: 900), nick: "alice")
        for text in [String(repeating: "x", count: 5_000), String(repeating: "👨‍👩‍👧‍👦", count: 512), String(repeating: "日本語", count: 900)] {
            let result = try await roundTrip(.privMsg([.nick(Self.bob)], text), auth: auth) { frame in
                let line = try frame.wireLine()
                let untagged = try IRCMessage(origin: frame.origin, target: frame.target, command: frame.command).wireLine()
                #expect(untagged.utf8.count + IRCMessage.lineTerminator.utf8.count <= 512)
                #expect(line.utf8.count - untagged.utf8.count <= 4_096)
            }
            guard case .privMsg(_, let rebuilt) = result.rebuilt?.command else { Issue.record("not rebuilt"); continue }
            #expect(rebuilt == text)
        }
    }

    // A standard server answers an empty PRIVMSG with 412 and doesn't relay `packet-metadata`, so
    // each frame carries its piece of text in the body too, sized for a relayed 512-byte line.
    @Test func privMsgAndNoticeFramesCarryTheirTextInTheBody() async throws {
        let alice = NeedleTailNick(name: "alice", deviceId: UUID())!
        let text = String(repeating: "Hello, world! ", count: 100) + String(repeating: "👨‍👩‍👧‍👦", count: 40)
        for command in [IRCCommand.privMsg([.nick(alice)], text), .notice([.nick(alice)], text)] {
            var pieces: [String] = []
            let result = try await roundTrip(command) { frame in
                switch frame.command {
                case .privMsg(_, let piece), .notice(_, let piece): pieces.append(piece)
                default: Issue.record("\(frame.command)")
                }
                // Relayed as `:<nick!user@host> PRIVMSG <target> :<piece>\r\n`, prefix up to 106 bytes.
                let line = try IRCMessage(command: frame.command).wireLine()
                #expect(1 + 106 + 1 + line.utf8.count + 2 <= 512)
            }
            #expect(result.frames > 1)
            #expect(!pieces.contains("") && pieces.joined() == text)
            #expect(pieces.allSatisfy { $0.unicodeScalars.first.map { !(0x200D...0x200D).contains($0.value) } ?? true })
            switch result.rebuilt?.command {
            case .privMsg(_, let rebuilt), .notice(_, let rebuilt): #expect(rebuilt == text)
            default: Issue.record("not rebuilt")
            }
        }
    }

    // IRCv3: a client sends no tags unless the server acknowledged `message-tags`. Without them,
    // a server reads `@packet-metadata=...` as the command and answers 421.
    @Test func v1FramesCarryNoTags() async throws {
        let generator = IRCMessageGenerator(executor: TestableExecutor(queue: .init(label: "no-tags")))
        #expect(await generator.version == .v3)
        await generator.setVersion(.v1)
        #expect(await IRCMessageGenerator(executor: TestableExecutor(queue: .init(label: "v1")), version: .v1).version == .v1)
        let text = String(repeating: "plain line text ", count: 80)
        var pieces: [String] = []
        let auth = AuthPacket(jwt: "header.body.sig", nick: "alice")
        for try await frame in await generator.createMessages(origin: "alice", command: .privMsg([.nick(Self.bob)], text), tags: [IRCTag(key: "+typing", value: "active")], authPacket: auth, logger: NeedleTailLogger()) {
            #expect(frame.tags == nil)
            #expect(!(try frame.wireLine()).hasPrefix("@"))
            guard case .privMsg(_, let piece) = frame.command else { Issue.record("\(frame.command)"); continue }
            pieces.append(piece)
        }
        #expect(pieces.count > 1 && pieces.joined() == text)
    }

    // Reassembly still works when only the body carries the text.
    @Test func reassemblyReadsTheBodyWhenTheTagHasNoText() async throws {
        let receiver = IRCMessageGenerator(executor: TestableExecutor(queue: .init(label: "body-only")))
        let groupId = UUID().uuidString
        var rebuilt: IRCMessage?
        for (index, piece) in ["Hello, ", "world: ", "done "].enumerated() {
            let packet = MultipartPacket(groupId: groupId, date: Date(), partNumber: index + 1, totalParts: 3, message: "")
            let tag = IRCTag(key: "packet-metadata", value: try BinaryEncoder().encode(packet).base64EncodedString())
            let line = try IRCMessage(origin: "alice", command: .privMsg([.nick(Self.bob)], piece), tags: [tag]).wireLine()
            if let done = try await receiver.messageReassembler(ircMessage: NeedleTailIRCParser.parseMessage(line)) { rebuilt = done }
        }
        guard case .privMsg(_, let text) = rebuilt?.command else { Issue.record("not rebuilt"); return }
        #expect(text == "Hello, world: done ")
    }

    @Test func customCommandPayloadsChunkLikeText() async throws {
        let payload = String(repeating: "p", count: 2_000)
        let result = try await roundTrip(.custom("PUBLISHBLOB", [payload]))
        #expect(result.frames == 4)
        #expect(result.rebuilt?.command.arguments == [payload])
    }
}
