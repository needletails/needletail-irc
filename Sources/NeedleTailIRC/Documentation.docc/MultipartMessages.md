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

let packetDerivation = PacketDerivation()
let largeMessage = String(repeating: "Hello, World! ", count: 1000)

// Automatically chunks the message into smaller packets
let stream = await packetDerivation.calculateAndDispense(
    text: largeMessage, 
    bufferingPolicy: .unbounded
)

// Send each packet over IRC
for await packet in stream {
    let ircMessage = IRCMessage(
        command: .privMsg(
            [.channel(NeedleTailChannel("#general")!)], 
            packet.message ?? ""
        )
    )
    // Send the IRC message
    await sendMessage(ircMessage)
}
```

### Receiving and Reassembling Messages

```swift
import NeedleTailIRC

let packetBuilder = PacketBuilder(executor: executor)

// Process incoming IRC messages
for message in incomingMessages {
    if let multipartPacket = MultipartPacket.from(message) {
        let result = await packetBuilder.processPacket(multipartPacket)
        
        switch result {
        case .message(let completeMessage):
            // Complete message reassembled
            print("Received complete message: \(completeMessage)")
            
        case .data(let completeData):
            // Complete binary data reassembled
            print("Received complete data: \(completeData.count) bytes")
            
        case .none:
            // Packet processed but message not yet complete
            break
        }
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
    bufferingPolicy: .unbounded
)
```
- Processes the entire message at once
- Uses more memory but is faster
- Best for smaller messages or when memory isn't a concern

### Bounded Buffering
```swift
let stream = await packetDerivation.calculateAndDispense(
    text: largeMessage, 
    bufferingPolicy: .bounded(maxSize: 1024 * 1024) // 1MB chunks
)
```
- Processes message in chunks of specified size
- More memory efficient for very large messages
- Slightly slower due to multiple processing passes

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
// Handle missing packets
let packetBuilder = PacketBuilder(executor: executor)

// Set timeout for incomplete packets
packetBuilder.timeout = 30.0 // 30 seconds

// Process packets with error handling
do {
    let result = await packetBuilder.processPacket(packet)
    switch result {
    case .message(let message):
        print("Complete message: \(message)")
    case .data(let data):
        print("Complete data: \(data.count) bytes")
    case .none:
        print("Packet processed, waiting for more parts")
    }
} catch {
    print("Error processing packet: \(error)")
}
```

## Performance Considerations

### Large File Transfers

For very large files, use bounded buffering to manage memory usage:

```swift
// For files larger than 100MB
let stream = await packetDerivation.calculateAndDispense(
    data: fileData, 
    bufferingPolicy: .bounded(maxSize: 10 * 1024 * 1024) // 10MB chunks
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

1. **Use Appropriate Buffering**: Choose unbounded for smaller messages, bounded for large files
2. **Handle Timeouts**: Set reasonable timeouts for packet reassembly
3. **Monitor Memory Usage**: For very large transfers, monitor memory consumption
4. **Error Recovery**: Implement retry logic for failed packet transmissions
5. **Cleanup**: Periodically clean up old incomplete packet groups

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