# Message Format

Learn about IRC message structure and formatting according to RFC 2812 and RFC 1459 standards.

## Overview

IRC messages follow a specific format defined by the IRC protocol standards. NeedleTailIRC provides type-safe representations of these messages while maintaining full compliance with the protocol specifications.

## Message Structure

### Basic Format

An IRC message consists of these components:

```
[@tags] [:prefix] command [parameters] [:trailing]
```

Where:
- **@tags** (optional): IRCv3 message tags
- **:prefix** (optional): Message origin/source
- **command**: The IRC command or numeric response
- **parameters**: Space-separated command parameters
- **:trailing** (optional): The final parameter, which can contain spaces

### Example Messages

```
:alice!alice@localhost PRIVMSG #general :Hello, everyone!
@time=2023-01-01T12:00:00Z :server.example.com 001 alice :Welcome to the server
:server.example.com PING :server.example.com
```

## Message Components

### Tags (IRCv3)

Tags provide additional metadata about messages and are prefixed with `@`:

```swift
// Create tags
let tags = [
    IRCTag(key: "time", value: "2023-01-01T12:00:00Z"),
    IRCTag(key: "account", value: "alice"),
    IRCTag(key: "msgid", value: "abc123")
]

// Use in message
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
    tags: tags
)
```

Common tag keys:
- `time`: Timestamp of the message
- `account`: User account name
- `msgid`: Unique message identifier
- `+draft/reply`: Reply to another message
- `+draft/react`: Message reaction

### Prefix

The prefix indicates the origin of the message:

```swift
// User message
let userMessage = IRCMessage(
    origin: "alice!alice@localhost",  // nickname!username@hostname
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!")
)

// Server message
let serverMessage = IRCMessage(
    origin: "server.example.com",     // server name
    command: .numeric(.replyWelcome, ["Welcome to the server!"])
)

// No prefix (client-originated)
let clientMessage = IRCMessage(
    command: .join(channels: [NeedleTailChannel("#general")!], keys: nil)
)
```

### Commands

Commands can be either text commands or numeric responses:

```swift
// Text commands
let privMsg = IRCCommand.privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!")
let join = IRCCommand.join(channels: [NeedleTailChannel("#general")!], keys: nil)
let nick = IRCCommand.nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)

// Numeric responses
let welcome = IRCCommand.numeric(.replyWelcome, ["Welcome to the server!"])
let error = IRCCommand.numeric(.errNicknameInUse, ["nickname", "Nickname is already in use"])
```

### Parameters

Parameters are space-separated values that follow the command:

```swift
// Single parameter
let ping = IRCCommand.ping(server: "server.example.com", server2: nil)

// Multiple parameters
let whois = IRCCommand.whois(server: nil, usermasks: ["alice", "bob"])

// Parameters with trailing
let privMsg = IRCCommand.privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, this is a long message with spaces!")
```

## Message Types

### Client Messages

Messages sent by clients to the server:

```swift
// Registration
let nickMsg = IRCMessage(command: .nick(NeedleTailNick(name: "alice", deviceId: UUID())!))
let userMsg = IRCMessage(command: .user(IRCUserDetails(username: "alice", realname: "Alice Smith", mode: 0)))

// Channel operations
let joinMsg = IRCMessage(command: .join(channels: [NeedleTailChannel("#general")!], keys: nil))
let partMsg = IRCMessage(command: .part(channels: [NeedleTailChannel("#general")!]))

// Messaging
let privMsg = IRCMessage(command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"))
let noticeMsg = IRCMessage(command: .notice([.user("bob")], "Important notice"))
```

### Server Messages

Messages sent by the server to clients:

```swift
// Welcome messages
let welcome = IRCMessage(
    origin: "server.example.com",
    command: .numeric(.replyWelcome, ["alice", "Welcome to the server!"])
)

// Error messages
let nickInUse = IRCMessage(
    origin: "server.example.com",
    command: .numeric(.errNicknameInUse, ["alice", "Nickname is already in use"])
)

// Information messages
let topic = IRCMessage(
    origin: "alice!alice@localhost",
    command: .topic(NeedleTailChannel("#general")!, "Channel topic")
)
```

### User Messages

Messages sent between users:

```swift
// Private message
let privMsg = IRCMessage(
    origin: "alice!alice@localhost",
    command: .privMsg([.user("bob")], "Hello, Bob!")
)

// Channel message
let channelMsg = IRCMessage(
    origin: "alice!alice@localhost",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, everyone!")
)
```

## Message Validation

### Channel Names

Channel names must follow IRC standards:

