//
//  IRCLowercased.swift
//  
//
//  Created by Cole M on 6/14/24.
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
