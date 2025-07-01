# API Reference

Complete API reference for all public types and methods in NeedleTailIRC.

## Overview

This document provides a comprehensive reference for all public APIs in the NeedleTailIRC SDK. Each type, method, and property is documented with its purpose, parameters, return values, and usage examples.

## Core Types

### IRCMessage

The main message type representing an IRC message.

```swift
struct IRCMessage {
    let origin: String?
    let command: IRCCommand
    let tags: [IRCTag]?
    
    init(origin: String? = nil, command: IRCCommand, tags: [IRCTag]? = nil)
}
```

**Properties:**
- `origin`: The message origin/source (optional)
- `command`: The IRC command or numeric response
- `tags`: IRCv3 message tags (optional)

**Example:**
```swift
let message = IRCMessage(
    origin: "alice!alice@localhost",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!"),
    tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
)
```

### IRCCommand

Enumeration of all supported IRC commands.

```swift
enum IRCCommand {
    // Connection commands
    case nick(NeedleTailNick)
    case user(IRCUserDetails)
    case quit(String?)
    case ping(server: String, server2: String?)
    case pong(server: String, server2: String?)
    
    // Channel commands
    case join(channels: [NeedleTailChannel], keys: [String]?)
    case part(channels: [NeedleTailChannel])
    case list(channels: [NeedleTailChannel]?, target: String?)
    case channelModeGet(NeedleTailChannel)
    case channelMode(NeedleTailChannel, addMode: IRCChannelPermissions?, addParameters: [String]?, removeMode: IRCChannelPermissions?, removeParameters: [String]?)
    
    // Messaging commands
    case privMsg([IRCMessageRecipient], String)
    case notice([IRCMessageRecipient], String)
    
    // Information commands
    case whois(server: String?, usermasks: [String])
    case who(usermask: String?, onlyOperators: Bool)
    case isOn([NeedleTailNick])
    
    // User management commands
    case modeGet(NeedleTailNick)
    case mode(NeedleTailNick, add: IRCUserModeFlags?, remove: IRCUserModeFlags?)
    case kick([NeedleTailChannel], [NeedleTailNick], [String])
    case kill(NeedleTailNick, String)
    
    // DCC commands
    case dccChat(NeedleTailNick, String, Int)
    case dccSend(NeedleTailNick, String, Int, String, Int)
    case dccResume(NeedleTailNick, String, Int, String, Int, Int)
    
    // CAP commands
    case cap(CAPSubcommand, [String])
    
    // Numeric responses
    case numeric(IRCCommandCode, [String])
    
    // Other commands
    case otherCommand(String, [String])
}
```

### IRCMessageRecipient

Represents message recipients (channels or users).

```swift
enum IRCMessageRecipient {
    case channel(NeedleTailChannel)
    case user(String)
}
```

### NeedleTailChannel

Represents an IRC channel with validation.

```swift
struct NeedleTailChannel {
    let name: String
    
    init?(_ name: String)
}
```

**Properties:**
- `name`: The channel name (e.g., "#general")

**Example:**
```swift
guard let channel = NeedleTailChannel("#general") else {
    print("Invalid channel name")
    return
}
```

### NeedleTailNick

Represents an IRC nickname with device ID.

```swift
struct NeedleTailNick {
    let name: String
    let deviceId: UUID
    
    init?(name: String, deviceId: UUID)
}
```

**Properties:**
- `name`: The nickname
- `deviceId`: Unique device identifier

**Example:**
```swift
guard let nick = NeedleTailNick(name: "alice", deviceId: UUID()) else {
    print("Invalid nickname")
    return
}
```

### IRCUserDetails

User information for registration.

```swift
struct IRCUserDetails {
    let username: String
    let realname: String
    let mode: Int
    
    init(username: String, realname: String, mode: Int)
}
```

**Properties:**
- `username`: Username for registration
- `realname`: Real name/GECOS field
- `mode`: User mode flags

### IRCTag

IRCv3 message tag.

```swift
struct IRCTag {
    let key: String
    let value: String
    
    init(key: String, value: String)
}
```

**Properties:**
- `key`: Tag key
- `value`: Tag value

## Command Codes

### IRCCommandCode

Numeric response codes.

