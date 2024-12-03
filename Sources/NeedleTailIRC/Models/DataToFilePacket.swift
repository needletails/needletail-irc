//
//  DataToFilePacket.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
//

import Foundation

public struct DataToFilePacket: Codable, Sendable, Equatable {
    public var mediaId: String
    public var fileName: String
    public var thumbnailName: String
    public var fileType: String
    public var thumbnailType: String
    public var fileLocation: String
    public var thumbnailLocation: String
    public var fileBlob: Data?
    public var thumbnailBlob: Data?
    public var symmetricKey: Data?
    public var fileTitle: String?
    public var fileSize: Int?
    public var thumbnailSize: Int?
    public var multipartUploadState: Data?
    public var multipartDownloadState: Data?
    
    public init(
        mediaId: String,
        fileName: String,
        thumbnailName: String,
        fileType: String,
        thumbnailType: String,
        fileLocation: String,
        thumbnailLocation: String,
        fileBlob: Data? = nil,
        thumbnailBlob: Data? = nil,
        symmetricKey: Data? = nil,
        fileTitle: String? = nil,
        fileSize: Int? = nil,
        thumbnailSize: Int? = nil,
        multipartUploadState: Data? = nil,
        multipartDownloadState: Data? = nil
    ) {
        self.mediaId = mediaId
        self.fileName = fileName
        self.thumbnailName = thumbnailName
        self.fileType = fileType
        self.thumbnailType = thumbnailType
        self.fileLocation = fileLocation
        self.thumbnailLocation = thumbnailLocation
        self.fileBlob = fileBlob
        self.thumbnailBlob = thumbnailBlob
        self.symmetricKey = symmetricKey
        self.fileTitle = fileTitle
        self.fileSize = fileSize
        self.thumbnailSize = thumbnailSize
        self.multipartUploadState = multipartUploadState
        self.multipartDownloadState = multipartDownloadState
    }
}
