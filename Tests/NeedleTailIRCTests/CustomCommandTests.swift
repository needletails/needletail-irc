//
//  CustomCommandTests.swift
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

import Foundation
import NeedleTailLogger
import Testing
@testable import NeedleTailIRC

private extension IRCCustomCommand {
    static let badgeUpdate: IRCCustomCommand = "BADGEUPDATE"
    static let bigUpload: IRCCustomCommand = "BIGUPLOAD"
}

/// Application commands are declared by the app, not the library.
@Suite struct CustomCommandTests {

    @Test func namesAreLettersAndUppercased() {
        #expect(IRCCustomCommand(rawValue: "badgeUpdate")?.rawValue == "BADGEUPDATE")
        #expect(IRCCustomCommand(rawValue: "BAD_ONE") == nil)
        #expect(IRCCustomCommand(rawValue: "") == nil)
        #expect(IRCCustomCommand(rawValue: "123") == nil)
        #expect(IRCCustomCommand(rawValue: "ÜBER") == nil)
        #expect(IRCCustomCommand.badgeUpdate.description == "BADGEUPDATE")
    }

    @Test func buildsAnOtherCommandLine() throws {
        let command = IRCCommand.custom(.badgeUpdate, ["3"])
        guard case .otherCommand(let name, let arguments) = command else { Issue.record("\(command)"); return }
        #expect(name == "BADGEUPDATE" && arguments == ["3"])
        #expect(try IRCMessage(command: command).wireLine() == "BADGEUPDATE :3")
        #expect(try IRCMessage(command: .custom(.badgeUpdate)).wireLine() == "BADGEUPDATE")
    }

    @Test func matchesParsedLinesInASwitch() throws {
        for line in ["BADGEUPDATE :3", "badgeupdate :3"] {
            let message = try NeedleTailIRCParser.parseMessage(line)
            switch message.command {
            case .otherCommand(IRCCustomCommand.badgeUpdate, let arguments):
                #expect(arguments == ["3"])
            default:
                Issue.record("\(line) did not match")
            }
        }
        #expect(!(IRCCustomCommand.badgeUpdate ~= "OFFLINEMESSAGES"))
    }

    @Test func largePayloadCommandsAreConfigurable() async throws {
        let executor = TestableExecutor(queue: .init(label: "custom-commands"))
        let payload = String(repeating: "x", count: 2_000)
        func frames(_ generator: IRCMessageGenerator, _ command: IRCCommand) async throws -> Int {
            var count = 0
            for try await _ in await generator.createMessages(origin: "alice", command: command, logger: NeedleTailLogger()) { count += 1 }
            return count
        }
        let standard = IRCMessageGenerator(executor: executor)
        let configured = IRCMessageGenerator(executor: executor, largePayloadCommands: [.bigUpload])
        #expect(try await frames(standard, .custom(.bigUpload, [payload])) > 1)
        #expect(try await frames(configured, .custom(.bigUpload, [payload])) == 1)
        // The default set keeps the media commands on 5 MB chunks.
        #expect(try await frames(standard, .otherCommand("MULTIPARTMEDIAUPLOAD", [payload])) == 1)
        #expect(IRCMessageGenerator.defaultLargePayloadCommands.map(\.rawValue).sorted() == ["MULTIPARTMEDIADOWNLOAD", "MULTIPARTMEDIAUPLOAD"])
    }
}
