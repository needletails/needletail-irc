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

### Core Concepts

- <doc:BasicUsage>

- <doc:MessageFormat>

- <doc:MessageHandling>

### IRC Operations

- <doc:IRCCommands>

- <doc:Channels>

- <doc:Users>

### Advanced Features

- <doc:MultipartMessages>

- <doc:TransportLayer>

### Error Handling

- <doc:ErrorHandling>

### API Reference

- <doc:APIReference>
