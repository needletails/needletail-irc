# NeedleTailIRC

A comprehensive Swift SDK for implementing IRC (Internet Relay Chat) protocol functionality with modern Swift concurrency features.

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B%20%7C%20macOS%2015%2B-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

NeedleTailIRC is a production-ready Swift package that provides a complete implementation of the IRC protocol (RFC 2812, RFC 1459) with support for IRCv3 extensions. It's designed for building IRC clients, servers, and bots with a focus on type safety, performance, and modern Swift features.

## Features

- **Full IRC Protocol Support**: Complete implementation of RFC 2812 and RFC 1459 standards
- **IRCv3 Extensions**: Support for modern IRC extensions including message tags and capabilities
- **Modern Swift Concurrency**: Built with async/await, actors, and structured concurrency
- **Type-Safe API**: Strongly typed interfaces for all IRC operations
- **Multipart Message Support**: Built-in support for large message chunking and reassembly
- **DCC Protocol**: Direct Client-to-Client file transfer and chat capabilities
- **Channel Management**: Comprehensive channel operations and permissions
- **User Management**: Complete user mode and permission handling
- **Error Handling**: Robust error handling with detailed error types
- **Logging Integration**: Built-in logging with NeedleTailLogger
- **BSON Serialization**: Efficient binary serialization for metadata
- **Transport Layer**: Flexible transport protocol abstraction

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
let parsedMessage = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello, world!")

// Encode a message to string format
let encodedString = await NeedleTailIRCEncoder.encode(value: message)
```

### Connection Management

```swift
// Create transport layer
let transport = TLSTransport(host: "irc.example.com", port: 6697)
try await transport.connect()

// Process incoming messages
for await data in transport.receiveStream {
    let messageString = String(data: data, encoding: .utf8) ?? ""
    let message = try NeedleTailIRCParser.parseMessage(messageString)
    await handleMessage(message)
}

// Send messages
let message = IRCMessage(command: .join(channels: [NeedleTailChannel("#general")!], keys: nil))
let encoded = await NeedleTailIRCEncoder.encode(value: message)
try await transport.send(encoded.data(using: .utf8)!)
```

## Standard IRC Ports

The standard ports to run the IRC protocol on are:
- **Port 6667**: Unencrypted traffic
- **Port 6697**: TLS/SSL encrypted connections

## Architecture

The SDK is organized into several key components:

### Core Components

- **Parsing**: `NeedleTailIRCParser` for parsing raw IRC messages
- **Encoding**: `NeedleTailIRCEncoder` for encoding messages to IRC format
- **Commands**: `IRCCommand` enum representing all IRC commands
- **Models**: Type-safe representations of IRC entities (channels, users, etc.)
- **Transport**: Protocol-based transport layer for message delivery
- **Multipart**: Support for large message handling and chunking

### Key Types

- `IRCMessage`: Complete IRC message representation
- `IRCCommand`: Type-safe IRC command enum
- `NeedleTailChannel`: Validated channel representation
- `NeedleTailNick`: Validated nickname representation
- `IRCTag`: IRCv3 message tag support
- `MultipartPacket`: Large message chunking support
- `NeedleTailIRCTransportProtocol`: Transport layer abstraction

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
    addMode: IRCChannelPermissions.inviteOnly,
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
// Handle large messages
let multipartPacket = MultipartPacket(
    recipients: [IRCMessageRecipient.channel(NeedleTailChannel("#general")!)],
    content: largeMessage,
    messageId: UUID().uuidString
)

// Create chunked messages
let messages = multipartPacket.createMessages()

// Send each part
for message in messages {
    try await sendMessage(message)
    try await Task.sleep(nanoseconds: 100_000_000) // Rate limiting
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

Comprehensive documentation is available in the [Documentation.docc](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc) directory:

- [Getting Started](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/GettingStarted.md) - Installation and basic setup
- [Basic Usage](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/BasicUsage.md) - Core concepts and patterns
- [Message Format](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/MessageFormat.md) - IRC message structure
- [Message Handling](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/MessageHandling.md) - Processing messages
- [IRC Commands](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/IRCCommands.md) - Complete command reference
- [Channels](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/Channels.md) - Channel management
- [Users](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/Users.md) - User management and permissions
- [Multipart Messages](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/MultipartMessages.md) - Large message handling
- [Transport Layer](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/TransportLayer.md) - Connection management
- [Error Handling](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/ErrorHandling.md) - Error types and strategies
- [API Reference](https://github.com/needletails/needletail-irc/tree/main/Sources/NeedleTailIRC/Documentation.docc/APIReference.md) - Complete API documentation

## Requirements

- **Swift**: 6.0+
- **Platforms**: 
  - iOS 18.0+
  - macOS 15.0+
- **Xcode**: 15.0+ (for iOS/macOS development)

## Dependencies

NeedleTailIRC automatically includes these dependencies:
- `swift-nio` - Network I/O framework (NIOCore, NIOConcurrencyHelpers)
- `swift-algorithms` - Algorithm utilities
- `swift-async-algorithms` - Async algorithm support
- `swift-collections` - Collection types (DequeModule)
- `needletail-logger` - Logging framework
- `needletail-algorithms` - Algorithm utilities
- `BSON` - Binary JSON serialization

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/needletails/needletail-irc.git", from: "1.0.0")
]
```

### Xcode

1. Go to **File** → **Add Package Dependencies**
2. Enter the repository URL: `https://github.com/needletails/needletail-irc.git`
3. Select the version you want to use
4. Add to your target

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [Documentation.docc](Documentation.docc)
- **Issues**: [GitHub Issues](https://github.com/needletails/needletail-irc/issues)

## Acknowledgments

- IRC protocol specifications (RFC 2812, RFC 1459)
- IRCv3 extension specifications
- Swift concurrency features
- The Swift community 
