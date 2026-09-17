import BinaryCodable
import Foundation
import Testing
@testable import NeedleTailIRC

@Suite(.serialized)
struct ModelCodableRegressionTests {
    @Test("PIN: IRCMessage target survives Codable round trips")
    func messageTargetRoundTrips() throws {
        let original = IRCMessage(
            origin: "irc.example.com",
            target: "alice",
            command: .numeric(.replyWelcome, ["Welcome"])
        )

        let jsonData = try JSONEncoder().encode(original)
        let jsonMessage = try JSONDecoder().decode(IRCMessage.self, from: jsonData)
        #expect(jsonMessage.target == "alice")

        let binaryData = try BinaryEncoder().encode(original)
        let binaryMessage = try BinaryDecoder().decode(IRCMessage.self, from: binaryData)
        #expect(binaryMessage.target == "alice")
    }

    @Test("Decoded channels preserve validation and canonical invariants")
    func decodedChannelRejectsInvalidOriginal() throws {
        let invalidJSON = "{\"a\":\"not-a-channel\",\"b\":\"#forged\"}"
        let invalid = Data(invalidJSON.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(NeedleTailChannel.self, from: invalid)
        }
    }

    @Test("Nick wire values never serialize a missing UUID as _nil")
    func nickWithoutDeviceIDHasStandardWireValue() throws {
        let nick = try #require(NeedleTailNick(name: "Alice", deviceId: nil))
        #expect(nick.stringValue == "alice")

        let recipient = try #require(IRCMessageRecipient("alice"))
        guard case .nick(let parsedNick) = recipient else {
            Issue.record("Expected a nick recipient")
            return
        }
        #expect(parsedNick.name == "alice")
        #expect(parsedNick.deviceId == nil)
    }

    @Test(
        "IRC user identifiers serialize each valid prefix shape",
        arguments: [
            (user: nil, host: nil, suffix: ""),
            (user: nil, host: "host.example", suffix: "@host.example"),
            (user: "user", host: nil, suffix: "!user"),
            (user: "user", host: "host.example", suffix: "!user@host.example"),
        ]
    )
    func userIdentifierWireShapes(
        user: String?,
        host: String?,
        suffix: String
    ) throws {
        let deviceID = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        let nick = try #require(NeedleTailNick(name: "Alice", deviceId: deviceID))
        let identifier = IRCUserIdentifier(nick: nick, user: user, host: host)
        #expect(identifier.stringValue == "alice_\(deviceID.uuidString)\(suffix)")
    }

    @Test("Channel packets and blobs retain bot message templates")
    func channelPacketAndBlobRoundTrip() throws {
        let channel = try #require(NeedleTailChannel("#general"))
        let templates = ChannelBotMessageTemplates(
            memberWelcome: "Welcome",
            operatorWelcome: "Operator online",
            idleHint: "Say hello"
        )
        let packet = NeedleTailChannelPacket(
            name: channel,
            channelOperatorAdmin: "admin",
            channelOperators: ["operator"],
            members: ["member"],
            enabledBots: [.chanBot],
            botMessages: templates
        )
        let original = IRCChannelBlob(metadata: packet, blob: ["payload"])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            IRCChannelBlob<[String]>.self,
            from: data
        )

        #expect(decoded.metadata.botMessages == templates)
        #expect(decoded.blob == ["payload"])
    }

    @Test("AuthPacket Codable preserves required values")
    func authPacketRoundTrip() throws {
        let original = AuthPacket(jwt: "jwt", nick: "alice")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuthPacket.self, from: data)
        #expect(decoded.jwt == "jwt")
        #expect(decoded.nick == "alice")
    }
}
