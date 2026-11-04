import Foundation
import SwiftData

/// Creative story progress, separate from inventory, missions and currency.
struct HomesteadBreadStory {
    enum Step: String, CaseIterable {
        case grow, mill, bake, share
        var kind: HomesteadKind {
            switch self { case .grow: return .garden; case .mill: return .windmill; case .bake: return .cottage; case .share: return .garden }
        }
        var title: String {
            switch self { case .grow: return "A little wheat"; case .mill: return "Turn grain into flour"; case .bake: return "Your own warm loaf"; case .share: return "A table to share" }
        }
        var verb: String {
            switch self { case .grow: return "Grow"; case .mill: return "Mill"; case .bake: return "Bake"; case .share: return "Share" }
        }
        var rawRecord: String { HomesteadBreadStory.prefix + rawValue }
        func recordID(childID: UUID) -> UUID { HomesteadIdentity.stable(childID: childID, key: rawRecord) }
    }
    static let prefix = "living-world:v1:story:field-to-flour:"
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
enum HomesteadBreadStoryActions {
    @discardableResult
    static func complete(_ step: HomesteadBreadStory.Step, kid: Child, in context: ModelContext,
                         allowsChanges: (() -> Bool)? = nil,
                         save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard allowsChanges?() ?? HomesteadActions.permitsChanges() else { throw HomesteadActions.Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw HomesteadActions.Failure.missingChild }
        let state = HomesteadBreadStory(kid: kid)
        if state.completed.contains(step) { return false }
        let starter = LivingWorldStarter(kid: kid)
        guard !starter.isLoading, starter.count == 3, starter.introduced, state.next == step else { throw HomesteadActions.Failure.invalid }
        guard try HomesteadBreadStory.hasPlace(step, kid: kid) else { throw HomesteadActions.Failure.notOwned }
        let row = WorldPlacement(discoveryID: step.rawRecord, zone: .village)
        row.id = step.recordID(childID: kid.id); context.insert(row); row.child = kid
        do { try save(context) }
        catch { row.child = nil; context.delete(row); throw error }
        return true
    }
}
