# Basic Usage

Understand the fundamental concepts and basic usage patterns for the NeedleTailIRC API.

## Overview

This guide covers the core concepts and common patterns you'll use when working with the NeedleTailIRC API. You'll learn about message creation, parsing, encoding, and the basic workflow for IRC operations.

## Core Concepts

### IRC Messages

An IRC message consists of several components:

```swift
let message = IRCMessage(
    origin: "alice!alice@localhost",  // Who sent the message
    target: "bob",                    // Who receives the message (optional)
    command: .privMsg([.user("bob")], "Hello!"),  // The IRC command
    tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]  // IRCv3 tags (optional)
)
```

### Message Structure

IRC messages follow this format:
```
[@tags] [:prefix] command [parameters] [:trailing]
```

Example:
```
@time=2023-01-01T12:00:00Z :alice!alice@localhost PRIVMSG #general :Hello, everyone!
```

## Creating Messages

### Simple Messages

```swift
// Basic private message
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, world!")
)

// Notice message
let notice = IRCMessage(
    origin: "server",
    command: .notice([.user("alice")], "Welcome to the server!")
)
```

### Messages with Tags

```swift
// Message with IRCv3 tags
let taggedMessage = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
    tags: [
        IRCTag(key: "time", value: "2023-01-01T12:00:00Z"),
        IRCTag(key: "account", value: "alice")
    ]
)
```

## Parsing Messages

### Parse Raw IRC Strings

```swift
// Parse a complete IRC message
let rawMessage = ":alice!alice@localhost PRIVMSG #general :Hello, everyone!"
let parsedMessage = try NeedleTailIRCParser.parseMessage(rawMessage)

print("Origin: \(parsedMessage.origin ?? "none")")
print("Command: \(parsedMessage.command)")
```

### Handle Parsing Errors

```swift
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    // Process the message
} catch MessageParsingErrors.invalidArguments(let details) {
    print("Invalid arguments: \(details)")
} catch MessageParsingErrors.invalidTag {
    print("Invalid tag format")
} catch {
    print("Unknown parsing error: \(error)")
}
```

## Encoding Messages

### Convert to IRC Format

```swift
// Create a message
let message = IRCMessage(
    origin: "bob",
    command: .join(channels: [NeedleTailChannel("#test")!], keys: nil)
)

// Encode to string format
let encodedString = await NeedleTailIRCEncoder.encode(value: message)
print(encodedString) // ":bob JOIN #test"
```

### Encode with Tags

```swift
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
    tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
)

let encoded = await NeedleTailIRCEncoder.encode(value: message)
print(encoded) // "@time=2023-01-01T12:00:00Z :alice PRIVMSG #general :Hello!"
```

## Working with Commands

### Connection Commands

```swift
// Change nickname
let nickCommand = IRCCommand.nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)

// Set user information
let userCommand = IRCCommand.user(IRCUserDetails(
    username: "alice",
    realname: "Alice Smith",
    mode: 0
))

// Quit the server
let quitCommand = IRCCommand.quit("Goodbye, everyone!")
```

### Channel Commands

```swift
// Join a channel
let joinCommand = IRCCommand.join(
    channels: [NeedleTailChannel("#general")!],
    keys: ["secretkey"]
)

// Part from a channel
let partCommand = IRCCommand.part(channels: [NeedleTailChannel("#general")!])

// Send message to channel
let messageCommand = IRCCommand.privMsg(
    [.channel(NeedleTailChannel("#general")!)],
    "Hello, channel!"
)
```

### Information Commands

```swift
// Check if users are online
let isOnCommand = IRCCommand.isOn([
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    NeedleTailNick(name: "bob", deviceId: UUID())!
])

// Get user information
let whoisCommand = IRCCommand.whois(server: nil, usermasks: ["alice"])

// List channels
let listCommand = IRCCommand.list(channels: nil, target: nil)
```

## Working with Recipients

### Message Recipients

```swift
// Send to a channel
let channelRecipient = IRCMessageRecipient.channel(NeedleTailChannel("#general")!)

// Send to a user
let userRecipient = IRCMessageRecipient.user("bob")

// Send to multiple recipients
let recipients = [
    IRCMessageRecipient.channel(NeedleTailChannel("#general")!),
    IRCMessageRecipient.user("alice")
]

let message = IRCMessage(
    command: .privMsg(recipients, "Hello, everyone!")
)
```