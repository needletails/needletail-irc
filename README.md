<img src="needletail_irc.svg" alt="NeedleTailIRC" width="200" />

# NeedleTailIRC

A Swift package for parsing, encoding, and framing IRC (Internet Relay Chat) messages with modern concurrency support.

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B%20%7C%20macOS%2015%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

NeedleTailIRC is a type-safe IRC protocol layer for the NeedleTail stack. It covers message parsing and encoding (RFC 2812, RFC 1459), IRCv3 message tags, multipart payload chunking, and NIO writer integration. It does **not** include socket/TLS connection management — you provide the transport and wire encoded lines through your own NIO pipeline or app layer.

## Features

- **Parse & encode IRC wire format**: `NeedleTailIRCParser` and `NeedleTailIRCEncoder`
- **IRCv3 message tags**: Tag parsing, escaping, and round-trip encoding
- **Type-safe commands & models**: `IRCCommand`, `NeedleTailChannel`, `NeedleTailNick`, and related types
- **Multipart framing**: `IRCMessageGenerator` and `PacketBuilder` for large payload chunking and reassembly
- **DCC command representation**: Encode/decode DCC-related IRC commands (not a full file-transfer client)
- **NIO integration**: `NeedleTailWriterDelegate` for sending framed messages through `NIOAsyncChannelOutboundWriter`
- **NeedleTail extensions**: Custom commands in `Constants` for blob sync, media, and device workflows

## Quick Start

### Installation

Add NeedleTailIRC to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/needletails/needletail-irc.git", from: "1.0.0")
]
```

### Basic Usage

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

// Encode a message to string format (synchronous)
let encodedString = NeedleTailIRCEncoder.encode(value: message)
```

### Sending Large Messages

`IRCMessageGenerator` splits oversized payloads into multipart IRC messages. Reassemble inbound chunks with `messageReassembler(ircMessage:)`.

```swift
let generator = IRCMessageGenerator(executor: executor)
let stream = await generator.createMessages(
    origin: "alice!user@host",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], largePayload),
    logger: NeedleTailLogger()
)

for await message in stream {
    let line = NeedleTailIRCEncoder.encode(value: message)
    // Write `line` through your NIO outbound writer or socket layer.
}

// On receive:
if let rebuilt = try await generator.messageReassembler(ircMessage: incomingMessage) {
    await handleMessage(rebuilt)
}
```

> **Note:** The codec does not enforce the classic 512-byte IRC line limit. Some NeedleTail deployments use larger lines; when talking to standard IRC networks, chunk payloads with `IRCMessageGenerator` and validate wire size in your transport layer.

## Architecture

### Core Components

- **Parsing**: `NeedleTailIRCParser` — raw IRC strings to `IRCMessage`
- **Encoding**: `NeedleTailIRCEncoder` — `IRCMessage` to wire-format strings
- **Commands**: `IRCCommand` — typed representation of IRC commands and numerics
- **Models**: Channels, nicks, tags, permissions, and error types
- **Multipart**: `IRCMessageGenerator`, `PacketBuilder`, `MultipartPacket`
- **Transport hook**: `NeedleTailWriterDelegate` — bridges message generation to NIO writers

### Key Types

- `IRCMessage` — complete IRC message representation
- `IRCCommand` — type-safe IRC command enum
- `NeedleTailChannel` — validated channel name
- `NeedleTailNick` — validated nickname (with optional device UUID suffix)
- `IRCTag` — IRCv3 message tag
- `IRCMessageGenerator` — multipart encode path
- `NeedleTailWriterDelegate` — NIO outbound transport helper

## Examples

### Channel Operations

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

### User Operations

```swift
// Change nickname
let nickCommand = IRCCommand.nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)

// Set user mode
let modeCommand = IRCCommand.mode(
    nick: NeedleTailNick(name: "alice", deviceId: UUID())!,
    add: [.invisible, .away],
    remove: nil
)

// Get user information
let whoisCommand = IRCCommand.whois(server: nil, usermasks: ["alice"])
```

### Multipart Messages

```swift
let generator = IRCMessageGenerator(executor: executor)
let stream = await generator.createMessages(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], largeMessage),
    logger: NeedleTailLogger()
)

for await chunk in stream {
    let line = NeedleTailIRCEncoder.encode(value: chunk)
    try await writeToTransport(line)
}
```

## Error Handling

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

## Documentation

Documentation lives in [Documentation.docc](Sources/NeedleTailIRC/Documentation.docc):

- [Getting Started](Sources/NeedleTailIRC/Documentation.docc/GettingStarted.md) — installation and first messages
- [Basic Usage](Sources/NeedleTailIRC/Documentation.docc/BasicUsage.md) — core concepts and patterns
- [Message Format](Sources/NeedleTailIRC/Documentation.docc/MessageFormat.md) — IRC message structure
- [Message Handling](Sources/NeedleTailIRC/Documentation.docc/MessageHandling.md) — processing messages
- [IRC Commands](Sources/NeedleTailIRC/Documentation.docc/IRCCommands.md) — command reference
- [Channels](Sources/NeedleTailIRC/Documentation.docc/Channels.md) — channel management
- [Users](Sources/NeedleTailIRC/Documentation.docc/Users.md) — user management and permissions
- [Multipart Messages](Sources/NeedleTailIRC/Documentation.docc/MultipartMessages.md) — large message handling
- [Transport Layer](Sources/NeedleTailIRC/Documentation.docc/TransportLayer.md) — NIO writer integration
- [Error Handling](Sources/NeedleTailIRC/Documentation.docc/ErrorHandling.md) — error types and strategies
- [API Reference](Sources/NeedleTailIRC/Documentation.docc/APIReference.md) — public API overview

## Requirements

- **Swift**: 6.0+
- **Platforms**: iOS 18.0+, macOS 15.0+
- **Xcode**: 15.0+ (for Apple platform development)

## Dependencies

NeedleTailIRC pulls in:

- `swift-nio` — NIOCore, NIOConcurrencyHelpers
- `swift-algorithms` — algorithm utilities
- `swift-async-algorithms` — async algorithm support
- `swift-collections` — DequeModule
- `needletail-logger` — logging
- `needletail-algorithms` — NeedleTailAsyncSequence and related utilities
- `binary-codable` — binary serialization for packet metadata

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/needletails/needletail-irc.git", from: "1.0.0")
]
```

### Xcode

1. Go to **File** → **Add Package Dependencies**
2. Enter: `https://github.com/needletails/needletail-irc.git`
3. Select the version you want
4. Add to your target

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Support

- **Documentation**: [Documentation.docc](Sources/NeedleTailIRC/Documentation.docc)
- **Issues**: [GitHub Issues](https://github.com/needletails/needletail-irc/issues)

## Acknowledgments

- IRC protocol specifications (RFC 2812, RFC 1459)
- IRCv3 extension specifications
- The Swift community
