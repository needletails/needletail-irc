import Foundation
import NIOCore
import NIOEmbedded
import Testing
@testable import NeedleTailIRC

/// Wire-level coverage for `IRCBinaryMessage` and the per-family gating in `IRCFrameDecoder`.
///
/// Organised by the guarantee under test:
/// 1. round trips, 2. framing inside a stream, 3. header limits,
/// 4. complete-but-malformed bodies must be `malformed` (never stall as `incomplete`),
/// 5. encode is atomic, 6. non-wire surfaces (Codable, Equatable, description), 7. decoder gates.
@Suite(.serialized)
struct IRCBinaryMessageFramingTests {

    // MARK: - Fixtures

    private let nick = NeedleTailNick(name: "bob", deviceId: UUID())!
    private let room = NeedleTailChannel("#room")!

    private func fullMessage() -> IRCBinaryMessage {
        IRCBinaryMessage(
            origin: "alice!a@h",
            recipients: [.nick(nick), .channel(room), .all],
            tags: [IRCTag(key: "msgid", value: "1"), IRCTag(key: "time", value: "t")],
            contentType: "application/octet-stream",
            sequence: .init(groupId: "g1", partNumber: 2, totalParts: 3),
            payload: Data((0..<5000).map { UInt8($0 & 0xFF) })
        )
    }

    private func minimalMessage(payload: Data = Data()) -> IRCBinaryMessage {
        IRCBinaryMessage(recipients: [.nick(nick)], payload: payload)
    }

    /// Payload with no `0x0A` / `0x0D`, so a text-only decoder does not split it into lines.
    private func newlineFreeMessage() -> IRCBinaryMessage {
        minimalMessage(payload: Data(repeating: 0x41, count: 64))
    }

    // MARK: - 1. Round trips

    @Test("Every field survives encode → decode")
    func fullRoundTrip() throws {
        let original = fullMessage()
        let decoded = try decodeSingleBinary(encode(.binary(original)), .withBinaryFrames())

        #expect(decoded.id == original.id)
        #expect(decoded.origin == original.origin)
        #expect(decoded.recipients == original.recipients)
        #expect(decoded.tags == original.tags)
        #expect(decoded.contentType == original.contentType)
        #expect(decoded.sequence == original.sequence)
        #expect(decoded.payload == original.payload)
    }

    @Test("Optional fields absent and empty payload round-trip")
    func minimalRoundTrip() throws {
        let original = minimalMessage()
        let decoded = try decodeSingleBinary(encode(.binary(original)), .withBinaryFrames())

        #expect(decoded.id == original.id)
        #expect(decoded.origin == nil)
        #expect(decoded.tags == nil)
        #expect(decoded.contentType == nil)
        #expect(decoded.sequence == nil)
        #expect(decoded.payload.isEmpty)
    }

    @Test("Wildcard recipient round-trips")
    func wildcardRecipient() throws {
        let decoded = try decodeSingleBinary(
            encode(.binary(IRCBinaryMessage(recipients: [.all], payload: Data([1])))),
            .withBinaryFrames()
        )
        #expect(decoded.recipients == [.all])
    }

    @Test("Type-level encode(into:) and IRCFrame.encode(into:) produce identical bytes")
    func frameDelegates() throws {
        let message = fullMessage()
        var direct = ByteBuffer()
        var viaFrame = ByteBuffer()
        try message.encode(into: &direct)
        try IRCFrame.binary(message).encode(into: &viaFrame)
        #expect(direct == viaFrame)
    }

    // MARK: - 2. Framing inside a stream

    @Test("Frame starts with the 0xFF discriminator and a correct body length")
    func wireHeader() throws {
        let buffer = try encode(.binary(minimalMessage()))
        #expect(buffer.getInteger(at: 0, as: UInt8.self) == IRCBinaryMessage.discriminator)
        let declared = try #require(buffer.getInteger(at: 1, as: UInt32.self))
        #expect(Int(declared) == buffer.readableBytes - IRCBinaryMessage.headerLength)
        #expect(buffer.getInteger(at: IRCBinaryMessage.headerLength, as: UInt8.self) == IRCBinaryMessage.wireVersion)
    }