```swift
// Valid channel names
let general = NeedleTailChannel("#general")!      // Standard channel
let secret = NeedleTailChannel("&secret")!        // Local channel
let server = NeedleTailChannel("+public")!        // Public channel

// Invalid channel names (will return nil)
let invalid1 = NeedleTailChannel("general")       // Missing prefix
let invalid2 = NeedleTailChannel("#")             // Empty name
let invalid3 = NeedleTailChannel("#invalid name") // Contains space
```

### Nicknames

Nicknames must be valid IRC nicknames:

```swift
// Valid nicknames
let alice = NeedleTailNick(name: "alice", deviceId: UUID())!
let bob123 = NeedleTailNick(name: "bob123", deviceId: UUID())!
let user_123 = NeedleTailNick(name: "user_123", deviceId: UUID())!

// Invalid nicknames (will return nil)
let invalid1 = NeedleTailNick(name: "123user", deviceId: UUID())    // Starts with number
let invalid2 = NeedleTailNick(name: "user-name", deviceId: UUID())  // Contains hyphen
let invalid3 = NeedleTailNick(name: "", deviceId: UUID())           // Empty name
```

## Message Encoding

### String Representation

Convert messages to IRC format strings:

```swift
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, world!")
)

let encoded = await NeedleTailIRCEncoder.encode(value: message)
print(encoded) // ":alice PRIVMSG #general :Hello, world!"
```

### With Tags

```swift
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
    tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
)

let encoded = await NeedleTailIRCEncoder.encode(value: message)
print(encoded) // "@time=2023-01-01T12:00:00Z :alice PRIVMSG #general :Hello!"
```

## Message Parsing

### Parse Raw Strings

Convert IRC format strings back to message objects:

```swift
let rawMessage = ":alice!alice@localhost PRIVMSG #general :Hello, everyone!"
let message = try NeedleTailIRCParser.parseMessage(rawMessage)

print(message.origin) // "alice!alice@localhost"
print(message.command) // IRCCommand.privMsg(...)
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

## Special Message Types

### PING/PONG

Keep-alive messages:

```swift
// Server PING
let ping = IRCMessage(
    origin: "server.example.com",
    command: .ping(server: "server.example.com", server2: nil)
)

// Client PONG response
let pong = IRCMessage(
    command: .pong(server: "server.example.com", server2: nil)
)
```

### Numeric Responses

Server responses with numeric codes:

```swift
// Welcome (001)
let welcome = IRCMessage(
    origin: "server.example.com",
    command: .numeric(.replyWelcome, ["alice", "Welcome to the server!"])
)

// Error responses
let nickInUse = IRCMessage(
    origin: "server.example.com",
    command: .numeric(.errNicknameInUse, ["nickname", "Nickname is already in use"])
)
```

### DCC Messages

Direct Client-to-Client messages:

```swift
// DCC Chat request
let dccChat = IRCMessage(
    origin: "alice",
    command: .dccChat(
        NeedleTailNick(name: "bob", deviceId: UUID())!,
        "192.168.1.100",
        12345
    )
)

// DCC Send request
let dccSend = IRCMessage(
    origin: "alice",
    command: .dccSend(
        NeedleTailNick(name: "bob", deviceId: UUID())!,
        "document.pdf",
        1024,
        "192.168.1.100",
        12345
    )
)
```

## Best Practices

### 1. Always Validate Input

```swift
// Good: Validate channel names
guard let channel = NeedleTailChannel(channelName) else {
    throw NeedleTailError.invalidIRCChannelName
}

// Good: Validate nicknames
guard let nick = NeedleTailNick(name: nickName, deviceId: deviceId) else {
    throw NeedleTailError.nilNickName
}
```

### 2. Use Type-Safe Commands

```swift
// Good: Use enum cases
let command = IRCCommand.privMsg(recipients, message)

// Avoid: Raw strings
let command = IRCCommand.otherCommand("PRIVMSG", [recipient, message])
```

### 3. Handle Tags Properly

```swift
// Good: Use structured tags
let tags = [IRCTag(key: "time", value: ISO8601DateFormatter().string(from: Date()))]

// Avoid: Manual tag formatting
let rawTags = "@time=\(timestamp)"
```

### 4. Proper Error Handling

```swift
// Good: Comprehensive error handling
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    // Process message
} catch let error as NeedleTailError {
    handleNeedleTailError(error)
} catch {
    handleUnknownError(error)
}
```

## Next Steps

Now that you understand message format, explore these related topics:

- <doc:MessageHandling> - Learn about processing and handling messages
- <doc:IRCCommands> - Discover all available IRC commands
- <doc:BasicUsage> - Understand basic usage patterns
- <doc:ErrorHandling> - Learn about error handling strategies