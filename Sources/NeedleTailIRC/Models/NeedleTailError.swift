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

/// Validation errors raised when building or reading NeedleTailIRC models.
///
/// ## Usage
///
/// ```swift
/// do {
///     let message = try NeedleTailIRCParser.parseMessage(line)
///     handle(message)
/// } catch NeedleTailError.nilNickName {
///     print("The line names an invalid nickname")
/// } catch NeedleTailError.invalidIRCChannelName {
///     print("The line names an invalid channel")
/// } catch {
///     print("Other error: \(error)")
/// }
/// ```
public enum NeedleTailError: String, Error, Sendable {
    /// The channel name is not a valid IRC channel name.
    case invalidIRCChannelName
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
