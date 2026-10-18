# API Reference

Complete API reference for all public types and methods in NeedleTailIRC.

## Overview

This document provides a comprehensive reference for all public APIs in the NeedleTailIRC SDK. Each type, method, and property is documented with its purpose, parameters, return values, and usage examples.

## Core Types

### IRCMessage

The main message type representing an IRC message.

```swift
struct IRCMessage {
    var id: UUID
    var origin: String?
    var target: String?
    var command: IRCCommand
    var tags: [IRCTag]?
    
    init(origin: String? = nil, target: String? = nil, command: IRCCommand, tags: [IRCTag]? = nil)

    static let maxParameters: Int // 15
    func wireLine() throws -> String
}
```

**Properties:**
- `origin`: The message origin/source (optional)
- `target`: The recipient's nick for numeric and CAP replies (optional; RFC 2812 §2.4)
- `command`: The IRC command or numeric response
- `tags`: IRCv3 message tags (optional)

`Equatable` is intentionally identity-based: two messages are equal when their generated `id` values match.

**Wire validation:** `wireLine()` throws an `IRCMessageGeneratorError` unless the message can be written as one RFC 2812 line with IRCv3 tags:
- The command is letters or three digits.
- The origin has no space.
- Every tag key is `[+][vendor/]name`.
- Every parameter before the last is one non-empty word that doesn't start with `:`.
- There are at most 15 parameters.
- Every `.mask` message target is an RFC 2812 mask or user address.

`sendAndFlushMessage` runs the same checks before writing. `wireLine()` also strips NUL, CR and LF. Line length is kept by `IRCMessageGenerator`'s chunking, not checked here.

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
    case partMessage(channels: [NeedleTailChannel], message: String)
    case list(channels: [NeedleTailChannel]?, target: String?)
    case channelModeGet(NeedleTailChannel)
    case channelMode(NeedleTailChannel, addMode: IRCChannelPermissions?, addParameters: [String]?, removeMode: IRCChannelPermissions?, removeParameters: [String]?)
    case channelModeChanges(NeedleTailChannel, [IRCChannelModeChange])  // every change in order
    
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
    case cap(CAPSubCommand, [String])
    
    // Numeric responses
    case numeric(IRCCommandCode, [String])
    
    // More RFC 2812 commands (the listing above is abridged; all 45 have cases)
    case pass(String)
    case service(nickname: String, distribution: String, type: String, info: String)
    case servlist(mask: String?, type: String?)
    case squery(serviceName: String, text: String)
    case whowas([NeedleTailNick], count: Int?, target: String?)
    case error(String)
    case summon(user: String, target: String?, channel: NeedleTailChannel?)
    case userhost([NeedleTailNick])

    // Other commands
    case otherCommand(String, [String])

    // An application command, sent as `otherCommand`
    static func custom(_ command: IRCCustomCommand, _ arguments: [String] = []) -> IRCCommand
}
```

### IRCCustomCommand

The name of a command your application defines on top of IRC. Declare each one in your app, send it with `IRCCommand.custom(_:_:)`, and match it in a `switch` over `otherCommand`.

```swift
struct IRCCustomCommand: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String       // uppercased
    init?(rawValue: String)    // nil unless ASCII letters only
}

func ~= (pattern: IRCCustomCommand, value: String) -> Bool  // case-insensitive
```

**Example:**
```swift
extension IRCCustomCommand {
    static let badgeUpdate: IRCCustomCommand = "BADGEUPDATE"
}

try await writer.transportMessage(command: .custom(.badgeUpdate, ["3"]))

switch message.command {
case .otherCommand(IRCCustomCommand.badgeUpdate, let arguments):
    handleBadge(arguments)
default:
    break
}
```

### Channel MODE pairing

RFC 2812 §3.2.3 pairs each parameter with the next mode letter that takes one. In `.channelMode`, each sign's modes are a set, so parameters pair with the modes that take one in `IRCChannelPermissions.stringValue` order (`o` before `v`, `l` before `k`), and extra parameters go to the last such mode. The parser stores them that way: `MODE #room +vo alice bob` parses as `addMode: [.channelOperator, .voice], addParameters: ["bob", "alice"]` and is written back as `MODE #room +ov bob alice`, which means the same thing.

A line the set can't express, such as `+oov alice bob carol`, parses as `.channelModeChanges`, which keeps each change in order:

