import BinaryCodable
import Foundation
import NeedleTailLogger
import NIOCore
import Testing
@testable import NeedleTailIRC

private struct AuthFailingBinaryEncoder: BinaryEncoding {
    enum Failure: Error {
        case forced
    }

    func encode<T: Encodable>(_ value: T) throws -> Data {
        if value is AuthPacket {
            throw Failure.forced
        }
        return try BinaryEncoder().encode(value)
    }
}

@Suite(.serialized)
struct GeneratorFailureTests {
    @Test("The throwing payload encoder rejects empty command targets")
    func payloadEncoderRejectsEmptyTargets() {
        let encoder = IRCPayloadEncoder()
        let messages = [
            IRCMessage(command: .join(channels: [], keys: nil)),
            IRCMessage(command: .privMsg([], "hello")),
            IRCMessage(command: .notice([], "hello")),
        ]

        for message in messages {
            #expect(throws: IRCMessageGeneratorError.emptyCommandRejected) {
                var output = ByteBuffer()
                try encoder.encode(data: .irc(message), out: &output)
            }
        }
    }

    @Test("Auth encoding failure terminates without yielding a frame")
    func authEncodingFailureIsSurfaced() async throws {
        let generator = IRCMessageGenerator(
            executor: TestableExecutor(queue: .global()),
            binaryEncoder: AuthFailingBinaryEncoder()
        )
        let channel = try #require(NeedleTailChannel("#general"))
        let stream = await generator.createMessages(
            origin: "alice",
            command: .privMsg([.channel(channel)], "secret"),
            authPacket: AuthPacket(jwt: "jwt", nick: "alice"),
            logger: NeedleTailLogger("[ GeneratorFailureTests ]")
        )

        var yieldedFrames = 0
        var receivedError: IRCMessageGeneratorError?
        do {
            for try await _ in stream {
                yieldedFrames += 1
            }
        } catch let error as IRCMessageGeneratorError {
            receivedError = error
        }

        #expect(yieldedFrames == 0)
        #expect(receivedError == .authPacketEncodeFailed)
    }

    @Test("PacketBuilder runtime configuration applies to the next packet")
    func packetBuilderConfigureAppliesImmediately() async {
        let builder = PacketBuilder(
            executor: TestableExecutor(queue: .global())
        )
        await builder.configure(maxTotalPartsPerGroup: 1)
        let configured = await builder.limits
        #expect(configured.maxTotalPartsPerGroup == 1)

        let rejected = await builder.processPacket(
            MultipartPacket(
                groupId: "too-many-parts",
                partNumber: 1,
                totalParts: 2,
                message: "first"
            )
        )
        guard case .none = rejected else {
            Issue.record("A packet above the configured part limit was accepted")
            return
        }
    }
}
