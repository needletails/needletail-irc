//
//  BinaryEncoding.swift
//  needletail-irc
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//

import Foundation
import BinaryCodable

/// Minimal encode seam so tests can force packet-metadata encode failures.
public protocol BinaryEncoding: Sendable {
    func encode<T: Encodable>(_ value: T) throws -> Data
}

extension BinaryEncoder: BinaryEncoding {}
