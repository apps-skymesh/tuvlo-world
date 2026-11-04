import CloudKit
import SwiftData

/// World purchases commit on the device. Sync transports the existing receipt;
/// it never runs the purchase again. Cash and Store rewards remain online-only.
@MainActor
enum WorldSpending {
    static func commit(_ claim: RewardClaim, in context: ModelContext, now: Date = Date(),
                       access: () -> Bool,
                       save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        guard access(), !FamilyDataDeletion.hasPendingLocalCleanup else { throw LivingWorldProjectActions.Failure.access }
        guard let kid = claim.child, kid.modelContext === context, !kid.isDeleted,
              claim.modelContext === context, !claim.isDeleted,
              var details = claim.storeDetails, let raw = details.worldProjectRaw else { throw SpendingConfirmation.Failure.changed }
        guard HomesteadConstruction.valid(details) else { throw SpendingConfirmation.Failure.changed }
        guard claim.status == .pending || claim.status == .approved else { throw SpendingConfirmation.Failure.changed }
        if context.hasChanges { try save(context) }
        guard !context.hasChanges else { throw SpendingConfirmation.Failure.localSave }

        // A receipt arriving through sync is also final. Repeating Build cannot
        // consume either currency or materials a second time.
        if let receipt = kid.payments.first(where: { $0.id == claim.id }) {
            guard let frozen = receipt.storeDetails, frozen.worldProjectRaw == raw,
                  !frozen.isCanceled else { throw SpendingConfirmation.Failure.changed }
            return
        }
        guard claim.status == .pending, details.claimID == claim.id else { throw SpendingConfirmation.Failure.changed }
        guard LivingWorldEconomy.currency(for: kid) == details.currency else { throw LivingWorldProjectActions.Failure.priceChanged }
        guard LivingWorldStarter(kid: kid).count == 3 else { throw LivingWorldProjectActions.Failure.notReady }
        for win in kid.completions {
            let history = try CompletionApprovalHistory.decode(win.approvalHistoryRaw, completionID: win.id)
            guard !history.needsResolution else { throw SpendingConfirmation.Failure.review }
        }

        let target: HomesteadBuildTarget
        let ownership: String
        if let project = LivingWorldProject(rawValue: raw) {
            let state = LivingWorldProjects(kid: kid, approvedWins: EconomyLedger.forChild(kid).approvedWins)
            guard !state.isBuilt(project) else { throw SpendingConfirmation.Failure.changed }
            target = .project(project)
            ownership = LivingWorldProjectEvent(project: project, action: .built, value: details.worldStyle ?? 0).rawValue
        } else if let item = LivingWorldExpansion(rawValue: raw) {
            guard !item.isOwned(by: kid), item.hasRequiredLand(for: kid) else { throw LivingWorldProjectActions.Failure.notReady }
            if item.kind != nil {
                guard let draft = LivingWorldExpansion.decodeObject(details.worldPlacementRaw, childID: kid.id, item: item) else { throw HomesteadActions.Failure.invalid }
                let state = try HomesteadActions.state(for: kid)
                let object = HomesteadGeometry.currentCoordinates(draft, land: state.land)
                guard HomesteadGeometry.canPlace(object, among: state.objects, land: state.land),
                      HomesteadNavigationRules.hasUsableRoutes(objects: state.objects + [object], land: state.land) else { throw HomesteadActions.Failure.blocked }
            } else if details.worldPlacementRaw != nil { throw HomesteadActions.Failure.invalid }
            target = .expansion(item)
            ownership = item.ownershipRaw
        } else { throw SpendingConfirmation.Failure.invalid }

        let ledger = EconomyLedger.forChild(kid)
        guard details.coins.isFinite, details.coins == target.price, details.quantity == 1 else { throw LivingWorldProjectActions.Failure.priceChanged }
        guard ledger.approvedWins >= target.requiredWins else { throw LivingWorldProjectActions.Failure.notReady }
        guard ledger.worldBalance(in: details.currency) >= target.price else { throw SpendingConfirmation.Failure.insufficient }
        try HomesteadMaterialActions.requireMaterials(for: target, kid: kid, now: now)

        // CKRecord is only the existing local-commit DTO here: no CloudKit API
        // is contacted. Receipt, claim, ownership and material use save together.
        let zone = CKRecordZone.ID(zoneName: "LocalWorldPurchase")
        details.deliveredAt = now; details.canceledAt = nil; details.updatedAt = now
        details.onlineConfirmed = nil
        let payment = Payment(amountDollars: 0, category: claim.category, paidAt: now)
        payment.id = claim.id; payment.storeDetails = details
        let receipt = FamilyShareRecordCodec.encode(payment, zoneID: zone)
        receipt["childID"] = kid.id.uuidString as CKRecordValue
        let verdict = FamilyShareRecordCodec.encode(claim, zoneID: zone)
        verdict["statusRaw"] = RewardClaimStatus.approved.rawValue as CKRecordValue
        verdict["storeDetailsRaw"] = details.encoded as CKRecordValue?
        verdict["kidAcknowledged"] = 1 as CKRecordValue
        verdict["parentNote"] = "" as CKRecordValue
        var rows = [receipt, verdict, HomesteadOpeningActions.record(raw: ownership, id: claim.id,
            child: kid.id, zone: zone, now: now)]
        let use = HomesteadMaterialRecord.use(target: target.key, target.materials)
        rows.append(HomesteadOpeningActions.record(raw: use.rawValue, id: use.recordID(childID: kid.id),
            child: kid.id, zone: zone, now: now))
        try SpendingLocalCommit.apply(rows, in: context, save: save)
    }
}
