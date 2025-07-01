# Channels

Learn about channel management and operations using the NeedleTailIRC API.

## Overview

Channels are the primary way users communicate in IRC. NeedleTailIRC provides comprehensive support for channel operations including joining, leaving, managing modes, and handling permissions.

## Channel Basics

### Creating Channel Objects

```swift
// Create a channel with validation
guard let channel = NeedleTailChannel("#general") else {
    print("Invalid channel name")
    return
}

// Channel names are automatically validated
print(channel.name) // "#general"

// Invalid channel names return nil
let invalidChannel = NeedleTailChannel("invalid") // nil
let invalidChannel2 = NeedleTailChannel("") // nil
```

### Channel Name Validation

Channel names must follow IRC standards:
- Start with `#`, `&`, `+`, or `!`
- Cannot contain spaces, commas, or other special characters
- Maximum length varies by server (typically 50 characters)

```swift
// Valid channel names
let validChannels = [
    NeedleTailChannel("#general"),
    NeedleTailChannel("&local"),
    NeedleTailChannel("+public"),
    NeedleTailChannel("!secure")
]

// Invalid channel names
let invalidChannels = [
    NeedleTailChannel("no-prefix"),
    NeedleTailChannel("#"),
    NeedleTailChannel("#channel with spaces"),
    NeedleTailChannel("#channel,with,commas")
]
```

## Channel Operations

### Joining Channels

```swift
// Join a single channel
func joinChannel(_ channelName: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let joinCommand = IRCCommand.join(channels: [channel], keys: nil)
    let message = IRCMessage(command: joinCommand)
    try await sendMessage(message)
}

// Join multiple channels
func joinChannels(_ channelNames: [String]) async throws {
    let channels = channelNames.compactMap { NeedleTailChannel($0) }
    guard !channels.isEmpty else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let joinCommand = IRCCommand.join(channels: channels, keys: nil)
    let message = IRCMessage(command: joinCommand)
    try await sendMessage(message)
}

// Join channel with key
func joinChannel(_ channelName: String, key: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let joinCommand = IRCCommand.join(channels: [channel], keys: [key])
    let message = IRCMessage(command: joinCommand)
    try await sendMessage(message)
}

// Usage
try await joinChannel("#general")
try await joinChannels(["#general", "#help", "#random"])
try await joinChannel("#secret", key: "password123")
```

### Leaving Channels

```swift
// Part from a single channel
func partChannel(_ channelName: String, reason: String? = nil) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let partCommand = IRCCommand.part(channels: [channel])
    let message = IRCMessage(command: partCommand)
    try await sendMessage(message)
}

// Part from multiple channels
func partChannels(_ channelNames: [String]) async throws {
    let channels = channelNames.compactMap { NeedleTailChannel($0) }
    guard !channels.isEmpty else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let partCommand = IRCCommand.part(channels: channels)
    let message = IRCMessage(command: partCommand)
    try await sendMessage(message)
}

// Usage
try await partChannel("#general")
try await partChannel("#general", reason: "Leaving for now")
try await partChannels(["#general", "#help"])
```

### Listing Channels

```swift
// List all channels
func listAllChannels() async throws {
    let listCommand = IRCCommand.list(channels: nil, target: nil)
    let message = IRCMessage(command: listCommand)
    try await sendMessage(message)
}

// List specific channels
func listChannels(_ channelNames: [String]) async throws {
    let channels = channelNames.compactMap { NeedleTailChannel($0) }
    let listCommand = IRCCommand.list(channels: channels, target: nil)
    let message = IRCMessage(command: listCommand)
    try await sendMessage(message)
}

// List channels on specific server
func listChannelsOnServer(_ server: String) async throws {
    let listCommand = IRCCommand.list(channels: nil, target: server)
    let message = IRCMessage(command: listCommand)
    try await sendMessage(message)
}

// Usage
try await listAllChannels()
try await listChannels(["#general", "#help"])
try await listChannelsOnServer("server.example.com")
```

## Channel Modes

### Getting Channel Modes