```swift
struct IRCChannelModeChange: Codable, Hashable, Sendable {
    var adding: Bool                  // + or -
    var mode: IRCChannelPermissions   // exactly one mode
    var parameter: String?
}
```

Both are written as one mode string followed by the parameters (`MODE #room +v-o alice bob`).

### IRCMessageRecipient

Represents message recipients (channels or users).

```swift
enum IRCMessageRecipient {
    case channel(NeedleTailChannel)
    case nick(NeedleTailNick)
    case all
    case mask(String)  // $*.example.net, nick!user@host, user%host@server, user%host, user@server
}
```

`mask` holds the RFC 2812 §3.3.1 targets that are neither a channel nor a nick, written as sent. They are valid PRIVMSG and NOTICE targets, but not MODE targets.

### NeedleTailChannel

Represents an IRC channel with validation.

```swift
final class NeedleTailChannel {
    var stringValue: String { get }
    var canonicalWireName: String { get }
    
    init?(_ name: String)
}
```

**Properties:**
- `stringValue`: The original validated channel name (for example, `#general`)
- `canonicalWireName`: The IRC-case-folded value used for equality and hashing

**Example:**
```swift
guard let channel = NeedleTailChannel("#general") else {
    print("Invalid channel name: \(name)")
    return
}
```

### NeedleTailNick

Represents an IRC nickname with device ID.

```swift
struct NeedleTailNick {
    let name: String
    let deviceId: UUID?

    init?(name: String, deviceId: UUID?)
    init?(wireValue: String)
}
```

**Properties:**
- `name`: The nickname
- `deviceId`: Optional NeedleTail device identifier

`stringValue` emits `name_UUID` when `deviceId` is present and a standard `name` otherwise.

`init?(name:deviceId:)` lowercases the name. `init?(wireValue:)`, which the parser uses, keeps a standard nick's case, as IRC servers do, and lowercases the name of a NeedleTail `name_UUID` nick, which is an account identity. Nicks compare without case using RFC 2812 §2.2 mapping, so `Bob == bob` and `Robo[t] == robo{t}`.

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
    let userModeFlags: IRCUserModeFlags?
    let hostname: String?
    let servername: String?

    init(username: String, realname: String)
    init(username: String, hostname: String, servername: String, realname: String)
}
```

**Properties:**
- `username`: Username for registration
- `realname`: Real name/GECOS field
- `userModeFlags`: Optional legacy user mode flags

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

`Hashable` and `Equatable` intentionally use the key only. Compare `value` explicitly when tag payload equality is required.

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
    case errorNoSuchNick = 401
    case errorNoSuchServer = 402
    case errorNoSuchChannel = 403
    case errorCannotSendToChain = 404
    case errorTooManyChannels = 405
    case errorWasNoSuchNick = 406
    case errorTooManyTargets = 407
    case errorNoSuchService = 408
    case errorNoOrigin = 409
    case errorNoRecipient = 411
    case errorNoTextToSend = 412
    case errorNoTopLevel = 413
    case errorWildTopLevel = 414
    case errorBadMask = 415
    case errorUnknownCommand = 421
    case errorNoMotD = 422
    case errorNoAdminInfo = 423
    case errorFileError = 424
    case errorNoNickNameGiven = 431
    case errorErroneousNickname = 432
    case errorNicknameInUse = 433
    case errorNickCollision = 436
    case errorUnavailableResource = 437
    case errorUserNotInChannel = 441
    case errorNotOnChannel = 442
    case errorUserOnChannel = 443
    case errorNoLogin = 444
    case errorSummonDisabled = 445
    case errorUsersDisabled = 446
    case errorNotRegistered = 451
    case errorNeedMoreParams = 461
    case errorAlreadyRegistered = 462
    case errorNoPermForHost = 463
    case errorPasswordMismatch = 464
    case errorYouReBannedCreep = 465
    case errorYouWillBeBanned = 466
    case errorKeySet = 467
    case errorChannelIsFull = 471
    case errorUnknownMode = 472
    case errorInviteOnlyChan = 473
    case errorBannedFromChan = 474
    case errorBadChannelKey = 475
    case errorBadChannelMask = 476
    case errorNoChannelModels = 477
    case errorBanListFull = 478
    case errorNoPrivileges = 481
    case errorChanOPrivsNeeded = 482
    case errorCantKillServer = 483
    case errorRestricted = 484
    case errorUniqOpPrivIsNeeded = 485
    case errorNoOperHost = 491
    case errorUModeUnknownFlag = 501
    case errorUsersDontMatch = 502
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
    static func parseMessage(_ message: String, limits: IRCParserLimits) throws -> IRCMessage
}
```

