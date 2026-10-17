# Standard IRC and IRCv3

Connect to standard RFC 1459 / RFC 2812 servers with IRCv3 extensions, without changing the NeedleTail wire format.

## Overview

NeedleTailIRC's default codec (``IRCFrameDecoder``, ``IRCFrameEncoder``, ``NeedleTailIRCParser``) speaks the NeedleTail dialect, which is tuned for NeedleTail servers. Standard IRC support is opt-in: install a different set of NIO handlers and the rest of your code keeps reading and writing ``IRCFrame``.

Nothing about the NeedleTail dialect changes when you use this. Both can run in the same process on different connections.

## Plugging in

Replace `IRCFrameDecoder` / `IRCFrameEncoder` with one call. Add TLS first if you use it.

```swift
let channel = try await ClientBootstrap(group: group)
    .connect(host: "irc.example.net", port: 6697) { channel in
        channel.eventLoop.makeCompletedFuture {
            // try channel.pipeline.syncOperations.addHandler(tlsHandler)
            try channel.pipeline.syncOperations.addStandardIRCHandlers()
            return try NIOAsyncChannel<IRCFrame, IRCFrame>(wrappingChannelSynchronously: channel)
        }
    }
```

Inbound lines arrive as `IRCFrame.text(IRCMessage)`. Outbound `.text` frames are written the standard way. `.binary` and `.dcc` frames are NeedleTail-only and fail with ``IRCStandardError/Code/unsupportedFrame``.

``IRCStandardConfiguration`` lets you observe the lossless form of every message (``IRCStandardConfiguration/rawObserver``), see lines that are not valid IRC (``IRCStandardConfiguration/unparsableLineHandler``), and enable ``IRCStandardKeepAliveHandler`` (``IRCStandardConfiguration/keepAlive``).

## Lossless messages

``IRCRawMessage`` is the standards-compliant message: tags, source, command, and every parameter exactly as received. The trailing parameter is the last element, verbatim. Nothing is split on commas or trimmed.

```swift
let raw = try IRCRawMessage.parse(":srv 433 * alice :Nickname is already in use")
raw.parameters   // ["*", "alice", "Nickname is already in use"]
try IRCRawMessage(command: "WHOWAS", parameters: ["bob", "5"]).wireLine()   // "WHOWAS bob 5"
```

Parsing is lenient (repeated spaces, more than 15 parameters). Serialization is strict: NUL, CR and LF are rejected in every field, so user text cannot inject commands.

## The typed model

``IRCStandardTranslator`` maps between ``IRCRawMessage`` and ``IRCMessage``. `IRCMessage(standardIRC:)` and `IRCRawMessage(standardIRC:)` are shortcuts.

Inbound, a message becomes a typed ``IRCCommand`` case only when that case can hold it faithfully. Everything else is delivered as `.otherCommand(command, parameters)` or `.otherNumeric(code, parameters)` with the parameters untouched. A valid line is never dropped.

- Numerics: the first parameter becomes ``IRCMessage/target``.
- `CAP` replies: the target becomes ``IRCMessage/target``. Multi-line continuations and `NEW`/`DEL` arrive as `.otherCommand("CAP", …)`.
- Nicknames use ``NeedleTailNick/NameRules/standardIRC``: underscores are allowed and case is kept.
- Channel `MODE` maps to `.channelMode` only when every parameter can stay paired with its letter. Use ``IRCModeParser`` for full detail.

Outbound, `.otherCommand`, `.numeric` and `.otherNumeric` are plain parameter lists, so they can send any command. `.ctcp` and `.ctcpreply` become standard `\u{1}CTCP\u{1}` PRIVMSG/NOTICE. `.ban`, `.voice` and similar become `MODE`. Commands without a portable form (DCC/SDCC, `.quiet`, `.owner`, `.kickban`, …) throw ``IRCStandardError/Code/unsupportedOnStandardIRC``.

### Limits of the typed model

These follow from keeping the existing types unchanged:

- `NeedleTailNick` requires two characters, so messages involving one-character nicks arrive as `.otherCommand`.
- Channel names longer than 50 characters arrive as `.otherCommand`.
- `.part` has no reason and `.join` has no extended-join fields. Read them from the raw observer.
- `IRCUserIdentifier` lowercases nicks. Use ``IRCSource`` with ``IRCISupport/caseMapping`` instead.
- `IRCMessageGenerator` produces NeedleTail multipart packets. Use ``IRCStandardTextSplitter`` on standard connections.

## Registration, CAP and SASL

``IRCRegistration`` drives a whole client registration: `CAP LS 302`, `PASS`, `NICK`, `USER`, capability requests, SASL before `CAP END`, nick collisions, `PING`, and ISUPPORT. It is a value type with no I/O. You send what it returns.

```swift
var registration = IRCRegistration(configuration: .init(
    nick: "alice", username: "alice", realname: "Alice",
    sasl: .plain(username: "alice", password: password)
))
send(registration.start())
// For every inbound IRCRawMessage:
send(registration.handle(message))
if registration.isRegistered { /* joined the network */ }
```

``IRCCapabilityNegotiator`` and ``IRCSASLAuthenticator`` can also be used on their own.

## Server features

- ``IRCISupport``: `RPL_ISUPPORT` (005) tokens such as `PREFIX`, `CHANMODES`, `CASEMAPPING`, `NICKLEN` and `TARGMAX`.
- ``IRCCaseMapping``: compare nicks and channels the way the server does.
- ``IRCModeParser``: any channel or user mode string, using the server's mode types.
- ``IRCBatchCollector``: IRCv3 batches, including nested ones.
- Tag accessors on ``IRCRawMessage`` and ``IRCMessage``: `serverTime`, `messageID`, `account`, `label`, `batchReference`, `clientOnlyTags`.
- ``IRCCTCPMessage``: standard CTCP inside PRIVMSG/NOTICE.
- ``IRCStandardTextSplitter``: split text to fit the 512-byte line limit without breaking characters.

## Topics

### Plugging in

- ``IRCStandardConfiguration``
- ``IRCStandardInboundBridge``
- ``IRCStandardFrameEncoder``
- ``IRCStandardLineDecoder``
- ``IRCRawMessageEncoder``
- ``IRCStandardKeepAliveHandler``
- ``IRCStandardKeepAliveConfiguration``

### Messages

- ``IRCRawMessage``
- ``IRCSource``
- ``IRCStandardTranslator``
- ``IRCStandardError``

### Session

- ``IRCRegistration``
- ``IRCRegistrationConfiguration``
- ``IRCCapabilityNegotiator``
- ``IRCSASLAuthenticator``
- ``IRCSASLCredentials``

### Server features

- ``IRCISupport``
- ``IRCCaseMapping``
- ``IRCMembershipPrefix``
- ``IRCChannelModeTypes``
- ``IRCModeParser``
- ``IRCModeChange``
- ``IRCBatchCollector``
- ``IRCBatch``
- ``IRCCTCPMessage``
- ``IRCStandardTextSplitter``
