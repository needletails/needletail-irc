//
//  IRCBinaryMessage.swift
//  needletail-irc
//
//  Created by NeedleTails on 10/9/26.
//

import Foundation
import struct NIOCore.ByteBuffer

/// An IRC-routed message whose body is opaque bytes rather than an RFC 1459 line.
///
/// `IRCBinaryMessage` is the binary sibling of ``IRCMessage``. It carries the same
/// envelope (origin, recipients, tags) so the server routes it exactly like a
/// `PRIVMSG`, but the body is a length-prefixed `Data` payload with no text
/// encoding, escaping, or 512-byte line limits.
///
/// ## Wire layout
/// ```
/// 0xFF                       discriminator (never a valid UTF-8 lead byte; outside DCC's 0...4)
/// UInt32  frameLength        byte count of everything after this field
/// UInt8   version            currently 1
/// 16B     id                 UUID bytes
/// UInt8   hasOrigin, [UInt32 len, UTF-8]
/// UInt16  recipientCount, N × [UInt32 len, UTF-8]
/// UInt16  tagCount,       N × [UInt32 len, UTF-8 key][UInt32 len, UTF-8 value]
/// UInt8   hasContentType, [UInt32 len, UTF-8]
/// UInt8   hasSequence,    [UInt32 len, UTF-8 groupId][UInt32 partNumber][UInt32 totalParts]
/// UInt32  payloadLength, bytes
/// ```
public struct IRCBinaryMessage: Codable, Sendable, IRCWireEncodable {

    /// Leading byte that identifies a binary frame on the server connection.
    public static let discriminator: UInt8 = 0xFF
    /// Wire layout version. Bump when the layout changes incompatibly.
    public static let wireVersion: UInt8 = 1

    /// Chunking metadata for payloads split across several frames.
    public struct Sequence: Codable, Sendable, Hashable {
        /// Groups all parts of one logical payload. Same role as `MultipartPacket.groupId`.
        public let groupId: String
        /// 1-based position of this part.
        public let partNumber: Int
        /// Total number of parts in the group.
        public let totalParts: Int

        public init(groupId: String, partNumber: Int, totalParts: Int) {
            self.groupId = groupId
            self.partNumber = partNumber
            self.totalParts = totalParts
        }
    }

    /// Unique identifier, used for tracking, deduplication, and equality.
    public var id: UUID = UUID()
    /// Sender, in the same `nick!user@host` or server-name form as ``IRCMessage/origin``.
    public var origin: String?
    /// Routing targets. Same type and semantics as `IRCCommand.privMsg`.
    public var recipients: [IRCMessageRecipient]
    /// Optional IRCv3 tags.
    public var tags: [IRCTag]?
    /// Application-defined type hint (MIME type or app-specific token). The IRC
    /// layer does not interpret it.
    public var contentType: String?
    /// Present when `payload` is one part of a larger transfer.
    public var sequence: Sequence?
    /// The opaque body.
    public var payload: Data

    public init(
        origin: String? = nil,
        recipients: [IRCMessageRecipient],
        tags: [IRCTag]? = nil,
        contentType: String? = nil,
        sequence: Sequence? = nil,
        payload: Data
    ) {
        self.origin = origin
        self.recipients = recipients
        self.tags = tags
        self.contentType = contentType
        self.sequence = sequence
        self.payload = payload
    }

    public var description: String {
        var output = "<IRCBinaryMessage:"
        if let origin { output += " from=\(origin)" }
        output += " to=\(recipients.map(\.stringValue).joined(separator: ","))"
        if let contentType { output += " type=\(contentType)" }
        if let sequence { output += " part=\(sequence.partNumber)/\(sequence.totalParts)" }
        output += " bytes=\(payload.count)>"
        return output
    }

    // MARK: - Codable (compact keys, matching IRCMessage)

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case origin = "a"
        case recipients = "b"
        case tags = "d"
        case contentType = "e"
        case sequence = "f"
        case payload = "g"
    }
}

extension IRCBinaryMessage: Equatable {
    public static func == (lhs: IRCBinaryMessage, rhs: IRCBinaryMessage) -> Bool {
        lhs.id == rhs.id
    }
}


