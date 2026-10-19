import Foundation
import Testing
@testable import NeedleTailIRC

@Suite(.serialized)
struct CommandParserTypedRoundTripTests {
    @Test("Known commands decode to their typed IRCCommand cases")
    func knownCommandsRemainTyped() throws {
        let channel = try #require(NeedleTailChannel("#general"))
        let nick = try #require(NeedleTailNick(name: "alice", deviceId: UUID()))
        let commands: [IRCCommand] = [
            .oper("operator", "password"),
            .knock(channel, "invite please"),
            .silence("mask!*@*"),
            .invite(nick, channel),
            .topic(channel, "Topic"),
            .names(channel),
            .clearmode(channel, "nt"),
            .rehash,
            .restart,
            .die,
            .connect("irc.example.com", 6697, "hub.example.com"),
            .trace("irc.example.com"),
            .stats("u", "irc.example.com"),
            .admin("irc.example.com"),
            .info("irc.example.com"),
            .version("irc.example.com"),
            .time("irc.example.com"),
            .lusers("*", "irc.example.com"),
            .motd("irc.example.com"),
            .rules("irc.example.com"),
            .map,
            .users("irc.example.com"),
            .wallops("message"),
            .globops("message"),
            .locops("message"),
        ]

        for original in commands {
            let wire = NeedleTailIRCEncoder.encode(value: IRCMessage(command: original))
            let parsed = try NeedleTailIRCParser.parseMessage(wire).command
            #expect(
                supplementalKind(parsed) == supplementalKind(original),
                "Expected \(supplementalKind(original)), got \(parsed)"
            )
            #expect(parsed.arguments == original.arguments)
        }
    }

    @Test("Optional command forms remain typed")
    func optionalFormsRemainTyped() throws {
        let channel = try #require(NeedleTailChannel("#general"))
        let commands: [IRCCommand] = [
            .quit(nil),
            .links(nil),
            .knock(channel, nil),
            .topic(channel, nil),
            .names(nil),
            .connect("irc.example.com", 6697, nil),
            .trace(nil),
            .stats(nil, nil),
            .admin(nil),
            .info(nil),
            .version(nil),
            .time(nil),
            .lusers(nil, nil),
            .motd(nil),
            .rules(nil),
            .users(nil),
            .cap(.end, []),
        ]

        for original in commands {
            let wire = NeedleTailIRCEncoder.encode(value: IRCMessage(command: original))
            let parsed = try NeedleTailIRCParser.parseMessage(wire).command
            #expect(supplementalKind(parsed) == supplementalKind(original))
            #expect(parsed.arguments == original.arguments)
        }
    }

    @Test(
        "Malformed numeric command arguments throw",
        arguments: [
            ("DCCCHAT", ["alice", "address", "not-a-port"]),
            ("DCCSEND", ["alice", "file", "not-a-size", "address", "6697"]),
            ("DCCRESUME", ["alice", "file", "1", "address", "6697", "offset"]),
            ("SERVER", ["server", "1.0", "hop", "info"]),
        ]
    )
    func malformedNumericArgumentsThrow(command: String, arguments: [String]) {
        #expect(throws: (any Error).self) {
            _ = try NeedleTailIRCCommandParser.parse(
                command: command,
                arguments: arguments
            )
        }
    }

    @Test("Commands that don't fit their typed case arrive as otherCommand")
    func untypedFormsFallBackToOtherCommand() throws {
        let lines: [(String, [String])] = [
            ("CONNECT", ["server", "port"]),
            ("NAMES", ["#a,#b"]),
            ("WHOWAS", ["bob", "five"]),
        ]
        for (command, arguments) in lines {
            let parsed = try NeedleTailIRCCommandParser.parse(command: command, arguments: arguments)
            guard case .otherCommand(let name, let parsedArguments) = parsed else {
                Issue.record("Expected otherCommand for \(command), got \(parsed)")
                continue
            }
            #expect(name == command)
            #expect(parsedArguments == arguments)
        }
    }

    @Test("PRIVMSG rejects a target that cannot be parsed")
    func invalidRecipientThrows() {
        #expect(throws: (any Error).self) {
            _ = try NeedleTailIRCCommandParser.parse(
                command: "PRIVMSG",
                arguments: ["bad nick", "hello"]
            )
        }
    }
}

private func supplementalKind(_ command: IRCCommand) -> String {
    switch command {
    case .quit: "quit"
    case .links: "links"
    case .cap: "cap"
    case .oper: "oper"
    case .knock: "knock"
    case .silence: "silence"
    case .invite: "invite"
    case .topic: "topic"
    case .names: "names"
    case .clearmode: "clearmode"
    case .rehash: "rehash"
    case .restart: "restart"
    case .die: "die"
    case .connect: "connect"
    case .trace: "trace"
    case .stats: "stats"
    case .admin: "admin"
    case .info: "info"
    case .version: "version"
    case .time: "time"
    case .lusers: "lusers"
    case .motd: "motd"
    case .rules: "rules"
    case .map: "map"
    case .users: "users"
    case .wallops: "wallops"
    case .globops: "globops"
    case .locops: "locops"
    default: "unexpected"
    }
}
