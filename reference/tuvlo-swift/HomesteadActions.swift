import Foundation
import SwiftData

@MainActor
enum HomesteadActions {
    enum Failure: LocalizedError {
        case access, missingChild, invalid, conflict, notOwned, blocked, expansionUndecided
        var errorDescription: String? {
            switch self {
            case .access: return "Your world is safe. Ask your parent to check access before making changes."
            case .missingChild: return "Return and choose your profile again."
            case .invalid, .conflict: return "Your world changed. Check it and try again."
            case .notOwned: return "Earn or choose this place before arranging it."
            case .blocked: return "Choose a clear spot with a path to your places."
            case .expansionUndecided: return "More land is coming soon. Keep growing through missions."
            }
        }
    }
    /// The free chapter step and its chosen location commit together. Cancelling
    /// the scene preview owns nothing; a failed save removes only these rows.
    static func placeStarter(_ event: LivingWorldStarter.Event, object: HomesteadObject,
                             commandID: UUID, kid: Child, in context: ModelContext,
                             allowsChanges: (() -> Bool)? = nil,
                             save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard let key = event.homesteadObjectKey,
              object.id == HomesteadIdentity.stable(childID: kid.id, key: key) else { throw Failure.invalid }
        let starter = LivingWorldStarter(kid: kid)
        if starter.events.contains(event.rawValue) {
            try apply(.arrange(object), commandID: commandID, kid: kid, in: context,
                      allowsChanges: allowsChanges, save: save)
            return
        }
        let current = try state(for: kid)
        let ownedIDs = Set(current.objects.map(\.id))
        let draft = try HomesteadProjection(kid: kid, reducedMotion: true, starterPreview: event)
        var additions = draft.items.filter { !ownedIDs.contains($0.id) }
        guard let index = additions.firstIndex(where: { $0.id == object.id }),
              additions[index].kind == object.kind, additions[index].style == object.style,
              additions[index].sourceID == object.sourceID else { throw Failure.invalid }
        additions[index] = object
        let final = current.objects + additions
        guard additions.allSatisfy({ HomesteadGeometry.canPlace($0, among: final, land: current.land) }),
              HomesteadNavigationRules.hasUsableRoutes(objects: final, land: current.land) else { throw Failure.blocked }
        try LivingWorldStarterActions.advance(event, kid: kid, context: context,
            allowsChanges: allowsChanges, save: { context in
                var inserted: [WorldPlacement] = []
                let date = max(Date(), (saved(for: kid).map(\.date).max() ?? .distantPast).addingTimeInterval(0.001))
                do {
                    for (offset, piece) in additions.enumerated() {
                        let identity = piece.id == object.id ? commandID : HomesteadIdentity.stable(childID: kid.id, key: "starter-placement:\(commandID):\(piece.id)")
                        let event = HomesteadEvent(childID: kid.id, commandID: identity, change: .arrange(piece))
                        let raw = try event.encoded()
                        if let existing = kid.worldPlacements.first(where: { !$0.isDeleted && $0.id == event.recordID }) {
                            guard existing.discoveryID == raw else { throw Failure.conflict }
                            continue
                        }
                        let row = WorldPlacement(discoveryID: raw, zone: .village,
                                                 placedAt: date.addingTimeInterval(Double(offset) * 0.001))
                        row.id = event.recordID; context.insert(row); row.child = kid; inserted.append(row)
                    }
                    try save(context)
                } catch {
                    for row in inserted { row.child = nil; context.delete(row) }
                    throw error
                }
            })
    }

