//
//  IRCSASL.swift
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

/// Credentials for IRCv3 SASL. The secret never appears in `description`.
public struct IRCSASLCredentials: Sendable, CustomStringConvertible {
    /// The SASL mechanism name sent in `AUTHENTICATE <mechanism>`.
    public let mechanism: String
    /// The initial client response for the mechanism.
    let response: [UInt8]

    /// `PLAIN`: `authzid \0 authcid \0 password`.
    public static func plain(username: String, password: String, authorizationIdentity: String = "") -> IRCSASLCredentials {
        let response = Array(authorizationIdentity.utf8) + [0] + Array(username.utf8) + [0] + Array(password.utf8)
        return IRCSASLCredentials(mechanism: "PLAIN", response: response)
    }

    /// `EXTERNAL`: authenticates with the TLS client certificate.
    public static func external(authorizationIdentity: String = "") -> IRCSASLCredentials {
        IRCSASLCredentials(mechanism: "EXTERNAL", response: Array(authorizationIdentity.utf8))
    }

    public var description: String {
        "IRCSASLCredentials(mechanism: \(mechanism), response: <redacted>)"
    }
}

/// Runs one SASL exchange (`AUTHENTICATE` and numerics 900–908). Performs no I/O.
public struct IRCSASLAuthenticator: Sendable {

    /// Maximum base64 characters per `AUTHENTICATE` line.
    static let chunkSize = 400

    private let credentials: IRCSASLCredentials
    private var hasSentResponse = false

    public private(set) var isFinished = false
    public private(set) var succeeded = false
    /// The account name from 900 (`RPL_LOGGEDIN`).
    public private(set) var account: String?
    /// The server's text for a failure numeric.
    public private(set) var failureReason: String?
    /// Mechanisms listed by 908 (`RPL_SASLMECHS`).
    public private(set) var serverMechanisms: [String] = []

    public init(credentials: IRCSASLCredentials) {
        self.credentials = credentials
    }

    /// `AUTHENTICATE <mechanism>`. Send after `sasl` is acknowledged.
    public mutating func start() -> [IRCRawMessage] {
        [IRCRawMessage(command: "AUTHENTICATE", parameters: [credentials.mechanism])]
    }

    /// Processes one inbound message and returns the messages to send in response.
    public mutating func handle(_ message: IRCRawMessage) -> [IRCRawMessage] {
        guard !isFinished else { return [] }

        if message.command == "AUTHENTICATE" {
            guard message.parameters.first == "+", !hasSentResponse else { return [] }
            hasSentResponse = true
            return Self.chunks(of: credentials.response).map {
                IRCRawMessage(command: "AUTHENTICATE", parameters: [$0])
            }
        }

        guard let numeric = message.numeric else { return [] }
        switch numeric {
        case 900:
            if message.parameters.count >= 3 { account = message.parameters[2] }
        case 903:
            isFinished = true
            succeeded = true
        case 902, 904, 905, 906, 907:
            isFinished = true
            succeeded = false
            failureReason = message.parameters.last
        case 908:
            if message.parameters.count >= 2 {
                serverMechanisms = message.parameters[1].split(separator: ",").map(String.init)
            }
        default:
            break
        }
        return []
    }

    /// Base64 in 400-character lines; an empty response or an exact multiple of 400 ends with `+`.
    static func chunks(of response: [UInt8]) -> [String] {
        let encoded = Data(response).base64EncodedString()
        guard !encoded.isEmpty else { return ["+"] }
        var result: [String] = []
        var index = encoded.startIndex
        while index < encoded.endIndex {
            let end = encoded.index(index, offsetBy: chunkSize, limitedBy: encoded.endIndex) ?? encoded.endIndex
            result.append(String(encoded[index..<end]))
            index = end
        }
        if result.last?.count == chunkSize { result.append("+") }
        return result
    }
}
