# Multipart Messages

Handle large messages that exceed IRC protocol limits by automatically chunking them into smaller packets.

## Overview

IRC protocol has a maximum message length of 512 bytes, which can be limiting when sending large text messages or binary data. The `MultipartPacket` system provides automatic chunking and reassembly of large messages, making it transparent to your application.

## Key Features

- **Automatic Chunking**: Large messages are automatically split into smaller packets
- **Message Reassembly**: Received packets are automatically reassembled into complete messages
- **Data Support**: Handles both text messages and binary data
- **Group Management**: Organizes related packets using unique group IDs
- **Error Handling**: Robust error handling for missing or corrupted packets

## Basic Usage

### Sending Large Messages

```swift
import NeedleTailIRC

let largeMessage = String(repeating: "Hello, World! ", count: 1000)

// Use IRCMessageGenerator to chunk/reassemble large messages while staying within
// the configured IRC max line bytes (defaults to 512 including CRLF).
let generator = IRCMessageGenerator(executor: executor)
let messages = await generator.createMessages(
    origin: "alice!user@host",
    command: .privMsg([.channel(NeedleTailChannel("#general")!)], largeMessage),
    logger: NeedleTailLogger()
)

for try await message in messages {
    // Send via your NIO pipeline using IRCPayloadEncoder
    // try await writer.write(.irc(message))
}
```

### Receiving and Reassembling Messages

```swift
import NeedleTailIRC

let generator = IRCMessageGenerator(executor: executor)

// Process incoming IRC messages
for message in incomingMessages {
    // `messageReassembler` returns nil until the final chunk arrives.
    if let rebuilt = try await generator.messageReassembler(ircMessage: message) {
        // Process the complete message
        print("Reassembled: \(rebuilt)")
    }
}
```

## Packet Structure

Each `MultipartPacket` contains:

```swift
struct MultipartPacket {
    let groupId: String           // Unique identifier for the message group
    let date: Date               // Timestamp for packet ordering
    let partNumber: Int          // Current part number (1-based)
    let totalParts: Int          // Total number of parts
    let message: String?         // Text content (for text messages)
    let data: Data?              // Binary content (for data messages)
}
```

## Buffering Policies

The `calculateAndDispense` method supports different buffering policies:

### Unbounded Buffering
```swift
let stream = await packetDerivation.calculateAndDispense(
    text: largeMessage,
    chunkCount: 512,
    bufferingPolicy: .unbounded
)
```
- Lets the async stream retain every pending packet
- Use `chunkCount` to control IRC payload size, not the stream policy

### Newest-N Buffering
```swift
let stream = await packetDerivation.calculateAndDispense(
    text: largeMessage,
    chunkCount: 512,
    bufferingPolicy: .bufferingNewest(16)
)
```
- Keeps only the newest N packets in the stream
- Does not change how source text is chunked

## Binary DirectMessage framing

Peer connections that carry `DirectMessage` values use `IRCPayloadDecoder.withBinaryFrames()`. Multipart `groupId` and message fields are UInt32 length-prefixed UTF-8. Discriminators `0`, `3`, and `4` keep their existing layouts.

## Binary Data Support

The system also supports sending and receiving binary data:

```swift
// Sending binary data
let binaryData = Data(repeating: 0x42, count: 1000000) // 1MB of data
let stream = await packetDerivation.calculateAndDispense(
    data: binaryData, 
    bufferingPolicy: .unbounded
)

for await packet in stream {
    // Send packet over IRC
    await sendPacket(packet)
}

// Receiving binary data
let result = await packetBuilder.processPacket(multipartPacket)
switch result {
case .data(let completeData):
    // Process the complete binary data
    saveToFile(completeData, filename: "received_file.bin")
case .message(_), .none:
    break
}
```

## Error Handling

The system includes robust error handling:

```swift
let packetBuilder = PacketBuilder(executor: executor)
await packetBuilder.configure(timeout: 30.0)

let result = await packetBuilder.processPacket(packet)
switch result {
case .message(let message):
    print("Complete message: \(message)")
case .data(let data):
    print("Complete data: \(data.count) bytes")
case .none:
    print("Packet processed, waiting for more parts")
}
```

## Performance Considerations

### Large File Transfers

For very large files, use bounded buffering to manage memory usage:

```swift
let stream = await packetDerivation.calculateAndDispense(
    data: fileData,
    chunkCount: 512,
    bufferingPolicy: .unbounded
)
```

### Concurrent Processing

The system supports concurrent processing of multiple message groups:

```swift
// Process multiple large messages concurrently
async let message1 = processLargeMessage(largeMessage1)
async let message2 = processLargeMessage(largeMessage2)
async let message3 = processLargeMessage(largeMessage3)

let results = await (message1, message2, message3)
```

## Best Practices

1. **Use Appropriate Buffering**: Prefer `.unbounded` unless a consumer needs `.bufferingNewest` / `.bufferingOldest`
2. **Handle Timeouts**: Configure `PacketBuilder` reassembly limits; incomplete groups are dropped when they expire
3. **Monitor Memory Usage**: For very large transfers, monitor memory consumption
4. **Propagate Failures**: `createMessages` is an `AsyncThrowingStream` — do not swallow generator errors
5. **Cleanup**: Incomplete groups are evicted by the configured timeout; do not add timer-based send retries in this layer

## Integration with IRC Protocol

The multipart system integrates seamlessly with IRC:

```swift
// Send large message over IRC
let largeMessage = "Very long message..." // > 512 characters
let stream = await packetDerivation.calculateAndDispense(
    text: largeMessage, 
    bufferingPolicy: .unbounded
)

for await packet in stream {
    // Each packet fits within IRC message limits
    let ircMessage = IRCMessage(
        command: .privMsg(
            [.channel(NeedleTailChannel("#general")!)], 
            packet.message ?? ""
        )
    )
    await ircClient.send(ircMessage)
}
```

## Advanced Features

### Custom Packet Serialization

You can customize how packets are serialized for transmission:

```swift
// Custom serialization for specific transport protocols
extension MultipartPacket {
    func serializeForCustomProtocol() -> Data {
        // Custom serialization logic
        return Data()
    }
}
```

### Packet Validation

Implement custom validation for received packets:

```swift
extension PacketBuilder {
    func validatePacket(_ packet: MultipartPacket) -> Bool {
        // Custom validation logic
        return packet.partNumber > 0 && packet.partNumber <= packet.totalParts
    }
}
```

This multipart message system provides a robust solution for handling large messages in IRC applications, making it easy to send and receive content that exceeds the standard IRC message size limits. 