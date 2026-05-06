//
//  NeedleTailChannelIdentity.swift
//  needletail-irc
//

import Foundation

/// Helpers for the stable channel identifier used on the IRC wire and in storage.
///
/// User-facing titles are converted into a deterministic IRC-safe shape:
/// `#slug_uuid`. The full value is the channel identity for JOIN/PART/cache/store
/// operations; UI should derive labels from `NeedleTailChannel.displayTitle`.
public enum NeedleTailChannelIdentity: Sendable {
    private static let previewUUID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    /// Builds a canonical wire/storage name from a display title and room id.
    ///
    /// Example: `"My Family"` + `00000000-0000-0000-0000-000000000001`
    /// becomes `#my-family_00000000-0000-0000-0000-000000000001`.
    public static func canonicalWireName(
        fromDisplayName displayName: String,
        roomId: UUID = UUID(),
        preferredPrefix: Character = "#"
    ) -> String? {
        wireName(
            fromDisplayName: displayName,
            suffix: roomId.uuidString.lowercased(),
            preferredPrefix: preferredPrefix)
    }

    /// Builds a preview wire name with a non-UUID placeholder suffix for UI hints.
    public static func previewWireName(
        fromDisplayName displayName: String,
        preferredPrefix: Character = "#"
    ) -> String? {
        wireName(
            fromDisplayName: displayName,
            suffix: previewUUID,
            preferredPrefix: preferredPrefix)
    }

    /// Builds and validates a `NeedleTailChannel` from a display title and room id.
    public static func canonicalChannel(
        fromDisplayName displayName: String,
        roomId: UUID = UUID(),
        preferredPrefix: Character = "#"
    ) -> NeedleTailChannel? {
        canonicalWireName(
            fromDisplayName: displayName,
            roomId: roomId,
            preferredPrefix: preferredPrefix)
            .flatMap(NeedleTailChannel.init)
    }

    /// Extracts the UUID suffix from a canonical `#slug_uuid` channel wire name.
    public static func uuidString(fromWireName wireName: String) -> String? {
        var candidate = wireName.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.first?.isChannelNamePrefixed == true {
            candidate.removeFirst()
        }
        guard let separatorIndex = candidate.lastIndex(of: "_") else { return nil }
        let suffix = String(candidate[candidate.index(after: separatorIndex)...])
        guard let uuid = UUID(uuidString: suffix) else { return nil }
        return uuid.uuidString.lowercased()
    }

    private static func wireName(
        fromDisplayName displayName: String,
        suffix: String,
        preferredPrefix: Character
    ) -> String? {
        guard let baseWire = NeedleTailChannel.derivedName(
            fromUserFacing: displayName,
            preferredPrefix: preferredPrefix)
        else {
            return nil
        }

        let baseBody = baseWire.first?.isChannelNamePrefixed == true ? String(baseWire.dropFirst()) : baseWire
        let reservedSuffixLength = 1 + suffix.count
        let availableSlugLength = NeedleTailChannel.maxChannelBodyLength - reservedSuffixLength
        guard availableSlugLength > 0 else { return nil }

        let trimmedSlug = String(baseBody.prefix(availableSlugLength))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        guard !trimmedSlug.isEmpty else { return nil }

        let candidate = "\(preferredPrefix)\(trimmedSlug)_\(suffix)"
        let wire = candidate.ircLowercased
        guard NeedleTailChannel.validate(string: wire) else { return nil }
        return wire
    }
}