```swift
// Get channel modes
func getChannelModes(_ channelName: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let modeCommand = IRCCommand.channelModeGet(channel)
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Get channel ban list
func getChannelBanList(_ channelName: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let banCommand = IRCCommand.channelModeGetBanMask(channel)
    let message = IRCMessage(command: banCommand)
    try await sendMessage(message)
}

// Usage
try await getChannelModes("#general")
try await getChannelBanList("#general")
```

### Setting Channel Modes

```swift
// Set channel mode
func setChannelMode(_ channelName: String, addMode: IRCChannelPermissions?, removeMode: IRCChannelPermissions?) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: addMode,
        addParameters: nil,
        removeMode: removeMode,
        removeParameters: nil
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Set channel limit
func setChannelLimit(_ channelName: String, limit: Int) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: IRCChannelPermissions.limit,
        addParameters: [String(limit)],
        removeMode: nil,
        removeParameters: nil
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Set channel key
func setChannelKey(_ channelName: String, key: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: IRCChannelPermissions.key,
        addParameters: [key],
        removeMode: nil,
        removeParameters: nil
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Remove channel key
func removeChannelKey(_ channelName: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: nil,
        addParameters: nil,
        removeMode: IRCChannelPermissions.key,
        removeParameters: ["*"]
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Usage
try await setChannelMode("#general", addMode: .inviteOnly, removeMode: nil)
try await setChannelLimit("#general", limit: 50)
try await setChannelKey("#secret", key: "password123")
try await removeChannelKey("#secret")
```

## Channel Permissions

### Permission Types

NeedleTailIRC supports all standard IRC channel permissions:

```swift
// Common channel permissions
let permissions: [IRCChannelPermissions] = [
    .inviteOnly,      // +i - Only invited users can join
    .moderated,       // +m - Only voiced users can speak
    .noExternal,      // +n - No messages from outside the channel
    .private,         // +p - Channel is private
    .secret,          // +s - Channel is secret
    .topicProtection, // +t - Only operators can change topic
    .key,             // +k - Channel requires a key to join
    .limit,           // +l - Channel has a user limit
    .ban,             // +b - Ban mask
    .exception,       // +e - Exception to ban mask
    .inviteException, // +I - Invite exception
    .quiet,           // +q - Quiet mask
    .voice,           // +v - Give voice to user
    .halfOperator,    // +h - Give half-operator to user
    .operator,        // +o - Give operator to user
    .protect,         // +a - Give protect to user
    .owner            // +q - Give owner to user
]
```

### Managing User Permissions

```swift
// Give operator to user
func giveOperator(_ channelName: String, to nickname: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: IRCChannelPermissions.operator,
        addParameters: [nickname],
        removeMode: nil,
        removeParameters: nil
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Remove operator from user
func removeOperator(_ channelName: String, from nickname: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: nil,
        addParameters: nil,
        removeMode: IRCChannelPermissions.operator,
        removeParameters: [nickname]
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Give voice to user
func giveVoice(_ channelName: String, to nickname: String) async throws {
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let modeCommand = IRCCommand.channelMode(
        channel,
        addMode: IRCChannelPermissions.voice,
        addParameters: [nickname],
        removeMode: nil,
        removeParameters: nil
    )
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Usage
try await giveOperator("#general", to: "alice")
try await removeOperator("#general", from: "bob")
try await giveVoice("#general", to: "charlie")
```

## Channel Validation

### Channel Name Validation

```swift
// Validate channel name
func isValidChannelName(_ name: String) -> Bool {
    return NeedleTailChannel(name) != nil
}

// Get channel type from name
func getChannelType(_ name: String) -> ChannelType? {
    guard let firstChar = name.first else { return nil }
    
    switch firstChar {
    case "#":
        return .public
    case "&":
        return .local
    case "+":
        return .publicUnmoderated
    case "!":
        return .secure
    default:
        return nil
    }
}

enum ChannelType {
    case `public`      // # - Public channel
    case local         // & - Local channel
    case publicUnmoderated // + - Public unmoderated channel
    case secure        // ! - Secure channel
}

// Usage
if isValidChannelName("#general") {
    print("Valid channel name")
}

if let type = getChannelType("#general") {
    print("Channel type: \(type)")
}
```