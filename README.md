<img src="needletail_irc.svg" alt="NeedleTailIRC" width="200" />

# NeedleTailIRC

A Swift package for parsing, encoding, and framing IRC (Internet Relay Chat) messages with modern concurrency support.

[![Swift](https://img.shields.io/badge/Swift-6.4+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B%20%7C%20macOS%2015%2B-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

NeedleTailIRC is a type-safe IRC protocol layer for the NeedleTail stack. It parses and encodes RFC 2812 / RFC 1459 lines with IRCv3 message tags, chunks long text into lines a server accepts, and frames length-prefixed binary and self-delimiting DCC payloads on the same socket. It does **not** open sockets, negotiate TLS, CAP or SASL, or run a registration state machine: you provide the NIO transport and session logic, and write `IRCFrame` values through it.

It has been run against public servers (Ergo, Libera.Chat's Solanum and OFTC): registration, CAP 302, PING/PONG, ISON, USERHOST, WHOIS, WHOWAS, PRIVMSG and NOTICE (including chunked text), AWAY, JOIN, NAMES, WHO, LIST, TOPIC, channel MODE, client tags, PART with a reason, QUIT and ERROR, with no line it couldn't parse.

## Features

- **Parse & encode IRC lines**: `NeedleTailIRCParser` and `NeedleTailIRCEncoder`, with `IRCMessage.wireLine()` as the validated encode path
- **Every RFC 2812 command typed**: all 45 commands have `IRCCommand` cases, and any other command travels as `.otherCommand(name, parameters)`
- **One socket unit**: `IRCFrame` is `.text(IRCMessage)`, `.binary(IRCBinaryMessage)`, or `.dcc(DCCMessage)`
- **IRCv3 message tags**: parsing, escaping, round-trip encoding, and `IRCVersion` (`.v1` without tags, `.v3` with them)
- **Chunked text**: `IRCMessageGenerator` cuts long PRIVMSG and NOTICE text into lines that fit RFC 2812's 512 bytes and reassembles them
- **Outbound validation**: a line that would break RFC 2812 or IRCv3 throws before anything is written
- **Custom commands**: declare application commands as `IRCCustomCommand`, send them with `IRCCommand.custom(_:_:)`, and match them in a `switch`
- **Binary payloads**: `IRCBinaryMessage` carries opaque bytes on the server connection without base64 or line limits
- **DCC frames**: encode/decode bounded, self-delimiting `DCCMessage` frames (not a full file-transfer client)
- **NIO integration**: `IRCFrameEncoder`, `IRCFrameDecoder`, and `NeedleTailWriterDelegate`

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/needletails/needletail-irc.git", from: "3.0.0")
]
```

### Xcode

1. Go to **File** → **Add Package Dependencies**
2. Enter: `https://github.com/needletails/needletail-irc.git`
3. Select the version you want
4. Add to your target

## Quick Start

```swift
import NeedleTailIRC

// Build a message and encode it as one validated line (no CRLF).
let message = IRCMessage(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], "Hello, world!")
)
let line = try message.wireLine()   // ":alice PRIVMSG #general :Hello, world!"

// Parse a line.
let parsed = try NeedleTailIRCParser.parseMessage(":alice!alice@localhost PRIVMSG #general :Hello, world!")
```

On a socket, write `IRCFrame.text(message)` through `NeedleTailWriterDelegate.sendAndFlushMessage`, which validates the line before it reaches the NIO pipeline. A throw inside `IRCFrameEncoder` would fail every later write on that channel.

### Sending long text

`IRCMessageGenerator` cuts PRIVMSG and NOTICE text into pieces, on Character boundaries where possible, sized so the line a server relays (`:<nick!user@host> PRIVMSG <targets> :<piece>`) fits 512 bytes. Each line also carries a `packet-metadata` tag with the piece's place in its group, and `messageReassembler(ircMessage:)` rebuilds the text.

```swift
let generator = IRCMessageGenerator(executor: executor)
for try await frame in await generator.createMessages(
    origin: "alice",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], longText),
    logger: NeedleTailLogger()
) {
    try await delegate.sendAndFlushMessage(writer: writer, message: IRCFrame.text(frame))
}

// On receive:
if let rebuilt = try await generator.messageReassembler(ircMessage: incomingMessage) {
    await handleMessage(rebuilt)
}
```

IRCv3 lets a client send tags only after the server acknowledges `message-tags`, and a server without tags answers a tagged line with `421`. After CAP negotiation, set the generator's version:

```swift
await generator.setVersion(acknowledgedCaps.contains("message-tags") ? .v3 : .v1)
```

`.v3` is the default and what NeedleTail servers speak. With `.v1`, frames carry no tags and the text travels in the body only, so other clients see consecutive lines.

## Examples

### Channel Operations

```swift
let general = NeedleTailChannel("#general")!

let join = IRCCommand.join(channels: [general], keys: nil)
let say = IRCCommand.privMsg([.channel(general)], "Hello, everyone!")
let inviteOnly = IRCCommand.channelMode(general, addMode: .inviteOnly, addParameters: nil, removeMode: nil, removeParameters: nil)
let leave = IRCCommand.partMessage(channels: [general], message: "see you later")   // PART #general :see you later
```

### User Operations

```swift
let me = NeedleTailNick(wireValue: "Alice")!          // keeps its case; nicks compare without case

let nick = IRCCommand.nick(me)
let modes = IRCCommand.mode(me, add: [.invisible], remove: [.wallOps])   // MODE Alice +i-w
let whois = IRCCommand.whois(server: nil, usermasks: ["Alice"])
let whowas = IRCCommand.whowas([NeedleTailNick(wireValue: "Wiz")!], count: 5, target: nil)
let userhost = IRCCommand.userhost([me])
```

### Custom Commands

```swift
extension IRCCustomCommand {
    static let badgeUpdate: IRCCustomCommand = "BADGEUPDATE"
}

let badge = IRCCommand.custom(.badgeUpdate, ["3"])   // BADGEUPDATE :3

switch message.command {
case .otherCommand(IRCCustomCommand.badgeUpdate, let arguments):
    handleBadge(arguments)
default:
    break
}
```

## Error Handling

```swift
do {
    let message = try NeedleTailIRCParser.parseMessage(rawLine)
    handle(message)
} catch NeedleTailIRCCommandParser.CommandParserErrors.invalidChannelName(let name) {
    print("Invalid channel name: \(name)")
} catch NeedleTailIRCCommandParser.CommandParserErrors.invalidNick(let nick) {
    print("Invalid nickname: \(nick)")
} catch MessageParsingErrors.invalidArguments(let details) {
    print("Invalid arguments: \(details)")
} catch MessageParsingErrors.invalidTag {
    print("Invalid tag format")
} catch {
    print("Unknown parsing error: \(error)")
}

do {
    let line = try message.wireLine()
    send(line)
} catch let error as IRCMessageGeneratorError {
    // invalidCommand, invalidOrigin, invalidTagKey, invalidParameter, tooManyParameters
    // or emptyCommandRejected: the message can't be written as an RFC 2812 line.
    print("Rejected outbound line: \(error)")
}
```

`IRCFrameDecoder` skips a line it can't parse (`IRCMessage.IgnoredLine`) and throws `IRCMessage.LineError.lineTooLong` when pending bytes pass its line limit.

## API and wire semantics

- **Lines** split by RFC 2812: single-word middle parameters, then one trailing parameter kept verbatim, trailing spaces included. A line carries at most 15 parameters; `ISON` past 14 nicks writes the rest as one trailing parameter.
- **Validation**: `wireLine()` requires a command of letters or three digits, an origin without spaces, tag keys of the form `[+][vendor/]name`, single-word middle parameters, RFC 2812 mask targets and at most 15 parameters, and strips NUL, CR and LF. `sendAndFlushMessage` runs the same checks before writing. Line length is kept by the generator's chunking, not checked here, so keep text you send directly short.
- **Commands**: all 45 RFC 2812 commands have typed cases, including `pass`, `service`, `servlist`, `squery`, `whowas`, `error`, `summon` and `userhost`. A bare `PASS` with no parameter (NeedleTail's legacy form, its value in `packet-metadata`) still parses as `.otherCommand("PASS", [])`. Many servers don't implement SERVICE, SERVLIST, SQUERY or SUMMON and answer `421`.
- **Nicks** read off the wire keep their case and compare without case (RFC 2812 §2.2). A NeedleTail `name_UUID` nick is an account identity and stays lowercased. `NeedleTailNick.stringValue` emits `name_UUID` when a device identifier exists and `name` otherwise. `IRCUserIdentifier("Alice!alice@host")` reads the nick the same way, so `Alice`, `a_b` and `x` are kept as sent; passing a `deviceId` builds a NeedleTail identity instead.
- **Targets**: `IRCMessageRecipient` is a channel, a nick, `*`, or `.mask` for the other RFC 2812 forms (`$*.example.net`, `nick!user@host`, `user%host@server`, `user%host`, `user@server`).
- **Numerics** with `target` set are written in RFC form (`:srv 433 alice bob :Nickname is already in use`). Without a target they keep the NeedleTail form (`465 :DEVICE_REVOKED, <uuid>`), which the parser still splits on commas. `transportMessage` and `createMessages` take an optional `target`.
- **CAP** replies keep their target, including the forms `.cap` can't hold (`LS *` continuations, `NEW`, `DEL`).
- **Modes**: a MODE line is one mode string followed by its parameters (`+iw-o`, `+ov-k bob alice key`). In `.channelMode` each sign's modes are a set, and parameters pair with the modes that take one in `IRCChannelPermissions.stringValue` order (`o` before `v`, `l` before `k`), so the parser stores `+vo alice bob` as `+ov bob alice`, the same meaning. A line a set can't express, such as `+oov alice bob carol`, parses as `.channelModeChanges` with every change in order. `USER` with mode flags writes the RFC 2812 bitmask (`USER alice 8 * :Real`); a bare `LIST` asks for every channel.
- **Chunking**: PRIVMSG and NOTICE pieces travel in the body and in `packet-metadata`; other commands are cut at 512 UTF-8 bytes into the tag only. `messageReassembler` reads the tag (`packet-metadata`, legacy `@packet-metadata`, or IRCv3 client-only `+packet-metadata`) and falls back to the body. Large application payloads belong in `IRCBinaryMessage`.
- **Frames**: the leading byte selects the family: `0xFF` is `IRCBinaryMessage`, `0x00...0x04` is `DCCMessage`, anything else is an `IRCMessage` line. Choose a decoder per socket: `lineBasedIRC()` (text only), `serverIRC()` (text plus binary, no DCC), `withBinaryFrames()` (all three).
- **DCC**: every variable-length `DCCMessage` field, including `serviceName`, is `UInt32` length-prefixed. `serviceName` changed in 2.0.0; both ends of a DCC connection must update together.
- **Parsing limits**: `NeedleTailIRCParser.parseMessage(_:)` keeps the historical unbounded tag behavior; use `parseMessage(_:limits:)` with `.standardIRC` for untrusted input.
- **Equality**: `IRCMessage` and `IRCBinaryMessage` equality is identity-based (`id`); `IRCTag` equality is key-based. Compare protocol fields explicitly when value equality is needed.
- **Events**: `IRCEventProtocol` has callbacks for the core commands (registration, CAP, channels, messaging, modes, queries, KICK, KILL) and DCC, each with a no-op default. Override the ones your integration needs; dispatch any other command from `IRCMessage.command` yourself.

## Architecture

- **Parsing**: `NeedleTailIRCParser` (line → `IRCMessage`) and `NeedleTailIRCCommandParser` (command and parameters → `IRCCommand`)
- **Encoding**: `IRCMessage.wireLine()` (validated) over `NeedleTailIRCEncoder`
- **Chunking**: `IRCMessageGenerator`, `PacketDerivation`, `PacketBuilder`, `MultipartPacket`
- **Framing**: `IRCFrame`, `IRCFrameDecoder`, `IRCFrameEncoder`
- **Models**: `IRCCommand`, `IRCCommandCode`, `IRCMessageRecipient`, `NeedleTailChannel`, `NeedleTailNick`, `IRCTag`, `IRCUserDetails`, `IRCChannelPermissions`, `IRCUserModeFlags`, `IRCCustomCommand`, `IRCVersion`
- **Transport hook**: `NeedleTailWriterDelegate`

## Documentation

Release history is in [CHANGELOG.md](CHANGELOG.md). API documentation lives in [Documentation.docc](Sources/NeedleTailIRC/Documentation.docc):

- [Getting Started](Sources/NeedleTailIRC/Documentation.docc/GettingStarted.md) — installation and first messages
- [Basic Usage](Sources/NeedleTailIRC/Documentation.docc/BasicUsage.md) — core concepts and patterns
- [Message Format](Sources/NeedleTailIRC/Documentation.docc/MessageFormat.md) — IRC message structure
- [Message Handling](Sources/NeedleTailIRC/Documentation.docc/MessageHandling.md) — processing messages
- [IRC Commands](Sources/NeedleTailIRC/Documentation.docc/IRCCommands.md) — command reference
- [Channels](Sources/NeedleTailIRC/Documentation.docc/Channels.md) — channel management
- [Users](Sources/NeedleTailIRC/Documentation.docc/Users.md) — user management and permissions
- [Multipart Messages](Sources/NeedleTailIRC/Documentation.docc/MultipartMessages.md) — chunked text
- [Transport Layer](Sources/NeedleTailIRC/Documentation.docc/TransportLayer.md) — NIO writer integration
- [Error Handling](Sources/NeedleTailIRC/Documentation.docc/ErrorHandling.md) — error types and strategies
- [API Reference](Sources/NeedleTailIRC/Documentation.docc/APIReference.md) — public API overview

## Requirements

- **Swift**: 6.4+ (`swift-tools-version: 6.4`)
- **Platforms**: iOS 18.0+, macOS 15.0+

## Dependencies

- `swift-nio` — NIOCore
- `swift-algorithms` — algorithm utilities
- `swift-log` — logging API used by transport integration
- `needletail-logger` — logging
- `needletail-algorithms` — NeedleTailAsyncSequence and related utilities
- `binary-codable` — binary serialization for `packet-metadata` and auth tags on the text path
- `swift-docc-plugin` — documentation builds

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Support

- **Documentation**: [Documentation.docc](Sources/NeedleTailIRC/Documentation.docc)
- **Issues**: [GitHub Issues](https://github.com/needletails/needletail-irc/issues)

## Acknowledgments

- IRC protocol specifications (RFC 2812, RFC 1459)
- IRCv3 extension specifications
- The Swift community
