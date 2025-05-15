//
//  Acknowledgment.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
//


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
        case synchronizedKeyBundle(String)
        case multipartReceived
        case multipartUploadNotification(MultipartUploadAckPacket)
        case multipartDownloadNotification(MultipartDownloadAckPacket)
        case dccState(DCCState)
    }

    public var acknowledgment: AckType
    
    public init(
        acknowledgment: AckType
    ) {
        self.acknowledgment = acknowledgment
    }
}
