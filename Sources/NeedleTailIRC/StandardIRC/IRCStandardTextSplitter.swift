//
//  IRCStandardTextSplitter.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

/// Splits text into PRIVMSG/NOTICE lines that fit the 512-byte limit of standard servers.
///
/// Use this instead of `IRCMessageGenerator` on standard connections: the generator wraps
/// messages in NeedleTail multipart packets that standard servers do not understand.
public enum IRCStandardTextSplitter {

    /// Bytes reserved for the `:nick!user@host ` prefix the server adds when relaying,
    /// when the caller does not know its own source.
    public static let defaultPrefixReserve = 110

    /// - Parameters:
    ///   - text: Any text. Each line becomes at least one message; blank lines are skipped.
    ///   - command: `PRIVMSG` or `NOTICE`.
    ///   - target: The channel or nick to send to.
    ///   - source: Our own `nick!user@host`, if known, for an exact length budget. It is not
    ///     written into the messages.
    ///   - tags: Tags to put on every message (tags do not count against the 512 bytes).
    ///   - maxLineBytes: The line limit including CRLF.
    ///   - preferWordBoundaries: Break at the last space that fits instead of mid-word.
    /// - Returns: Messages whose last parameter is never empty and never splits a character.
    public static func split(
        _ text: String,
        command: String = "PRIVMSG",
        target: String,
        source: String? = nil,
        tags: [IRCTag] = [],
        maxLineBytes: Int = 512,
        preferWordBoundaries: Bool = true
    ) -> [IRCRawMessage] {
        let prefixReserve = source.map { $0.utf8.count + 2 } ?? defaultPrefixReserve
        let fixed = command.utf8.count + 1 + target.utf8.count + 2 // "CMD target :"
        let budget = max(1, maxLineBytes - 2 - prefixReserve - fixed)

        let cleaned = String(text.unicodeScalars.filter { $0 != "\u{0}" })
        var messages: [IRCRawMessage] = []
        for line in cleaned.split(whereSeparator: \.isNewline) {
            for chunk in chunks(of: line, budget: budget, preferWordBoundaries: preferWordBoundaries) where !chunk.isEmpty {
                messages.append(IRCRawMessage(
                    tags: tags,
                    command: command,
                    parameters: [target, chunk],
                    forcesTrailingParameter: true
                ))
            }
        }
        return messages
    }

    private static func chunks(of line: Substring, budget: Int, preferWordBoundaries: Bool) -> [String] {
        var result: [String] = []
        var current: [Character] = []
        var currentBytes = 0

        func bytes(_ characters: some Sequence<Character>) -> Int {
            characters.reduce(0) { $0 + $1.utf8.count }
        }

        for character in line {
            let size = character.utf8.count
            var dropsCharacter = false
            while !current.isEmpty, currentBytes + size > budget {
                if preferWordBoundaries, character == " " {
                    // The overflowing character is a space: break here and drop it.
                    result.append(String(current))
                    current = []
                    dropsCharacter = true
                    break
                }
                if preferWordBoundaries, let space = current.lastIndex(of: " "), space > 0 {
                    // Break at the last space; the space itself is dropped.
                    result.append(String(current[..<space]))
                    current = Array(current[(space + 1)...])
                } else {
                    result.append(String(current))
                    current = []
                }
                currentBytes = bytes(current)
            }
            if dropsCharacter {
                currentBytes = 0
                continue
            }
            current.append(character)
            currentBytes += size
        }
        if !current.isEmpty { result.append(String(current)) }
        return result
    }
}
