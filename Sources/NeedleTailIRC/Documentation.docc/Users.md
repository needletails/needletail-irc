# Users

Understand user management and permissions using the NeedleTailIRC API.

## Overview

User management is a core aspect of IRC operations. NeedleTailIRC provides comprehensive support for handling users, nicknames, user modes, and permissions with type-safe APIs.

## User Basics

### Creating Nickname Objects

```swift
// Create a nickname with device ID
guard let nick = NeedleTailNick(name: "alice", deviceId: UUID()) else {
    print("Invalid nickname")
    return
}

// Nickname validation
print(nick.name) // "alice"
print(nick.deviceId) // UUID

// Invalid nicknames return nil
let invalidNick1 = NeedleTailNick(name: "", deviceId: UUID()) // nil
let invalidNick2 = NeedleTailNick(name: "123user", deviceId: UUID()) // nil (starts with number)
let invalidNick3 = NeedleTailNick(name: "user-name", deviceId: UUID()) // nil (contains hyphen)
```

### Nickname Validation

Nicknames must follow IRC standards:
- Cannot start with a number
- Cannot contain hyphens or special characters
- Must be between 1 and 9 characters (typically)
- Cannot contain spaces

```swift
// Valid nicknames
let validNicks = [
    NeedleTailNick(name: "alice", deviceId: UUID()),
    NeedleTailNick(name: "bob123", deviceId: UUID()),
    NeedleTailNick(name: "user_123", deviceId: UUID()),
    NeedleTailNick(name: "test", deviceId: UUID())
]

// Invalid nicknames
let invalidNicks = [
    NeedleTailNick(name: "", deviceId: UUID()),           // Empty
    NeedleTailNick(name: "123user", deviceId: UUID()),    // Starts with number
    NeedleTailNick(name: "user-name", deviceId: UUID()),  // Contains hyphen
    NeedleTailNick(name: "user name", deviceId: UUID())   // Contains space
]
```

## User Operations

### Changing Nickname

```swift
// Change nickname
func changeNickname(_ newNickname: String) async throws {
    guard let nick = NeedleTailNick(name: newNickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let nickCommand = IRCCommand.nick(nick)
    let message = IRCMessage(command: nickCommand)
    try await sendMessage(message)
}

// Change nickname with validation
func changeNicknameSafely(_ newNickname: String) async throws {
    // Validate nickname format
    guard !newNickname.isEmpty else {
        throw NeedleTailError.nilNickName
    }
    
    guard !newNickname.first!.isNumber else {
        throw NeedleTailError.nilNickName
    }
    
    guard !newNickname.contains("-") && !newNickname.contains(" ") else {
        throw NeedleTailError.nilNickName
    }
    
    try await changeNickname(newNickname)
}

// Usage
try await changeNickname("newNick")
try await changeNicknameSafely("alice")
```

### Setting User Information

```swift
// Set user details
func setUserInfo(username: String, realname: String, mode: Int = 0) async throws {
    let userDetails = IRCUserDetails(
        username: username,
        realname: realname,
        mode: mode
    )
    
    let userCommand = IRCCommand.user(userDetails)
    let message = IRCMessage(command: userCommand)
    try await sendMessage(message)
}

// Usage
try await setUserInfo(username: "alice", realname: "Alice Smith")
try await setUserInfo(username: "bob", realname: "Bob Johnson", mode: 8)
```

### Checking User Status

```swift
// Check if users are online
func checkUserStatus(_ nicknames: [String]) async throws {
    let nicks = nicknames.compactMap { NeedleTailNick(name: $0, deviceId: UUID()) }
    guard !nicks.isEmpty else {
        throw NeedleTailError.nilNickName
    }
    
    let isOnCommand = IRCCommand.isOn(nicks)
    let message = IRCMessage(command: isOnCommand)
    try await sendMessage(message)
}

// Get user information
func getUserInfo(_ usermasks: [String], server: String? = nil) async throws {
    guard !usermasks.isEmpty else { return }
    
    let whoisCommand = IRCCommand.whois(server: server, usermasks: usermasks)
    let message = IRCMessage(command: whoisCommand)
    try await sendMessage(message)
}

// List users
func listUsers(mask: String? = nil, operatorsOnly: Bool = false) async throws {
    let whoCommand = IRCCommand.who(usermask: mask, onlyOperators: operatorsOnly)
    let message = IRCMessage(command: whoCommand)
    try await sendMessage(message)
}

// Usage
try await checkUserStatus(["alice", "bob", "charlie"])
try await getUserInfo(["alice*", "bob"])
try await listUsers(mask: "alice*")
try await listUsers(operatorsOnly: true)
```

## User Modes

### User Mode Types

NeedleTailIRC supports all standard IRC user modes:

