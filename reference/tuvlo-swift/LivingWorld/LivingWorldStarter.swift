import Foundation
import SwiftData

/// Eligibility is part of the child snapshot, not inferred from wins or missing
/// placements. nil is a pre-chapter child, whose existing homestead stays owned.
struct LivingWorldStarter {
    enum Event: CaseIterable {
        case enrolled, cottage, tree, path, introduced
        var rawValue: String { LivingWorldStarter.prefix + name }
        private var name: String {
            switch self {
            case .enrolled: return "enrolled"
            case .cottage: return "cottage"
            case .tree: return "tree"
            case .path: return "path"
            case .introduced: return "introduced"
            }
        }
    }
    static let prefix = "living-world:v1:starter:"
    let isEligible: Bool
    let events: Set<String>
    init(kid: Child) {
        isEligible = kid.worldStarterVersion == 1
        events = Set(kid.worldPlacements.filter { !$0.isDeleted }.map(\.discoveryID))
    }
    var isLoading: Bool { isEligible && !events.contains(Event.enrolled.rawValue) }
    var count: Int {
        guard isEligible else { return 3 }
        guard !isLoading else { return 0 }
        return [Event.cottage, .tree, .path].prefix { events.contains($0.rawValue) }.count
    }
    var introduced: Bool { !isEligible || events.contains(Event.introduced.rawValue) }
    var needsGuide: Bool { isEligible && !isLoading && (count < 3 || !introduced) }

    /// Legacy data must never turn a known tutorial child back into an old child.
    /// Explicit 0 is reserved for deduplication with an older, fully owned world.
    static func mergingVersion(current: Int?, incoming: Int?) -> Int? {
        if current == 0 || incoming == 0 { return 0 }
        if current == 1 || incoming == 1 { return 1 }
        return current
    }
}

@MainActor
enum LivingWorldStarterActions {
    enum Failure: LocalizedError {
        case access, missingChild, notReady
        var errorDescription: String? {
            switch self {
            case .access: return "Your World is safe. Ask your parent to check access before making changes."
            case .missingChild: return "Return and choose your profile again."
            case .notReady: return "Your World is still getting ready. Please try again."
            }
        }
    }

    /// Called only by local child creation, in the same save as the new child.
    /// Remote import deliberately does not call this.
    @discardableResult
    static func enroll(_ kid: Child, in context: ModelContext) -> WorldPlacement {
        kid.worldStarterVersion = 1
        return insert(.enrolled, kid: kid, context: context)
    }

    @discardableResult
    static func advance(_ event: LivingWorldStarter.Event, kid: Child, context: ModelContext,
                        allowsChanges: (() -> Bool)? = nil,
                        save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard allowsChanges?() ?? (DeviceLinkStorage.role == .kid ? KidParentAccess.shared.allowsRequests : AppAccess.allowsChanges) else { throw Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw Failure.missingChild }
        let state = LivingWorldStarter(kid: kid)
        guard state.isEligible, !state.isLoading else { throw Failure.notReady }
        if state.events.contains(event.rawValue) { return false }
        let expected: LivingWorldStarter.Event = [.cottage, .tree, .path, .introduced][state.count]
        guard event == expected else { throw Failure.notReady }
        let row = insert(event, kid: kid, context: context)
        do { try save(context) }
        catch { row.child = nil; context.delete(row); throw error }
        return true
    }

    private static func insert(_ event: LivingWorldStarter.Event, kid: Child, context: ModelContext) -> WorldPlacement {
        let row = WorldPlacement(discoveryID: event.rawValue, zone: .village)
        context.insert(row); row.child = kid
        return row
    }
}
