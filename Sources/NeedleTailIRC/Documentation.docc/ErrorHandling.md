# Error Handling

Understand error types provided by the NeedleTailIRC API.

## Overview

NeedleTailIRC provides specific error types for different failure scenarios. Understanding these errors is important for working with the API.

## Error Types

### Core Error Types

```swift
// Main error enum
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

### Message Parsing Errors

```swift
// Message parsing specific errors
enum MessageParsingErrors: Error {
    case invalidArguments(String)
    case invalidTag
    case invalidPrefix
    case invalidCommand
    case invalidParameters
    case malformedMessage
}
```

### Transport Errors

```swift
// Transport layer errors
enum TransportError: Error {
    case connectionFailed(String)
    case connectionTimeout
    case sslHandshakeFailed
    case invalidCertificate
    case networkUnavailable
    case protocolError(String)
}
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

### Encoding Errors

```swift
do {
    let encodedMessage = await NeedleTailIRCEncoder.encode(value: message)
    // Use encoded message
} catch NeedleTailError.encodingFailed {
    print("Failed to encode message")
} catch {
    print("Other encoding error: \(error)")
}
```