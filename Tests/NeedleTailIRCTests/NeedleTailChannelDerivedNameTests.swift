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
}
