import CloudKit
import SwiftData

/// Fixed, single-input recipe chains use shared ordinal identities. The nth
/// mill/bake/pack is the same operation on every device, even while offline.
@MainActor
enum HomesteadOfflineOpening {
    static func perform(_ action: HomesteadOpeningEvent.Action, expected: Int, roundLoaf: Bool,
                        kid: Child, in context: ModelContext, now: Date, access: () -> Bool,
                        save: (ModelContext) throws -> Void) throws {
        typealias Failure = HomesteadOpeningActions.Failure
        guard access(), kid.modelContext === context, !kid.isDeleted,
              !FamilyDataDeletion.hasPendingLocalCleanup else { throw Failure.access }
        if context.hasChanges { try save(context) }
        guard !context.hasChanges else { throw SpendingConfirmation.Failure.localSave }
        let starter = LivingWorldStarter(kid: kid)
        guard starter.count == 3, starter.introduced else { throw Failure.place }
        if HomesteadFarmJournal(kid: kid).started {
            guard action == .begin else { throw Failure.changed }
            return
        }
        let state = HomesteadOpeningLedger(kid: kid)
        guard state.valid else { throw Failure.changed }
        if action == .begin, state.started { return }
        guard state.nextSequence == expected else { throw Failure.changed }
        guard state.started || action == .begin else { throw Failure.changed }
        for win in kid.completions {
            let history = try CompletionApprovalHistory.decode(win.approvalHistoryRaw, completionID: win.id)
            guard !history.needsResolution else { throw SpendingConfirmation.Failure.review }
        }
        let wins = EconomyLedger.forChild(kid).approvedWins
        let day = FamilyDay.key(for: now)
        let scene = try HomesteadActions.state(for: kid)
        func require(_ kind: HomesteadKind) throws {
            guard scene.objects.contains(where: { $0.kind == kind && $0.isPlaced }) else { throw Failure.place }
        }
        switch action {
        case .begin: break
        case .harvest:
            try require(.garden)
            guard state.ready(wins: wins, day: day) > 0 else { throw Failure.ingredients }
        case .mill:
            try require(.windmill)
            guard LivingWorldExpansion.windmill.isOwned(by: kid) else { throw Failure.place }
            guard state.wheat >= 2 else { throw Failure.ingredients }
        case .bake:
            try require(.cottage)
            guard state.flour >= 1 else { throw Failure.ingredients }
        case .pack:
            guard state.bread >= 1 else { throw Failure.ingredients }
        case .picnic:
            try require(.nook)
            guard LivingWorldProjects(kid: kid, approvedWins: wins).isBuilt(.nook) else { throw Failure.place }
            guard state.hasBaked else { throw Failure.ingredients }
            if state.picnic { return }
        }
        let old = HomesteadMaterialLedger(kid: kid, now: now)
        let legacyGarden = kid.worldStarterVersion != 1 || wins > 0 || old.through[.garden] != nil || old.found.contains(.garden)
        let transforms: [HomesteadOpeningEvent.Action] = [.mill, .bake, .pack]
        let unit = transforms.contains(action) ? state.completed(action) : 0
        let harvest = action == .begin || action == .harvest
        let event = HomesteadOpeningEvent(sequence: 0, action: action,
            wins: harvest ? wins : 0, day: harvest ? day : "1970-01-01",
            daily: action == .harvest || action == .begin && legacyGarden,
            roundLoaf: action == .bake && roundLoaf, offlineUnit: unit)
        let zone = CKRecordZone.ID(zoneName: "LocalWorldRecipe")
        func record(_ value: HomesteadMaterialRecord) -> CKRecord {
            HomesteadOpeningActions.record(raw: value.rawValue, id: value.recordID(childID: kid.id),
                child: kid.id, zone: zone, now: now)
        }
        var additions = [HomesteadOpeningActions.record(raw: try event.encoded(), id: event.id(child: kid.id),
            child: kid.id, zone: zone, now: now)]
        if action == .begin {
            // Preserve the previous producers' outstanding stock at activation;
            // their saved Food is never reinterpreted as new wheat.
            if legacyGarden && !old.found.contains(.garden) { additions.append(record(.find(.garden, day: day))) }
            let owned = Set(scene.objects.map(\.kind))
            for producer in [HomesteadProducer.garden, .pond, .windmill] {
                guard let kind = producer.kind, owned.contains(kind), wins > (old.through[producer] ?? 0) else { continue }
                additions.append(record(.collect(producer, through: wins)))
            }
        }
        try SpendingLocalCommit.apply(additions, in: context, save: save)
    }
}
