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
    try await outboundWriter.write(.text(message)) // IRCFrame
}
```

## NeedleTailWriterDelegate

Conforming types implement `sendAndFlushMessage` for your `OutboundOut` type (typically `IRCFrame`). The protocol extension provides a default `transportMessage` that:

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

## Frames and wire contracts

Everything on a NeedleTail IRC socket is an `IRCFrame`. The leading byte selects the family:

| First byte | Frame | Payload type | Framing |
|---|---|---|---|
| `0xFF` | `.binary` | `IRCBinaryMessage` | `UInt32` frame length, versioned body |
| `0x00...0x04` | `.dcc` | `DCCMessage` | discriminator + case-specific body |
| anything else | `.text` | `IRCMessage` | `\r?\n`-terminated RFC 1459 line |

Each payload type owns its own wire contract through `IRCWireEncodable` and a matching
`static decode(from:…)`; `IRCFrameEncoder` and `IRCFrameDecoder` are thin NIO adapters.
You can encode or decode without a pipeline:

```swift
var buffer = ByteBuffer()
try IRCFrame.text(message).encode(into: &buffer)      // or message.encode(into:)
try IRCFrame.binary(binaryMessage).encode(into: &buffer)
```

Error policy differs by family on purpose. A malformed text line is consumed and reported
as `IRCMessage.IgnoredLine` (the next newline resynchronises the stream). A malformed
binary frame throws and should close the connection (there is no delimiter to resync on).
All binary lengths are bounded before allocation.

## Choosing a decoder per socket

`IRCFrameDecoder.BinaryFraming` controls which binary families a socket will recognise.
Anything not enabled is framed as text:

```swift
// Server client listener: routes IRCBinaryMessage, must never interpret 0...4 as DCC.
let server = IRCFrameDecoder.serverIRC()

// Client pipelines: talk to the server and may open DCC.
let client = IRCFrameDecoder.withBinaryFrames(maxBinaryFrameLength: 8 * 1024 * 1024)

// Pure text sockets (SFU signaling, mock servers).
let textOnly = IRCFrameDecoder.lineBasedIRC()
```

`IRCBinaryMessage` carries the same envelope as a `PRIVMSG` (`origin`, `recipients`,
`tags`) so the server routes it with the same logic, plus an opaque `payload`, an optional
`contentType` hint, and an optional `sequence` for payloads split across frames.

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
