//
//  Constants.swift
//  needletail-irc
//
//  Created by Cole M on 12/2/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

public enum Constants: String, Sendable {
    case cLF = "\n"
    case cCR = "\r"
    case space = " "
    case hashTag = "#"
    case star = "*"
    case colon = ":"
    case comma = ","
    case bString = "b"
    case oString = "o"
    case plus = "+"
    case minus = "-"
    case atString = "@"
    case equalsString = "="
    case semiColon = ";"
    case none = ""
    case semiColonSpace = "; "
    case exclamation = "!"
    case underScore = "_"
    case ampersand = "&"
    case keys = "keys:"
    case nick = "NICK"
    case join = "JOIN"
    case join0 = "JOIN0"
    case part = "PART"
    case user = "USER"
    case privMsg = "PRIVMSG"
    case mode = "MODE"
    case kill = "KILL"
    case kick = "KICK"
    case dccChat = "DCCCHAT"
    case dccSend = "DCCSEND"
    case dccResume = "DCCRESUME"
    case sdccChat = "SDCCCHAT"
    case sdccSend = "SDCCSEND"
    case sdccResume = "SDCCRESUME"
    case registryRequest = "REGISTRYREQUEST"
    case registryResponse = "REGISTRYRESPONSE"
    case newDevice = "NEWDEVICE"
    case offlineMessages = "OFFLINEMESSAGES"
    case deleteOfflineMessage = "DELETEOFFLINEMESSAGE"
    case pass = "PASS"
    case publishBlob = "PUBLISHBLOB"
    case readPublishedBlob = "READPUBLISHEDBLOB"
    case quit = "QUIT"
    case isOn = "ISON"
    case ping = "PING"
    case pong = "PONG"
    case list = "LIST"
    case notice = "NOTICE"
    case cap = "CAP"
    case whoIs = "WHOIS"
    case who = "WHO"
    case badgeUpdate = "BADGEUPDATE"
    case multipartMediaDownload = "MULTIPARTMEDIADOWNLOAD"
    case multipartMediaUpload = "MULTIPARTMEDIAUPLOAD"
    case listBucket = "LISTBUCKET"
    case requestMediaDeletion = "REQUESTMEDIADELETION"
    case destoryUser = "DESTROYUSER"
    case sQuit = "SQUIT"
    case server = "SERVER"
    case links = "LINKS"
    
    // MARK: - Additional IRC Commands for 100% Conformance (RFC 2812, RFC 1459)
    // These are added for protocol completeness. Implementation may be stubbed/TODO.
    case away = "AWAY"
    case oper = "OPER"
    case knock = "KNOCK"
    case silence = "SILENCE"
    case invite = "INVITE"
    case topic = "TOPIC"
    case names = "NAMES"
    case ban = "BAN"
    case unban = "UNBAN"
    case kickban = "KICKBAN"
    case clearmode = "CLEARMODE"
    case except = "EXCEPT"
    case unexcept = "UNEXCEPT"
    case inviteExcept = "INVITEEXCEPT"
    case uninviteExcept = "UNINVITEEXCEPT"
    case quiet = "QUIET"
    case unquiet = "UNQUIET"
    case voice = "VOICE"
    case devoice = "DEVOICE"
    case halfop = "HALFOP"
    case dehalfop = "DEHALFOP"
    case protect = "PROTECT"
    case deprotect = "DEPROTECT"
    case owner = "OWNER"
    case deowner = "DEOWNER"
    case rehash = "REHASH"
    case restart = "RESTART"
    case die = "DIE"
    case connect = "CONNECT"
    case trace = "TRACE"
    case stats = "STATS"
    case admin = "ADMIN"
    case info = "INFO"
    case version = "VERSION"
    case time = "TIME"
    case lusers = "LUSERS"
    case motd = "MOTD"
    case rules = "RULES"
    case map = "MAP"
    case users = "USERS"
    case wallops = "WALLOPS"
    case globops = "GLOBOPS"
    case locops = "LOCOPS"
    case adl = "ADL"
    case odlist = "ODLIST"
    case ctcp = "CTCP"
    case ctcpreply = "CTCPREPLY"
}

// MARK: - Additional Server Modes for 100% Conformance (RFC 2812, RFC 1459)
// This struct is added for protocol completeness. Implementation may be stubbed/TODO.

import Foundation

/// Represents various server modes in the IRC protocol.
public struct IRCServerModes: Codable, OptionSet, Sendable, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    // Example server modes (stubs)
    public static let hidden = IRCServerModes(rawValue: 1 << 0) // +h
    public static let debug = IRCServerModes(rawValue: 1 << 1) // +d
    public static let restricted = IRCServerModes(rawValue: 1 << 2) // +r
    public static let full = IRCServerModes(rawValue: 1 << 3) // +f
    public static let operOnly = IRCServerModes(rawValue: 1 << 4) // +o
    public static let snotice = IRCServerModes(rawValue: 1 << 5) // +s
    public static let receiveWallops = IRCServerModes(rawValue: 1 << 6) // +w
    public static let receiveGlobops = IRCServerModes(rawValue: 1 << 7) // +g
    public static let receiveLocops = IRCServerModes(rawValue: 1 << 8) // +l
    public static let receiveAdl = IRCServerModes(rawValue: 1 << 9) // +a
    public static let receiveOdlist = IRCServerModes(rawValue: 1 << 10) // +O
    public var stringValue: String {
        var modes = ""
        if contains(.hidden) { modes += "h" }
        if contains(.debug) { modes += "d" }
        if contains(.restricted) { modes += "r" }
        if contains(.full) { modes += "f" }
        if contains(.operOnly) { modes += "o" }
        if contains(.snotice) { modes += "s" }
        if contains(.receiveWallops) { modes += "w" }
        if contains(.receiveGlobops) { modes += "g" }
        if contains(.receiveLocops) { modes += "l" }
        if contains(.receiveAdl) { modes += "a" }
        if contains(.receiveOdlist) { modes += "O" }
        return modes
    }
}
