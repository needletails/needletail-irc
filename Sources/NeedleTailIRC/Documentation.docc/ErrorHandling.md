# Error Handling

Understand error types provided by the NeedleTailIRC API.

## Overview

NeedleTailIRC provides specific error types for different failure scenarios. Understanding these errors is important for working with the API.

## Key Errors You Should Handle

- **`NeedleTailError.payloadTooLarge`**: Raised when inbound buffering exceeds configured safety limits (e.g. runaway buffer without newline).
- **`MessageParsingErrors`**: Raised when parsing a single IRC line fails (invalid tags/arguments/etc).

## Outbound (encoding) limits

```swift
// IRCPayloadEncoder is the mandatory outbound encoding boundary.
// This SDK does not enforce a hard IRC line length limit at the encoder boundary by default,
// because some deployments support/require larger-than-512 lines.
```

## Inbound (decoding) limits

```swift
// IRCPayloadDecoder enforces safety limits:
// - Oversize IRC lines are treated as protocol violations (error + close by default).
// - If the buffer grows beyond the configured max without a newline, it errors + closes.
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
    // Ensure large payloads are chunked using IRCMessageGenerator before sending.
} catch {
    print("Other encoding error: \(error)")
}
```