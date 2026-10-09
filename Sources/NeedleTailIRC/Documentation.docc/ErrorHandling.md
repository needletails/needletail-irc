# Error Handling

Understand error types provided by the NeedleTailIRC API.

## Overview

NeedleTailIRC provides specific error types for different failure scenarios. Understanding these errors is important for working with the API.

## Key Errors You Should Handle

- **`IRCMessage.LineError.lineTooLong`** (aliased as `IRCFrameDecoder.DecoderError`): Raised when pending IRC bytes exceed the configured line limit, with or without a newline.
- **`MessageParsingErrors`**: Raised when parsing a single IRC line fails (invalid tags/arguments/etc).
- **`IRCMessageGeneratorError`**: Raised for empty outbound commands and authentication or packet-metadata encoding failures.

## Outbound (encoding) limits

```swift
// IRCFrameEncoder is the mandatory outbound encoding boundary; it delegates to
// IRCWireEncodable.encode(into:) on each payload type.
// This SDK does not enforce a hard IRC line length limit at the encoder boundary by default,
// because some deployments support/require larger-than-512 lines.
// IRCMessage: empty required channels/recipients throw emptyCommandRejected; embedded
//             CR/LF are stripped at the scalar level so a line can never contain its own terminator.
// IRCBinaryMessage: empty recipients throw emptyCommandRejected; payload > UInt32.max is malformed.
```

## Inbound (decoding) limits

```swift
// IRCFrameDecoder enforces safety limits:
// - Oversize IRC lines are treated as protocol violations (error + close by default).
// - If the buffer grows beyond the configured max without a newline, it errors + closes.
// - Unparsable or blank text lines are consumed and skipped (IRCMessage.IgnoredLine), not thrown.
// - Binary frame lengths are validated before their payload is consumed; a malformed
//   binary frame throws because there is no delimiter to resynchronise on.
```

## Basic Error Handling

```swift
// Handle errors in message parsing
func parseMessageSafely(_ rawMessage: String) -> IRCMessage? {
    do {
        return try NeedleTailIRCParser.parseMessage(rawMessage)
    } catch MessageParsingErrors.invalidArguments(let details) {
        print("Invalid arguments: \(details)")
        return nil
    } catch MessageParsingErrors.invalidTag {
        print("Invalid tag format")
        return nil
    } catch {
        print("Unknown parsing error: \(error)")
        return nil
    }
}

// Handle connection errors
func connectToServer(host: String, port: Int) async {
    do {
        try await connectionManager.connect(host: host, port: port, useSSL: false)
        print("Successfully connected to \(host):\(port)")
    } catch NeedleTailError.couldNotConnectToServer {
        print("Failed to connect to server")
    } catch NeedleTailError.transportNotIntitialized {
        print("Transport layer not initialized")
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

## Error Usage Examples

### Channel Validation Errors

```swift
// Handle channel validation
guard let channel = NeedleTailChannel("#general") else {
    throw NeedleTailError.invalidIRCChannelName
}
```

### Nickname Validation Errors

```swift
// Handle nickname validation
guard let nick = NeedleTailNick(name: "alice", deviceId: UUID()) else {
    throw NeedleTailError.nilNickName
}
```

### Message Parsing Errors

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

### Encoding / wire-size errors

```swift
do {
    let stream = await generator.createMessages(
        origin: origin,
        command: command,
        authPacket: authPacket,
        logger: logger
    )
    for try await message in stream {
        try await writer.write(.text(message))
    }
} catch IRCMessageGeneratorError.authPacketEncodeFailed {
    // Authentication metadata was not sent; no frame was yielded.
} catch IRCMessageGeneratorError.packetMetadataEncodeFailed {
    // Multipart metadata was not sent; no contentless frame was yielded.
} catch IRCMessageGeneratorError.emptyCommandRejected {
    // JOIN/PART/PRIVMSG/NOTICE was missing a required target.
} catch {
    print("Other encoding error: \(error)")
}
```
