<img src="needletail_irc.svg" alt="NeedleTailIRC" width="200" />

# NeedleTailIRC

A Swift package for parsing, encoding, and framing IRC (Internet Relay Chat) messages with modern concurrency support. It speaks the NeedleTail dialect by default and standard RFC 1459 / RFC 2812 IRC with IRCv3 as an opt-in.

[![Swift](https://img.shields.io/badge/Swift-6.4+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B%20%7C%20macOS%2015%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

NeedleTailIRC is a type-safe IRC protocol layer for the NeedleTail stack. It covers message parsing and encoding, IRCv3 message tags, multipart text chunking, length-prefixed binary frames, self-delimiting DCC frames, and NIO pipeline integration.

It ships two wire dialects:

- **NeedleTail** (default): what NeedleTail clients and servers speak to each other. `IRCFrameDecoder`, `IRCFrameEncoder`, `NeedleTailIRCParser` and `NeedleTailIRCEncoder`.
- **Standard IRC / IRCv3** (opt-in): for any RFC-compliant server, such as Solanum, InspIRCd, UnrealIRCd, Ergo or ngIRCd. Install it with `addStandardIRCHandlers()`.

Choosing the standard dialect on one connection changes nothing for NeedleTail connections. Both can run in the same process.

NeedleTailIRC does **not** manage sockets or TLS. You bring the transport (usually `NIOPosix` plus `NIOSSL`) and add NeedleTailIRC's handlers to your pipeline.

## Features

**Shared**

- **Type-safe commands and models**: `IRCCommand`, `IRCMessage`, `NeedleTailChannel`, `NeedleTailNick`, `IRCTag` and related types
- **IRCv3 message tags**: parsing, escaping and round-trip encoding
- **One socket unit**: `IRCFrame` is `.text(IRCMessage)`, `.binary(IRCBinaryMessage)` or `.dcc(DCCMessage)`

**NeedleTail dialect**

- **Parse and encode**: `NeedleTailIRCParser` and `NeedleTailIRCEncoder`
- **Multipart text framing**: `IRCMessageGenerator` and `PacketBuilder` for large text payloads (`packet-metadata` tags)
- **Binary payloads**: `IRCBinaryMessage` carries opaque bytes on the server connection without base64 or line limits
- **DCC frames**: bounded, self-delimiting `DCCMessage` frames (not a full file-transfer client)
- **NIO integration**: `IRCFrameEncoder`, `IRCFrameDecoder` and `NeedleTailWriterDelegate`
- **NeedleTail extensions**: custom commands in `Constants` for blob sync, media and device workflows

**Standard IRC / IRCv3 dialect (opt-in)**

- **One-call pipeline**: `addStandardIRCHandlers()` swaps in the standard codec. Existing `IRCFrame` handlers keep working.
- **Lossless messages**: `IRCRawMessage` keeps tags, source, command and every parameter exactly as sent
- **Translation**: `IRCStandardTranslator` maps standard messages onto `IRCCommand` and back, and never drops a valid line
- **Registration**: `IRCRegistration` handles `CAP LS 302`, SASL, `NICK`/`USER`, nick collisions, `PING` and ISUPPORT
- **IRCv3**: capability negotiation with `cap-notify`, SASL `PLAIN`/`EXTERNAL`, batches, server-time, msgid, account and label tags, client-only tags
- **Server awareness**: `IRCISupport` (005), `IRCCaseMapping`, `IRCModeParser`, membership prefixes for `NAMES`
- **Messaging helpers**: standard CTCP (`IRCCTCPMessage`) and splitting text to the 512-byte limit (`IRCStandardTextSplitter`)
- **Keepalive**: optional automatic `PONG` and dead-connection detection (`IRCStandardKeepAliveHandler`)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/needletails/needletail-irc.git", from: "2.1.0")
]
```

Then add `"NeedleTailIRC"` to your target's dependencies. The standard IRC support needs 2.1.0 or later. The NeedleTail dialect works the same as in 2.0.0.

### Xcode

1. Go to **File** → **Add Package Dependencies**
2. Enter `https://github.com/needletails/needletail-irc.git`
3. Choose the version
4. Add `NeedleTailIRC` to your target

## NeedleTail dialect

### Basic usage

```swift
import NeedleTailIRC

// Create an IRC message
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, world!")
)

// Parse an IRC message string
let parsedMessage = try NeedleTailIRCParser.parseMessage(
    ":alice!alice@localhost PRIVMSG #general :Hello, world!"
)

// Encode a message to its wire form (synchronous)
let encodedString = NeedleTailIRCEncoder.encode(value: message)
```

### Sending large messages

`IRCMessageGenerator` splits oversized payloads into multipart IRC messages. Reassemble inbound chunks with `messageReassembler(ircMessage:)`.

```swift
let generator = IRCMessageGenerator(executor: executor)
let stream = await generator.createMessages(
    origin: "alice!user@host",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], largePayload),
    logger: NeedleTailLogger()
)

for try await message in stream {
    try await writer.write(.text(message))
}

// On receive:
if let rebuilt = try await generator.messageReassembler(ircMessage: incomingMessage) {
    await handleMessage(rebuilt)
}
```

> **Note:** The NeedleTail codec does not enforce the classic 512-byte line limit, because NeedleTail deployments use larger lines. `IRCMessageGenerator` output is NeedleTail-specific. Standard servers do not understand `packet-metadata` multipart packets, so use `IRCStandardTextSplitter` on standard connections.

### Channel operations

```swift
// Join a channel
let joinCommand = IRCCommand.join(
    channels: [NeedleTailChannel("#general")!],
    keys: nil
)

// Send a message to a channel
let message = IRCMessage(
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, everyone!")
)

// Set channel modes
let modeCommand = IRCCommand.channelMode(
    NeedleTailChannel("#general")!,
    addMode: .inviteOnly,
    addParameters: nil,
    removeMode: nil,
    removeParameters: nil
)
```

### User operations

```swift
// Change nickname
let nickCommand = IRCCommand.nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)

// Set user mode
let modeCommand = IRCCommand.mode(
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    add: [.invisible, .away],
    remove: nil
)

// Get user information
let whoisCommand = IRCCommand.whois(server: nil, usermasks: ["alice"])
```

## Standard IRC / IRCv3

### Plug in, keep your `IRCFrame` code

`addStandardIRCHandlers()` replaces `IRCFrameDecoder` / `IRCFrameEncoder`. Everything after it still reads and writes `IRCFrame`, so existing handlers and `NIOAsyncChannel<IRCFrame, IRCFrame>` consumers work unchanged.

```swift
import NIOCore
import NIOPosix
import NeedleTailIRC

let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
    .connect(host: "irc.example.net", port: 6667) { channel in
        channel.eventLoop.makeCompletedFuture {
            // Add TLS here first if you use it.
            try channel.pipeline.syncOperations.addStandardIRCHandlers()
            return try NIOAsyncChannel<IRCFrame, IRCFrame>(wrappingChannelSynchronously: channel)
        }
    }

try await channel.executeThenClose { inbound, outbound in
    try await outbound.write(.text(IRCMessage(command: .join(channels: [NeedleTailChannel("#swift")!], keys: nil))))
    for try await frame in inbound {
        guard case .text(let message) = frame else { continue }
        // `message` is an ordinary IRCMessage, translated the standard way.
    }
}
```

`IRCStandardConfiguration` controls the extras:

```swift
var configuration = IRCStandardConfiguration()
configuration.rawObserver = { raw, typed in
    // The lossless message next to the typed one, e.g. a PART reason.
}
configuration.unparsableLineHandler = { line, error in
    // Lines that are not valid IRC. They are skipped; the connection continues.
}
configuration.keepAlive = IRCStandardKeepAliveConfiguration()  // automatic PONG + dead-connection detection
try channel.pipeline.syncOperations.addStandardIRCHandlers(configuration: configuration)
```

Keepalive is off by default, because most applications already answer `PING`.

### Raw messages and registration

New code can work with `IRCRawMessage` directly and let `IRCRegistration` handle the handshake:

```swift
let channel = try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
    .connect(host: "irc.example.net", port: 6697) { channel in
        channel.eventLoop.makeCompletedFuture {
            // try channel.pipeline.syncOperations.addHandler(tlsHandler)
            try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(IRCStandardLineDecoder()))
            try channel.pipeline.syncOperations.addHandler(MessageToByteHandler(IRCRawMessageEncoder()))
            return try NIOAsyncChannel<IRCRawMessage, IRCRawMessage>(wrappingChannelSynchronously: channel)
        }
    }

try await channel.executeThenClose { inbound, outbound in
    var registration = IRCRegistration(configuration: .init(
        nick: "alice",
        username: "alice",
        realname: "Alice",
        alternativeNicks: ["alice_"],
        sasl: .plain(username: "alice", password: password)
    ))
    try await outbound.write(contentsOf: registration.start())

    for try await message in inbound {
        // Answers PING, negotiates CAP, runs SASL, retries taken nicks, reads 005.
        try await outbound.write(contentsOf: registration.handle(message))
        if let failure = registration.failure { throw failure }
        guard registration.isRegistered else { continue }

        if let ctcp = message.ctcp, ctcp.command == "VERSION", let from = message.sourceComponents?.nick {
            try await outbound.write(.ctcpReply(IRCCTCPMessage(command: "VERSION", argument: "MyClient 1.0"), to: from))
        }
        let typed = IRCMessage(standardIRC: message)   // the typed view, when you want it
    }
}
```

`IRCCapabilityNegotiator` and `IRCSASLAuthenticator` can also be used on their own. All three are value types with no I/O: you feed them messages and send what they return.

### Building and reading messages

```swift
let raw = try IRCRawMessage.parse(":srv 433 * alice :Nickname is already in use")
raw.numeric             // 433
raw.parameters          // ["*", "alice", "Nickname is already in use"]

try IRCRawMessage(command: "WHOWAS", parameters: ["bob", "5"]).wireLine()
// "WHOWAS bob 5"

// Typed messages, written the standard way
try IRCMessage(command: .otherCommand("WHOWAS", ["bob", "5"])).standardIRCWireLine()
// "WHOWAS bob 5"

// Long text, split to fit 512 bytes without breaking characters
let lines = IRCStandardTextSplitter.split(longText, target: "#swift")

// Server features from 005
var isupport = IRCISupport()
isupport.apply(raw)                                  // non-005 messages are ignored
isupport.caseMapping.equals("Bob[1]", "bob{1}")
isupport.splitMembershipPrefixes("~@carol")          // ([q, o], "carol")

// Any MODE line, with every parameter paired to its letter
IRCModeParser.channelModeChanges(from: modeMessage, isupport: isupport)

// IRCv3 tags
message.serverTime      // Date?
message.messageID       // msgid
message.account         // account-tag
```

### How the dialects differ

| | NeedleTail (default) | Standard IRC (opt-in) |
|---|---|---|
| Pipeline | `IRCFrameDecoder` / `IRCFrameEncoder` | `addStandardIRCHandlers()` |
| Parsing | `NeedleTailIRCParser` | `IRCRawMessage.parse` + `IRCStandardTranslator` |
| Numeric and `otherCommand` arguments | Comma-joined into one trailing parameter | RFC parameters, one per value |
| Nicknames | Lowercased, no `_`, `name_UUID` device form | Case kept, `_` allowed |
| Lines that fail to parse | Dropped with a warning | Reported to `unparsableLineHandler`; never stalls |
| Binary and DCC frames | Supported | Rejected (`unsupportedFrame`) |
| Default max line length | 32 MB | 8,703 bytes (512 + IRCv3 tags) |
| Long text | `IRCMessageGenerator` (multipart packets) | `IRCStandardTextSplitter` |

### Typed model limits

The standard dialect reuses the existing types without changing them, so a few things only show up in the raw form:

- `NeedleTailNick` needs at least two characters. Messages involving one-character nicks arrive as `.otherCommand`.
- Channel names longer than 50 characters arrive as `.otherCommand`.
- `.part` has no reason and `.join` has no extended-join fields. Read them through `rawObserver`.
- CAP `NEW`/`DEL` and multi-line `LS` continuations arrive as `.otherCommand("CAP", …)`.
- Channel `MODE` maps to `.channelMode` only when every parameter can stay paired with its letter. Otherwise use `IRCModeParser`.
- `IRCUserIdentifier` lowercases nicks. Use `IRCSource` with `IRCISupport.caseMapping` instead.
- Commands with no portable form (DCC/SDCC, `.quiet`, `.owner`, `.kickban`, `.clearmode`, …) throw `unsupportedOnStandardIRC`. Send `.otherCommand("MODE", …)` with the server's own mode letter instead.

## Architecture

### Core components

- **Commands and models**: `IRCCommand`, `IRCMessage`, channels, nicks, tags, permissions and error types
- **NeedleTail dialect**: `NeedleTailIRCParser`, `NeedleTailIRCEncoder`, `IRCFrameDecoder`, `IRCFrameEncoder`, `IRCMessageGenerator`, `PacketBuilder`, `MultipartPacket`, `NeedleTailWriterDelegate`
- **Standard dialect**: `IRCRawMessage`, `IRCStandardTranslator`, `IRCStandardLineDecoder`, `IRCRawMessageEncoder`, `IRCStandardInboundBridge`, `IRCStandardFrameEncoder`, `IRCStandardKeepAliveHandler`
- **Standard session helpers**: `IRCRegistration`, `IRCCapabilityNegotiator`, `IRCSASLAuthenticator`, `IRCISupport`, `IRCCaseMapping`, `IRCModeParser`, `IRCBatchCollector`, `IRCCTCPMessage`, `IRCStandardTextSplitter`

### Key types

- `IRCMessage`: typed IRC message
- `IRCCommand`: type-safe command enum
- `IRCFrame`: one socket unit (text, binary or DCC)
- `NeedleTailChannel`: validated channel name
- `NeedleTailNick`: validated nickname, with an optional device UUID suffix
- `IRCTag`: IRCv3 message tag
- `IRCRawMessage`: lossless standard IRC message
- `IRCRegistration`: standard client registration state machine

## Error handling

NeedleTail dialect:

```swift
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    // Process the message
} catch NeedleTailError.invalidIRCChannelName {
    print("Invalid channel name")
} catch NeedleTailError.nilNickName {
    print("Invalid nickname")
} catch MessageParsingErrors.invalidArguments(let details) {
    print("Invalid arguments: \(details)")
} catch MessageParsingErrors.invalidTag {
    print("Invalid tag format")
} catch {
    print("Unknown parsing error: \(error)")
}
```

Standard dialect errors are `IRCStandardError`. It's a struct, so new codes never break your `switch`. Match on `code`:

```swift
let message = IRCRawMessage(command: "PRIVMSG", parameters: ["#c", userText])
do {
    _ = try message.wireLine()   // validate before handing it to the pipeline
    try await outbound.write(message)
} catch let error as IRCStandardError where error.code == .forbiddenCharacter {
    // CR, LF or NUL in user text: rejected instead of sent, so it cannot inject commands.
}
```

An invalid message that reaches the pipeline unvalidated fails inside the encoder and is reported through the channel's error handling, not as an error from `write`.

## API and wire semantics

- `NeedleTailNick.stringValue` emits `name_UUID` when a device identifier exists and plain `name` otherwise.
- `IRCUserIdentifier.stringValue` emits `nick[!user][@host]`.
- `IRCMessage` and `IRCBinaryMessage` equality is identity-based (`id`). `IRCTag` equality is key-based. `IRCRawMessage` equality compares every field, including tag values. Compare protocol fields explicitly when you need value equality on the typed model.
- `NeedleTailIRCParser.parseMessage(_:)` keeps the historical unbounded tag behaviour. Use `parseMessage(_:limits:)` with `.standardIRC` for untrusted input. `IRCRawMessage.parse` and the standard pipeline apply `.standardIRC` limits by default.
- A NeedleTail socket speaks `IRCFrame`. The leading byte selects the family: `0xFF` is `IRCBinaryMessage`, `0x00...0x04` is `DCCMessage`, anything else is an `IRCMessage` line.
- Every variable-length `DCCMessage` field, including `serviceName`, is `UInt32` length-prefixed. `serviceName` changed in 2.0.0, so both ends of a DCC connection must update together.
- Choose a NeedleTail decoder per socket: `lineBasedIRC()` (text only), `serverIRC()` (text plus binary, no DCC), `withBinaryFrames()` (all three). For standard servers, use `addStandardIRCHandlers()`.
- `createMessages` still chunks large text into base64 `packet-metadata` tags. Application payloads that should avoid that overhead belong in `IRCBinaryMessage`.
- `IRCRawMessage.parse` is lenient (repeated spaces, more than 15 parameters). `wireLine()` is strict: it rejects NUL, CR and LF in every field, invalid middle parameters, and more than 15 parameters.
- `IRCEventProtocol` supplies no-op defaults for every callback. Override every event your integration needs.

## Testing

```bash
swift test
```

`NeedleTailUnchangedTests` holds a golden snapshot of what the NeedleTail parser, encoder and frame decoder produce. It guards the default dialect against accidental changes. If a change to that output is intentional, regenerate the snapshot and paste the printed values into the test:

```bash
NTIRC_CAPTURE_GOLDEN=1 swift test --filter NeedleTailUnchangedTests
```

`StandardIRCCorpusTests` runs whole sessions in the style of Solanum, InspIRCd, UnrealIRCd, Ergo and ngIRCd through every layer of the standard dialect. The transcripts are hand-written in each server's style, not packet captures.

## Documentation

Release history is in [CHANGELOG.md](CHANGELOG.md). API documentation lives in [Documentation.docc](Sources/NeedleTailIRC/Documentation.docc):

- [Getting Started](Sources/NeedleTailIRC/Documentation.docc/GettingStarted.md): installation and first messages
- [Basic Usage](Sources/NeedleTailIRC/Documentation.docc/BasicUsage.md): core concepts and patterns
- [Message Format](Sources/NeedleTailIRC/Documentation.docc/MessageFormat.md): IRC message structure
- [Message Handling](Sources/NeedleTailIRC/Documentation.docc/MessageHandling.md): processing messages
- [IRC Commands](Sources/NeedleTailIRC/Documentation.docc/IRCCommands.md): command reference
- [Channels](Sources/NeedleTailIRC/Documentation.docc/Channels.md): channel management
- [Users](Sources/NeedleTailIRC/Documentation.docc/Users.md): user management and permissions
- [Multipart Messages](Sources/NeedleTailIRC/Documentation.docc/MultipartMessages.md): large message handling
- [Transport Layer](Sources/NeedleTailIRC/Documentation.docc/TransportLayer.md): NIO writer integration
- [Standard IRC and IRCv3](Sources/NeedleTailIRC/Documentation.docc/StandardIRC.md): the opt-in standard dialect
- [Error Handling](Sources/NeedleTailIRC/Documentation.docc/ErrorHandling.md): error types and strategies
- [API Reference](Sources/NeedleTailIRC/Documentation.docc/APIReference.md): public API overview

## Requirements

- **Swift**: 6.4+
- **Platforms**: iOS 18.0+, macOS 15.0+
- **Xcode**: 27.0+ (for Apple platform development)

## Dependencies

NeedleTailIRC pulls in:

- `swift-nio`: NIOCore
- `swift-algorithms`: algorithm utilities
- `swift-log`: logging API used by transport integration
- `needletail-logger`: logging
- `needletail-algorithms`: NeedleTailAsyncSequence and related utilities
- `binary-codable`: binary serialization for `packet-metadata` and auth tags on the text path

The standard dialect adds no dependencies. Your app supplies the transport, typically `NIOPosix` and `NIOSSL`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

## Support

- **Documentation**: [Documentation.docc](Sources/NeedleTailIRC/Documentation.docc)
- **Issues**: [GitHub Issues](https://github.com/needletails/needletail-irc/issues)

## Acknowledgments

- IRC protocol specifications (RFC 1459, RFC 2811, RFC 2812)
- IRCv3 extension specifications
- The Swift community
