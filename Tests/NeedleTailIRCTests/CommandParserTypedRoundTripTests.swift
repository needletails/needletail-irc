import Foundation
import Testing
@testable import NeedleTailIRC

@Suite(.serialized)
struct CommandParserTypedRoundTripTests {
    @Test("Commands without a typed case arrive as otherCommand with RFC parameters")
    func untypedCommandsRoundTripAsOtherCommand() throws {
        let commands: [IRCCommand] = [
            .otherCommand("TOPIC", ["#general", "Topic text"]),
            .otherCommand("INVITE", ["alice", "#general"]),
            .otherCommand("AWAY", ["gone for lunch"]),
            .otherCommand("WHOWAS", ["bob", "5"]),
            .otherCommand("MOTD", []),
        ]

        for original in commands {
            let wire = NeedleTailIRCEncoder.encode(value: IRCMessage(command: original))
            let parsed = try NeedleTailIRCParser.parseMessage(wire).command
            guard case .otherCommand(let name, let arguments) = parsed else {
                Issue.record("Expected otherCommand, got \(parsed)")
                continue
            }
            #expect(name == original.commandAsString)
            #expect(arguments == original.arguments)
        }
    }

    @Test("Optional command forms remain typed")
    func optionalFormsRemainTyped() throws {
        let commands: [IRCCommand] = [
            .quit(nil),
            .links(nil),
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
    default: "unexpected"
    }
}
