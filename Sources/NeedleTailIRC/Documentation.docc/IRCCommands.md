# IRC Commands

Explore all available IRC commands and their usage in NeedleTailIRC.

## Overview

NeedleTailIRC provides comprehensive support for all standard IRC commands as defined in RFC 2812 and RFC 1459, plus IRCv3 extensions. All commands are type-safe and provide compile-time safety for IRC operations.

## Command Categories

### Connection Commands

Commands used during connection and registration:

#### NICK - Change Nickname

```swift
// Change nickname
let nickCommand = IRCCommand.nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)

// Create message
let message = IRCMessage(command: nickCommand)
```

#### USER - Set User Information

```swift
// Set user details
let userDetails = IRCUserDetails(
    username: "alice",
    realname: "Alice Smith",
    mode: 0
)
let userCommand = IRCCommand.user(userDetails)

// Create message
let message = IRCMessage(command: userCommand)
```

#### QUIT - Disconnect from Server

```swift
// Quit with message
let quitCommand = IRCCommand.quit("Goodbye, everyone!")

// Quit without message
let quitCommand = IRCCommand.quit(nil)

// Create message
let message = IRCMessage(command: quitCommand)
```

#### PING/PONG - Keep-Alive

```swift
// Server PING
let pingCommand = IRCCommand.ping(server: "server.example.com", server2: nil)

// Client PONG response
let pongCommand = IRCCommand.pong(server: "server.example.com", server2: nil)

// Create messages
let pingMessage = IRCMessage(command: pingCommand)
let pongMessage = IRCMessage(command: pongCommand)
```

### Channel Commands

Commands for managing channels:

#### JOIN - Join Channel

```swift
// Join single channel
let joinCommand = IRCCommand.join(
    channels: [NeedleTailChannel("#general")!],
    keys: nil
)

// Join multiple channels
let joinCommand = IRCCommand.join(
    channels: [
        NeedleTailChannel("#general")!,
        NeedleTailChannel("#help")!
    ],
    keys: ["secretkey", nil]
)

// Join with key
let joinCommand = IRCCommand.join(
    channels: [NeedleTailChannel("#secret")!],
    keys: ["password123"]
)

// Create message
let message = IRCMessage(command: joinCommand)
```

#### PART - Leave Channel

```swift
// Part from single channel
let partCommand = IRCCommand.part(channels: [NeedleTailChannel("#general")!])

// Part from multiple channels
let partCommand = IRCCommand.part(channels: [
    NeedleTailChannel("#general")!,
    NeedleTailChannel("#help")!
])

// Create message
let message = IRCMessage(command: partCommand)
```

#### LIST - List Channels

```swift
// List all channels
let listCommand = IRCCommand.list(channels: nil, target: nil)

// List specific channels
let listCommand = IRCCommand.list(
    channels: [
        NeedleTailChannel("#general")!,
        NeedleTailChannel("#help")!
    ],
    target: nil
)

// List channels on specific server
let listCommand = IRCCommand.list(channels: nil, target: "server.example.com")

// Create message
let message = IRCMessage(command: listCommand)
```

#### MODE - Channel Modes

```swift
// Get channel modes
let modeGetCommand = IRCCommand.channelModeGet(NeedleTailChannel("#general")!)

// Set channel modes
let modeCommand = IRCCommand.channelMode(
    NeedleTailChannel("#general")!,
    addMode: IRCChannelPermissions.inviteOnly,
    addParameters: nil,
    removeMode: nil,
    removeParameters: nil
)

// Set channel limit
let limitCommand = IRCCommand.channelMode(
    NeedleTailChannel("#general")!,
    addMode: IRCChannelPermissions.limit,
    addParameters: ["50"],
    removeMode: nil,
    removeParameters: nil
)

// Create messages
let message = IRCMessage(command: modeCommand)
```

### Messaging Commands

Commands for sending messages:

#### PRIVMSG - Private Message

