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
    case exclamation = "!"
    case underScore = "_"
    case nick = "NICK"
    case join = "JOIN"
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
    case pass = "PASS"
    case quit = "QUIT"
    case isOn = "ISON"
    case ping = "PING"
    case pong = "PONG"
    case list = "LIST"
    case notice = "NOTICE"
    case cap = "CAP"
    case whoIs = "WHOIS"
    case who = "WHO"
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
    case clearmode = "CLEARMODE"
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
}
