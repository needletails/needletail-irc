# Message Handling

Discover how to handle incoming and outgoing IRC messages using the NeedleTailIRC API.

## Overview

Message handling is a core aspect of working with IRC. This guide covers how to process incoming messages, send outgoing messages, and work with different message types using the NeedleTailIRC API.

## Incoming Message Processing

### Basic Message Processing

```swift
// Process incoming messages
for await rawMessage in messageStream {
    do {
        let message = try NeedleTailIRCParser.parseMessage(rawMessage)
        await handleMessage(message)
    } catch {
        print("Failed to parse message: \(error)")
    }
}

// Handle different message types
func handleMessage(_ message: IRCMessage) async {
    switch message.command {
    case .privMsg(let recipients, let text):
        await handlePrivateMessage(from: message.origin, to: recipients, text: text)
    case .notice(let recipients, let text):
        await handleNotice(from: message.origin, to: recipients, text: text)
    case .join(let channels, _):
        await handleJoin(from: message.origin, channels: channels)
    case .part(let channels):
        await handlePart(from: message.origin, channels: channels)
    case .numeric(let code, let parameters):
        await handleNumericResponse(code: code, parameters: parameters)
    default:
        print("Unhandled command: \(message.command)")
    }
}
```

### Message Type Handlers

```swift
// Handle private messages
func handlePrivateMessage(from origin: String?, to recipients: [IRCMessageRecipient], text: String) async {
    print("Private message from \(origin ?? "unknown"): \(text)")
    
    // Check if message is for us
    for recipient in recipients {
        switch recipient {
        case .user(let username):
            if username == ourNickname {
                await processPrivateMessage(from: origin, text: text)
            }
        case .channel(let channel):
            await processChannelMessage(from: origin, channel: channel, text: text)
        }
    }
}

// Handle notices
func handleNotice(from origin: String?, to recipients: [IRCMessageRecipient], text: String) async {
    print("Notice from \(origin ?? "unknown"): \(text)")
    
    // Process notice based on origin
    if origin?.hasSuffix("server.example.com") == true {
        await handleServerNotice(text: text)
    } else {
        await handleUserNotice(from: origin, text: text)
    }
}

// Handle channel joins
func handleJoin(from origin: String?, channels: [NeedleTailChannel]) async {
    guard let origin = origin else { return }
    
    for channel in channels {
        print("\(origin) joined \(channel.name)")
        await updateChannelUsers(channel: channel, user: origin, joined: true)
    }
}

// Handle channel parts
func handlePart(from origin: String?, channels: [NeedleTailChannel]) async {
    guard let origin = origin else { return }
    
    for channel in channels {
        print("\(origin) left \(channel.name)")
        await updateChannelUsers(channel: channel, user: origin, joined: false)
    }
}
```

### Numeric Response Handling

```swift
// Handle server numeric responses
func handleNumericResponse(code: IRCCommandCode, parameters: [String]) async {
    switch code {
    case .replyWelcome:
        await handleWelcome(parameters: parameters)
    case .replyYourHost:
        await handleYourHost(parameters: parameters)
    case .replyCreated:
        await handleCreated(parameters: parameters)
    case .replyMyInfo:
        await handleMyInfo(parameters: parameters)
    case .errNicknameInUse:
        await handleNicknameInUse(parameters: parameters)
    case .errNoSuchChannel:
        await handleNoSuchChannel(parameters: parameters)
    default:
        print("Unhandled numeric response: \(code) - \(parameters)")
    }
}

// Handle specific numeric responses
func handleWelcome(parameters: [String]) async {
    guard parameters.count >= 2 else { return }
    let nickname = parameters[0]
    let message = parameters[1]
    
    print("Welcome message: \(message)")
    await onRegistrationComplete(nickname: nickname)
}

func handleNicknameInUse(parameters: [String]) async {
    guard parameters.count >= 2 else { return }
    let nickname = parameters[0]
    let message = parameters[1]
    
    print("Nickname \(nickname) is in use: \(message)")
    await tryAlternativeNickname(original: nickname)
}
```

## Outgoing Message Sending

### Basic Message Sending

```swift
// Send a message
func sendMessage(_ message: IRCMessage) async throws {
    let encodedMessage = await NeedleTailIRCEncoder.encode(value: message)
    try await sendToServer(encodedMessage)
}

// Send to a channel
func sendToChannel(_ channel: NeedleTailChannel, message: String) async throws {
    let ircMessage = IRCMessage(
        command: .privMsg([.channel(channel)], message)
    )
    try await sendMessage(ircMessage)
}

// Send to a user
func sendToUser(_ username: String, message: String) async throws {
    let ircMessage = IRCMessage(
        command: .privMsg([.user(username)], message)
    )
    try await sendMessage(ircMessage)
}

// Send a notice
func sendNotice(to recipients: [IRCMessageRecipient], message: String) async throws {
    let ircMessage = IRCMessage(
        command: .notice(recipients, message)
    )
    try await sendMessage(ircMessage)
}
```

### Connection Management

```swift
// Join a channel
func joinChannel(_ channel: NeedleTailChannel, key: String? = nil) async throws {
    let joinCommand = IRCCommand.join(
        channels: [channel],
        keys: key.map { [$0] }
    )
    let message = IRCMessage(command: joinCommand)
    try await sendMessage(message)
}

// Part from a channel
func partChannel(_ channel: NeedleTailChannel, reason: String? = nil) async throws {
    let partCommand = IRCCommand.part(channels: [channel])
    let message = IRCMessage(command: partCommand)
    try await sendMessage(message)
}

// Change nickname
func changeNickname(_ nickname: String) async throws {
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let nickCommand = IRCCommand.nick(nick)
    let message = IRCMessage(command: nickCommand)
    try await sendMessage(message)
}
```

## Message Types

### Private Messages

```swift
// Create private message
let privMsg = IRCMessage(
    origin: "alice!alice@localhost",
    command: .privMsg([.user("bob")], "Hello, Bob!")
)

// Create channel message
let channelMsg = IRCMessage(
    origin: "alice!alice@localhost",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, everyone!")
)
```

### Notices

```swift
// Create notice message
let notice = IRCMessage(
    origin: "server.example.com",
    command: .notice([.user("alice")], "Welcome to the server!")
)

// Create channel notice
let channelNotice = IRCMessage(
    origin: "alice!alice@localhost",
    command: .notice([.channel(NeedleTailChannel("#general")!)], "Important announcement!")
)
```

### Server Messages

```swift
// Create welcome message
let welcome = IRCMessage(
    origin: "server.example.com",
    command: .numeric(.replyWelcome, ["alice", "Welcome to the server!"])
)

// Create error message
let error = IRCMessage(
    origin: "server.example.com",
    command: .numeric(.errNicknameInUse, ["alice", "Nickname is already in use"])
)
```

## Message Validation

### Channel Validation

```swift
// Validate channel before use
guard let channel = NeedleTailChannel("#general") else {
    throw NeedleTailError.invalidIRCChannelName
}

// Use validated channel
let message = IRCMessage(
    command: .privMsg([.channel(channel)], "Hello!")
)
```

### Nickname Validation

```swift
// Validate nickname before use
guard let nick = NeedleTailNick(name: "alice", deviceId: UUID()) else {
    throw NeedleTailError.nilNickName
}

// Use validated nickname
let message = IRCMessage(
    command: .nick(nick)
)
```