```swift
// Common user modes
let userModes: [IRCUserModeFlags] = [
    .away,           // a - User is away
    .invisible,      // i - User is invisible
    .wallops,        // w - User receives wallops
    .restricted,     // r - User is restricted
    .operator,       // o - User is an IRC operator
    .localOperator,  // O - User is a local operator
    .serverNotice    // s - User receives server notices
]
```

### Managing User Modes

```swift
// Get user modes
func getUserModes(_ nickname: String) async throws {
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let modeCommand = IRCCommand.modeGet(nick)
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Set user modes
func setUserModes(_ nickname: String, addModes: [IRCUserModeFlags]?, removeModes: [IRCUserModeFlags]?) async throws {
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let addMode = addModes?.reduce(IRCUserModeFlags(), { $0.union($1) })
    let removeMode = removeModes?.reduce(IRCUserModeFlags(), { $0.union($1) })
    
    let modeCommand = IRCCommand.mode(nick, add: addMode, remove: removeMode)
    let message = IRCMessage(command: modeCommand)
    try await sendMessage(message)
}

// Set specific user modes
func setUserAway(_ nickname: String, away: Bool) async throws {
    if away {
        try await setUserModes(nickname, addModes: [.away], removeModes: nil)
    } else {
        try await setUserModes(nickname, addModes: nil, removeModes: [.away])
    }
}

func setUserInvisible(_ nickname: String, invisible: Bool) async throws {
    if invisible {
        try await setUserModes(nickname, addModes: [.invisible], removeModes: nil)
    } else {
        try await setUserModes(nickname, addModes: nil, removeModes: [.invisible])
    }
}

// Usage
try await getUserModes("alice")
try await setUserModes("alice", addModes: [.invisible, .away], removeModes: nil)
try await setUserAway("alice", away: true)
try await setUserInvisible("alice", invisible: true)
```

## User Management Commands

### Kicking Users

```swift
// Kick user from channel
func kickUser(_ nickname: String, from channelName: String, reason: String? = nil) async throws {
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    guard let channel = NeedleTailChannel(channelName) else {
        throw NeedleTailError.invalidIRCChannelName
    }
    
    let kickCommand = IRCCommand.kick([channel], [nick], [reason ?? "No reason given"])
    let message = IRCMessage(command: kickCommand)
    try await sendMessage(message)
}

// Usage
try await kickUser("bob", from: "#general", reason: "Breaking rules")
try await kickUser("alice", from: "#help")
```

### Killing Users

```swift
// Kill user (server operator only)
func killUser(_ nickname: String, reason: String) async throws {
    guard let nick = NeedleTailNick(name: nickname, deviceId: UUID()) else {
        throw NeedleTailError.nilNickName
    }
    
    let killCommand = IRCCommand.kill(nick, reason)
    let message = IRCMessage(command: killCommand)
    try await sendMessage(message)
}

// Usage
try await killUser("spammer", reason: "Spamming")
```

## User Validation

### Nickname Validation

```swift
// Validate nickname
func isValidNickname(_ nickname: String) -> Bool {
    return NeedleTailNick(name: nickname, deviceId: UUID()) != nil
}

// Validate username
func isValidUsername(_ username: String) -> Bool {
    // Username validation rules
    guard !username.isEmpty else { return false }
    guard username.count <= 32 else { return false }
    guard !username.contains(" ") else { return false }
    guard !username.contains(":") else { return false }
    return true
}

// Validate realname
func isValidRealname(_ realname: String) -> Bool {
    // Realname validation rules
    guard !realname.isEmpty else { return false }
    guard realname.count <= 64 else { return false }
    return true
}

// Usage
if isValidNickname("alice") {
    print("Valid nickname")
}

if isValidUsername("alice") {
    print("Valid username")
}

if isValidRealname("Alice Smith") {
    print("Valid realname")
}
```

### User Name Utilities

```swift
// Extract nickname from origin
func extractNicknameFromOrigin(_ origin: String) -> String? {
    return origin.components(separatedBy: "!").first
}

// Extract username from origin
func extractUsernameFromOrigin(_ origin: String) -> String? {
    let components = origin.components(separatedBy: "!")
    guard components.count >= 2 else { return nil }
    
    let userHost = components[1]
    return userHost.components(separatedBy: "@").first
}

// Extract hostname from origin
func extractHostnameFromOrigin(_ origin: String) -> String? {
    let components = origin.components(separatedBy: "!")
    guard components.count >= 2 else { return nil }
    
    let userHost = components[1]
    let userHostComponents = userHost.components(separatedBy: "@")
    guard userHostComponents.count >= 2 else { return nil }
    
    return userHostComponents[1]
}

// Usage
let nickname = extractNicknameFromOrigin("alice!alice@localhost") // "alice"
let username = extractUsernameFromOrigin("alice!alice@localhost") // "alice"
let hostname = extractHostnameFromOrigin("alice!alice@localhost") // "localhost"
```