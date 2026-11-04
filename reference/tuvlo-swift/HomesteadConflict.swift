import Foundation

/// Retains an inadmissible remote runtime record without letting it replace a
/// committed command. It is ordinary family data: backed up, synced and erased.
nonisolated struct HomesteadConflict: Equatable, Sendable {
    static let prefix = "homestead-conflict:v1:"
    static let maximumBytes = HomesteadEvent.maximumBytes + 128
    let childID: UUID
    let sourceID: UUID
    let incomingRaw: String
    var rawValue: String { Self.prefix + childID.uuidString + ":" + sourceID.uuidString + ":" + incomingRaw }
    var id: UUID { HomesteadIdentity.stable(childID: childID, key: "conflict:\(sourceID):\(HomesteadIdentity.digest(Data(incomingRaw.utf8)))") }
    init(childID: UUID, sourceID: UUID, incomingRaw: String) {
        self.childID = childID; self.sourceID = sourceID; self.incomingRaw = incomingRaw
    }
    init?(_ raw: String) {
        guard raw.hasPrefix(Self.prefix), raw.utf8.count <= Self.maximumBytes else { return nil }
        let fields = raw.dropFirst(Self.prefix.count).split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard fields.count == 3, let child = UUID(uuidString: String(fields[0])), let source = UUID(uuidString: String(fields[1])),
              fields[2].hasPrefix(HomesteadEvent.prefix), fields[2].utf8.count <= HomesteadEvent.maximumBytes else { return nil }
        childID = child; sourceID = source; incomingRaw = String(fields[2])
    }
    static func isRuntimeRecord(_ raw: String) -> Bool { raw.hasPrefix(HomesteadEvent.prefix) || raw.hasPrefix(prefix) }
}
