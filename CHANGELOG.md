# Changelog

## 2.0.0

### Commit message

```
Introduce IRCFrame and route binary payloads off IRC text lines.

Replace IRCPayload with IRCFrame { text, binary, dcc } so server-routed
opaque bytes and peer DCC frames are length-prefixed and self-delimiting.
Each payload owns encode(into:) / decode(from:); the NIO codecs only dispatch.
```

### Release notes

**Breaking**

- `IRCPayload` is now `IRCFrame`: `.irc(IRCMessage)` is `.text(IRCMessage)`, `.dcc(DirectMessage)` is `.dcc(DCCMessage)`, and `.binary(IRCBinaryMessage)` is new.
- `IRCPayloadEncoder` / `IRCPayloadDecoder` are `IRCFrameEncoder` / `IRCFrameDecoder`. `allowsBinaryFrames: Bool` still compiles (`true` means all families, `false` means none). Prefer `lineBasedIRC()`, `serverIRC()`, and `withBinaryFrames()`.
- `DirectMessage` is `DCCMessage`. Discriminator `0` (`serviceName`) is now a `UInt32` length-prefixed UTF-8 string. Old and new peers cannot exchange that frame. Both ends of a DCC or Bonjour connection must update together.
- `DCCChannelContext` carries `NIOAsyncChannel<IRCFrame, IRCFrame>`.
- The deprecated `IRCCommand.squit` case is removed. Use `sQuit`.
- A terminated IRC line longer than `maxLineLength` now throws `IRCMessage.LineError.lineTooLong`. Previously only a line with no newline yet was limited. The default remains 32 MB.
- Embedded CR and LF in an `IRCMessage` body are stripped as Unicode scalars. A CRLF pair inside a PRIVMSG body can no longer inject a second command.

**Added**

- `IRCBinaryMessage`: `0xFF` discriminator, version byte, UUID, origin, recipients, tags, content type, optional sequence, and an opaque payload. The declared frame length is checked before allocation. A field that overruns that length is malformed, so the decoder does not wait forever or read into the next frame.
- `IRCWireEncodable`. `IRCFrameEncoder` delegates to it. Encode either writes a complete frame or throws without writing.
- `IRCFrameDecoder.serverIRC()` accepts text plus `IRCBinaryMessage` and does not treat bytes `0...4` as DCC. Use it on a server client listener. Clients that also open DCC keep `withBinaryFrames()`.
- `IRCMessage.wireLine()` and `encode(into:)` / `decode(from:maxLineLength:)`. A blank or unparsable text line is consumed and reported as `IgnoredLine`. A bad binary frame still throws.

**Unchanged**

- `IRCMessage`, the parser, and the encoder still own RFC 1459 text. Registration, JOIN/PART, NOTICE, and `otherCommand` stay text.
- `createMessages` still chunks application text into base64 `packet-metadata` tags. Moving chat and SFU payloads onto `.binary` is the next change in the client and the servers, not this library release.