```swift
// Send to channel
let privMsgCommand = IRCCommand.privMsg(
    [.channel(NeedleTailChannel("#general")!)],
    "Hello, everyone!"
)

// Send to user
let privMsgCommand = IRCCommand.privMsg(
    [.user("alice")],
    "Hello, Alice!"
)

// Send to multiple recipients
let privMsgCommand = IRCCommand.privMsg(
    [
        .channel(NeedleTailChannel("#general")!),
        .user("alice")
    ],
    "Hello, everyone and Alice!"
)

// Create message
let message = IRCMessage(command: privMsgCommand)
```

#### NOTICE - Notice Message

```swift
// Send notice to channel
let noticeCommand = IRCCommand.notice(
    [.channel(NeedleTailChannel("#general")!)],
    "Important announcement!"
)

// Send notice to user
let noticeCommand = IRCCommand.notice(
    [.user("alice")],
    "You have a new message."
)

// Create message
let message = IRCMessage(command: noticeCommand)
```

### Information Commands

Commands for getting information:

#### WHOIS - User Information

```swift
// WHOIS single user
let whoisCommand = IRCCommand.whois(server: nil, usermasks: ["alice"])

// WHOIS multiple users
let whoisCommand = IRCCommand.whois(
    server: nil,
    usermasks: ["alice", "bob", "charlie"]
)

// WHOIS on specific server
let whoisCommand = IRCCommand.whois(
    server: "server.example.com",
    usermasks: ["alice"]
)

// Create message
let message = IRCMessage(command: whoisCommand)
```

#### WHO - List Users

```swift
// WHO all users
let whoCommand = IRCCommand.who(usermask: nil, onlyOperators: false)

// WHO with mask
let whoCommand = IRCCommand.who(usermask: "alice*", onlyOperators: false)

// WHO operators only
let whoCommand = IRCCommand.who(usermask: nil, onlyOperators: true)

// Create message
let message = IRCMessage(command: whoCommand)
```

#### ISON - Check Online Status

```swift
// Check single user
let isOnCommand = IRCCommand.isOn([
    NeedleTailNick(name: "alice", deviceId: UUID())!
])

// Check multiple users
let isOnCommand = IRCCommand.isOn([
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    NeedleTailNick(name: "bob", deviceId: UUID())!,
    NeedleTailNick(name: "charlie", deviceId: UUID())!
])

// Create message
let message = IRCMessage(command: isOnCommand)
```

### User Management Commands

Commands for managing user modes and permissions:

#### MODE - User Modes

```swift
// Get user modes
let modeGetCommand = IRCCommand.modeGet(NeedleTailNick(name: "alice", deviceId: UUID())!)

// Set user modes
let modeCommand = IRCCommand.mode(
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    add: [.invisible, .away],
    remove: nil
)

// Remove user modes
let modeCommand = IRCCommand.mode(
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    add: nil,
    remove: [.away]
)

// Create messages
let message = IRCMessage(command: modeCommand)
```

#### KICK - Kick User from Channel

```swift
// Kick single user
let kickCommand = IRCCommand.kick(
    [NeedleTailChannel("#general")!],
    [NeedleTailNick(name: "troublemaker", deviceId: UUID())!],
    ["Breaking the rules"]
)

// Kick multiple users
let kickCommand = IRCCommand.kick(
    [NeedleTailChannel("#general")!],
    [
        NeedleTailNick(name: "user1", deviceId: UUID())!,
        NeedleTailNick(name: "user2", deviceId: UUID())!
    ],
    ["Spamming"]
)

// Create message
let message = IRCMessage(command: kickCommand)
```

#### KILL - Disconnect User

```swift
// Kill user
let killCommand = IRCCommand.kill(
    NeedleTailNick(name: "malicious", deviceId: UUID())!,
    "Violation of server rules"
)

// Create message
let message = IRCMessage(command: killCommand)
```

### DCC Commands

Direct Client-to-Client commands:

#### DCC CHAT - DCC Chat

```swift
// DCC Chat request
let dccChatCommand = IRCCommand.dccChat(
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    "192.168.1.100",
    12345
)

// Create message
let message = IRCMessage(command: dccChatCommand)
```

