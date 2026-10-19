//
//  NeedleTailError.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

/// Validation errors for NeedleTailIRC models.
///
/// The parser throws ``nilNickName`` when a DCC line names an invalid nickname. The other cases
/// are for applications validating their own users, devices and data. Line and command parsing
/// errors are ``MessageParsingErrors`` and ``NeedleTailIRCCommandParser/CommandParserErrors``.
public enum NeedleTailError: String, Error, Sendable {
    /// The nickname is missing or not a valid IRC nickname.
    case nilNickName
    /// The user identifier is not valid.
    case invalidUserId
    /// The device identifier is missing.
    case deviceIdNil
    /// The username is missing.
    case usernameNil
    /// Data is missing.
    case nilData
}