```swift
enum IRCCommandCode {
    // Welcome messages
    case replyWelcome = 1
    case replyYourHost = 2
    case replyCreated = 3
    case replyMyInfo = 4
    
    // Error responses
    case errNoSuchNick = 401
    case errNoSuchServer = 402
    case errNoSuchChannel = 403
    case errCannotSendToChan = 404
    case errTooManyChannels = 405
    case errWasNoSuchNick = 406
    case errTooManyTargets = 407
    case errNoSuchService = 408
    case errNoOrigin = 409
    case errNoRecipient = 411
    case errNoTextToSend = 412
    case errNoTopLevel = 413
    case errWildTopLevel = 414
    case errBadMask = 415
    case errUnknownCommand = 421
    case errNoMotd = 422
    case errNoAdminInfo = 423
    case errFileError = 424
    case errNoNicknameGiven = 431
    case errErroneousNickname = 432
    case errNicknameInUse = 433
    case errNickCollision = 436
    case errUnavailResource = 437
    case errUserNotInChannel = 441
    case errNotOnChannel = 442
    case errUserOnChannel = 443
    case errNoLogin = 444
    case errSummonDisabled = 445
    case errUsersDisabled = 446
    case errNotRegistered = 451
    case errNeedMoreParams = 461
    case errAlreadyRegistered = 462
    case errNoPermForHost = 463
    case errPasswdMismatch = 464
    case errYoureBannedCreep = 465
    case errYouWillBeBanned = 466
    case errKeySet = 467
    case errChannelIsFull = 471
    case errUnknownMode = 472
    case errInviteOnlyChan = 473
    case errBannedFromChan = 474
    case errBadChannelKey = 475
    case errBadChanMask = 476
    case errNoChanModes = 477
    case errBanListFull = 478
    case errNoPrivileges = 481
    case errChanOpPrivsNeeded = 482
    case errCantKillServer = 483
    case errRestricted = 484
    case errUniqOpPrivsNeeded = 485
    case errNoOperHost = 491
    case errUModeUnknownFlag = 501
    case errUsersDontMatch = 502
}
```

## Permission Types

### IRCChannelPermissions

Channel permission flags.

```swift
enum IRCChannelPermissions {
    case inviteOnly
    case moderated
    case noExternal
    case `private`
    case secret
    case topicProtection
    case key
    case limit
    case ban
    case exception
    case inviteException
    case quiet
    case voice
    case halfOperator
    case `operator`
    case protect
    case owner
}
```

### IRCUserModeFlags

User mode flags.

```swift
enum IRCUserModeFlags {
    case away
    case invisible
    case wallops
    case restricted
    case `operator`
    case localOperator
    case serverNotice
}
```

## Parser and Encoder

### NeedleTailIRCParser

Static methods for parsing IRC messages.

```swift
struct NeedleTailIRCParser {
    static func parseMessage(_ message: String) throws -> IRCMessage
}
```

**Parameters:**
- `message`: Raw IRC message string

**Returns:**
- `IRCMessage`: Parsed message object

**Throws:**
- `MessageParsingErrors`: Various parsing errors

**Example:**
```swift
do {
    let message = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello!")
    print("Origin: \(message.origin ?? "none")")
    print("Command: \(message.command)")
} catch {
    print("Parsing error: \(error)")
}
```

### NeedleTailIRCEncoder

Static methods for encoding IRC messages.

```swift
struct NeedleTailIRCEncoder {
    static func encode(value: IRCMessage) async -> String
}
```

**Parameters:**
- `value`: IRC message to encode

**Returns:**
- `String`: Encoded IRC message string

**Example:**
```swift
let message = IRCMessage(
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello!")
)
let encoded = await NeedleTailIRCEncoder.encode(value: message)
print(encoded) // ": PRIVMSG #general :Hello!"
```

## Transport Protocol

### NeedleTailWriterDelegate

Protocol for message transport delegation.

```swift
protocol NeedleTailWriterDelegate: AnyObject, Sendable {
    func transportMessage(
        _ messageGenerator: IRCMessageGenerator,
        executor: any AnyExecutor,
        consumer: NeedleTailAsyncConsumer<ByteBuffer>,
        logger: NeedleTailLogger,
        writer: NIOAsyncChannelOutboundWriter<ByteBuffer>,
        origin: String,
        command: IRCCommand,
        tags: [IRCTag]?,
        authPacket: AuthPacket?
    ) async throws
}
```

**Methods:**
- `transportMessage(...)`: Transport messages using the provided generator and writer

## Error Types

### NeedleTailError

Main error enumeration.

```swift
enum NeedleTailError: Error {
    case couldNotConnectToServer
    case transportNotIntitialized
    case invalidIRCChannelName
    case nilNickName
    case invalidMessageFormat
    case encodingFailed
    case decodingFailed
    case timeout
    case networkError(String)
    case protocolError(String)
    case validationError(String)
}
```

### MessageParsingErrors

Message parsing specific errors.

```swift
enum MessageParsingErrors: Error {
    case invalidArguments(String)
    case invalidTag
    case invalidPrefix
    case invalidCommand
    case invalidParameters
    case malformedMessage
}
```

## Packet Types

### MultipartPacket

Handles large message chunking and reassembly.

```swift
struct MultipartPacket {
    let recipients: [IRCMessageRecipient]
    let content: String
    let messageId: String
    let partNumber: Int
    let totalParts: Int
    let isLast: Bool
    
    init(recipients: [IRCMessageRecipient], content: String, messageId: String, partNumber: Int = 1, totalParts: Int = 1, isLast: Bool = true)
    
    func createMessages() -> [IRCMessage]
    static func from(_ message: IRCMessage) -> MultipartPacket?
}
```

### DCCPacket

Direct Client-to-Client packet.

```swift
struct DCCPacket {
    let filename: String
    let fileSize: Int
    let ipAddress: String
    let port: Int
    
    init(filename: String, fileSize: Int, ipAddress: String, port: Int)
}
```

### DataToFilePacket

Data-to-file transfer packet.

