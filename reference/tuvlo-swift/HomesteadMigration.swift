import Foundation
import SwiftData
import CoreGraphics

/// A read-only projection of shipped data. No rewards, IDs or source rows change.
@MainActor
enum HomesteadMigration {
    static func starterPlacements(count: Int) -> [(HomesteadKind, String, HomesteadCell)] {
        var result: [(HomesteadKind, String, HomesteadCell)] = []
        if count >= 1 { result.append((.cottage, "base:cottage", .init(x: 3, z: 2))) }
        if count >= 2 { result.append((.tree, "base:tree", .init(x: 12, z: 2))) }
        if count >= 3 {
            result.append((.garden, "base:garden", .init(x: 2, z: 10)))
            for z in 5...10 { result.append((.path, "base:path:5:\(z)", .init(x: 5, z: z))) }
            for x in 6...10 { result.append((.path, "base:path:\(x):6", .init(x: x, z: 6))) }
        }
        return result
    }
    static func initialCell(_ project: LivingWorldProject, alternate: Bool) -> HomesteadCell {
        switch project {
        case .pond: return .init(x: alternate ? 7 : 11, z: alternate ? 8 : 7)
        case .nook: return .init(x: 1, z: alternate ? 12 : 6)
        case .treehouse: return .init(x: alternate ? 13 : 12, z: alternate ? 11 : 3)
        }
    }
    static func baseline(for kid: Child, previewStarterCount: Int? = nil) throws -> HomesteadBaseline {
        let originals = kid.worldPlacements.filter { !$0.isDeleted && !HomesteadConflict.isRuntimeRecord($0.discoveryID) }.map {
            HomesteadLegacyPlacement(id: $0.id, discoveryID: $0.discoveryID, zoneRaw: $0.zoneRaw,
                                     boardX: $0.boardX, boardY: $0.boardY, placedAt: $0.placedAt)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        var source = try encoder.encode(originals)
        source.append(Data(kid.characterID.utf8))
        var objects: [HomesteadObject] = []
        var issues: [HomesteadMigrationIssue] = []
        func insert(_ kind: HomesteadKind, key: String, cell: HomesteadCell, style: Int = 0, sourceID: UUID? = nil) {
            var item = HomesteadObject(id: HomesteadIdentity.stable(childID: kid.id, key: key), kind: kind,
                                      cell: cell, rotation: 0, style: style, sourceID: sourceID)
            if !HomesteadGeometry.canPlace(item, among: objects, land: []) {
                item.cell = HomesteadGeometry.nearestPlacement(for: item, among: objects, land: [])
                issues.append(.init(sourceID: sourceID, reason: item.cell == nil ? "inventory-only-no-free-space" : "relocated-to-free-cell", original: key))
            }
            objects.append(item)
        }
        // A draft count is used only for the unsaved placement preview.
        let starterCount = previewStarterCount ?? LivingWorldStarter(kid: kid).count
        for (kind, key, cell) in starterPlacements(count: starterCount) {
            insert(kind, key: key, cell: cell)
        }
        let wins = EconomyLedger.forChild(kid).approvedWins
        source.append(try encoder.encode(wins))
        let state = LivingWorldProjects(kid: kid, approvedWins: wins)
        for project in state.built.sorted(by: { $0.rawValue < $1.rawValue }) {
            let kind = HomesteadKind(rawValue: project.rawValue)!
            let alternate = state.spot(project) == .alternate
            let cell = initialCell(project, alternate: alternate)
            insert(kind, key: "project:\(project.rawValue)", cell: cell, style: state.style(project))
        }
        if wins >= 21 {
            for (index, cell) in [HomesteadCell(x: 10, z: 7), .init(x: 10, z: 8), .init(x: 10, z: 9)].enumerated() {
                insert(.flowers, key: "growth:wildflowers:\(index)", cell: cell)
            }
        }
        source.append(try encoder.encode(objects))
        var legacyKinds: [String: HomesteadKind] = ["flower": .flowers, "bench": .bench, "tree": .tree, "cottage": .cottage, "treehouse": .treehouse]
        #if DEBUG
        // Test-only inventory cannot be recognized in a family's real store.
        if WorldSandboxSession.isSandbox(kid) {
            for kind in WorldSandboxSession.decorations {
                legacyKinds[WorldSandboxSession.decorationPrefix + kind.rawValue] = kind
            }
        }
        #endif
        for row in originals where !row.discoveryID.hasPrefix(LivingWorldProjectEvent.prefix) && SpendingReviewAdjustment.decode(row.discoveryID) == nil && !row.discoveryID.hasPrefix(LivingWorldExpansion.ownershipPrefix) {
            guard let kind = legacyKinds[row.discoveryID] else {
                // Unknown and retired discovery IDs stay stored and visible in the migration report/inventory.
                issues.append(.init(sourceID: row.id, reason: "no-3d-model-yet", original: row.discoveryID)); continue
            }
            let zone = WorldZone(rawValue: row.zoneRaw)
            let fallback = zone?.defaultBoardPoint ?? CGPoint(x: 0.5, y: 0.5)
            let valid = row.boardX?.isFinite != false && row.boardY?.isFinite != false
            let x = row.boardX?.isFinite == false ? fallback.x : min(1, max(0, row.boardX ?? fallback.x))
            let z = row.boardY?.isFinite == false ? fallback.y : min(1, max(0, row.boardY ?? fallback.y))
            if zone == nil { issues.append(.init(sourceID: row.id, reason: "unknown-original-zone-preserved", original: row.zoneRaw)) }
            if [row.boardX, row.boardY].compactMap({ $0 }).contains(where: { $0.isFinite && !(0...1).contains($0) }) {
                issues.append(.init(sourceID: row.id, reason: "original-coordinate-clamped-for-layout", original: row.discoveryID))
            }
            if !valid { issues.append(.init(sourceID: row.id, reason: "invalid-original-coordinate-preserved", original: row.discoveryID)) }
            insert(kind, key: "legacy:\(row.id)", cell: .init(x: Int((x * 17).rounded()), z: Int((z * 15).rounded())), sourceID: row.id)
        }
        if KidAppearance(characterID: kid.characterID) == nil && KidCharacter(rawValue: kid.characterID) == nil {
            issues.append(.init(sourceID: nil, reason: "unknown-character-identity-preserved", original: kid.characterID))
        }
        return .init(version: 1, sourceDigest: HomesteadIdentity.digest(source), originalCharacterID: kid.characterID,
                     originalPlacements: originals, objects: objects, issues: issues)
    }
}
