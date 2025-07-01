//
//  IRCCommandCode+Errors.swift
//  needletail-irc
//
//  Created by Cole M on 9/23/22.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

extension IRCCommandCode {
    /// Returns a formatted error message for the IRC command code.
    /// If the code is unmapped, it returns a default message indicating the code.
    public var formattedErrorMessage: String {
        // Use the command error messages mapping to get the corresponding message
        return commandErrorMessages[self, default: "Error \(self.rawValue): Unrecognized error code."]
    }
}

// Dictionary mapping IRC command codes to standardized error messages
fileprivate let commandErrorMessages: [IRCCommandCode: String] = [
    .errorUnknownCommand:    "401 :No such command.",
    .errorNoSuchServer:      "402 :No such server.",
    .errorNicknameInUse:     "433 :Nickname is already in use.",
    .errorNoSuchNick:        "401 :No such nick.",
    .errorAlreadyRegistered: "462 :You may not reregister.",
    .errorNotRegistered:     "451 :You have not registered.",
    .errorUsersDontMatch:    "437 :Users do not match.",
    .errorNoSuchChannel:     "403 :No such channel."
]