```swift
struct DataToFilePacket {
    let filename: String
    let data: Data
    
    init(filename: String, data: Data)
}
```

## Helper Types

### Acknowledgment

Acknowledgment packet.

```swift
struct Acknowledgment {
    let messageId: String
    let timestamp: Date
    
    init(messageId: String, timestamp: Date = Date())
}
```

### Call

Call packet.

```swift
struct Call {
    let callId: String
    let participants: [String]
    let timestamp: Date
    
    init(callId: String, participants: [String], timestamp: Date = Date())
}
```

### Constants

IRC protocol constants.

```swift
struct Constants {
    static let maxMessageLength = 512
    static let maxNickLength = 9
    static let maxChannelLength = 50
    static let defaultPort = 6667
    static let defaultSSLPort = 6697
}
```

## Usage Examples

### Basic Message Creation

```swift
// Create a simple message
let message = IRCMessage(
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, world!")
)

// Create message with origin
let messageWithOrigin = IRCMessage(
    origin: "alice!alice@localhost",
    command: .notice([.user("bob")], "Important notice")
)

// Create message with tags
let messageWithTags = IRCMessage(
    origin: "alice",
    command: .join(channels: [NeedleTailChannel("#general")!], keys: nil),
    tags: [IRCTag(key: "time", value: "2023-01-01T12:00:00Z")]
)
```

### Message Parsing

```swift
// Parse incoming message
let rawMessage = ":alice!alice@localhost PRIVMSG #general :Hello, everyone!"
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    
    switch message.command {
    case .privMsg(let recipients, let text):
        print("Private message from \(message.origin ?? "unknown"): \(text)")
        for recipient in recipients {
            switch recipient {
            case .channel(let channel):
                print("To channel: \(channel.name)")
            case .user(let username):
                print("To user: \(username)")
            }
        }
    default:
        print("Other command: \(message.command)")
    }
} catch {
    print("Failed to parse message: \(error)")
}
```

### Message Encoding

```swift
// Encode message for transmission
let message = IRCMessage(
    origin: "bob",
    command: .join(channels: [NeedleTailChannel("#test")!], keys: nil)
)

let encoded = await NeedleTailIRCEncoder.encode(value: message)
print(encoded) // ":bob JOIN #test"
```

### Channel Operations

```swift
// Join channel
let joinMessage = IRCMessage(
    command: .join(channels: [NeedleTailChannel("#general")!], keys: nil)
)

// Join with key
let joinWithKey = IRCMessage(
    command: .join(channels: [NeedleTailChannel("#secret")!], keys: ["password123"])
)

// Part channel
let partMessage = IRCMessage(
    command: .part(channels: [NeedleTailChannel("#general")!])
)
```

### User Operations

```swift
// Change nickname
let nickMessage = IRCMessage(
    command: .nick(NeedleTailNick(name: "newNick", deviceId: UUID())!)
)

// Set user info
let userMessage = IRCMessage(
    command: .user(IRCUserDetails(
        username: "alice",
        realname: "Alice Smith",
        mode: 0
    ))
)

// Set user modes
let modeMessage = IRCMessage(
    command: .mode(
        NeedleTailNick(name: "alice", deviceId: UUID())!,
        add: [.invisible, .away],
        remove: nil
    )
)
```

### Error Handling

```swift
// Handle different error types
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    // Process message
} catch NeedleTailError.invalidIRCChannelName {
    print("Invalid channel name")
} catch NeedleTailError.nilNickName {
    print("Invalid nickname")
} catch MessageParsingErrors.invalidArguments(let details) {
    print("Invalid arguments: \(details)")
} catch {
    print("Unknown error: \(error)")
}
```

## Best Practices

### 1. Always Validate Input

```swift
// Validate channel names
guard let channel = NeedleTailChannel(channelName) else {
    throw NeedleTailError.invalidIRCChannelName
}

// Validate nicknames
guard let nick = NeedleTailNick(name: nickName, deviceId: deviceId) else {
    throw NeedleTailError.nilNickName
}
```

### 2. Use Type-Safe Commands

```swift
// Good: Use enum cases
let command = IRCCommand.privMsg(recipients, message)

// Avoid: Raw commands
let command = IRCCommand.otherCommand("PRIVMSG", [recipient, message])
```

### 3. Handle Errors Properly

```swift
// Comprehensive error handling
do {
    let message = try NeedleTailIRCParser.parseMessage(rawMessage)
    await processMessage(message)
} catch let error as NeedleTailError {
    await handleNeedleTailError(error)
} catch let error as MessageParsingErrors {
    await handleParsingError(error)
} catch {
    await handleUnknownError(error)
}
```

### 4. Use Async/Await Correctly

```swift
// Proper async usage
let encodedMessage = await NeedleTailIRCEncoder.encode(value: message)
try await transport.send(encodedMessage.data(using: .utf8)!)
```

## Next Steps

Now that you have the complete API reference, explore these topics:

- <doc:GettingStarted> - Learn how to get started
- <doc:BasicUsage> - Understand basic usage patterns
- <doc:MessageHandling> - Learn about message processing
- <doc:ErrorHandling> - Understand error handling strategies