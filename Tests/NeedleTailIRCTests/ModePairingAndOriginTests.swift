//
//  ModePairingAndOriginTests.swift
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

/// RFC 2812 §3.2.3 pairs each parameter with the mode letter that asked for it, in order. A
/// channel MODE must keep that pairing through parse and encode.
@Suite struct ModePairingTests {
    func reencode(_ line: String) throws -> String { try NeedleTailIRCParser.parseMessage(line).wireLine() }

    /// The (sign, letter, parameter) triples a MODE line means, read the RFC way.
    func meaning(_ line: String) -> [String] {
        let parts = line.split(separator: " ").map(String.init)
        var parameters = Array(parts.dropFirst(3))
        var adding = true
        var result: [String] = []
        for letter in parts[2] {
            if letter == "+" { adding = true; continue }
            if letter == "-" { adding = false; continue }
            let takes = NeedleTailIRCCommandParser.channelModeTakesParameter(letter, adding: adding)
            result.append("\(adding ? "+" : "-")\(letter)\(takes && !parameters.isEmpty ? " " + parameters.removeFirst() : "")")
        }
        return result.sorted()
    }

    @Test(arguments: [
        "MODE #room +vo alice bob",          // voice alice, op bob
        "MODE #room +ov alice bob",
        "MODE #room +kl key 10",             // key "key", limit 10
        "MODE #room +lk 10 key",
        "MODE #room +bb *!*@a *!*@b",
        "MODE #room +oov alice bob carol",   // op two, voice one: needs every letter kept
        "MODE #room +vbo alice *!*@x bob",
        "MODE #room +o-v+b alice bob *!*@x",
        "MODE #room -o+v bob carol",
        "MODE #room +ntk key",
    ])
    func pairingSurvivesParseAndEncode(_ line: String) throws {
        let again = try reencode(line)
        #expect(meaning(again) == meaning(line), "\(line) re-encoded as \(again)")
    }

    @Test func setFormIsCanonicalAndOrderedListFormIsExact() throws {
        // Representable as a set: parameters stored in the letters' canonical order.
        guard case .channelMode(_, let add, let addParameters, _, _) = try NeedleTailIRCParser.parseMessage("MODE #room +vo alice bob").command else {
            Issue.record("expected .channelMode"); return
        }
        #expect(add == [.channelOperator, .voice] && addParameters == ["bob", "alice"])
        #expect(try reencode("MODE #room +vo alice bob") == "MODE #room +ov bob alice")

        // Not representable as a set: every change kept in order, and written back as sent.
        let line = "MODE #room +oov alice bob carol"
        guard case .channelModeChanges(_, let changes) = try NeedleTailIRCParser.parseMessage(line).command else {
            Issue.record("expected .channelModeChanges"); return
        }
        #expect(changes == [
            IRCChannelModeChange(adding: true, mode: .channelOperator, parameter: "alice"),
            IRCChannelModeChange(adding: true, mode: .channelOperator, parameter: "bob"),
            IRCChannelModeChange(adding: true, mode: .voice, parameter: "carol"),
        ])
        #expect(try reencode(line) == line)
    }

    @Test func orderedChangesEncodeAsWritten() throws {
        let channel = NeedleTailChannel("#room")!
        let command = IRCCommand.channelModeChanges(channel, [
            IRCChannelModeChange(adding: true, mode: .voice, parameter: "alice"),
            IRCChannelModeChange(adding: false, mode: .channelOperator, parameter: "bob"),
            IRCChannelModeChange(adding: true, mode: .moderated),
        ])
        #expect(try IRCMessage(command: command).wireLine() == "MODE #room +v-o+m alice bob")
        // One mode per change, and parameters are single words.
        #expect(throws: IRCMessageGeneratorError.invalidParameter) {
            try IRCMessage(command: .channelModeChanges(channel, [IRCChannelModeChange(adding: true, mode: [.voice, .channelOperator], parameter: "x")])).wireLine()
        }
        #expect(throws: IRCMessageGeneratorError.invalidParameter) {
            try IRCMessage(command: .channelModeChanges(channel, [IRCChannelModeChange(adding: true, mode: .banMask, parameter: "a b")])).wireLine()
        }
        #expect(throws: IRCMessageGeneratorError.invalidParameter) {
            try IRCMessage(command: .channelModeChanges(channel, [])).wireLine()
        }
    }
}

/// `IRCUserIdentifier` reads a standard origin the way the parser does: case kept, `_` and
/// one-character nicks allowed.
@Suite struct OriginIdentifierTests {
    @Test func standardOriginsKeepTheirNick() {
        #expect(IRCUserIdentifier("Alice!alice@host")?.nick.stringValue == "Alice")
        for origin in ["a_b!ab@host", "NeedleBot_!bot@host", "x!x@host", "[Robo]!r@h"] {
            #expect(IRCUserIdentifier(origin) != nil, "\(origin)")
        }
        #expect(IRCUserIdentifier("Alice!alice@host")?.stringValue == "Alice!alice@host")
        #expect(IRCUserIdentifier("Alice") == IRCUserIdentifier("alice"))
    }

    @Test func needleTailIdentitiesAreUnchanged() {
        let deviceId = UUID()
        let wire = IRCUserIdentifier("Alice_\(deviceId.uuidString)!u@h")
        #expect(wire?.nick.name == "alice" && wire?.nick.deviceId == deviceId)
        // An explicit device id still builds a NeedleTail identity, lowercased.
        let explicit = IRCUserIdentifier("Alice", deviceId: deviceId)
        #expect(explicit?.nick.name == "alice" && explicit?.nick.deviceId == deviceId)
    }
}
