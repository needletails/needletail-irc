//
//  IRCStandardError.swift
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

/// Errors raised by the opt-in standard IRC / IRCv3 support.
///
/// This is a struct rather than an enum so new codes can be added without breaking
/// exhaustive `switch` statements in client code. Match on ``code``.
public struct IRCStandardError: Error, Hashable, Sendable, CustomStringConvertible {

    /// Identifies the kind of failure.
    public struct Code: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public var description: String { rawValue }

        /// The line was empty or whitespace only.
        public static let emptyLine = Code(rawValue: "emptyLine")
        /// The IRCv3 tag section was malformed or exceeded the configured limits.
        public static let invalidTags = Code(rawValue: "invalidTags")
        /// The message source (prefix) was empty or malformed.
        public static let invalidSource = Code(rawValue: "invalidSource")
        /// No command followed the tags or source.
        public static let missingCommand = Code(rawValue: "missingCommand")
        /// The command was neither letters nor a three-digit numeric.
        public static let invalidCommand = Code(rawValue: "invalidCommand")
        /// A parameter cannot be represented on the wire in its position.
        public static let invalidParameter = Code(rawValue: "invalidParameter")
        /// More than 15 parameters were supplied.
        public static let tooManyParameters = Code(rawValue: "tooManyParameters")
        /// A field contained NUL, CR or LF.
        public static let forbiddenCharacter = Code(rawValue: "forbiddenCharacter")
        /// An inbound line exceeded the configured maximum length.
        public static let lineTooLong = Code(rawValue: "lineTooLong")
        /// The command has no standard IRC representation.
        public static let unsupportedOnStandardIRC = Code(rawValue: "unsupportedOnStandardIRC")
        /// A binary or DCC frame was written to a standard IRC connection.
        public static let unsupportedFrame = Code(rawValue: "unsupportedFrame")
        /// A command that needs at least one target was given none.
        public static let missingTarget = Code(rawValue: "missingTarget")
        /// The server rejected the connection during registration (ERROR, 464, 465, no usable nick).
        public static let registrationFailed = Code(rawValue: "registrationFailed")
        /// SASL was required but failed or was not offered.
        public static let saslFailed = Code(rawValue: "saslFailed")
        /// The server did not answer a keepalive PING in time.
        public static let keepAliveTimeout = Code(rawValue: "keepAliveTimeout")
    }

    /// The kind of failure.
    public let code: Code
    /// Human-readable detail. Never contains credentials.
    public let detail: String

    public init(_ code: Code, _ detail: String = "") {
        self.code = code
        self.detail = detail
    }

    public var description: String {
        detail.isEmpty ? "IRCStandardError(\(code))" : "IRCStandardError(\(code)): \(detail)"
    }
}
