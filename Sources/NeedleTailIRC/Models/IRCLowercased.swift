//
//  IRCLowercased.swift
//  
//
//  Created by Cole M on 6/14/24.
//

extension String {
  // You wonder why, admit it! ;-)
public  func ircLowercased() -> String {
    return String(lowercased().map { c in
      switch c {
        case "[":  return "{"
        case "]":  return "}"
        case "\\": return "|"
        case "~":  return "^"
        default:   return c
      }
    })
  }
}
