//
//  NeedleTailError.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
//


public enum NeedleTailError: String, Error, Sendable {
    case invalidResponse
    case invalidIRCChannelName
    case nilBSONResponse
    case nilToken
    case urlNil
    case urlResponseNil
    case nilClient
    case clientExists
    case nilChannelName
    case nilNickName
    case nilNTM
    case nilData
    case nilChannelData
    case nilBlob
    case invalidUserId
    case missingAuthInfo
    case membersCountInsufficient = "Insufficient members. You are trying to create a group chat with only 1 member."
    case nilElG
    case transportNotIntitialized
    case transportBridgeDelegateNotSet
    case transportationStateError
    case messengerNotIntitialized
    case masterDeviceReject = "The Master Device rejected the request to add a new device"
    case registrationFailure
    case storeNotIntitialized = "You must initialize a store"
    case mechanisimNotIntitialized = "You must initialize a mechanism"
    case clientInfotNotIntitialized = "You must initialize client info"
    case messageReceivedError
    case senderNil
    case channelIsNil
    case channelExists
    case parsingError
    case channelMonitorIsNil
    case cannotPublishKeyBundle
    case cannotReadKeyBundle
    case cannotRegisterNewDevice
    case saltIsNotInKeychain
    case acknowledgmentCorrupted
    case deviceIdNil
    case usernameNil
    case bridgeDelegateNotSet
    case cypherMessengerNotSet
    case couldNotCreateHandlers = "Could Not Create Handlers"
    case emitterIsNil = "Emitter is nil"
    case cannotFindChat
    case mediaIdNil
    case payloadTooLarge
    case couldNotConnectToNetwork
    case couldNotConnectToServer
    case outboundWriterNotSet
    case inboundStreamNotSet
    case filePathDoesntExist
    case symmetricKeyDoesNotExist
    case contactBundleDoesNotExistForMediaId
    case contactBundleDoesNotExistForMessageId
    case internalContactBundleDoesNotExist
    case mediaCacheError
    case nickNotOnline
    case invalidFileFormat
    case accessDenied
}