#### DCC SEND - DCC File Transfer

```swift
// DCC Send request
let dccSendCommand = IRCCommand.dccSend(
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    "document.pdf",
    1024,
    "192.168.1.100",
    12345
)

// Create message
let message = IRCMessage(command: dccSendCommand)
```

#### DCC RESUME - Resume File Transfer

```swift
// DCC Resume request
let dccResumeCommand = IRCCommand.dccResume(
    NeedleTailNick(name: "alice", deviceId: UUID())!,
    "document.pdf",
    1024,
    "192.168.1.100",
    12345,
    512 // offset in bytes
)

// Create message
let message = IRCMessage(command: dccResumeCommand)
```

### CAP Commands

IRCv3 capability negotiation:

```swift
// List capabilities
let capListCommand = IRCCommand.cap(.ls, [])

// Request capabilities
let capReqCommand = IRCCommand.cap(.req, ["multi-prefix", "extended-join"])

// Acknowledge capabilities
let capAckCommand = IRCCommand.cap(.ack, ["multi-prefix"])

// End capability negotiation
let capEndCommand = IRCCommand.cap(.end, [])

// Create messages
let message = IRCMessage(command: capReqCommand)
```

### Numeric Commands

Server responses and error codes:

```swift
// Welcome message
let welcomeCommand = IRCCommand.numeric(
    .replyWelcome,
    ["alice", "Welcome to the server!"]
)

// Error responses
let nickInUseCommand = IRCCommand.numeric(
    .errNicknameInUse,
    ["nickname", "Nickname is already in use"]
)

let noSuchChannelCommand = IRCCommand.numeric(
    .errNoSuchChannel,
    ["#nonexistent", "No such channel"]
)

// Create messages
let message = IRCMessage(command: welcomeCommand)
```

## Command Building Patterns

### Helper Functions

```swift
// Build join command with validation
func buildJoinCommand(channelName: String, key: String? = nil) -> IRCCommand? {
    guard let channel = NeedleTailChannel(channelName) else {
        return nil
    }
    
    return IRCCommand.join(
        channels: [channel],
        keys: key.map { [$0] }
    )
}

// Build message command with validation
func buildMessageCommand(to recipients: [String], message: String) -> IRCCommand? {
    let messageRecipients = recipients.compactMap { recipient in
        if recipient.hasPrefix("#") {
            guard let channel = NeedleTailChannel(recipient) else { return nil }
            return IRCMessageRecipient.channel(channel)
        } else {
            return IRCMessageRecipient.user(recipient)
        }
    }
    
    guard !messageRecipients.isEmpty else { return nil }
    
    return IRCCommand.privMsg(messageRecipients, message)
}

// Usage
if let joinCommand = buildJoinCommand(channelName: "#general", key: "secret") {
    let message = IRCMessage(command: joinCommand)
    // Send the message
}

if let messageCommand = buildMessageCommand(to: ["#general", "alice"], message: "Hello!") {
    let message = IRCMessage(command: messageCommand)
    // Send the message
}
```

### Command Factories

```swift
// Command factory for common operations
struct IRCCommandFactory {
    
    static func joinChannel(_ channel: String, key: String? = nil) -> IRCCommand? {
        guard let channelObj = NeedleTailChannel(channel) else { return nil }
        return IRCCommand.join(channels: [channelObj], keys: key.map { [$0] })
    }
    
    static func sendMessage(to recipients: [String], text: String) -> IRCCommand? {
        let messageRecipients = recipients.compactMap { recipient in
            if recipient.hasPrefix("#") {
                return NeedleTailChannel(recipient).map { IRCMessageRecipient.channel($0) }
            } else {
                return IRCMessageRecipient.user(recipient)
            }
        }
        
        guard !messageRecipients.isEmpty else { return nil }
        return IRCCommand.privMsg(messageRecipients, text)
    }
    
    static func changeNickname(_ nickname: String) -> IRCCommand? {
        return NeedleTailNick(name: nickname, deviceId: UUID()).map { IRCCommand.nick($0) }
    }
    
    static func quit(reason: String? = nil) -> IRCCommand {
        return IRCCommand.quit(reason)
    }
}

// Usage
if let joinCommand = IRCCommandFactory.joinChannel("#general") {
    let message = IRCMessage(command: joinCommand)
    // Send the message
}

if let messageCommand = IRCCommandFactory.sendMessage(to: ["#general"], text: "Hello!") {
    let message = IRCMessage(command: messageCommand)
    // Send the message
}
```

