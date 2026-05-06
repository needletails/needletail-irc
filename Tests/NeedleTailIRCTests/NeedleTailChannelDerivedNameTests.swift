//
//  NeedleTailChannelDerivedNameTests.swift
//  needletail-irc
//

import Foundation
import Testing
@testable import NeedleTailIRC

@Suite
struct NeedleTailChannelDerivedNameTests {
    @Test func myFamilyBecomesHyphenatedSlug() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "My Family") == "#my-family")
    }

    @Test func stripsLeadingHashAndTrims() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "  #My Family  ") == "#my-family")
    }

    @Test func simpleName() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "test") == "#test")
    }

    @Test func underscoresPreservedInSegment() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "my_room") == "#my_room")
    }

    @Test func punctuationBecomesSeparator() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "foo, bar") == "#foo-bar")
    }

    @Test func emptyAndWhitespaceNil() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "") == nil)
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "   ") == nil)
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "#") == nil)
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "###") == nil)
    }

    @Test func onlyNonAsciiNil() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "😀😀") == nil)
    }

    @Test func preferredAmpersand() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "ab", preferredPrefix: "&") == "&ab")
    }

    @Test func invalidPreferredPrefixNil() {
        #expect(NeedleTailChannel.derivedName(fromUserFacing: "ab", preferredPrefix: "x") == nil)
    }

    @Test func truncatesLongSlugToMaxBody() {
        let long = String(repeating: "a", count: NeedleTailChannel.maxChannelBodyLength + 20)
        let got = NeedleTailChannel.derivedName(fromUserFacing: long)
        #expect(got != nil)
        #expect(got?.count == 50)
        #expect(got?.first == "#")
        #expect(NeedleTailChannel.validate(string: got!))
    }

    @Test func displayTitleStripsCanonicalUuidSuffix() {
        let uuid = UUID().uuidString.lowercased()
        let channel = NeedleTailChannel("#travel_\(uuid)")
        #expect(channel?.displayTitle == "travel")
    }

    @Test func displayTitlePreservesLegacyChannelNames() {
        let channel = NeedleTailChannel("#travel")
        #expect(channel?.displayTitle == "travel")
    }

    @Test func canonicalWireNameNormalizesValidatedChannel() {
        let channel = NeedleTailChannel("#Travel_00000000-0000-0000-0000-000000000001")
        #expect(channel?.canonicalWireName == "#travel_00000000-0000-0000-0000-000000000001")
        #expect(channel?.identityUUIDString == "00000000-0000-0000-0000-000000000001")
        #expect(channel?.displayTitle == "Travel")
    }

    @Test func canonicalWireNameAddsUuidSuffix() throws {
        let uuid = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let wireName = NeedleTailChannelIdentity.canonicalWireName(
            fromDisplayName: "My Family",
            roomId: uuid)
        #expect(wireName == "#my-family_00000000-0000-0000-0000-000000000001")
        #expect(wireName.flatMap(NeedleTailChannel.init) != nil)
    }

    @Test func canonicalWireNameTrimsSlugToLeaveRoomForUuid() throws {
        let uuid = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let wireName = NeedleTailChannelIdentity.canonicalWireName(
            fromDisplayName: "abcdefghijklmnopqrstuvwxyz",
            roomId: uuid)
        #expect(wireName == "#abcdefghijkl_00000000-0000-0000-0000-000000000001")
        #expect(wireName?.count == 50)
    }

    @Test func previewWireNameUsesPlaceholderUuid() {
        let wireName = NeedleTailChannelIdentity.previewWireName(fromDisplayName: "My Family")
        #expect(wireName == "#my-family_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
        #expect(wireName.flatMap(NeedleTailChannel.init) != nil)
    }

    @Test func uuidStringParsesCanonicalWireNameSuffix() {
        let uuid = NeedleTailChannelIdentity.uuidString(
            fromWireName: "#travel_00000000-0000-0000-0000-000000000001")
        #expect(uuid == "00000000-0000-0000-0000-000000000001")
        #expect(NeedleTailChannelIdentity.uuidString(fromWireName: "#travel") == nil)
    }
}