    @Test("Text, binary, and DCC frames interleaved in one buffer decode in order")
    func interleavedFamilies() throws {
        let text = IRCMessage(origin: "alice", command: .privMsg([.nick(nick)], "hi"))
        var combined = try encode(.text(text))
        combined.writeImmutableBuffer(try encode(.binary(fullMessage())))
        combined.writeImmutableBuffer(try encode(.dcc(.blob(Data([9, 9, 9])))))
        combined.writeImmutableBuffer(try encode(.text(text)))

        let frames = try decodeAll(combined, .withBinaryFrames())
        #expect(frames.count == 4)
        guard frames.count == 4 else { return }
        guard case .text = frames[0], case .binary = frames[1], case .dcc = frames[2], case .text = frames[3] else {
            Issue.record("Unexpected frame order: \(frames)")
            return
        }
    }

    @Test("Two back-to-back binary frames decode independently")
    func coalescedBinaryFrames() throws {
        let first = minimalMessage(payload: Data([1]))
        let second = minimalMessage(payload: Data([2, 2]))
        var combined = try encode(.binary(first))
        combined.writeImmutableBuffer(try encode(.binary(second)))

        let frames = try decodeAll(combined, .withBinaryFrames())
        #expect(frames.count == 2)
        guard frames.count == 2, case .binary(let a) = frames[0], case .binary(let b) = frames[1] else {
            Issue.record("Expected two binary frames")
            return
        }
        #expect(a.id == first.id && a.payload == first.payload)
        #expect(b.id == second.id && b.payload == second.payload)
    }