extension IRCBinaryMessage {

    /// Size of the fixed header: discriminator (1) + frame length (4).
    static let headerLength = 1 + 4

    /// Writes a complete frame, or throws having written nothing.
    ///
    /// All validation happens first and the body is built in a scratch buffer, so a
    /// failure part-way through can never leave a partial frame on the socket.
    public func encode(into buffer: inout ByteBuffer) throws {
        // Same contract as PRIVMSG/NOTICE: a frame with nobody to route to is a caller bug.
        guard !recipients.isEmpty else {
            throw IRCMessageGeneratorError.emptyCommandRejected
        }
        guard payload.count <= Int(UInt32.max) else {
            throw NIODecodeError.malformed("Binary payload is too large to encode")
        }
        guard recipients.count <= Int(UInt16.max) else {
            throw NIODecodeError.malformed("Too many recipients")
        }
        guard (tags?.count ?? 0) <= Int(UInt16.max) else {
            throw NIODecodeError.malformed("Too many tags")
        }
        var encodedSequence: (part: UInt32, total: UInt32)?
        if let sequence {
            guard let part = UInt32(exactly: sequence.partNumber),
                  let total = UInt32(exactly: sequence.totalParts) else {
                throw NIODecodeError.malformed("Sequence values exceed UInt32")
            }
            encodedSequence = (part, total)
        }

        var body = ByteBuffer()
        body.writeInteger(Self.wireVersion)
        _ = withUnsafeBytes(of: id.uuid) { body.writeBytes($0) }

        try body.writeOptionalLengthPrefixedUTF8(origin)

        body.writeInteger(UInt16(recipients.count))
        for recipient in recipients {
            try body.writeLengthPrefixedUTF8(recipient.stringValue)
        }

        let tags = tags ?? []
        body.writeInteger(UInt16(tags.count))
        for tag in tags {
            try body.writeLengthPrefixedUTF8(tag.key)
            try body.writeLengthPrefixedUTF8(tag.value)
        }

        try body.writeOptionalLengthPrefixedUTF8(contentType)

        if let encodedSequence, let sequence {
            body.writeInteger(UInt8(1))
            try body.writeLengthPrefixedUTF8(sequence.groupId)
            body.writeInteger(encodedSequence.part)
            body.writeInteger(encodedSequence.total)
        } else {
            body.writeInteger(UInt8(0))
        }

        body.writeInteger(UInt32(payload.count))
        body.writeBytes(payload)

        guard body.readableBytes <= Int(UInt32.max) else {
            throw NIODecodeError.malformed("Binary frame is too large to encode")
        }

        // Nothing has touched `buffer` until here.
        buffer.writeInteger(Self.discriminator)
        buffer.writeInteger(UInt32(body.readableBytes))
        buffer.writeBuffer(&body)
    }

    /// Decodes one frame. Expects `buffer.readerIndex` to be at the discriminator byte.
    ///
    /// Only the header can report `incomplete`. Once `frameLength` bytes are present the
    /// body is fenced into its own slice, so a field whose declared length overruns the frame
    /// is `malformed` (the peer sent a bad frame), never `incomplete` (which would make the
    /// decoder wait for bytes that will never come, or read into the next frame).
    static func decode(
        from buffer: inout ByteBuffer,
        maxFrameLength: Int
    ) throws -> IRCBinaryMessage {
        guard let discriminator = buffer.readInteger(as: UInt8.self) else {
            throw NIODecodeError.incomplete("Missing discriminator")
        }
        guard discriminator == Self.discriminator else {
            throw NIODecodeError.malformed("Not a binary frame: \(discriminator)")
        }
        guard let frameLength = buffer.readInteger(as: UInt32.self) else {
            throw NIODecodeError.incomplete("Missing frame length")
        }
        guard Int(frameLength) <= maxFrameLength else {
            throw NIODecodeError.malformed("Binary frame exceeds configured limit")
        }
        guard var body = buffer.readSlice(length: Int(frameLength)) else {
            throw NIODecodeError.incomplete("Incomplete binary frame")   // decoder → needMoreData
        }

        let message: IRCBinaryMessage
        do {
            message = try decodeBody(&body, maxFieldLength: Int(frameLength))
        } catch let error as NIODecodeError where error.kind == .incomplete {
            throw NIODecodeError.malformed("Field overruns frame: \(error.message)")
        }

        guard body.readableBytes == 0 else {
            throw NIODecodeError.malformed("\(body.readableBytes) trailing byte(s) after payload")
        }
        return message
    }