## Error Handling

### Command Validation

```swift
// Validate command before sending
func validateCommand(_ command: IRCCommand) -> Bool {
    switch command {
    case .join(let channels, _):
        return !channels.isEmpty && channels.allSatisfy { $0.name.count > 1 }
    case .privMsg(let recipients, let text):
        return !recipients.isEmpty && !text.isEmpty && text.count <= 512
    case .nick(let nick):
        return nick.name.count > 0
    default:
        return true
    }
}

// Usage
let command = IRCCommand.join(channels: [NeedleTailChannel("#general")!], keys: nil)
if validateCommand(command) {
    let message = IRCMessage(command: command)
    // Send the message
} else {
    print("Invalid command")
}
```

### Error Recovery

```swift
// Handle command errors
func sendCommandWithRetry(_ command: IRCCommand, maxRetries: Int = 3) async throws {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            let message = IRCMessage(command: command)
            try await sendMessage(message)
            return // Success
        } catch {
            lastError = error
            print("Attempt \(attempt) failed: \(error)")
            
            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000) // Exponential backoff
            }
        }
    }
    
    throw lastError ?? NeedleTailError.transportNotIntitialized
}

// Usage
do {
    try await sendCommandWithRetry(IRCCommand.join(channels: [NeedleTailChannel("#general")!], keys: nil))
} catch {
    print("Failed to join channel after retries: \(error)")
}
```

## Best Practices

### 1. Always Validate Input

```swift
// Good: Validate before creating commands
guard let channel = NeedleTailChannel(channelName) else {
    throw NeedleTailError.invalidIRCChannelName
}
let command = IRCCommand.join(channels: [channel], keys: nil)

// Bad: Force unwrapping
let command = IRCCommand.join(channels: [NeedleTailChannel(channelName)!], keys: nil)
```

### 2. Use Type-Safe Commands

```swift
// Good: Use enum cases
let command = IRCCommand.privMsg(recipients, message)

// Bad: Use raw commands
let command = IRCCommand.otherCommand("PRIVMSG", [recipient, message])
```

### 3. Handle Command Responses

```swift
// Good: Handle numeric responses
func handleNumericResponse(code: IRCCommandCode, parameters: [String]) async {
    switch code {
    case .replyWelcome:
        await onRegistrationComplete()
    case .errNicknameInUse:
        await tryAlternativeNickname()
    case .errNoSuchChannel:
        await handleChannelNotFound()
    default:
        print("Unhandled response: \(code)")
    }
}
```

### 4. Rate Limiting

```swift
// Good: Implement rate limiting
actor CommandRateLimiter {
    private var lastCommandTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.5
    
    func canSendCommand() -> Bool {
        return Date().timeIntervalSince(lastCommandTime) >= minInterval
    }
    
    func recordCommand() {
        lastCommandTime = Date()
    }
}

// Usage
let rateLimiter = CommandRateLimiter()
if await rateLimiter.canSendCommand() {
    let message = IRCMessage(command: command)
    try await sendMessage(message)
    await rateLimiter.recordCommand()
} else {
    print("Rate limit exceeded")
}
```

## Next Steps

Now that you understand IRC commands, explore these related topics:

- <doc:BasicUsage> - Learn basic usage patterns
- <doc:MessageHandling> - Understand message processing
- <doc:Channels> - Master channel operations
- <doc:Users> - Learn about user management
- <doc:ErrorHandling> - Understand error handling strategies