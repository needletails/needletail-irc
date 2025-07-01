# Getting Started

Learn how to use the NeedleTailIRC API to create and work with IRC messages.

## Overview

This guide shows you how to use the NeedleTailIRC API to create, parse, and encode IRC messages.

## Import the Module

```swift
import NeedleTailIRC
```

## Create Your First IRC Message

```swift
// Create a simple message
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, world!")
)

print(message.description)
// Output: <IRCProtocolMessage: from=alice command=PRIVMSG #general :Hello, world!>
```

## Parse IRC Messages

```swift
// Parse a raw IRC message string
let rawMessage = ":alice!alice@localhost PRIVMSG #general :Hello, everyone!"
let parsedMessage = try NeedleTailIRCParser.parseMessage(rawMessage)

print("Origin: \(parsedMessage.origin ?? "none")")
print("Command: \(parsedMessage.command)")
```

## Encode Messages

```swift
// Create a message
let message = IRCMessage(
    origin: "bob",
    command: .join(channels: [NeedleTailChannel("#test")!], keys: nil)
)

// Encode to IRC format
let encodedString = await NeedleTailIRCEncoder.encode(value: message)
print(encodedString)
// Output: :bob JOIN #test
```

## Working with Channels

### Creating Channel Objects

```swift
// Create a channel with validation
guard let channel = NeedleTailChannel("#general") else {
    print("Invalid channel name")
    return
}

// Channel names are automatically validated
print(channel.name) // "#general"
```

### Channel Operations

```swift
// Join a channel
let joinCommand = IRCCommand.join(
    channels: [NeedleTailChannel("#general")!],
    keys: nil
)

// Part from a channel
let partCommand = IRCCommand.part(channels: [NeedleTailChannel("#general")!])

// Send a message to a channel
let messageCommand = IRCCommand.privMsg(
    [.channel(NeedleTailChannel("#general")!)],
    "Hello, channel!"
)
```

## Working with Users

### Creating Nickname Objects

```swift
// Create a nickname with device ID
let nick = NeedleTailNick(name: "alice", deviceId: UUID())!

// Change nickname
let nickCommand = IRCCommand.nick(nick)
```

### User Modes

```swift
// Set user modes
let modeCommand = IRCCommand.mode(
    nick: NeedleTailNick(name: "alice", deviceId: UUID())!,
    add: [.invisible, .away],
    remove: nil
)
```

## Error Handling

```swift
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    // Process the message
} catch NeedleTailError.invalidIRCChannelName {
    print("Invalid channel name format")
} catch NeedleTailError.nilNickName {
    print("Nickname is required")
} catch {
    print("Other error: \(error)")
}
```

## Next Steps

Now that you have the basics, explore these topics:

- <doc:BasicUsage> - Learn more about core concepts
- <doc:IRCCommands> - Discover all available IRC commands
- <doc:MessageHandling> - Understand message processing
- <doc:Channels> - Master channel operations
- <doc:Users> - Learn about user management

## Standard IRC Ports

When connecting to IRC servers, use these standard ports:
- **Port 6667**: Unencrypted connections
- **Port 6697**: SSL/TLS encrypted connections

## Example Project Structure

```
MyIRCClient/
├── Sources/
│   └── MyIRCClient/
│       ├── IRCClient.swift
│       ├── MessageHandler.swift
│       └── ChannelManager.swift
├── Tests/
│   └── MyIRCClientTests/
└── Package.swift
```

This structure provides a good foundation for building a complete IRC client application.
