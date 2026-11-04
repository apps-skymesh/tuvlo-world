import SwiftUI
import SwiftData

/// The existing Tuvlo journey and atomic spending service remain authoritative.
struct HomesteadProjectPanel: View {
    let kid: Child
    let project: LivingWorldProject
    let missions: () -> Void
    var resolveRequirement: (() -> Void)? = nil
    var resolveMaterial: ((HomesteadMaterial) -> Void)? = nil
    let finished: () -> Void
    let visit: () -> Void
    var close: () -> Void = {}
    var back: () -> Void = {}
    var committed: (HomesteadBuildTarget, String) -> Void = { _, _ in }
    var showSite: (HomesteadKind) -> Void = { _ in }
    #if DEBUG
    var playground: WorldSandboxSession? = nil
    #endif
    private var demoAuthorization: (() -> Bool)? {
        #if DEBUG
        if let playground { return { playground.owns(kid, in: context) } }
        #endif
        return nil
    }
    private var allowsChanges: Bool { demoAuthorization?() ?? HomesteadActions.permitsChanges() }
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var textSize
    @ObservedObject private var parentAccess = KidParentAccess.shared
    @Query private var rows: [WorldPlacement]
    let preview: (Int) -> Void
    let busyChanged: (Bool) -> Void
    @State private var style: Int?
    @State private var busy = false
    @State private var error: String?
    private var state: LivingWorldProjects {
        _ = rows.count
        return .init(kid: kid, approvedWins: EconomyLedger.forChild(kid).approvedWins)
    }
    private var materials: HomesteadMaterialLedger {
        _ = rows.count
        return .init(kid: kid)
    }
    private var canBuild: Bool {
        guard materials.canAfford(.project(project)) else { return false }
        #if DEBUG
        if let playground { return playground.canBuild(.project(project)) }
        #endif
        return state.canBuild(project)
    }
    private var buildRequirement: String? {
        #if DEBUG
        if let playground { return playground.requirement(for: .project(project)) }
        #endif
        return nil
    }
    var body: some View {
        let current = state
        if current.isBuilt(project) {
            WorldPlacePage(title: project.worldKind.title, icon: project.worldKind.controlIcon, needsTitle: "Place", recipeTitle: "Visit", back: back, close: close) {
                HomesteadRequirementChip(title: "Owned", icon: "house.fill", state: .ready) {}
            } recipe: {
                HomesteadActionButton(title: "Open", icon: project.worldKind.controlIcon, action: visit)
            } hero: {
                HomesteadShelfArtwork(asset: "WorldPlace_" + project.worldKind.rawValue, active: false, affordable: true)
                    .environment(\.worldPictureTiles, true).frame(maxWidth: 220, maxHeight: 220)
            }
        } else {
        WorldBuildConfirmation(title: project.worldKind.title, icon: project.worldKind.controlIcon,
            asset: "WorldPlace_" + project.worldKind.rawValue, price: project.price, currency: current.currency,
            ready: canBuild, allowsChanges: allowsChanges, busy: busy,
            actionTitle: current.hasPendingPurchase(project) ? "Retry build" : "Build",
            plannedSeconds: HomesteadTimePresentation.plannedBuild(.project(project), kid: kid, currency: current.currency),
            error: error ?? buildRequirement, failure: error, identifier: "homestead.project.confirm", back: back, close: close,
            confirm: { purchase(currency: current.currency) }, resolve: resolveRequirement) {
                WorldBuildNeeds(wins: current.approvedWins, requiredWins: project.requiredWins,
                    food: materials.balance.food, requiredFood: HomesteadBuildTarget.project(project).materials.food,
                    chapterComplete: LivingWorldStarter(kid: kid).count == 3, allowsChanges: allowsChanges,
                    missions: missions, meals: { resolveMaterial?(.food) }, chapter: { resolveRequirement?() }, land: { resolveRequirement?() })
            }.onAppear { preview(current.style(project)) }
        }
    }
    private func purchase(currency: RewardCurrency) {
        guard !busy else { return }
        if HomesteadConstruction.duration(for: project.worldKind) != nil,
           let site = HomesteadConstruction.pending(kid: kid).first {
            showSite(site.kind)
            return
        }
        error = nil; busy = true; busyChanged(true)
        Task {
            defer { busy = false; busyChanged(false) }
            do {
                #if DEBUG
                if let playground {
                    guard playground.owns(kid, in: context) else { throw HomesteadActions.Failure.access }
                    try playground.build(project, timedConstruction: true)
                    try HomesteadMaterialActions.recordUse(for: .project(project), kid: kid, in: context)
                    committed(.project(project), "playground:" + kid.id.uuidString + ":" + project.rawValue)
                    finished()
                    return
                }
                #endif
                if !state.hasPendingPurchase(project) {
                    try HomesteadMaterialActions.requireMaterials(for: .project(project), kid: kid)
                }
                let request = try OnlineSpending.requestWorld(project, style: state.style(project), currency: currency, kid: kid, in: context, timedConstruction: true)
                try await OnlineSpending.approve(request, in: context, giveNow: true)
                // The receipt is committed; materials follow under the place's identity.
                try HomesteadMaterialActions.recordUse(for: .project(project), kid: kid, in: context)
                // The service has committed its frozen receipt before any reveal.
                committed(.project(project), request.id.uuidString)
                finished()
            } catch { self.error = OnlineSpending.worldPurchaseMessage(for: error) }
        }
    }
}
