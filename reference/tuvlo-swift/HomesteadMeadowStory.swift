import Foundation
import SwiftData

/// Creative story progress, separate from inventory, missions and currency.
struct HomesteadMeadowStory {
    enum Step: String, CaseIterable {
        case gather, craft, bake, share
        var kind: HomesteadKind {
            switch self { case .gather: return .orchard; case .craft: return .workshop; case .bake: return .cottage; case .share: return .garden }
        }
        var title: String {
            switch self { case .gather: return "Pick a little fruit"; case .craft: return "Fold your basket"; case .bake: return "Bake a little tart"; case .share: return "Set the picnic" }
        }
        var verb: String {
            switch self { case .gather: return "Pick"; case .craft: return "Make"; case .bake: return "Bake"; case .share: return "Share" }
        }
        var rawRecord: String { HomesteadMeadowStory.prefix + rawValue }
        func recordID(childID: UUID) -> UUID { HomesteadIdentity.stable(childID: childID, key: rawRecord) }
    }
    static let prefix = "living-world:v1:story:meadow-table:"
    let completed: Set<Step>
    init(kid: Child) {
        completed = Set(Step.allCases.filter { step in
            kid.worldPlacements.contains { !$0.isDeleted && $0.discoveryID == step.rawRecord && $0.id == step.recordID(childID: kid.id) }
        })
    }
    var count: Int { Step.allCases.prefix { completed.contains($0) }.count }
    var next: Step? { Step.allCases.dropFirst(count).first }
    static func hasPlace(_ step: Step, kid: Child) throws -> Bool {
        // Stored pieces remain owned; arranging one again is always free.
        try HomesteadActions.state(for: kid).objects.contains { $0.kind == step.kind && $0.isPlaced }
    }
}

@MainActor
enum HomesteadMeadowStoryActions {
    @discardableResult
    static func complete(_ step: HomesteadMeadowStory.Step, kid: Child, in context: ModelContext,
                         allowsChanges: (() -> Bool)? = nil,
                         save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard allowsChanges?() ?? HomesteadActions.permitsChanges() else { throw HomesteadActions.Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw HomesteadActions.Failure.missingChild }
        let state = HomesteadMeadowStory(kid: kid)
        if state.completed.contains(step) { return false }
        let starter = LivingWorldStarter(kid: kid)
        guard !starter.isLoading, starter.count == 3, starter.introduced, state.next == step else { throw HomesteadActions.Failure.invalid }
        guard try HomesteadMeadowStory.hasPlace(step, kid: kid) else { throw HomesteadActions.Failure.notOwned }
        let row = WorldPlacement(discoveryID: step.rawRecord, zone: .village)
        row.id = step.recordID(childID: kid.id); context.insert(row); row.child = kid
        do { try save(context) }
        catch { row.child = nil; context.delete(row); throw error }
        return true
    }
}
