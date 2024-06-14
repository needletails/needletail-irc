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

public struct IRCUserID: Codable, Hashable, CustomStringConvertible, Sendable {
  
  public let nick: NeedleTailNick
  public let user : String?
  public let host : String?
  
  public init(nick: NeedleTailNick, user: String? = nil, host: String? = nil) {
    self.nick = nick
    self.user = user
    self.host = host
  }
  
    public init?(_ s: String, deviceId: DeviceId? = nil) {
        if let atIdx = s.firstIndex(of: Character(Constants.atString.rawValue)) {
      let hs = s.index(after: atIdx)
      self.host = String(s[hs..<s.endIndex])
      
      let nickString : String
            if let exIdx = s.firstIndex(of: Character(Constants.exclamation.rawValue)) {
        let hs = s.index(after: exIdx)
        self.user = String(s[hs..<atIdx])
        
        nickString = String(s[s.startIndex..<exIdx])
      } else {
        self.user = nil
        nickString = String(s[s.startIndex..<atIdx])
      }
      guard let nick = NeedleTailNick(name: nickString, deviceId: deviceId) else { return nil }
      self.nick = nick
    } else {
      guard let nick = NeedleTailNick(name: s, deviceId: deviceId) else { return nil }
      self.nick = nick
      self.user = nil
      self.host = nil
    }
  }
  
  public func hash(into hasher: inout Hasher) { nick.hash(into: &hasher) }
  
  public static func ==(lhs: IRCUserID, rhs: IRCUserID) -> Bool {
    return lhs.nick == rhs.nick && lhs.user == rhs.user && lhs.host == rhs.host
  }
  
  public var stringValue : String {
    var ms = "\(nick)"
    if let host = host {
        if let user = user { ms += "\(Constants.exclamation)\(user)" }
        ms += "\(Constants.atString)\(host)"
    }
    return ms
  }
  
  public var description: String { return stringValue }
}
