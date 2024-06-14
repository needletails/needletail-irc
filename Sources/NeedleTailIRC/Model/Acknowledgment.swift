//
//  Acknowledgment.swift
//
//
//  Created by Cole M on 3/23/22.
//

import Foundation

public struct Acknowledgment: Codable, Sendable {
    
    public enum AckType: Codable, Equatable, Sendable {
        case registered(String)
        case isOnline(String)
        case registryRequestRejected(String, String)
        case registryRequestAccepted(String, String)
        case newDevice(String)
        case readKeyBundle(String)
        case voip(String)
        case apn(String)
        case none
        case messageSent
        case blocked
        case unblocked
        case quited
        case publishedKeyBundle(String)
        case readReceipt
        case multipartReceived
        case multipartUploadNotification(MultipartUploadAckPacket)
        case multipartDownloadNotification(MultipartDownloadAckPacket)
    }

    public var acknowledgment: AckType
    
    public init(
        acknowledgment: AckType
    ) {
        self.acknowledgment = acknowledgment
    }
}

public enum MultipartUploadState: Codable, Sendable, Equatable {
    case uploading, uploaded, failed(String)
}

public struct MultipartUploadAckPacket: Sendable, Codable, Equatable {

    public var id = UUID()
    public var name: String
    public var mediaId: String?
    public var size: Int
    public var state: MultipartUploadState
    
    public init(
        name: String,
        mediaId: String?,
        size: Int,
        state: MultipartUploadState
    ) {
        self.name = name
        self.mediaId = mediaId
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
    public var mediaId: String
    public var state: MultipartDownloadState
    
    public init(
        name: String,
        mediaId: String,
        state: MultipartDownloadState
    ) {
        self.name = name
        self.mediaId = mediaId
        self.state = state
    }
    
    public static func == (lhs: MultipartDownloadAckPacket, rhs: MultipartDownloadAckPacket) -> Bool {
        lhs.id == rhs.id
    }
}
