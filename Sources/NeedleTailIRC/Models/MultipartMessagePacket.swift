//
//  MultipartMessagePacket.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
//


import Foundation

public struct MultipartMessagePacket: Codable, Sendable, Equatable {
    public var id: String
    public var sender: String
    public var recipient: String?
    public var dtfp: DataToFilePacket?
    public var usersFileName: String?
    public var usersThumbnailName: String?
  
    public init(
      id: String,
      sender: String,
      recipient: String? = nil,
      dtfp: DataToFilePacket? = nil,
      usersFileName: String? = nil,
      usersThumbnailName: String? = nil
  ) {
      self.id = id
      self.sender = sender
      self.recipient = recipient
      self.dtfp = dtfp
      self.usersFileName = usersFileName
      self.usersThumbnailName = usersThumbnailName
  }
}


public struct MultipartUploadAckPacket: Sendable, Codable, Equatable {

    public var id = UUID()
    public var name: String
    public var sharedMessageIdentity: String?
    public var size: Int
    public var state: MultipartUploadState
    
    public init(
        name: String,
        sharedMessageIdentity: String?,
        size: Int,
        state: MultipartUploadState
    ) {
        self.name = name
        self.sharedMessageIdentity = sharedMessageIdentity
        self.size = size
        self.state = state
    }
    
    public static func == (lhs: MultipartUploadAckPacket, rhs: MultipartUploadAckPacket) -> Bool {
        lhs.id == rhs.id
    }
}

public enum MultipartDownloadState: Codable, Sendable, Equatable {
    case downloading, downloaded, failed(String)
}

public struct MultipartDownloadAckPacket: Sendable, Codable, Equatable {

    
    public var id = UUID()
    public var name: String
    public var sharedMessageIdentity: String
    public var state: MultipartDownloadState
    
    public init(
        name: String,
        sharedMessageIdentity: String,
        state: MultipartDownloadState
    ) {
        self.name = name
        self.sharedMessageIdentity = sharedMessageIdentity
        self.state = state
    }
    
    public static func == (lhs: MultipartDownloadAckPacket, rhs: MultipartDownloadAckPacket) -> Bool {
        lhs.id == rhs.id
    }
}

public enum MultipartUploadState: Codable, Sendable, Equatable {
    case uploading, uploaded, failed(String)
}
