//
//  NeedleTailError.swift
//  needletail-irc
//
//  Created by Cole M on 12/3/24.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

/// A comprehensive error enumeration for the NeedleTailIRC SDK.
///
/// `NeedleTailError` defines all possible errors that can occur during IRC operations,
/// providing detailed error information for debugging and error handling.
///
/// ## Error Categories
///
/// The errors are organized into several categories:
/// - **Connection Errors**: Network and server connection issues
/// - **Authentication Errors**: JWT, token, and authentication problems
/// - **Channel Errors**: Channel-related operations and validation
/// - **Message Errors**: Message handling and delivery issues
/// - **Device Errors**: Device registration and management
/// - **Media Errors**: File upload/download and media handling
/// - **Transport Errors**: Transport layer and communication issues
///
/// ## Usage
///
/// ```swift
/// do {
///     try await ircClient.sendMessage("Hello", to: "#general")
/// } catch NeedleTailError.channelIsNil {
///     print("Channel is not available")
/// } catch NeedleTailError.transportNotIntitialized {
///     print("Transport layer not initialized")
/// } catch {
///     print("Other error: \(error)")
/// }
/// ```
///
/// ## Thread Safety
///
/// This enum is thread-safe and can be used concurrently from multiple threads.
public enum NeedleTailError: String, Error, Sendable {
    
    // MARK: - Response and Validation Errors
    
    /// Invalid response received from the server.
    case invalidResponse
    /// Invalid IRC channel name format.
    case invalidIRCChannelName
    /// BSON response is nil or invalid.
    case nilBSONResponse
    /// Authentication token is nil or missing.
    case nilToken
    /// URL is nil or invalid.
    case urlNil
    /// URL response is nil or invalid.
    case urlResponseNil
    
    // MARK: - Client and Connection Errors
    
    /// Client instance is nil or not properly initialized.
    case nilClient
    /// Client already exists and cannot be created again.
    case clientExists
    /// Could not connect to the network.
    case couldNotConnectToNetwork
    /// Could not connect to the server.
    case couldNotConnectToServer
    
    // MARK: - Channel and User Errors
    
    /// Channel name is nil or invalid.
    case nilChannelName
    /// Nickname is nil or invalid.
    case nilNickName
    /// Channel data is nil or missing.
    case nilChannelData
    /// Channel already exists.
    case channelExists
    /// Channel is nil when expected to be available.
    case channelIsNil
    /// Channel monitor is nil or not initialized.
    case channelMonitorIsNil
    /// Invalid user ID format or content.
    case invalidUserId
    /// User is not online.
    case nickNotOnline
    
    // MARK: - Authentication and Device Errors
    
    /// Missing authentication information.
    case missingAuthInfo
    /// Master device rejected the new device request.
    case masterDeviceReject = "The Master Device rejected the request to add a new device"
    /// Registration process failed.
    case registrationFailure
    /// Device ID is nil or missing.
    case deviceIdNil
    /// Username is nil or missing.
    case usernameNil
    /// Salt is not found in keychain.
    case saltIsNotInKeychain
    /// Cannot register new device.
    case cannotRegisterNewDevice
    /// New device state management.
    case newDevice
    
    // MARK: - Message and Communication Errors
    
    /// Message received with error.
    case messageReceivedError
    /// Sender information is nil.
    case senderNil
    /// Parsing error occurred.
    case parsingError
    /// Cannot find chat or conversation.
    case cannotFindChat
    /// Payload is too large for transmission.
    case payloadTooLarge
    
    // MARK: - Key Bundle and Security Errors
    
    /// Cannot publish key bundle.
    case cannotPublishKeyBundle
    /// Cannot read key bundle.
    case cannotReadKeyBundle
    /// Acknowledgment data is corrupted.
    case acknowledgmentCorrupted
    /// Contact bundle does not exist for media ID.
    case contactBundleDoesNotExistForMediaId
    /// Contact bundle does not exist for message ID.
    case contactBundleDoesNotExistForMessageId
    /// Internal contact bundle does not exist.
    case internalContactBundleDoesNotExist
    /// Symmetric key does not exist.
    case symmetricKeyDoesNotExist
    
    // MARK: - Media and File Errors
    
    /// Media ID is nil or missing.
    case mediaIdNil
    /// Media cache error occurred.
    case mediaCacheError
    /// Invalid file format.
    case invalidFileFormat
    /// File path does not exist.
    case filePathDoesntExist
    /// Access denied to file or resource.
    case accessDenied
    
    // MARK: - Transport and Infrastructure Errors
    
    /// Transport layer not initialized.
    case transportNotIntitialized
    /// Transport bridge delegate not set.
    case transportBridgeDelegateNotSet
    /// Transportation state error.
    case transportationStateError
    /// Messenger not initialized.
    case messengerNotIntitialized
    /// Store not initialized.
    case storeNotIntitialized = "You must initialize a store"
    /// Mechanism not initialized.
    case mechanisimNotIntitialized = "Mechanism not initialized"
    /// Client info not initialized.
    case clientInfotNotIntitialized = "You must initialize client info"
    /// Bridge delegate not set.
    case bridgeDelegateNotSet
    /// Cypher messenger not set.
    case cypherMessengerNotSet
    /// Could not create handlers.
    case couldNotCreateHandlers = "Could Not Create Handlers"
    /// Emitter is nil.
    case emitterIsNil = "Emitter is nil"
    /// Outbound writer not set.
    case outboundWriterNotSet
    /// Inbound stream not set.
    case inboundStreamNotSet
    
    // MARK: - Data and Resource Errors
    
    /// Data is nil or missing.
    case nilData
    /// Blob is nil or missing.
    case nilBlob
    /// ElGamal key is nil or missing.
    case nilElG
    /// NTM (NeedleTail Message) is nil or missing.
    case nilNTM
    /// Insufficient members for group chat creation.
    case membersCountInsufficient = "Insufficient members. You are trying to create a group chat with only 1 member."
}
