//
//  IRCLowercased.swift
//  needletail-irc
//
//  Created by Cole M on 6/14/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

extension String {
    /// A computed property that returns the string in lowercase,
    /// with specific characters replaced to comply with IRC conventions.
    public var ircLowercased: String {
        // Lowercase the string and perform character substitutions
        return self.lowercased()
            .replacingOccurrences(of: "[", with: "{")
            .replacingOccurrences(of: "]", with: "}")
            .replacingOccurrences(of: "\\", with: "|")
            .replacingOccurrences(of: "~", with: "^")
    }
}
