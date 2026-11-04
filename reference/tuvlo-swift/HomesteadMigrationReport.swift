import Foundation
import SwiftData

/// Read-only developer/parent-export input. No report is automatically written
/// outside the family store or sent anywhere, and raw internals never enter UI.
nonisolated struct HomesteadMigrationReport: Codable, Sendable {
    let version: Int
    let childID: UUID
    let candidate: HomesteadBaseline
    let committedBaselines: [HomesteadBaseline]
    let retainedConflicts: [String]
    let currentObjects: [HomesteadObject]

    @MainActor
    static func make(for kid: Child) throws -> Self {
        let committed = HomesteadActions.saved(for: kid).compactMap { saved -> HomesteadBaseline? in
            if case .migration(let base) = saved.event.change { return base }; return nil
        }
        return Self(version: 1, childID: kid.id, candidate: try HomesteadMigration.baseline(for: kid),
                    committedBaselines: committed,
                    retainedConflicts: kid.worldPlacements.filter { !$0.isDeleted && $0.discoveryID.hasPrefix(HomesteadConflict.prefix) }.map(\.discoveryID).sorted(),
                    currentObjects: try HomesteadActions.state(for: kid).objects)
    }
    func json() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(self)
    }
}
