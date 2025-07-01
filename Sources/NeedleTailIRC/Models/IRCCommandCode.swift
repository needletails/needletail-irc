//
//  IRCCommandCode.swift
//  needletail-irc
//
//  Created by Cole M on 9/23/22.
//
//  Copyright (c) 2025 NeedleTails Organization.
//  This project is licensed under the MIT License.
//
//  See the LICENSE file for more information.
//
//  This file is part of the NeedleTailIRC SDK, which provides
//  IRC protocol implementation and messaging capabilities.
//

import Foundation

/// Represents various IRC command codes as defined by the IRC protocol (RFC 2812).
public enum IRCCommandCode: Int, Codable, Sendable {
    
    // MARK: - Server Replies (1...399)
    
    case replyWelcome               = 1
    case replyYourHost              = 2
    case replyCreated               = 3
    case replyMyInfo                = 4
    case replyBounce                = 5
    
    case replyAway                  = 301
    case replyUserhost              = 302
    case replyISON                  = 303 // List of nicks that are online
    case replyUnAway                = 305
    case replyNowAway               = 306
    
    case replyWhoIsUser             = 311
    case replyWhoIsServer           = 312
    case replyWhoIsOperator         = 313
    case replyWhoWasUser            = 314
    case replyWhoIsIdle             = 317
    case replyEndOfWhoIs            = 318
    case replyWhoIsChannels         = 319
    case replyEndOfWhoWas           = 369
    
    case replyListStart             = 321 // Obsolete
    case replyList                  = 322
    case replyListEnd               = 323
    
    case replyChannelModeIs         = 324
    case replyUniqOpIs              = 325
    
    case replyIsLoggedInAs          = 330 // Freenode-specific
    
    case replyNoTopic               = 331
    case replyTopic                 = 332
    
    case replyInviting              = 341
    case replySummoning             = 342
    case replyInviteList            = 346
    case replyEndOfInviteList       = 347
    case replyExceptList            = 348
    case replyEndOfExceptList       = 349
    
    case replyVersion               = 351
    case replyWhoReply              = 352
    case replyEndOfWho              = 315
    case replyNameReply             = 353
    case replyEndOfNames            = 366
    
    case replyLinks                 = 364
    case replyEndOfLinks            = 365
    
    case replyBanList               = 367
    case replyEndOfBanList          = 368
    
    case replyInfo                  = 371
    case replyEndOfInfo             = 374
    case replyMotDStart             = 375
    case replyMotD                  = 372
    case replyEndOfMotD             = 376
    
    case replyIsConnectingFrom       = 378 // Freenode-specific
    
    case replyYouROper              = 381
    case replyRehashing             = 382
    case replyYourService           = 383
    
    case replyTime                  = 391
    case replyUsersStart            = 392
    case replyUsers                 = 393
    case replyEndOfUsers            = 394
    case replyNoUsers               = 395
    
    // MARK: - Trace Replies (200...299)
    
    case replyTraceLinkInfo         = 210
    case replyStatsLinkInfo         = 211
    case replyStatsCommands         = 212
    case replyEndOfStats            = 219
    case replyStatsUptime           = 242
    case replyStatsOLine            = 243
    case replyUModeIs               = 221
    
    case replyServList              = 234
    case replyServListEnd           = 235
    
    // MARK: - User Counts Replies (250...259)
    
    case replyLUserClient           = 251
    case replyLUserOp               = 252
    case replyLUserUnknown          = 253
    case replyLUserChannels         = 254
    case replyLUserMe               = 255
    
    // MARK: - Admin Replies (256...259)
    
    case replyAdminMe               = 256
    case replyAdminLoc1             = 257
    case replyAdminLoc2             = 258
    case replyAdminEmail            = 259
    
    // MARK: - Error Replies (400...599)
    
    case errorNoSuchNick            = 401
    case errorNoSuchServer          = 402
    case errorNoSuchChannel         = 403
    case errorCannotSendToChain     = 404
    case errorTooManyChannels       = 405
    case errorWasNoSuchNick         = 406
    case errorTooManyTargets        = 407
    case errorNoSuchService         = 408
    case errorNoOrigin              = 409
    case errorInvalidCAPCommand     = 410 // IRCv3.net
    case errorNoRecipient           = 411
    case errorNoTextToSend          = 412
    case errorNoTopLevel            = 413
    case errorWildTopLevel          = 414
    case errorBadMask               = 415
    case errorUnknownCommand        = 421
    case errorNoMotD                = 422
    case errorNoAdminInfo           = 423
    case errorFileError             = 424
    case errorNoNickNameGiven       = 431
    case errorErroneousNickname     = 432
    case errorNicknameInUse         = 433
    case errorNickCollision         = 436
    case errorUnavailableResource    = 437
    case errorUserNotInChannel      = 441
    case errorNotOnChannel          = 442
    case errorUserOnChannel         = 443
    case errorNoLogin               = 444
    case errorSummonDisabled        = 445
    case errorUsersDisabled         = 446
    case errorNotRegistered         = 451
    case errorNeedMoreParams        = 461
    case errorAlreadyRegistered     = 462
    case errorNoPermForHost         = 463
    case errorPasswordMismatch      = 464
    case errorYouReBannedCreep      = 465
    case errorYouWillBeBanned       = 466
    case errorKeySet                = 467
    case errorChannelIsFull         = 471
    case errorUnknownMode           = 472
    case errorInviteOnlyChan        = 473
    case errorBannedFromChan        = 474
    case errorBadChannelKey         = 475
    case errorBadChannelMask        = 476
    case errorNoChannelModels       = 477
    case errorBanListFull           = 478
    case errorNoPrivileges          = 481
    case errorChanOPrivsNeeded      = 482
    case errorCantKillServer        = 483
    case errorRestricted            = 484
    case errorUniqOpPrivIsNeeded    = 485
    case errorNoOperHost            = 491
    
    case errorUModeUnknownFlag      = 501
    case errorUsersDontMatch        = 502
    
    // MARK: - Freenode-Specific Errors
    
    case errorIllegalChannelName    = 479
    
    // MARK: - Additional Numeric Replies for 100% Conformance (RFC 2812, RFC 1459)
    // Only add cases not already present above. Do not duplicate raw values.
    case replyYourUniqueID = 42
    case replyTraceLink = 200
    case replyTraceConnecting = 201
    case replyTraceHandshake = 202
    case replyTraceUnknown = 203
    case replyTraceOperator = 204
    case replyTraceUser = 205
    case replyTraceServer = 206
    case replyTraceService = 207
    case replyTraceNewType = 208
    case replyTraceClass = 209
    case replyStatsCLine = 213
    case replyStatsNLine = 214
    case replyStatsILine = 215
    case replyStatsKLine = 216
    case replyStatsQLine = 217
    case replyStatsYLine = 218
    case replyStatsLLine = 241
    case replyStatsHLine = 244
    case replyStatsGLine = 247
    case replyStatsULine = 248
    case replyStatsZLine = 223
    case replyTraceLog = 261
    case replyTraceEnd = 262
}
