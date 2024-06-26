//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio-irc open source project
//
// Copyright (c) 2018-2021 ZeeZide GmbH. and the swift-nio-irc project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIOIRC project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import CypherMessaging

public enum IRCMessageRecipient: Codable, Hashable, Sendable {
  
  case channel(IRCChannelName)
  case nick(NeedleTailNick)
  case everything // Note: this doesn't seem to be spec'ed?!
  
  // TODO:
  // or: user, or user%host, @server, etc
  // or: nickname!user@host
  public func hash(into hasher: inout Hasher) {
    switch self {
      case .channel (let name): return name.hash(into: &hasher)
      case .nick(let name): return name.hash(into: &hasher)
      case .everything:         return 42.hash(into: &hasher) // TBD?
    }
  }
  
  public static func ==(lhs: IRCMessageRecipient, rhs: IRCMessageRecipient)
                  -> Bool
  {
    switch ( lhs, rhs ) {
      case ( .everything,        .everything ):       return true
      case ( .channel (let lhs), .channel (let rhs)): return lhs == rhs
      case ( .nick(let lhs), .nick(let rhs)): return lhs == rhs
      default: return false
    }
  }
}

public extension IRCMessageRecipient {
  
  init?(_ s: String) {
      var nick: NeedleTailNick?
      if s.contains(Constants.underScore.rawValue) {
          let split = s.components(separatedBy: Constants.underScore.rawValue)
          guard let name = split.first else { return nil }
          guard let deviceId = split.last else { return nil }
          nick = NeedleTailNick(name: name, deviceId: DeviceId(deviceId))
      }
      if s == Constants.star.rawValue {
        self = .everything
      } else if let channel = s.ircChanneled {
        self = .channel(channel)
    } else if let needletail = nick {
        self = .nick(needletail)
    } else {
        return nil
    }
  }
  
  var stringValue : String {
    switch self {
      case .channel (let name):
        return name.stringValue
    case .nick(let name):
        return name.stringValue
      case .everything:
        return Constants.star.rawValue
    }
  }
}

extension IRCMessageRecipient : CustomStringConvertible {
  
  public var description : String {
    switch self {
      case .channel (let name) : return name.description
      case .nick(let name) : return name.description
    case .everything :return "<IRCRecipient: \(Constants.star.rawValue)>"
    }
  }
}
