# ``NeedleTailIRC``

A comprehensive Swift SDK for implementing IRC (Internet Relay Chat) protocol functionality with modern Swift concurrency features.

## Overview

NeedleTailIRC is a production-ready Swift package that provides a complete implementation of the IRC protocol (RFC 2812, RFC 1459) with support for IRCv3 extensions. It's designed for building IRC clients, servers, and bots with a focus on type safety, performance, and modern Swift features.

The SDK offers:

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

## Quick Start

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

## Topics

### Getting Started

- <doc:GettingStarted>
Learn how to set up and start using NeedleTailIRC in your project.

### Core Concepts

- <doc:BasicUsage>
Understand the fundamental concepts and basic usage patterns.

- <doc:MessageFormat>
Learn about IRC message structure and formatting.

- <doc:MessageHandling>
Discover how to handle incoming and outgoing IRC messages.

### IRC Operations

- <doc:IRCCommands>
Explore all available IRC commands and their usage.

- <doc:Channels>
Learn about channel management and operations.

- <doc:Users>
Understand user management and permissions.

### Advanced Features

- <doc:MultipartMessages>
Handle large messages with automatic chunking and reassembly.

- <doc:TransportLayer>
Learn about the transport layer and connection management.

### Error Handling

- <doc:ErrorHandling>
Understand error types and best practices for error handling.

### API Reference

- <doc:APIReference>
Complete API reference for all public types and methods.