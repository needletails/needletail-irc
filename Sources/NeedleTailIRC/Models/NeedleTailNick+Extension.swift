//
//  NeedleTailNick+Extension.swift
//  needletail-irc
//
//  Created by Cole M on 8/11/24.
//
import NIOConcurrencyHelpers
import CypherMessaging
import NeedleTailStructures

public extension NeedleTailNick {
    convenience init?(
        name: String,
        deviceId: DeviceId?
    ) {
        self.init(name: name.ircLowercased(), deviceId: deviceId, nameRules: .init())
    }
}
