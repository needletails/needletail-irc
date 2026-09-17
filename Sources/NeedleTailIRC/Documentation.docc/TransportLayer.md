# Transport Layer

Integrate NeedleTailIRC with your NIO-based outbound pipeline.

## Overview

NeedleTailIRC does not open sockets or manage TLS. Your app owns connection lifecycle, line framing, and backpressure. This package provides:

- `NeedleTailIRCEncoder` / `NeedleTailIRCParser` for wire-format strings
- `IRCMessageGenerator` for multipart outbound framing
- `NeedleTailWriterDelegate` for writing encoded payloads through a `NIOAsyncChannelOutboundWriter`

## Outbound: IRCMessageGenerator + encoder

For most sends, generate one or more `IRCMessage` values, encode each to a line, and write through your transport:

```swift
let generator = IRCMessageGenerator(executor: executor)

let writer = MyIRCWriter()

try await writer.transportMessage(
    generator,
    executor: executor,
    logger: logger,
    writer: outboundWriter,
    origin: "alice!user@host",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], text),
    tags: nil,
    authPacket: nil
)
```

Or manually:

```swift
let stream = await generator.createMessages(
    origin: "alice",
    command: .join(channels: [NeedleTailChannel("#general")!], keys: nil),
    logger: logger
)

for try await message in stream {
    let line = NeedleTailIRCEncoder.encode(value: message)
    var buffer = ByteBuffer()
    buffer.writeString(line)
    buffer.writeString("\r\n")
    try await outboundWriter.write(.irc(message)) // or your IRCPayload wrapper
}
```

## NeedleTailWriterDelegate

Conforming types implement `sendAndFlushMessage` for your `OutboundOut` type (typically `IRCPayload`). The protocol extension provides a default `transportMessage` that:

1. Calls `IRCMessageGenerator.createMessages(...)`
2. Encodes and writes each chunk via `sendAndFlushMessage`

```swift
final class MyIRCWriter: NeedleTailWriterDelegate {
    func sendAndFlushMessage<OutboundOut>(
        executor: (any AnyExecutor)?,
        logger: NeedleTailLogger,
        writer: NIOAsyncChannelOutboundWriter<OutboundOut>,
        message: OutboundOut
    ) async throws {
        try await writer.write(message)
    }
}
```

## Inbound: parse and reassemble

Read CRLF-delimited lines from your NIO inbound handler, then parse and optionally reassemble multipart chunks:

```swift
let generator = IRCMessageGenerator(executor: executor)

func handleLine(_ line: String) async throws {
    let message = try NeedleTailIRCParser.parseMessage(line)

    if let complete = try await generator.messageReassembler(ircMessage: message) {
        await processCompleteMessage(complete)
    }
}
```

For untrusted standard-IRC connections, parse with explicit tag limits:

```swift
let message = try NeedleTailIRCParser.parseMessage(
    line,
    limits: .standardIRC
)
```

## Binary DirectMessage framing

Use `IRCPayloadDecoder.withBinaryFrames()` only on peer connections that carry
`DirectMessage` values. Multipart `groupId` and message fields are UInt32
length-prefixed UTF-8, and binary lengths are bounded before allocation. The
line-only factory avoids interpreting a leading byte in `0...4` as a binary
discriminator:

```swift
let ircDecoder = IRCPayloadDecoder.lineBasedIRC()
let peerDecoder = IRCPayloadDecoder.withBinaryFrames(
    maxBinaryFrameLength: 8 * 1024 * 1024
)
```

## Line length and interoperability

The encoder does not hard-cap output at 512 bytes. NeedleTail transports may allow larger lines (for example base64 `packet-metadata` tags). When integrating with standard IRC servers:

- Use `IRCMessageGenerator` to chunk large application payloads
- Enforce line limits in your transport before writing to the socket
- Document deployment-specific limits for your operators

## What this package does not provide

- TCP/TLS connection setup
- SASL or CAP negotiation
- Connection registration state machines
- Rate limiting or flood protection

Build those in your client or server target on top of this protocol layer.

`IRCEventProtocol` provides no-op defaults so integrations can adopt callbacks
incrementally. Override every callback that is meaningful to your application;
an unimplemented callback is intentionally ignored.