**Parameters:**
- `message`: Raw IRC message string

**Returns:**
- `IRCMessage`: Parsed message object

**Throws:**
- `MessageParsingErrors`: Various parsing errors

The one-argument overload retains compatibility with large NeedleTail tags. Pass
`IRCParserLimits.standardIRC` when parsing untrusted standard-IRC traffic.

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
    static func encode(value: IRCMessage) -> String
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
let encoded = NeedleTailIRCEncoder.encode(value: message)
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
        logger: NeedleTailLogger,
        writer: NIOAsyncChannelOutboundWriter<IRCFrame>,
        origin: String,
        target: String?,
        command: IRCCommand,
        tags: [IRCTag]?,
        authPacket: AuthPacket?
    ) async throws

    func sendAndFlushMessage<OutboundOut>(
        executor: (any AnyExecutor)?,
        logger: NeedleTailLogger,
        writer: NIOAsyncChannelOutboundWriter<OutboundOut>,
        message: OutboundOut
    ) async throws
}
```

**Methods:**
- `transportMessage(...)`: Generate multipart messages and write each through `sendAndFlushMessage`
- `sendAndFlushMessage(...)`: Write a single outbound payload to the NIO writer. A text line goes through the `wireLine()` checks first, so an invalid one throws to the caller and never reaches the pipeline. A throw inside `IRCFrameEncoder` would fail every later write on that channel.

See <doc:TransportLayer> for integration guidance. This package does not provide socket or TLS connectivity.

### IRCEventProtocol

Inbound command callbacks used by an application dispatcher.

Every requirement has a no-op default. Override each callback that is meaningful to your integration; an unimplemented callback is ignored.

## Error Types

### NeedleTailError

Validation errors for NeedleTailIRC models.

```swift
enum NeedleTailError: String, Error, Sendable {
    case nilNickName
    case invalidUserId
    case deviceIdNil
    case usernameNil
    case nilData
}
```

### MessageParsingErrors

Message parsing specific errors.

```swift
enum MessageParsingErrors: Error, Sendable {
    case invalidArguments(String)
    case invalidCAPCommand(String)
    case invalidTag
}
```

### IRCMessageGeneratorError

Outbound errors. Nothing has been written when one of these is thrown.

```swift
enum IRCMessageGeneratorError: Error, Sendable, Equatable {
    case zeroFramesGenerated        // transportMessage wrote no frames
    case packetMetadataEncodeFailed
    case emptyCommandRejected       // JOIN/PART without channels, PRIVMSG/NOTICE without recipients
    case authPacketEncodeFailed
    case invalidCommand             // not letters or three digits
    case invalidOrigin              // origin contains a space
    case invalidTagKey              // not [+][vendor/]name
    case invalidParameter           // a parameter before the last is empty, has a space or starts with ':'
    case tooManyParameters          // more than 15
}
```

## Packet Types

### MultipartPacket

Binary/text chunk used by `PacketDerivation` and `PacketBuilder`.

```swift
struct MultipartPacket {
    let groupId: String
    var date: Date
    var partNumber: Int
    let totalParts: Int
    var message: String?
    var data: Data?

    init(groupId: String, date: Date, partNumber: Int, totalParts: Int, message: String?, data: Data?)
}
```

### IRCMessageGenerator

Actor that creates outbound IRC messages and reassembles multipart inbound chunks.

```swift
actor IRCMessageGenerator {
    init(executor: any AnyExecutor, binaryEncoder: any BinaryEncoding = BinaryEncoder(), version: IRCVersion = .v3)
    private(set) var version: IRCVersion
    func setVersion(_ version: IRCVersion)

    func createMessages(origin: String, target: String?, command: IRCCommand, tags: [IRCTag]?, authPacket: AuthPacket?, logger: NeedleTailLogger) async -> AsyncThrowingStream<IRCMessage, Error>
    func messageReassembler(ircMessage: IRCMessage) async throws -> IRCMessage?
}
```

PRIVMSG and NOTICE text is cut into pieces sized so each relayed line fits RFC 2812's 512 bytes. Each piece travels in the line's body and in a base64 `packet-metadata` tag of about 800 bytes that also records its place in the group. Other commands are cut at 512 UTF-8 bytes and carried in the tag only. Send large payloads as `IRCBinaryMessage`.

### IRCVersion

The protocol level a connection speaks. It decides whether outgoing lines carry tags.

```swift
enum IRCVersion: Sendable, Equatable {
    case v1  // RFC 1459 / RFC 2812: no tags
    case v3  // IRCv3 with message-tags acknowledged: tags (the default)
}
```

IRCv3 lets a client send tags only after the server acknowledges `message-tags`; a server without it reads `@...` as the command and answers 421. After CAP negotiation, call `generator.setVersion(acked.contains("message-tags") ? .v3 : .v1)`. With `.v1`, frames carry no tags and each PRIVMSG and NOTICE piece travels in the body only.

### PacketBuilder

Actor that reassembles `MultipartPacket` values into complete text or binary payloads.

```swift
actor PacketBuilder {
    func processPacket(_ packet: MultipartPacket) -> ProcessedResult
}
```

### IRCFrame

The unit read from or written to a socket. Every payload conforms to `IRCWireEncodable`.

```swift
enum IRCFrame: IRCWireEncodable {
    case text(IRCMessage)          // CRLF line
    case binary(IRCBinaryMessage)  // 0xFF-discriminated, length-prefixed
    case dcc(DCCMessage)           // 0...4-discriminated peer frame
}