    static func saved(for kid: Child) -> [HomesteadSavedEvent] {
        kid.worldPlacements.compactMap { row in
            guard !row.isDeleted, let event = HomesteadEvent.decode(row.discoveryID),
                  event.childID == kid.id, event.recordID == row.id else { return nil }
            return .init(id: row.id, date: row.placedAt, event: event)
        }
    }
    static func state(for kid: Child) throws -> HomesteadState {
        let canonical = try HomesteadMigration.baseline(for: kid)
        var objects = canonical.objects
        for item in LivingWorldExpansion.allCases where item.kind != nil && item.isOwned(by: kid) {
            objects.append(item.ownedObject(for: kid))
        }
        let land: Set<HomesteadLand> = LivingWorldExpansion.ownedLand(for: kid)
        return HomesteadState(childID: kid.id, saved: saved(for: kid),
                              canonicalObjects: objects, allowsExpansion: false, canonicalLand: land)
    }
    static func saveCharacter(_ appearance: KidAppearance, kid: Child, in context: ModelContext,
                              allowsChanges: (() -> Bool)? = nil,
                              save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard allowsChanges?() ?? permitsChanges() else { throw Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw Failure.missingChild }
        try KidCharacterActions.save(appearance.characterID, for: kid) { try save(context) }
    }
    static func permitsChanges() -> Bool {
        DeviceLinkStorage.role == .kid ? KidParentAccess.shared.allowsRequests : AppAccess.allowsChanges
    }
    @discardableResult
    static func ensureMigration(for kid: Child, in context: ModelContext,
                                allowsChanges: (() -> Bool)? = nil,
                                save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        if saved(for: kid).contains(where: { if case .migration = $0.event.change { return true }; return false }) { return false }
        let base = try HomesteadMigration.baseline(for: kid)
        return try apply(.migration(base), commandID: HomesteadIdentity.stable(childID: kid.id, key: "migration:1:\(base.sourceDigest)"),
                         kid: kid, in: context, allowsChanges: allowsChanges, save: save)
    }
    /// Commands are retried with their original identity. No scene can write a
    /// payment, approve a mission, grant inventory or alter earned progression.
    @discardableResult
    static func apply(_ change: HomesteadChange, commandID: UUID, kid: Child, in context: ModelContext,
                      now: Date = Date(), allowsChanges: (() -> Bool)? = nil,
                      save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard allowsChanges?() ?? permitsChanges() else { throw Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw Failure.missingChild }
        let event = HomesteadEvent(childID: kid.id, commandID: commandID, change: change)
        guard event.isValid else { throw Failure.invalid }
        let raw = try event.encoded()
        if let existing = kid.worldPlacements.first(where: { !$0.isDeleted && $0.id == event.recordID }) {
            guard existing.discoveryID == raw else { throw Failure.conflict }
            return false
        }
        let current = try state(for: kid)
        switch change {
        case .arrange(let object):
            guard object.landGridVersion == 2 else { throw Failure.invalid }
            guard let owned = current.objects.first(where: { $0.id == object.id }),
                  owned.kind == object.kind, owned.sourceID == object.sourceID, owned.style == object.style else { throw Failure.notOwned }
            guard HomesteadGeometry.canPlace(object, among: current.objects, land: current.land) else { throw Failure.blocked }
            let arranged = current.objects.map { $0.id == object.id ? object : $0 }
            guard HomesteadNavigationRules.hasUsableRoutes(objects: arranged, land: current.land) else { throw Failure.blocked }
        case .remove(let id):
            guard current.objects.contains(where: { $0.id == id }) else { throw Failure.notOwned }
        case .windmillLook:
            guard LivingWorldExpansion.windmill.isOwned(by: kid) else { throw Failure.notOwned }
        case .orchardVariety:
            guard LivingWorldExpansion.orchard.isOwned(by: kid) else { throw Failure.notOwned }
        case .appearance(let look):
            guard look.characterID == kid.characterID else { throw Failure.conflict }
        case .expand: throw Failure.expansionUndecided
        case .discovery:
            guard HomesteadGeometry.hasDuckHabitat(current.objects) else { throw Failure.invalid }
            if current.discovered { return false }
        case .migration:
            let expected = HomesteadEvent(childID: kid.id, commandID: commandID,
                                          change: .migration(try HomesteadMigration.baseline(for: kid)))
            guard current.baseline == nil, raw == (try expected.encoded()) else { throw Failure.conflict }
        }
        let date = max(now, (saved(for: kid).map(\.date).max() ?? .distantPast).addingTimeInterval(0.001))
        let row = WorldPlacement(discoveryID: raw, zone: .village, placedAt: date)
        row.id = event.recordID
        // Insert before linking: linking an unmanaged row first can register it twice.
        context.insert(row); row.child = kid
        do { try save(context) }
        catch { row.child = nil; context.delete(row); throw error }
        return true
    }
}

// Stable original keys retain compatibility with every already-built world.
extension LivingWorldStarter.Event {
    var homesteadBuildCount: Int? {
        switch self { case .cottage: return 1; case .tree: return 2; case .path: return 3; default: return nil }
    }
    var homesteadObjectKey: String? {
        switch self {
        case .cottage: return "base:cottage"
        case .tree: return "base:tree"
        case .path: return "base:path:5:5"
        default: return nil
        }
    }
}
