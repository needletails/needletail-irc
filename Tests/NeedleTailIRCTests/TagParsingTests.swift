import Testing
@testable import NeedleTailIRC

struct TagParsingTests {
    @Test("PIN: legacy repeated-at tag syntax remains accepted")
    func legacyRepeatedAtSyntax() throws {
        let message = try NeedleTailIRCParser.parseMessage(
            "@first=1;@second=2 PRIVMSG #general :hello"
        )
        #expect(message.tags == [
            IRCTag(key: "first", value: "1"),
            IRCTag(key: "second", value: "2"),
        ])
    }

    @Test("Legacy semicolon-space tag separators retain every tag")
    func semicolonSpaceSeparators() throws {
        let message = try NeedleTailIRCParser.parseMessage(
            "@first=1; second=2 PRIVMSG #general :hello"
        )
        #expect(message.tags == [
            IRCTag(key: "first", value: "1"),
            IRCTag(key: "second", value: "2"),
        ])
    }

    @Test("Configured tag count and byte limits reject oversized input")
    func configuredLimitsAreEnforced() {
        let limits = IRCParserLimits(
            maxTagSectionBytes: 12,
            maxTagCount: 1,
            maxTagKeyBytes: 8,
            maxTagValueBytes: 8
        )

        #expect(throws: MessageParsingErrors.self) {
            _ = try NeedleTailIRCParser.parseMessage(
                "@first=1;second=2 PRIVMSG #general :hello",
                limits: limits
            )
        }
        #expect(throws: MessageParsingErrors.self) {
            _ = try NeedleTailIRCParser.parseMessage(
                "@first=long-value PRIVMSG #general :hello",
                limits: limits
            )
        }
    }

    @Test("Default parsing remains compatible with large tag values")
    func defaultParsingRemainsUnbounded() throws {
        let value = String(repeating: "x", count: 128 * 1024)
        let message = try NeedleTailIRCParser.parseMessage(
            "@payload=\(value) PRIVMSG #general :hello"
        )
        #expect(message.tags?.first?.value == value)
    }
}