protocol IRCWireEncodable: Sendable {
    func encode(into buffer: inout ByteBuffer) throws
}
```

### IRCBinaryMessage

Server-routed binary sibling of `IRCMessage`. Same envelope, opaque body.

```swift
struct IRCBinaryMessage: IRCWireEncodable {
    static let discriminator: UInt8 = 0xFF
    static let wireVersion: UInt8 = 1

    var id: UUID
    var origin: String?
    var recipients: [IRCMessageRecipient]
    var tags: [IRCTag]?
    var contentType: String?
    var sequence: Sequence?        // groupId, partNumber, totalParts
    var payload: Data
}
```

### DCCMessage

DCC-style peer frame (encode/decode only — not a socket file-transfer client).

Multipart packet strings use UInt32 length-prefixed UTF-8 fields so frames can be
decoded incrementally and independently. Configure binary size limits with
`IRCFrameDecoder.withBinaryFrames(maxBinaryFrameLength:)`.

```swift
enum DCCMessage: IRCWireEncodable {
    case serviceName(String)
    case message(MultipartPacket)
    case multipart(MultipartPacket)
    case blob(Data)
    case close
}
```

### IRCFrameDecoder.BinaryFraming

Per-socket gate for which binary families the decoder recognises.

```swift
struct BinaryFraming: OptionSet { static let dcc, ircBinary, none, all }

IRCFrameDecoder.lineBasedIRC()      // none
IRCFrameDecoder.serverIRC()         // .ircBinary
IRCFrameDecoder.withBinaryFrames()  // .all
```

### Constants

String constants for IRC command names and NeedleTail extension commands.

```swift
enum Constants: String {
    case privMsg = "PRIVMSG"
    case nick = "NICK"
    case join = "JOIN"
    case pass = "PASS"
    // ...
}
```

NeedleTail's application commands are not in `Constants`. Declare each as an `IRCCustomCommand` in your app; the wire names stay the same, for example `static let badgeUpdate: IRCCustomCommand = "BADGEUPDATE"`.

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
    command: .notice([.nick(NeedleTailNick(name: "bob", deviceId: UUID())!)], "Important notice")
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
                print("To channel: \(channel.stringValue)")
            case .nick(let nick):
                print("To nick: \(nick.name)")
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

let encoded = NeedleTailIRCEncoder.encode(value: message)
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
        realname: "Alice Smith"
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
} catch NeedleTailIRCCommandParser.CommandParserErrors.invalidChannelName(let name) {
    print("Invalid channel name: \(name)")
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
    throw NeedleTailIRCCommandParser.CommandParserErrors.invalidChannelName(channelName)
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

### 4. Chunk large payloads before sending

```swift
let generator = IRCMessageGenerator(executor: executor)
let stream = await generator.createMessages(
    origin: "alice",
    command: .privMsg([.channel(channel)], largeText),
    logger: logger
)

for try await message in stream {
    let line = NeedleTailIRCEncoder.encode(value: message)
    try await writeLineToYourTransport(line)
}
```

## Next Steps

Now that you have the complete API reference, explore these topics:

- <doc:GettingStarted> - Learn how to get started
- <doc:BasicUsage> - Understand basic usage patterns
- <doc:MessageHandling> - Learn about message processing
- <doc:ErrorHandling> - Understand error handling strategies