    /// Decodes the versioned body. `body` must contain exactly one frame's worth of bytes.
    private static func decodeBody(
        _ body: inout ByteBuffer,
        maxFieldLength: Int
    ) throws -> IRCBinaryMessage {
        guard let version = body.readInteger(as: UInt8.self) else {
            throw NIODecodeError.incomplete("Missing version")
        }
        guard version == Self.wireVersion else {
            throw NIODecodeError.malformed("Unsupported binary frame version \(version)")
        }
        guard let uuidBytes = body.readBytes(length: 16) else {
            throw NIODecodeError.incomplete("Missing id")
        }
        let id = UUID(uuid: uuidBytes.withUnsafeBytes { $0.load(as: uuid_t.self) })

        let origin = try body.readOptionalLengthPrefixedUTF8(field: "origin", maxLength: maxFieldLength)

        guard let recipientCount = body.readInteger(as: UInt16.self) else {
            throw NIODecodeError.incomplete("Missing recipient count")
        }
        guard recipientCount > 0 else {
            throw NIODecodeError.malformed("Binary frame has no recipients")
        }
        var recipients: [IRCMessageRecipient] = []
        recipients.reserveCapacity(Int(recipientCount))
        for _ in 0..<recipientCount {
            let raw = try body.readLengthPrefixedUTF8(field: "recipient", maxLength: maxFieldLength)
            guard let recipient = IRCMessageRecipient(raw) else {
                throw NIODecodeError.malformed("Invalid recipient: \(raw.prefix(64))")
            }
            recipients.append(recipient)
        }

        guard let tagCount = body.readInteger(as: UInt16.self) else {
            throw NIODecodeError.incomplete("Missing tag count")
        }
        var tags: [IRCTag] = []
        tags.reserveCapacity(Int(tagCount))
        for _ in 0..<tagCount {
            let key = try body.readLengthPrefixedUTF8(field: "tag.key", maxLength: maxFieldLength)
            let value = try body.readLengthPrefixedUTF8(field: "tag.value", maxLength: maxFieldLength)
            tags.append(IRCTag(key: key, value: value))
        }

        let contentType = try body.readOptionalLengthPrefixedUTF8(field: "contentType", maxLength: maxFieldLength)

        var sequence: Sequence?
        guard let hasSequence = body.readInteger(as: UInt8.self) else {
            throw NIODecodeError.incomplete("Missing sequence flag")
        }
        switch hasSequence {
        case 0:
            break
        case 1:
            let groupId = try body.readLengthPrefixedUTF8(field: "groupId", maxLength: maxFieldLength)
            guard let part = body.readInteger(as: UInt32.self),
                  let total = body.readInteger(as: UInt32.self) else {
                throw NIODecodeError.incomplete("Missing sequence values")
            }
            sequence = Sequence(groupId: groupId, partNumber: Int(part), totalParts: Int(total))
        default:
            throw NIODecodeError.malformed("Invalid sequence presence flag \(hasSequence)")
        }

        guard let payloadLength = body.readInteger(as: UInt32.self) else {
            throw NIODecodeError.incomplete("Missing payload length")
        }
        guard Int(payloadLength) <= maxFieldLength else {
            throw NIODecodeError.malformed("Payload exceeds frame")
        }
        guard let bytes = body.readBytes(length: Int(payloadLength)) else {
            throw NIODecodeError.incomplete("Incomplete payload")
        }

        var message = IRCBinaryMessage(
            origin: origin,
            recipients: recipients,
            tags: tags.isEmpty ? nil : tags,
            contentType: contentType,
            sequence: sequence,
            payload: Data(bytes)
        )
        message.id = id
        return message
    }
}