    @Test("Binary frame delivered one byte at a time decodes once complete")
    func fragmentedFrame() throws {
        var encoded = try encode(.binary(fullMessage()))
        let bytes = encoded.readBytes(length: encoded.readableBytes) ?? []
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames()))
        defer { _ = try? channel.finish() }

        for (index, byte) in bytes.enumerated() {
            var fragment = channel.allocator.buffer(capacity: 1)
            fragment.writeInteger(byte)
            try channel.writeInbound(fragment)
            if index < bytes.count - 1 {
                #expect(try channel.readInbound(as: IRCFrame.self) == nil, "no output before the last byte")
            }
        }

        let frame = try #require(try channel.readInbound(as: IRCFrame.self))
        guard case .binary(let decoded) = frame else {
            Issue.record("Expected a binary frame")
            return
        }
        #expect(decoded.payload == fullMessage().payload)
    }

    @Test("Truncated frame consumes nothing and emits nothing")
    func truncatedFrame() throws {
        var encoded = try encode(.binary(fullMessage()))
        encoded.moveWriterIndex(to: encoded.writerIndex - 1)
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames()))
        defer { _ = try? channel.finish() }
        try channel.writeInbound(encoded)
        #expect(try channel.readInbound(as: IRCFrame.self) == nil)
    }

    @Test("Header-only partials report incomplete at every cut point")
    func headerPartialsAreIncomplete() throws {
        let full = try encode(.binary(minimalMessage()))
        for cut in 0..<IRCBinaryMessage.headerLength {
            var partial = full
            partial.moveWriterIndex(to: partial.readerIndex + cut)
            expectDecodeError(partial, kind: .incomplete, "cut at \(cut)")
        }
    }

    // MARK: - 3. Header limits

    @Test("Frame exactly at maxFrameLength decodes; one byte over is malformed")
    func frameLengthBoundary() throws {
        let encoded = try encode(.binary(minimalMessage(payload: Data(repeating: 7, count: 100))))
        let bodyLength = encoded.readableBytes - IRCBinaryMessage.headerLength

        let exact = try decodeAll(encoded, IRCFrameDecoder(binaryFraming: .ircBinary, maxBinaryFrameLength: bodyLength))
        #expect(exact.count == 1)

        expectDecodeError(encoded, maxFrameLength: bodyLength - 1, kind: .malformed, "one byte over")
    }

    @Test("Declared length over the limit fails before any body bytes arrive")
    func oversizedDeclaredLengthFailsEarly() {
        var header = ByteBuffer()
        header.writeInteger(IRCBinaryMessage.discriminator)
        header.writeInteger(UInt32(10_000))
        // No body at all: a bounded decoder must reject on the header alone, not wait.
        expectDecodeError(header, maxFrameLength: 1024, kind: .malformed, "oversize header")
    }

    // MARK: - 4. Complete-but-malformed bodies

    @Test("Unsupported wire version is malformed")
    func unsupportedVersion() throws {
        var buffer = try encode(.binary(minimalMessage()))
        buffer.setInteger(IRCBinaryMessage.wireVersion &+ 1, at: IRCBinaryMessage.headerLength)
        expectDecodeError(buffer, kind: .malformed)
    }

    @Test("Zero recipients on the wire is malformed")
    func zeroRecipients() {
        let frame = craftFrame { body in
            writeVersionAndId(&body)
            body.writeInteger(UInt8(0))      // no origin
            body.writeInteger(UInt16(0))     // recipientCount = 0
        }
        expectDecodeError(frame, kind: .malformed)
    }

    @Test("Recipient string the parser rejects is malformed")
    func invalidRecipient() {
        let frame = craftFrame { body in
            writeVersionAndId(&body)
            body.writeInteger(UInt8(0))
            body.writeInteger(UInt16(1))
            try? body.writeLengthPrefixedUTF8("")   // empty is never a valid nick/channel
        }
        expectDecodeError(frame, kind: .malformed)
    }

    @Test("Bad presence flag on an optional field is malformed")
    func badPresenceFlag() {
        let frame = craftFrame { body in
            writeVersionAndId(&body)
            body.writeInteger(UInt8(2))      // origin presence must be 0 or 1
        }
        expectDecodeError(frame, kind: .malformed)
    }

    @Test("Bad sequence presence flag is malformed")
    func badSequenceFlag() throws {
        let frame = craftFrame { body in
            writeVersionAndId(&body)
            body.writeInteger(UInt8(0))                                // origin
            body.writeInteger(UInt16(1)); try? body.writeLengthPrefixedUTF8(nick.stringValue)
            body.writeInteger(UInt16(0))                               // tags
            body.writeInteger(UInt8(0))                                // contentType
            body.writeInteger(UInt8(7))                                // sequence flag: invalid
        }
        expectDecodeError(frame, kind: .malformed)
    }

    /// Regression for the stall bug: a field length that overruns an otherwise complete
    /// frame must be `malformed`. Reporting `incomplete` would make the decoder wait forever
    /// or swallow the next frame's bytes.
    @Test("Inner field length overrunning the frame is malformed, not incomplete")
    func innerLengthOverrunIsMalformed() {
        // The claimed length must be *within* maxFrameLength (so the generic field-size
        // guard does not catch it) but beyond the bytes actually present in the frame.
        let frame = craftFrame { body in
            writeVersionAndId(&body)
            body.writeInteger(UInt8(1))                 // origin present
            body.writeInteger(UInt32(1000))             // ...claims 1000 bytes
            body.writeBytes([0x41, 0x42])               // but only 2 follow
        }
        expectDecodeError(frame, kind: .malformed)
        expectDecodeError(frame, maxFrameLength: 1_000_000, kind: .malformed, "generous limit still malformed")

        // Through the pipeline: must throw, must not sit in needMoreData.
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(IRCFrameDecoder.withBinaryFrames()))
        defer { _ = try? channel.finish() }
        #expect(throws: (any Error).self) { try channel.writeInbound(frame) }
    }

    @Test("Payload length overrunning the frame is malformed")
    func payloadOverrunIsMalformed() throws {
        var buffer = try encode(.binary(minimalMessage(payload: Data([1, 2, 3]))))
        // Payload length is the last UInt32 before the 3 payload bytes.
        let payloadLengthOffset = buffer.writerIndex - 3 - 4
        buffer.setInteger(UInt32(3000), at: payloadLengthOffset)
        expectDecodeError(buffer, kind: .malformed)
    }

    @Test("Frame length shorter than the body it contains is malformed")
    func frameLengthTooShortForBody() throws {
        var buffer = try encode(.binary(minimalMessage(payload: Data([1, 2, 3]))))
        // Claim the body is only 3 bytes: version + 2 bytes of UUID, then it ends.
        buffer.setInteger(UInt32(3), at: 1)
        expectDecodeError(buffer, kind: .malformed)
    }

    @Test("Trailing bytes after the payload are malformed")
    func trailingBytesAreMalformed() throws {
        var buffer = try encode(.binary(minimalMessage(payload: Data([1]))))
        buffer.writeInteger(UInt8(0xAA))                         // junk inside the frame...
        let declared = try #require(buffer.getInteger(at: 1, as: UInt32.self))
        buffer.setInteger(declared + 1, at: 1)                   // ...accounted for by the length
        expectDecodeError(buffer, kind: .malformed)
    }

    @Test("Wrong discriminator passed to decode is malformed")
    func wrongDiscriminator() {
        var buffer = ByteBuffer()
        buffer.writeInteger(UInt8(0x01))
        buffer.writeInteger(UInt32(0))
        expectDecodeError(buffer, kind: .malformed)
    }

    // MARK: - 5. Encode is atomic

    @Test("Encoder rejects a binary message with no recipients, writing nothing")
    func emptyRecipientsRejected() {
        var buffer = ByteBuffer(string: "pre")
        #expect(throws: IRCMessageGeneratorError.emptyCommandRejected) {
            try IRCBinaryMessage(recipients: [], payload: Data([1])).encode(into: &buffer)
        }
        #expect(buffer.readableBytes == 3, "buffer must be untouched on failure")
    }

    @Test("Sequence values beyond UInt32 are rejected before anything is written")
    func sequenceOverflowRejectedAtomically() {
        let message = IRCBinaryMessage(
            recipients: [.nick(nick)],
            sequence: .init(groupId: "g", partNumber: Int(UInt32.max) + 1, totalParts: 1),
            payload: Data()
        )
        var buffer = ByteBuffer(string: "pre")
        do {
            try message.encode(into: &buffer)
            Issue.record("Expected malformed")
        } catch let error as NIODecodeError {
            #expect(error.kind == .malformed)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(buffer.readableBytes == 3, "buffer must be untouched on failure")
    }

    @Test("More than UInt16.max tags are rejected before anything is written")
    func tooManyTagsRejectedAtomically() {
        let tags = (0...Int(UInt16.max)).map { IRCTag(key: "k\($0)", value: "v") }
        let message = IRCBinaryMessage(recipients: [.nick(nick)], tags: tags, payload: Data())
        var buffer = ByteBuffer()
        do {
            try message.encode(into: &buffer)
            Issue.record("Expected malformed")
        } catch let error as NIODecodeError {
            #expect(error.kind == .malformed)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(buffer.readableBytes == 0)
    }

    // MARK: - 6. Non-wire surfaces

    @Test("Codable round-trip preserves every field and uses compact keys")
    func codableRoundTrip() throws {
        let original = fullMessage()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IRCBinaryMessage.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.origin == original.origin)
        #expect(decoded.recipients == original.recipients)
        #expect(decoded.tags == original.tags)
        #expect(decoded.contentType == original.contentType)
        #expect(decoded.sequence == original.sequence)
        #expect(decoded.payload == original.payload)

        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["i", "a", "b", "d", "e", "f", "g"], "compact keys, matching IRCMessage")
    }

    @Test("Equality is by id only")
    func equalityIsById() {
        var a = minimalMessage(payload: Data([1]))
        var b = minimalMessage(payload: Data([2]))
        #expect(a != b)
        b.id = a.id
        #expect(a == b, "same id ⇒ equal even with different payloads (dedup semantics)")
        a.id = UUID()
        #expect(a != b)
    }

    @Test("description summarises routing and size without dumping the payload")
    func descriptionIsLogSafe() {
        let message = fullMessage()
        let text = message.description
        #expect(text.contains("from=alice!a@h"))
        #expect(text.contains("type=application/octet-stream"))
        #expect(text.contains("part=2/3"))
        #expect(text.contains("bytes=5000"))
        #expect(!text.contains("[0, 1, 2"), "payload bytes must not appear")
        #expect(text.count < 300)
        #expect(IRCFrame.binary(message).description == text)
    }

    // MARK: - 7. Decoder gates

    @Test("serverIRC() decodes binary but treats DCC bytes as text")
    func serverGate() throws {
        let binary = try decodeAll(try encode(.binary(minimalMessage())), .serverIRC())
        guard case .binary? = binary.first else {
            Issue.record("serverIRC() must decode IRCBinaryMessage")
            return
        }
        // A DCC frame has no newline; on a server socket it must sit as pending text, not decode.
        let dcc = try decodeAll(try encode(.dcc(.close)), .serverIRC())
        #expect(dcc.isEmpty)
    }

    @Test("DCC-only framing does not decode a 0xFF frame as binary")
    func dccOnlyGate() throws {
        // No CR/LF in the payload: with binary framing off, 0x0A would be a line break and
        // the text decoder would log a warning for every fragment.
        let frames = try decodeAll(try encode(.binary(newlineFreeMessage())), IRCFrameDecoder(binaryFraming: .dcc))
        #expect(!frames.contains { if case .binary = $0 { return true } else { return false } })
    }

    @Test("lineBasedIRC() never produces a binary frame")
    func lineOnlyGate() throws {
        let frames = try decodeAll(try encode(.binary(newlineFreeMessage())), .lineBasedIRC())
        #expect(!frames.contains { if case .binary = $0 { return true } else { return false } })
    }

    @Test("Legacy allowsBinaryFrames: maps to all-or-nothing")
    func legacyBoolShim() {
        #expect(IRCFrameDecoder(allowsBinaryFrames: true).binaryFraming == .all)
        #expect(IRCFrameDecoder(allowsBinaryFrames: false).binaryFraming == .none)
    }

    // MARK: - Crafting helpers

    /// Builds `0xFF | UInt32 length | body` from a hand-written body.
    private func craftFrame(_ body: (inout ByteBuffer) -> Void) -> ByteBuffer {
        var bodyBuffer = ByteBuffer()
        body(&bodyBuffer)
        var frame = ByteBuffer()
        frame.writeInteger(IRCBinaryMessage.discriminator)
        frame.writeInteger(UInt32(bodyBuffer.readableBytes))
        frame.writeBuffer(&bodyBuffer)
        return frame
    }

    private func writeVersionAndId(_ body: inout ByteBuffer) {
        body.writeInteger(IRCBinaryMessage.wireVersion)
        body.writeBytes([UInt8](repeating: 0x11, count: 16))
    }

    /// Calls the type-level decoder directly and asserts the error kind and that nothing was consumed.
    private func expectDecodeError(
        _ buffer: ByteBuffer,
        maxFrameLength: Int = IRCFrameDecoder.defaultMaxBinaryFrameLength,
        kind: NIODecodeError.Kind,
        _ label: String = "",
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var copy = buffer
        do {
            _ = try IRCBinaryMessage.decode(from: &copy, maxFrameLength: maxFrameLength)
            Issue.record("Expected \(kind) \(label)", sourceLocation: sourceLocation)
        } catch let error as NIODecodeError {
            #expect(error.kind == kind, "\(label): \(error)", sourceLocation: sourceLocation)
        } catch {
            Issue.record("Unexpected error \(error) \(label)", sourceLocation: sourceLocation)
        }
    }
}

// MARK: - Pipeline helpers

private func encode(_ frame: IRCFrame) throws -> ByteBuffer {
    let channel = EmbeddedChannel(handler: MessageToByteHandler(IRCFrameEncoder()))
    defer { _ = try? channel.finish() }
    try channel.writeOutbound(frame)
    return try #require(try channel.readOutbound(as: ByteBuffer.self))
}

private func decodeAll(_ buffer: ByteBuffer, _ decoder: IRCFrameDecoder) throws -> [IRCFrame] {
    let channel = EmbeddedChannel(handler: ByteToMessageHandler(decoder))
    defer { _ = try? channel.finish() }
    try channel.writeInbound(buffer)
    var frames: [IRCFrame] = []
    while let frame = try channel.readInbound(as: IRCFrame.self) {
        frames.append(frame)
    }
    return frames
}

private func decodeSingleBinary(_ buffer: ByteBuffer, _ decoder: IRCFrameDecoder) throws -> IRCBinaryMessage {
    let frames = try decodeAll(buffer, decoder)
    #expect(frames.count == 1)
    guard case .binary(let message)? = frames.first else {
        throw BinaryTestError.expectedBinary
    }
    return message
}

private enum BinaryTestError: Error {
    case expectedBinary
}
