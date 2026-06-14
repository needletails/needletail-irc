# ``NeedleTailIRC``

A Swift package for parsing, encoding, and framing IRC messages with modern concurrency support.

## Overview

NeedleTailIRC is a type-safe IRC protocol layer for the NeedleTail stack. It handles message parsing and encoding (RFC 2812, RFC 1459), IRCv3 tags, multipart payload chunking, and NIO writer integration. Socket and TLS connectivity live in your application — not in this package.

The SDK offers:

- **Parse & encode**: `NeedleTailIRCParser` and `NeedleTailIRCEncoder`
- **IRCv3 tags**: Message tag parsing and escaping
- **Modern Swift concurrency**: `IRCMessageGenerator` and `PacketBuilder` actors
- **Type-safe API**: `IRCCommand`, channels, nicks, permissions
- **Multipart framing**: Large payload chunking and reassembly
- **DCC command types**: Wire-format encode/decode for DCC-related commands
- **NIO hooks**: `NeedleTailWriterDelegate` for outbound integration

## Quick Start

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

// Encode a message to string format
let encodedString = NeedleTailIRCEncoder.encode(value: message)
```

## Topics

### Getting Started

- <doc:GettingStarted>
Installation and your first IRC messages.

### Core Concepts

- <doc:BasicUsage>
Fundamental concepts and usage patterns.

- <doc:MessageFormat>
IRC message structure and formatting.

- <doc:MessageHandling>
Processing incoming and outgoing messages.

### IRC Operations

- <doc:IRCCommands>
IRC commands and numerics.

- <doc:Channels>
Channel naming, validation, and operations.

- <doc:Users>
Nicknames, user modes, and permissions.

### Advanced Features

- <doc:MultipartMessages>
Chunking and reassembling large payloads.

- <doc:TransportLayer>
NIO writer integration (no built-in sockets).

### Error Handling

- <doc:ErrorHandling>
Error types and handling strategies.

### API Reference

- <doc:APIReference>
Public API overview.
