//
//  NeedleTailNick.swift
//  needletail-irc
//
//  Created by Cole M on 9/28/24.
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

public struct NeedleTailNick: Codable, Hashable, Equatable, CustomStringConvertible, Sendable {
    
    public let name: String
    public let deviceId: UUID?
    
    public var description: String {
        return "NeedleTailNick(name: \(self.name), deviceId: \(deviceId?.uuidString ?? "nil"))"
    }
    
    public var stringValue: String {
        return "\(name)_\(deviceId?.uuidString ?? "nil")"
    }
    
    public init?(name: String, deviceId: UUID?, nameRules: NameRules = NameRules()) {
        guard NeedleTailNick.validateName(name, nameRules: nameRules) == .isValidated else { return nil }
        self.name = name
        self.deviceId = deviceId
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(deviceId)
    }
    
    public static func ==(lhs: NeedleTailNick, rhs: NeedleTailNick) -> Bool {
        return lhs.deviceId == rhs.deviceId && lhs.name == rhs.name
    }
    
    public enum ValidatedNameStatus {
        case isValidated, failedValidation
    }
    
    public struct NameRules: Sendable {
        public var allowsStartingDigit: Bool = true
        public var disallowsUnderScore: Bool = true
        public var lengthLimit: Int = 1024
        
        public init() {}
    }
    
    public static func validateName(_ name: String, nameRules: NameRules) -> ValidatedNameStatus {
        guard name.count > 1, name.count <= nameRules.lengthLimit else {
            return .failedValidation
        }
        
        if nameRules.disallowsUnderScore && name.contains("_") {
            return .failedValidation
        }
        
        let firstCharacterSet = nameRules.allowsStartingDigit ? CharacterSets.letterDigitOrSpecial : CharacterSets.letterOrSpecial
        let restCharacterSet = CharacterSets.letterDigitSpecialOrDash
        
        guard let firstScalar = name.unicodeScalars.first, firstCharacterSet.contains(firstScalar) else {
            return .failedValidation
        }
        
        for scalar in name.unicodeScalars.dropFirst() {
            guard restCharacterSet.contains(scalar) else {
                return .failedValidation
            }
        }
        return .isValidated
    }
    
    public enum CodingKeys: String, CodingKey, Sendable {
        case name = "a"
        case deviceId = "b"
    }
    
    // MARK: - Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.deviceId = try container.decodeIfPresent(UUID.self, forKey: .deviceId)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
    }
    
    /// Initializes a `NeedleTailNick` instance with a lowercase version of the provided name.
    ///
    /// - Parameters:
    ///   - name: The desired nickname, which will be converted to lowercase.
    ///   - deviceId: An optional UUID representing the device ID associated with the nickname.
    /// - Returns: A new `NeedleTailNick` instance, or `nil` if initialization fails.
    public init?(name: String, deviceId: UUID?) {
        // Initialize with the lowercase version of the name and default name rules
        self.init(name: name.lowercased(), deviceId: deviceId, nameRules: .init())
    }
}

fileprivate enum CharacterSets: Sendable {
    static let letter = CharacterSet.letters
    static let digit = CharacterSet.decimalDigits
    static let special = CharacterSet(charactersIn: "[]\\`_^{|}")
    static let letterOrSpecial = letter.union(special)
    static let letterDigitOrSpecial = letter.union(digit).union(special)
    static let letterDigitSpecialOrDash = letterDigitOrSpecial.union(CharacterSet(charactersIn: "-"))
}

extension String {
    public var constructedNick: NeedleTailNick? {
        let senderComponents = self.split(separator: "_").map(String.init)
        guard let senderUsername = senderComponents.first,
              senderComponents.count > 1,
              let senderDeviceId = UUID(uuidString: senderComponents.last!) else {
            return nil
        }
        return NeedleTailNick(name: senderUsername, deviceId: senderDeviceId)
    }
}
