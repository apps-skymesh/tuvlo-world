import SwiftUI
import SwiftData
import UIKit

struct KidWorldDestination: View {
    let kid: Child
    var isVisible = true
    var onMissions: () -> Void = {}
    var onExit: () -> Void = {}
    var projectRequest: WorldBuildRequest?
    var onProjectHandled: () -> Void = {}
    var body: some View {
        TuvloWorldEntry(isVisible: isVisible, onTasks: onMissions, nativeRecoveryReady: LivingWorldStarter(kid: kid).isLoading) { worldVisible, entryReady, returnToTuvlo in
            KidHomesteadWorldView(kid: kid, isVisible: worldVisible, onMissions: returnToTuvlo, projectRequest: projectRequest,
                onProjectHandled: onProjectHandled, entryReady: entryReady)
        }
    }
}

enum HomesteadVisitMotion {
    /// A recipe sheet stays in the clearing. Build, missions, and settings still hold the yard.
    static func keepsMoving(playable: Bool, exitRequested: Bool, panelOpen: Bool, recipeSheetOnly: Bool) -> Bool {
        playable && !exitRequested && (!panelOpen || recipeSheetOnly)
    }
}

struct KidHomesteadWorldView: View {
    let kid: Child
    let isVisible: Bool
    let onMissions: () -> Void
    let projectRequest: WorldBuildRequest?
    let onProjectHandled: () -> Void
    var entryReady: Binding<Bool>? = nil
    #if DEBUG
    var playground: WorldSandboxSession? = nil
    var resetPlayground: ((Bool) -> Void)? = nil
    var startFromBeginning: (() -> Void)? = nil
    #endif
    private var demoAuthorization: (() -> Bool)? {
        #if DEBUG
        if let playground { return { playground.owns(kid, in: context) } }
        #endif
        return nil
    }
    private var sequentialPlayground: Bool {
        #if DEBUG
        return playground != nil
        #else
        return false
        #endif
    }
    private var farm: HomesteadFarm? {
        #if DEBUG
        if let playground { return playground.farm }
        #endif
        return normalFarm
    }
    @State private var normalFarm = HomesteadFarm()
    @State private var farmStation = HomesteadFarm.Station.field
    @State private var menuSession = WorldMenuSession()
    private struct RecipeReturn { let station: HomesteadFarm.Station; let recipe: HomesteadFarm.Recipe }
    @State private var recipeFromWarehouse = false
    @State private var recipeReturns: [RecipeReturn] = []
    @State private var warehouseOpen = false
    @State private var walletOpen = false
    @State private var farmMenu = false
    @State private var inspectionInsets = CGSize.zero
    @State private var placeOverview: UUID?
    @State private var worldCanvasFrame = CGRect.zero
    @State private var ovenRecipe = HomesteadFarm.Recipe.bread
    @State private var farmSceneKey = ""
    @State private var constructionKind: HomesteadKind?
    #if DEBUG
    @State private var injectedFarmFailure = false
    #endif
    @State private var workingBuilds = Set<HomesteadKind>()
    @State private var constructionClocks: [HomesteadConstruction] = []
    @State private var timeClock = HomesteadTimeClock()
    @State private var projectionDay = ""
    private func buildRequirement(_ project: LivingWorldProject) -> String? {
        #if DEBUG
        return playground?.requirement(for: .project(project))
        #else
        return nil
        #endif
    }
    private func buildRequirement(_ expansion: LivingWorldExpansion) -> String? {
        #if DEBUG
        return playground?.requirement(for: .expansion(expansion))
        #else
        return nil
        #endif
    }
    private func testDecorationRequirement(_ kind: HomesteadKind) -> String? {
        #if DEBUG
        return playground?.requirement(for: .decoration(kind))
        #else
        return nil
        #endif
    }
    private func buildTestDecoration(_ kind: HomesteadKind) {
        #if DEBUG
        guard let playground, playground.owns(kid, in: context) else { return }
        guard playground.canBuild(.decoration(kind)) else { assetDetails = .piece(kind); return }
        do {
            try playground.buildDecoration(kind)
            closePanel()
            Task {
                await refresh()
                if let object = projection?.items.first(where: { $0.kind == kind }) { selectCatalogueObject(object) }
            }
        } catch { self.error = error.localizedDescription }
        #endif
    }
    private var allowsChanges: Bool { demoAuthorization?() ?? HomesteadActions.permitsChanges() }
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Query private var placements: [WorldPlacement]
    @Query private var worldTasks: [TaskDefinition]
    @StateObject private var bridge = HomesteadRuntimeBridge()
    @ObservedObject private var parentAccess = KidParentAccess.shared
    @State private var projection: HomesteadProjection?
    @State private var missionGoal: LivingWorldProject?
    @State private var missionsOpen = false
    @State private var inventory = false
    @State private var assetDetails: HomesteadAssetSelection?
    @State private var shelfSelection: HomesteadAssetSelection?
    @State private var expansionChoice: LivingWorldExpansion?
    @State private var expansionQuote = false
    @State private var expansionCurrency: RewardCurrency?
    @State private var buildingDraft: HomesteadObject?
    @State private var workshopActivity = false
    @State private var greenhouseActivity = false
    @State private var orchardActivity = false
    @State private var openingOpen = false
    @State private var breadStoryOpen = false
    @State private var meadowStoryOpen = false
    @State private var catalogueSection = "build"
    @State private var shelfCategory: HomesteadShelfCategory?
    @State private var catalogueScrollVersion = 0
    @State private var catalogueKind: HomesteadKind?
    @State private var requestedProject: LivingWorldProject?
    @State private var extras = false
    @State private var look = false
    @State private var exitRequested = false
    @State private var worldMenu = false
    @State private var introductionDismissedFor: UUID?
    @State private var replayIntroduction = false
    private var introductionVisible: Bool {
        replayIntroduction || (introductionDismissedFor != kid.id && !sequentialPlayground && !KidIntroductionMemory.shared.hasSeen(.world, childID: kid.id))
    }
    private func finishIntroduction() {
        introductionDismissedFor = kid.id; replayIntroduction = false
        updateBridge(); openRequestedProject(); claimCheckIn()
    }
    @State private var settingsOpen = false
    @State private var checkInOpen = false
    @State private var sandboxTools = false
    @State private var projectBusy = false
    @State private var previewLook: KidAppearance?
    @State private var previewExtras: HomesteadAppearanceExtras?
    @State private var previewStyle = 0
    @State private var musicOwner = UUID()
    @AppStorage(SoundEffects.enabledKey) private var soundsEnabled = true
    @AppStorage(AppAudioPreferences.effectsLevelKey) private var effectsLevel = 1.0
    @AppStorage(AppAudioPreferences.musicLevelKey) private var musicLevel = 1.0
    @AppStorage(WorldAudioPreferences.musicEnabledKey) private var musicEnabled = true
    @State private var starterPlacement: LivingWorldStarter.Event?
    @State private var selected: UUID?
    @State private var cameraBeforePlace: String?
    @State private var spotPreview: HomesteadCell?
    @State private var placementPage: HomesteadBuilderPage?
    @State private var placementFailure: String?
    @State private var previewValid = false
    @State private var previewRotation: Int?
    @State private var previewCell: HomesteadCell?
    @State private var hasEditedMap = false
    #if DEBUG
    @State private var injectedEntryFailure = false
    #endif
    @State private var error: String?
    @State private var camera = "arrival"
    @State private var focusedPlace: UUID?
    @State private var worldWindowSize = CGSize.zero
    /// Where the production card's ring sits on screen; the camera centres the live place there.
    @State private var productionRing = CGRect.zero
    /// The map's frame in `HomesteadWorldSpace`, the space cards report their ring in.
    @State private var sceneFrame = CGRect.zero
    private var hasLandscapeSpace: Bool {
        worldWindowSize.width >= 544 && worldWindowSize.width > worldWindowSize.height && (!placePageOpen || worldWindowSize.height >= 350)
    }
    @State private var accessHelpOpen = false
    @ObservedObject private var accessStore = PremiumStore.shared
    private var accessIssue: KidAccessIssue? { allowsChanges ? nil : KidAccessIssue.current }
    private var menuWalletHeight: CGFloat { HomesteadToolbeltGeometry.height + (accessIssue == nil ? 0 : 50) }
    @State private var recommendationPulsed = false
    @State private var activity = String(localized: "Exploring your homestead")

    @State private var tip: HomesteadTip?
    @State private var tipQueue: [HomesteadTip] = []
    @State private var collected: HomesteadMaterialAmounts?
    @State private var checkInBonus: WorldCheckInBonus.Grant?
    private var starter: LivingWorldStarter { .init(kid: kid) }
    private var showsChapter: Bool { starter.needsGuide }
    private var projects: LivingWorldProjects { .init(kid: kid, approvedWins: EconomyLedger.forChild(kid).approvedWins) }
    private var meadowStory: HomesteadMeadowStory {
        _ = placements.count
        return .init(kid: kid)
    }
    private var breadStory: HomesteadBreadStory {
        _ = placements.count
        return .init(kid: kid)
    }
    private var materials: HomesteadMaterialLedger {
        _ = placements.count
        return .init(kid: kid, objects: projection?.items, land: projection.map { Set($0.land.compactMap(HomesteadLand.init(rawValue:))) })
    }
    private var opening: HomesteadOpeningLedger { .init(kid: kid) }
    private var openingWheatReady: Int {
        opening.ready(wins: projects.approvedWins, day: FamilyDay.key(for: Date(), in: .current))
    }
    private var goal: HomesteadGoal? {
        let next: HomesteadBuildTarget? = opening.picnic ? (!projects.isBuilt(.treehouse) ? .project(.treehouse) : !LivingWorldExpansion.workshop.isOwned(by: kid) ? .expansion(.workshop) : nil) : nil
        return showsChapter || starter.isLoading ? nil : HomesteadGoal.next(kid: kid, ledger: materials, projects: projects, preferredTarget: next)
    }
    private var showsMaterials: Bool { !showsChapter && !starter.isLoading }
    private var panelOpen: Bool { introductionVisible || warehouseOpen || walletOpen || placeOverview != nil || farmMenu || placementPage != nil || shelfSelection != nil || checkInOpen || constructionKind != nil || openingOpen || breadStoryOpen || meadowStoryOpen || assetDetails != nil || missionsOpen || inventory || extras || look || worldMenu || settingsOpen || sandboxTools || expansionChoice != nil || workshopActivity || greenhouseActivity || orchardActivity || error != nil }
    private var focusedSurface: Bool { panelOpen || selected != nil || exitRequested || accessHelpOpen }
    /// Farm, oven, and orders are the visit. Other sheets still hold the people and the camera.
    private var recipeSheetOnly: Bool {
        guard farm != nil, openingOpen || breadStoryOpen || meadowStoryOpen else { return false }
        return shelfSelection == nil && constructionKind == nil && assetDetails == nil && !missionsOpen && !inventory && !extras && !look
            && !worldMenu && !settingsOpen && !checkInOpen && !sandboxTools && expansionChoice == nil
            && !workshopActivity && !greenhouseActivity && !orchardActivity && error == nil
    }
    private var placePageOpen: Bool {
        constructionKind != nil || shelfSelection != nil || placeOverview != nil || (farm != nil && (openingOpen || breadStoryOpen || meadowStoryOpen) && !farmMenu)
            || expansionChoice != nil || (inventory && requestedProject != nil)
    }
    /// Production cards show the place themselves, so only these pages borrow the map camera.
    private var mapPlacePageOpen: Bool { constructionKind != nil || placeOverview != nil }
    /// The open production card's station: its own place, framed at a fixed scale behind the card.
    private var productionFocusKey: String? {
        guard farm != nil, openingOpen || breadStoryOpen || meadowStoryOpen, !farmMenu, constructionKind == nil, placeOverview == nil else { return nil }
        return farmStation.rawValue
    }
    /// The dim clears in the middle whenever the map itself is the picture.
    private var mapPictureOpen: Bool { mapPlacePageOpen || (spotPreview != nil && shelfSelection != nil) }
    private var menuRoute: WorldMenuRoute? {
        guard panelOpen || selected != nil else { return nil }
        return .init(name: warehouseOpen ? "warehouse" : walletOpen ? "wallet" : settingsOpen ? "settings" : missionsOpen ? "missions" : placePageOpen ? "place." + (shelfSelection?.title ?? requestedProject?.rawValue ?? expansionChoice?.rawValue ?? placeOverview?.uuidString ?? constructionKind?.rawValue ?? farmStation.rawValue) : selected != nil ? "builder" : "journal",
                     window: warehouseOpen || walletOpen || settingsOpen || missionsOpen || error != nil)
    }
    private var active: Bool {
        HomesteadVisitMotion.keepsMoving(
            playable: !starter.isLoading && isVisible && hasLandscapeSpace && phase == .active && !accessHelpOpen,
            exitRequested: exitRequested, panelOpen: panelOpen, recipeSheetOnly: recipeSheetOnly)
    }
    // Music belongs to the visible visit, including menus and exit confirmation.
    private var worldAudioActive: Bool {
        isVisible && hasLandscapeSpace && phase == .active && bridge.status == .ready && soundsEnabled && musicEnabled
    }

    private var worldMusicTrack: WorldMusicTrack {
        if showsChapter { return .clearing }
        if openingOpen || orchardActivity || breadStoryOpen || meadowStoryOpen { return .clearing }
        if panelOpen || exitRequested { return .menu }
        return .upbeat
    }
    private func celebrateWorldMusic() {
        let owner = musicOwner
        Task { await OpeningMusic.sunshine.celebrateWorld(ownerID: owner) }
    }
    /// The first visit records the current wins and stays quiet. A later approval
    /// warms the light, and the child and any villager look up. It spends nothing.
    /// A visible visit after a 6-hour window, a new day or a 7-day streak saves
    /// its bonus first, then shows one chip. Repeats in the same window add nothing.
    private func claimCheckIn() {
        guard bridge.status == .ready, isVisible, hasLandscapeSpace, phase == .active,
              !starter.isLoading, !showsChapter, !exitRequested, !introductionVisible else { return }
        do {
            guard let grant = try WorldCheckInBonus.claim(kid: kid, in: context, allowsChanges: demoAuthorization) else { return }
            withAnimation(reducedMotion ? nil : .snappy) { checkInBonus = grant }
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.Announcement("Check-in bonus, \(grant.currency.amountLabel(grant.amount))").post()
            }
        } catch {
            // A failed save leaves nothing behind; the next visit tries again.
        }
    }
    private func noteSunnyDay() {
        guard bridge.status == .ready, isVisible, hasLandscapeSpace, phase == .active,
              !starter.isLoading, !exitRequested else { return }
        guard HomesteadSunnyDayMemory().claimSunrise(wins: projects.approvedWins, childID: kid.id) else { return }
        celebrateWorldMusic()
        bridge.send("sunrise", payload: [:])
        Haptics.selection()
    }
    /// The first visit records the current wins. Later approvals walk the child
    /// to the mission tree and water it once each. Reduce Motion grows the tree
    /// without the walk. Nothing is spent.
    private func noteTreeWatering() -> Bool {
        guard bridge.status == .ready, isVisible, hasLandscapeSpace, phase == .active,
              !starter.isLoading, !exitRequested else { return false }
        let count = HomesteadTreeWaterMemory().claim(wins: projects.approvedWins, childID: kid.id)
        guard count > 0 else { return false }
        if !reducedMotion { bridge.send("waterTree", payload: ["count": count]) }
        return true
    }
    /// A skipped family day yellows a few leaves. The next watering clears them.
    /// The trunk, earned growth, goods, and wins stay.
    private func noteTreeThirst(watering: Bool) {
        guard bridge.status == .ready, isVisible, hasLandscapeSpace, phase == .active,
              !starter.isLoading, !exitRequested else { return }
        let memory = HomesteadTreeThirstMemory()
        var yellow = memory.noteVisit(day: FamilyDay.key(for: Date()), childID: kid.id)
        if watering {
            memory.clear(childID: kid.id)
            yellow = false
        }
        bridge.send("treeLeaves", payload: ["yellow": yellow])
    }

    private var changeKey: String {
        // Sync can amend a receipt without changing its identity. Invalidate the
        // cached construction clocks for those amendments as well as new purchases.
        kid.characterID + ":\(kid.worldStarterVersion.map(String.init) ?? "legacy"):\(reducedMotion):\(EconomyLedger.forChild(kid).approvedWins):" +
        placements.filter { !$0.isDeleted && $0.child?.id == kid.id }.map { "\($0.id):\($0.discoveryID):\($0.placedAt.timeIntervalSince1970)" }.sorted().joined(separator: "|") +
        kid.payments.map { "\($0.id):\($0.paidAt.timeIntervalSince1970):\($0.isDeleted):\($0.storeDetailsRaw ?? "")" }.sorted().joined(separator: "|")
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    // Only the map extends beneath the cutout and home indicator.
                    // Native controls stay in the safe area and intercept their own taps.
                    worldScene
                        .opacity(starter.isLoading || projection == nil ? 0 : 1)
                        .allowsHitTesting(!starter.isLoading && !panelOpen)
                        .accessibilityHidden(panelOpen || exitRequested)
                        .ignoresSafeArea(.container)
                    if starter.isLoading {
                        chapterWaiting.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .padding(16).zIndex(1)
                    }
                    // Hidden/covered worlds retain their engine and data, but
                    // never retain a second accessible set of gameplay actions.
                    if isVisible && !panelOpen && !starter.isLoading {
                    VStack(spacing: 8) {
                        topHUD.padding(.horizontal, 12).accessibilityHidden(exitRequested)
                        if let checkInBonus, selected == nil {
                            WorldCheckInBanner(kid: kid, grant: checkInBonus) { self.checkInBonus = nil }
                                .transition(reducedMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                    }.padding(.top, 12).padding(.bottom, HomesteadToolbeltGeometry.dockHeight)
                    }
                    if isVisible && !panelOpen && !starter.isLoading, let selected,
                       let object = projection?.items.first(where: { $0.id == selected }) {
                        placementControls(object).accessibilityHidden(exitRequested)
                    }
                    if panelOpen {
                        ZStack(alignment: .topTrailing) {
                            Button(action: dismissMenu) {
                                Color.black.opacity(productionFocusKey != nil ? 0 : placePageOpen ? 0.30 : 0.20)
                                    .mask {
                                        if mapPictureOpen {
                                            RadialGradient(colors: [.clear, .black], center: UnitPoint(x: 0.5, y: 0.56),
                                                startRadius: worldWindowSize.height * 0.18, endRadius: worldWindowSize.height * 0.70)
                                        } else { Rectangle() }
                                    }.contentShape(Rectangle())
                            }.buttonStyle(.plain).ignoresSafeArea()
                                .disabled(projectBusy || error != nil || introductionVisible).accessibilityHidden(true)
                            overlayWindow.padding(.top, menuWalletHeight + 24)
                                .environment(\.worldMapShowsPlace, spotPreview != nil)
                                .padding(.bottom, 8).clipped().accessibilityHidden(exitRequested)
                            topHUD.allowsHitTesting(error == nil).accessibilityHidden(error != nil || exitRequested)
                            .background {
                                Button(action: dismissMenu) { Color.clear.contentShape(Rectangle()) }
                                    .buttonStyle(.plain).accessibilityHidden(true)
                            }
                            .padding(12)
                        }.accessibilityElement(children: .contain)
                    }

                    if isVisible && !starter.isLoading && !focusedSurface {
                        bottomPlaceButtons
                            .padding(.top, menuWalletHeight + 24).padding(.bottom, 8)
                            .padding(.horizontal, 12).allowsHitTesting(error == nil && !focusedSurface).accessibilityHidden(error != nil || focusedSurface).zIndex(3)
                    }
                }
                .overlayPreferenceValue(HomesteadTipAnchors.self) { anchors in
                    GeometryReader { area in
                        if canShowTip, let feedback = attachedTip, let anchor = anchors[feedback.control] {
                            HomesteadAttachedTip(tip: feedback, target: area[anchor], bounds: area.size, dismiss: dismissAttachedTip)
                        }
                    }
                }
                .overlayPreferenceValue(WorldMenuAnchors.self) { anchors in
                    GeometryReader { area in
                        let frames = anchors.mapValues { area[$0].offsetBy(dx: area.frame(in: .global).minX, dy: area.frame(in: .global).minY) }
                        Color.clear.onChange(of: frames, initial: true) { _, value in menuSession.updateFrames(value) }
                    }.allowsHitTesting(false)
                }
                .overlay { WorldSavedFlightLayer(session: menuSession) }
                .opacity(hasLandscapeSpace ? 1 : 0)
                .allowsHitTesting(hasLandscapeSpace)
                .accessibilityHidden(!hasLandscapeSpace || !isVisible)
                if !hasLandscapeSpace, isVisible {
                    VStack(spacing: 8) {
                        HStack { Spacer(minLength: 0); worldWallet.disabled(introductionVisible).frame(width: min(320, max(0, geometry.size.width - 24))) }
                            .allowsHitTesting(false).accessibilityHidden(true)
                        Spacer(minLength: 0)
                        Text(worldWindowSize.width > worldWindowSize.height ? "Expand this window" : "Turn to landscape")
                            .font(.headline).accessibilityAddTraits(.isHeader)
                        HStack(spacing: 12) {
                            if placePageOpen && worldWindowSize.width > worldWindowSize.height {
                                HomesteadActionButton(title: "Back to World", icon: "chevron.backward", action: closePanel)
                                    .disabled(projectBusy).accessibilityIdentifier("homestead.orientation.back")
                            }
                            HomesteadActionButton(title: "Leave", icon: "arrow.uturn.backward") { exitRequested = true }
                                .disabled(projectBusy).accessibilityIdentifier("homestead.orientation.exit")
                        }
                        Spacer(minLength: 0)
                    }.padding(12).accessibilityElement(children: .contain).accessibilityIdentifier("homestead.orientation.waiting")
                }
            }
            .onChange(of: geometry.size, initial: true) { _, size in
                worldWindowSize = size
            }
        }
        // One space for the map and the cards, inside any orientation transform.
        .coordinateSpace(name: HomesteadWorldSpace.name)
        #if DEBUG
        .modifier(HomesteadHUDPreviewWindow())
        #endif
        .background(CartoonTheme.kidBgGradient)
        .accessibilityHidden(!isVisible)
        .task {
            #if DEBUG
            playground?.attachHomestead(bridge, child: kid, in: context)
            #endif
            SoundEffects.warmUpForWorld()
            bridge.start()
        }
        .task(id: isVisible && hasLandscapeSpace && phase == .active) {
            guard isVisible, hasLandscapeSpace, phase == .active else { return }
            while !Task.isCancelled {
                let now = Date()
                timeClock.advance(to: now, activities: HomesteadTimedActivity.all(farm: farm, construction: constructionClocks))
                let building = constructionClocks.filter { $0.remaining(at: now) > 0 }
                let pending = Set(building.map(\.kind))
                if !workingBuilds.subtracting(pending).isEmpty {
                    await refresh(); SoundEffects.playWorld(.construction); Haptics.selection()
                }
                workingBuilds = pending
                // A failed initial load waits for explicit recovery; the clock
                // must not retry store mutations every tick before a map exists.
                if let farm, projection != nil {
                    let day = FamilyDay.key(for: now, in: .current)
                    if day != projectionDay { await refresh() }
                    let stages = farm.fields.map { $0.stage(at: now) }
                    let production = farm.production(at: now)
                    let constructionKey = building.map { "\($0.kind.rawValue):\($0.remaining(at: now))" }.joined(separator: "|")
                    let key = constructionKey + stages.map(String.init).joined() + production.map { "\($0.station):\($0.state):\($0.remaining):\($0.good)" }.joined(separator: "|")
                    if key != farmSceneKey {
                        farmSceneKey = key
                        do {
                            if var snapshot = projection {
                                try snapshot.updateTimers(farmStages: stages,
                                    farmFruitStage: farm.orchardWatered == nil ? 0 : farm.orchardRemaining(at: now) > 0 ? 1 : 2,
                                    production: production, building: building, now: now)
                                updateBridge(snapshot)
                            }
                        } catch { self.error = error.localizedDescription }
                    }
                } else {
                    let key = building.map { "\($0.kind.rawValue):\($0.remaining(at: now))" }.joined(separator: "|")
                    if key != farmSceneKey {
                        farmSceneKey = key
                        do {
                            if var snapshot = projection {
                                try snapshot.updateConstructionTimers(building: building, now: now)
                                updateBridge(snapshot)
                            }
                        } catch { self.error = error.localizedDescription }
                    }
                }
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
        .task(id: changeKey) { await refresh() }
        // Entry loads the engine while isVisible is false. Refresh the callback
        // when that value changes so messages use the current interaction lease.
        .onChange(of: active) { _, _ in
            bridge.onMessage = handle
            updateBridge()
        }
        .onChange(of: selected) { _, value in
            if value == nil { placementPage = nil; placementFailure = nil }
            updateBuilderFraming()
        }
        .onChange(of: worldWindowSize) { _, _ in updateBuilderFraming(); updatePlaceFraming() }
        .onChange(of: menuRoute, initial: true) { _, value in menuSession.present(value); updatePlaceFraming() }
        .onChange(of: mapPlacePageOpen) { _, _ in updatePlaceFraming() }
        .onChange(of: productionFocusKey) { _, _ in frameProduction() }
        .onChange(of: productionRing) { _, _ in frameProduction() }
        .onChange(of: canShowNewTip) { _, available in if available { queueTips(); showNextTip() } }
        .task(id: "\(attachedTip?.key ?? "")-\(attachedTip?.text ?? "")-\(canShowTip)") {
            guard canShowTip, let feedback = attachedTip else { return }
            do { try await Task.sleep(for: .seconds(4.5)) } catch { return }
            if attachedTip == feedback { dismissAttachedTip() }
        }
        .onChange(of: projectRequest) { _, _ in openRequestedProject() }
        .onChange(of: isVisible) { _, _ in openRequestedProject() }
        .onChange(of: showsChapter) { _, _ in openRequestedProject() }
        .onAppear { openRequestedProject() }
        .onChange(of: panelOpen) { _, open in
            if open { checkInBonus = nil }
            if open && error == nil && !expansionQuote && placementPage == nil { cancelSelection() }
            updateBridge()
        }
        .onChange(of: bridge.status, initial: true) { _, status in
            entryReady?.wrappedValue = status != .loading || error != nil
            if status == .ready { updateLandPreview(); queueTips(); noteSunnyDay(); noteTreeThirst(watering: noteTreeWatering()); claimCheckIn() }
        }
        .onChange(of: phase) { _, phase in if phase == .active { claimCheckIn() } else { checkInBonus = nil } }
        .onChange(of: isVisible) { _, visible in if visible { claimCheckIn() } else { checkInBonus = nil } }
        .onChange(of: error) { _, error in if error != nil { entryReady?.wrappedValue = true } }
        .onChange(of: orchardActivity) { _, open in if open && farm != nil { farmStation = .orchard } }
        .task(id: worldAudioActive) {
            guard !Task.isCancelled else { return }
            await OpeningMusic.sunshine.setAppActive(phase == .active)
            await OpeningMusic.sunshine.stop(ownerID: musicOwner)
            guard !Task.isCancelled, worldAudioActive else { return }
            let owner = UUID(); musicOwner = owner
            defer { if Task.isCancelled { Task { await OpeningMusic.sunshine.stop(ownerID: owner) } } }
            _ = await OpeningMusic.sunshine.playSunshine(.world, ownerID: owner, worldTrack: worldMusicTrack)
        }
        .onChange(of: worldMusicTrack) { _, track in
            guard worldAudioActive else { return }
            let owner = musicOwner
            Task { await OpeningMusic.sunshine.setWorldTrack(track, ownerID: owner) }
        }
        .overlay(alignment: .topLeading) {
            #if DEBUG
            if UITestLaunchConfiguration.isEnabled, ProcessInfo.processInfo.arguments.contains("-ui-testing-music") {
                MusicPlaybackUITestProbe(identifier: "world.music.playback")
            }
            #endif
        }
        .background {
            if active && selected == nil {
                // Hardware shortcuts have no on-screen or accessibility buttons.
                Group {
                    Button("") { zoomCamera(1 / 1.2) }.keyboardShortcut("+", modifiers: [])
                    Button("") { zoomCamera(1 / 1.2) }.keyboardShortcut("=", modifiers: [])
                    Button("") { zoomCamera(1.2) }.keyboardShortcut("-", modifiers: [])
                }.frame(width: 0, height: 0).clipped().opacity(0)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .worldExitConfirmation(isPresented: $exitRequested, leave: onMissions)
        .modifier(WorldKidAccessHelp(presented: $accessHelpOpen, issue: accessIssue, worldVisible: isVisible))
        .onChange(of: accessIssue) { old, next in
            bridge.onMessage = handle
            updateBridge()
            if old != nil && next == nil {
                accessHelpOpen = false
                if isVisible { AccessibilityNotification.Announcement("Access restored").post() }
            }
        }
        .onDisappear {
            menuSession.stopVisuals()
            normalFarm.commit = nil
            Task { [owner = musicOwner] in await OpeningMusic.sunshine.stop(ownerID: owner) }
        }
        .environment(\.worldMenuSession, menuSession)
    }

    private var worldScene: some View {
    ZStack {
        HomesteadCanvas(bridge: bridge)
            .accessibilityIdentifier("homestead.canvas")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { worldCanvasFrame = $0; menuSession.canvas = $0 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(HomesteadWorldSpace.name)) } action: { sceneFrame = $0 }
        // The entry wrapper owns loading presentation; direct preview hosts
        // without that wrapper retain a local loading fallback.
        if bridge.status == .loading && entryReady == nil {
            ProgressView("Opening your world…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        if bridge.status == .failed {
            VStack(spacing: 12) {
                Text("Your world is safe. It could not open this time.")
                HomesteadIconButton(title: "Return to Tuvlo", icon: "arrow.uturn.backward") { exitRequested = true }
            }.padding().background(Color(livingWorldHex: "#E6E0CE"), in: RoundedRectangle(cornerRadius: 22))
        }
    }.accessibilityElement(children: .contain)
        .accessibilityLabel(bridge.status == .ready ? "Your homestead is ready" : "Your homestead")
        .accessibilityValue(activity)
        .accessibilityIdentifier("homestead.surface")
        .modifier(HomesteadTimeMapActions(clock: timeClock, statuses: projection?.production ?? [], action: openTimedActivity))
    }
    private var chapterWaiting: some View {
        VStack(spacing: 16) {
            Text("Getting your World ready").font(.title2.bold())
            Text("Your progress is still arriving from your family. Connect to sync and check again.")
                .multilineTextAlignment(.center)
            Button {
                Task { await FamilyAutoSyncCoordinator.shared.syncNow(reason: "world-starter-refresh"); await refresh() }
            } label: { Text("Check again").frame(minHeight: 48) }
                .buttonStyle(.borderedProminent)
            HomesteadReturnButton { exitRequested = true }
        }.padding(24).accessibilityElement(children: .contain).accessibilityIdentifier("world.chapter.loading")
    }
    private var chapterGuide: some View {
        LivingWorldStarterGuide(starter: starter, projects: projects,
            handoff: .init(kid: kid, tasks: worldTasks, currency: projects.currency), allowsChanges: allowsChanges, isPlayground: sequentialPlayground,
            advance: beginStarterPlacement, finish: { missions in
                do {
                    try LivingWorldStarterActions.advance(.introduced, kid: kid, context: context, allowsChanges: demoAuthorization)
                    #if DEBUG
                    try playground?.prepareProductionAfterFirstVisit()
                    #endif
                    closePanel()
                    Task {
                        await refresh()
                        do { if !opening.started { try await performOpening(.begin, round: false) } }
                        catch { self.error = error.localizedDescription }
                        if missions { openMissions() } else { openingOpen = true }
                    }
                } catch { self.error = error.localizedDescription }
            })
    }
    private var statusText: some View {
        Text(bridge.status == .ready ? "Your homestead is ready" : "Your homestead")
            .font(.caption).accessibilityIdentifier("homestead.status")
            .accessibilityValue(activity)
    }
    private var topHUD: some View {
        VStack(spacing: 6) {
            topHUDControls
            if let issue = accessIssue {
                KidAccessNoticeButton(issue: issue, compact: true) { accessHelpOpen = true }
                    .frame(maxWidth: 320).frame(maxWidth: .infinity, alignment: .trailing)
                    .opacity(accessHelpOpen ? 0 : 1)
                    .accessibilityIdentifier("homestead.access.notice")
            }
        }
    }
    private var topHUDControls: some View {
        GeometryReader { area in
            HStack(spacing: 8) {
                HomesteadReturnButton { menuSession.control("hud.return"); exitRequested = true }
                    .disabled(projectBusy).worldMenuAnchor("hud.return")
                    .frame(width: HomesteadToolbeltGeometry.returnControl)
                levelRing.disabled(introductionVisible).frame(width: HomesteadToolbeltGeometry.levelRing).worldMenuAnchor("hud.level")
                if focusedSurface {
                    Color.clear.frame(width: HomesteadToolbeltGeometry.ticket).accessibilityHidden(true)
                    Color.clear.frame(width: HomesteadToolbeltGeometry.activity).accessibilityHidden(true)
                } else {
                    recommendedAction.frame(width: HomesteadToolbeltGeometry.ticket).worldMenuAnchor("hud.goal")
                    activityButton.frame(width: HomesteadToolbeltGeometry.activity).worldMenuAnchor("hud.activity")
                }
                Spacer(minLength: 0)
                worldWallet.disabled(introductionVisible).frame(width: HomesteadToolbeltGeometry.walletWidth(in: area.size.width)).worldMenuAnchor("hud.wallet")
                    // Collected products fly to the warehouse box, the wallet's last column.
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(HomesteadWorldSpace.name)) } action: { frame in
                        guard sceneFrame.width > 0, sceneFrame.height > 0 else { return }
                        bridge.send("hudAnchors", payload: ["warehouse": ["x": (frame.maxX - frame.width / 6 - sceneFrame.minX) / sceneFrame.width, "y": (frame.midY - sceneFrame.minY) / sceneFrame.height]])
                    }
            }
        }.frame(height: HomesteadToolbeltGeometry.height)
            .accessibilityElement(children: .contain).accessibilityIdentifier("homestead.hud")
    }
    private var overviewControl: some View {
        Button {
            menuSession.control("camera.overview"); WorldMenuFeedback.touch(.brass)
            camera = "overview"
            bridge.send("camera", payload: ["mode": "overview", "resetZoom": true])
        } label: {
            WorldControlIcon(symbol: "overview").frame(width: 32, height: 32)
                .scaleEffect(camera == "overview" ? 1.08 : 1).frame(width: 48, height: 52).background(HomesteadControlSurface(selected: camera == "overview")).contentShape(Rectangle())
        }.buttonStyle(HomesteadControlButtonStyle()).disabled(projectBusy)
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .accessibilityLabel("Overview").accessibilityIdentifier("homestead.camera.overview")
            .accessibilityAddTraits(camera == "overview" ? .isSelected : [])
            .accessibilityAction(named: Text("Zoom in")) { zoomCamera(1 / 1.2) }
            .accessibilityAction(named: Text("Zoom out")) { zoomCamera(1.2) }
            .worldMenuAnchor("camera.overview")
    }
    private var worldWallet: some View {
        HomesteadWorldBalance(kid: kid, materials: showsMaterials ? materials.balance : nil, displaysMeals: farm != nil,
            storedGoods: farm.map { farm in HomesteadFarm.Good.allCases.reduce(0) { $0 + farm[$1] } },
            openDetails: (selected != nil || look || extras) ? nil : { openWalletPage() }, openWarehouse: { openWarehousePage() }, showsLevel: false)
    }
    private var levelRing: some View {
        let wallet = EconomyLedger.forChild(kid)
        return HomesteadLevelRing(level: wallet.level, progress: wallet.levelProgress) {
            if settingsOpen { dismissMenu() } else { openSettings { settingsOpen = true } }
        }.disabled(projectBusy || starter.isLoading)
    }
    private var activityButton: some View {
        HomesteadActivityPill(clock: timeClock, action: openTimedActivity).disabled(projectBusy || showsChapter)
    }
    private func openTimedActivity(_ destination: HomesteadTimedActivity.Destination) {
        guard !projectBusy else { return }
        switch destination {
        case .farm(let station): openFarm(station)
        case .construction(let kind): openConstruction(kind)
        }
    }
    private var checkInButton: some View {
        Button {
            guard !projectBusy else { return }
            if checkInOpen { dismissMenu() }
            else { resetPanels(); checkInOpen = true; updateBridge() }
        } label: {
            VStack(spacing: 2) {
            TimelineView(.periodic(from: .now, by: 60)) { clock in
                StreakTrailGrowth(stage: max(1, (WorldBonusLedger(kid: kid).streak(at: clock.date) - 1) % 7 + 1))
                    .frame(width: 30, height: 30).frame(width: 48, height: 48)
                    .background(HomesteadControlSurface(selected: checkInOpen))
                    .overlay(alignment: .topTrailing) {
                        let count = WorldBonusLedger(kid: kid).streak(at: clock.date)
                        Text(count > 99 ? "99+" : "\(count)").font(.system(size: 10, weight: .bold))
                            .frame(width: 26, height: 16).background(Color(livingWorldHex: "#D7E3BD"), in: Capsule())
                    }
                    .accessibilityValue("\(WorldBonusLedger(kid: kid).streak(at: clock.date))-day check-in streak")
            }
            Text("Streak").font(.caption.bold())
            }
        }.buttonStyle(HomesteadMenuButtonStyle()).disabled(projectBusy || showsChapter || starter.isLoading)
            .accessibilityLabel("Streak trail").accessibilityIdentifier("homestead.streak")
    }
    @ViewBuilder private var recommendedAction: some View {
        if showsChapter || starter.isLoading {
            HomesteadNextStepTicket(title: starter.count == 0 ? "Build cottage" : starter.count == 1 ? "Plant tree" : starter.count == 2 ? "Lay path" : "Start garden", pulsed: $recommendationPulsed, readOnly: !allowsChanges, picture: {
                recommendationPlace(starter.count == 0 ? .cottage : starter.count == 1 ? .tree : starter.count == 2 ? .path : .garden)
            }, action: { openBottomMenu("build") })
                .disabled(starter.isLoading || projectBusy || selected != nil || !allowsChanges)
                .accessibilityIdentifier("homestead.chapter.goal")
        } else {
            farmGoalButton.disabled(projectBusy || selected != nil || !allowsChanges)
        }
    }
    private func updatePlaceFraming() {
        let height = max(1, worldWindowSize.height)
        let insets = CGSize(width: mapPlacePageOpen ? min(0.45, (menuWalletHeight + 24 + 56) / height) : 0,
                            height: 0)
        guard insets != inspectionInsets else { return }
        inspectionInsets = insets
        bridge.send("camera", payload: ["inspectionTop": insets.width, "inspectionBottom": insets.height])
    }
    private func requestFeedbackAnchor(_ id: String, _ event: String) {
        bridge.send("feedbackAnchor", payload: ["id": id, "event": event, "station": farmStation.rawValue])
    }
    private func savedPlace(_ kind: HomesteadKind, identity: String, from: String? = nil) {
        updateBridge()
        let object = projection?.items.first { $0.kind == kind && $0.isPlaced }
        _ = menuSession.saved(identity, picture: .place(kind), from: from,
                              destination: object.map { "map:" + $0.id.uuidString } ?? "dock.build", request: requestFeedbackAnchor)
    }
    private func savedCharacter() {
        updateBridge()
        _ = menuSession.saved("appearance:" + UUID().uuidString, picture: .character,
                              destination: "map:resident", request: requestFeedbackAnchor)
    }
    private func productionSaved(_ good: HomesteadFarm.Good, _ collected: Bool, _ identity: String, count: Int? = nil) {
        farm?.clearNotice()
        updateBridge()
        let kind: HomesteadKind = farmStation == .orders && projects.isBuilt(.nook) ? .nook : farmStation.kind
        let object = projection?.items.first { $0.kind == kind && $0.isPlaced }
        let destination = collected ? "hud.warehouse" : object.map { "map:" + $0.id.uuidString } ?? "dock.more"
        let pieces = count ?? (collected ? [.wheat: 2, .fruit: 3, .meal: 3, .meat: 2][good, default: 1] : 1)
        // Goods leave from whatever was last touched: a plot, the place, or a map bubble.
        _ = menuSession.saved(identity, picture: .good(good), count: pieces, destination: destination, request: requestFeedbackAnchor)
    }
    private var ovenIntroduced: Bool {
        if sequentialPlayground { return farm?.hasIntroducedOven == true }
        return !starter.isEligible || farm?.hasIntroducedOven == true
    }

    private func openOwnedPlace(_ object: HomesteadObject) {
        guard !projectBusy else { return }
        if showsChapter { openBottomMenu("build"); return }
        if HomesteadConstruction.current(object.kind, kid: kid) != nil { openConstruction(object.kind); return }
        if [.garden, .windmill, .cottage, .orchard, .nook, .barn, .grill].contains(object.kind)
            && (object.kind != .cottage || ovenIntroduced) {
            openFarm(object.kind == .garden ? .field : object.kind == .windmill ? .mill : object.kind == .cottage ? (farm?.cottageStation ?? .oven)
                     : object.kind == .orchard ? .orchard : object.kind == .nook ? .orders : object.kind == .barn ? .barn : .grill)
            return
        }
        resetPanels(); placeOverview = object.id; focusedPlace = object.id
        framePlaced(object.kind); updateBridge()
    }
    private func ownedPlacePage(_ object: HomesteadObject) -> some View {
        let plays = [.workshop, .greenhouse].contains(object.kind)
        return WorldPlacePage(title: object.kind.title, icon: object.kind.controlIcon, needsTitle: "Look", recipeTitle: "Place",
                              back: { openBottomMenu("build") }, close: closePanel) {
            if !builderLookNames(object).isEmpty { builderLooks(object) }
            else {
                Image(object.kind.heroArtwork).resizable().scaledToFit().frame(width: 120, height: 96)
                    .accessibilityElement().accessibilityLabel(Text(object.kind.purpose))
            }
        } recipe: {
            VStack(spacing: 10) {
                if plays {
                    placeUtility("Play", icon: "play.fill", large: true) { openPlaceActivity(object.kind) }
                        .accessibilityIdentifier("homestead." + object.kind.rawValue + ".play")
                }
                // Move and Put away are equals, side by side.
                HStack(spacing: 10) {
                    placeUtility("Move", icon: "tool.move") { selectCatalogueObject(object) }.accessibilityIdentifier("homestead.details.move")
                    placeUtility("Put away", icon: "archivebox") {
                        let command = UUID()
                        do {
                            try HomesteadActions.apply(.remove(object.id), commandID: command, kid: kid, in: context, allowsChanges: demoAuthorization)
                            _ = menuSession.saved(command.uuidString, picture: .place(object.kind), destination: "dock.build", request: requestFeedbackAnchor)
                            closePanel(); Task { await refresh() }
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
        } hero: { Color.clear }
    }
    /// Picture-only place actions; the word stays in the accessibility label.
    private func placeUtility(_ title: String, icon: String, large: Bool = false, action: @escaping () -> Void) -> some View {
        Button { menuSession.control("utility:" + title); WorldMenuFeedback.touch(.wood); action() } label: {
            WorldControlIcon(symbol: icon).frame(width: large ? 44 : 38, height: large ? 44 : 38)
                .frame(width: large ? 148 : 69, height: large ? 72 : 69).background(WorldTileSurface(cornerRadius: 18, lit: large && allowsChanges))
                .opacity(allowsChanges ? 1 : 0.5)
        }.buttonStyle(WorldCardPress()).disabled(!allowsChanges).worldMenuAnchor("utility:" + title)
            .accessibilityLabel(Text(LocalizedStringKey(title))).accessibilityIdentifier("homestead.place." + title.lowercased())
    }
    private func openPlaceActivity(_ kind: HomesteadKind) {
        guard !projectBusy else { return }
        resetPanels()
        if kind == .workshop { workshopActivity = true }
        else if kind == .greenhouse { greenhouseActivity = true }
        else if kind == .orchard { orchardActivity = true }
        updateBridge()
    }

    private func openWarehousePage() {
        guard !projectBusy, error == nil else { return }
        if selected != nil { cancelSelection(); guard error == nil else { return } }
        resetPanels(); warehouseOpen = true; updateBridge()
    }
    private func openWalletPage() {
        guard !projectBusy, error == nil else { return }
        resetPanels(); walletOpen = true; updateBridge()
    }
    private func warehouseSource(_ good: HomesteadFarm.Good) {
        guard !showsChapter else { openBottomMenu("build"); return }
        let station: HomesteadFarm.Station
        switch good {
        case .wheat: station = .field
        case .flour: station = .mill
        case .bread, .tart: station = .oven
        case .meal: station = .pantry
        case .fruit: station = .orchard
        case .meat: station = .barn
        }
        if good == .bread || good == .tart { ovenRecipe = good == .tart ? .tart : .bread }
        openFarm(station); recipeFromWarehouse = true
    }
    private func openFarm(_ station: HomesteadFarm.Station) {
        guard farm != nil, !projectBusy else { return }
        resetPanels(); farmStation = station; openingOpen = true; farmMenu = false; updateBridge()
    }
    private func openRecipeSource(_ good: HomesteadFarm.Good) {
        recipeReturns.append(.init(station: farmStation, recipe: ovenRecipe))
        switch good {
        case .wheat: farmStation = .field
        case .flour: farmStation = .mill
        case .bread: ovenRecipe = .bread; farmStation = .oven
        case .meal: farmStation = .pantry
        case .fruit: farmStation = .orchard
        case .tart: ovenRecipe = .tart; farmStation = .oven
        case .meat: farmStation = .barn
        }
    }
    /// The farm's next suggested step. Only the suggestion changes; saved jobs,
    /// orders, prices and mission gates are untouched.
    private enum FarmGoal {
        case collect(HomesteadFarm.Station, HomesteadFarm.Good), wheat, windmill, bread, meals, nook, picnic
        case meadow, orchard, shareBread, tart, barn, sheep, grill, grillMeals, dog, waterside, remaining
    }
    private var farmGoal: FarmGoal? {
        _ = farmSceneKey
        guard let farm else { return nil }
        if let ready = HomesteadFarm.Station.allCases.first(where: { farm.jobs[$0].map { $0.remaining(at: Date()) == 0 } == true }), let job = farm.jobs[ready] {
            return .collect(ready, job.recipe.output)
        }
        if farm.wheatHarvested < 2 { return .wheat }
        if !LivingWorldExpansion.windmill.isOwned(by: kid) { return .windmill }
        if farm.breadMade == 0 { return .bread }
        if !projects.isBuilt(.nook) { return farm[.meal] >= 3 ? .nook : .meals }
        if !farm.picnicServed { return .picnic }
        // Fruit follows the loaf once its mission gate is met; until then the
        // barn chain fills the wait, then fruit is suggested even while gated.
        func fruit(waiting: Bool) -> FarmGoal? {
            if !LivingWorldExpansion.meadow.isOwned(by: kid) {
                return waiting || projects.approvedWins >= LivingWorldExpansion.meadow.requiredWins ? .meadow : nil
            }
            if !LivingWorldExpansion.orchard.isOwned(by: kid) {
                return waiting || projects.approvedWins >= LivingWorldExpansion.orchard.requiredWins ? .orchard : nil
            }
            if farm.orders == 0 { return .shareBread }
            if farm.orders == 1 { return .tart }
            return nil
        }
        if let step = fruit(waiting: false) { return step }
        if !LivingWorldExpansion.barn.isOwned(by: kid) { return .barn }
        if farm.grilledMade == 0 {
            if farm[.meat] == 0 { return .sheep }
            return LivingWorldExpansion.grill.isOwned(by: kid) ? .grillMeals : .grill
        }
        if !LivingWorldExpansion.doghouse.isOwned(by: kid) { return .dog }
        if let step = fruit(waiting: true) { return step }
        if !LivingWorldExpansion.waterside.isOwned(by: kid) { return .waterside }
        return .remaining
    }
    private var farmGoalButton: some View {
        HomesteadNextStepTicket(title: farmTicketTitle, pulsed: $recommendationPulsed, readOnly: !allowsChanges, picture: { farmGoalArtwork }) {
            guard let farm, let goal = farmGoal else { return }
            switch goal {
            case .collect(let station, _): openFarm(station)
            case .wheat: openFarm(.field)
            case .windmill: followTicketTarget(.expansion(.windmill))
            case .bread: openFarm(farm[.flour] > 0 || farm.jobs[.oven] != nil ? .oven : .mill)
            case .meals: openFarm(.pantry)
            case .nook: followTicketTarget(.project(.nook))
            case .picnic, .shareBread: openFarm(.orders)
            case .meadow: followTicketTarget(.expansion(.meadow))
            case .orchard: followTicketTarget(.expansion(.orchard))
            case .tart: openFarm(farm[.tart] > 0 ? .orders : .orchard)
            case .barn: followTicketTarget(.expansion(.barn))
            case .sheep: openFarm(.barn)
            case .grill: followTicketTarget(.expansion(.grill))
            case .grillMeals: openFarm(.grill)
            case .dog: followTicketTarget(.expansion(.doghouse))
            case .waterside: followTicketTarget(.expansion(.waterside))
            case .remaining: followRemainingTicket()
            }
        }
            .accessibilityLabel(farmGoalTitle).help(farmGoalTitle)
            .accessibilityValue(allowsChanges ? "Next step" : "Read only")
            .accessibilityIdentifier("homestead.farm.goal")
    }
    private func followTicketTarget(_ target: HomesteadBuildTarget) {
        let next = openingBuildGoal(target)
        if next.step == .build {
            if case .expansion(let item) = target, item.land != nil { openBottomMenu("land") }
            else { openBottomMenu("build") }
        } else { followGoal(next) }
    }
    private func followRemainingTicket() {
        #if DEBUG
        if let next = playground?.nextBuild {
            switch next {
            case .project(let project): followTicketTarget(.project(project))
            case .expansion(let item): followTicketTarget(.expansion(item))
            case .decoration: openBottomMenu("build")
            }
            return
        }
        #endif
        openFarm(.orders)
    }
    private var farmTicketTitle: String {
        switch farmGoal {
        case .collect: return "Collect"
        case .waterside: return "Inspect land"
        case .remaining: return sequentialPlayground ? "Next build" : "Check orders"
        default: return farmGoalTitle
        }
    }
    private func recommendationPlace(_ kind: HomesteadKind) -> some View {
        Image(kind.heroArtwork).resizable().scaledToFit()
            .frame(width: 40, height: 40).accessibilityHidden(true)
    }
    @ViewBuilder private var farmGoalArtwork: some View {
        if let farm, let goal = farmGoal {
            switch goal {
            case .collect(_, let good): HomesteadFarmGoodIcon(good: good)
            case .wheat: HomesteadFarmGoodIcon(good: .wheat)
            case .windmill: gatedRecommendation(.expansion(.windmill)) { recommendationPlace(.windmill) }
            case .bread, .shareBread: HomesteadFarmGoodIcon(good: .bread)
            case .meals, .picnic: HomesteadFarmGoodIcon(good: .meal)
            case .nook: gatedRecommendation(.project(.nook)) { recommendationPlace(.nook) }
            case .meadow: gatedRecommendation(.expansion(.meadow)) { Image("WorldLand_west").resizable().scaledToFit() }
            case .orchard: gatedRecommendation(.expansion(.orchard)) { recommendationPlace(.orchard) }
            case .tart: HomesteadFarmGoodIcon(good: farm[.tart] > 0 ? .tart : .fruit)
            case .barn: gatedRecommendation(.expansion(.barn)) { recommendationPlace(.barn) }
            case .sheep: WorldControlIcon(symbol: "sheep")
            case .grill, .grillMeals: gatedRecommendation(.expansion(.grill)) { recommendationPlace(.grill) }
            case .dog: gatedRecommendation(.expansion(.doghouse)) { recommendationPlace(.doghouse) }
            case .waterside: gatedRecommendation(.expansion(.waterside)) { Image("WorldLand_east").resizable().scaledToFit() }
            case .remaining: remainingTicketArtwork
            }
        } else { WorldControlIcon(symbol: "garden") }
    }
    @ViewBuilder private var remainingTicketArtwork: some View {
        #if DEBUG
        if let next = playground?.nextBuild {
            switch next {
            case .project(let project): gatedRecommendation(.project(project)) { recommendationPlace(project.worldKind) }
            case .expansion(let item): gatedRecommendation(.expansion(item)) {
                if let kind = item.kind { recommendationPlace(kind) }
                else { WorldControlIcon(symbol: "land") }
            }
            case .decoration(let kind): recommendationPlace(kind)
            }
        } else { HomesteadFarmGoodIcon(good: .meal) }
        #else
        HomesteadFarmGoodIcon(good: .meal)
        #endif
    }
    private func readyTitle(_ target: HomesteadBuildTarget, _ ready: String) -> String {
        switch openingBuildGoal(target).step {
        case .missions: return "Do missions"
        case .earn: return projects.currency == .stars ? "Earn Stars" : "Earn Coins"
        case .landFirst: return "Inspect land"
        case .grow, .collect: return "Make meals"
        case .build: return ready
        }
    }
    @ViewBuilder private func gatedRecommendation<Ready: View>(_ target: HomesteadBuildTarget, @ViewBuilder ready: () -> Ready) -> some View {
        switch openingBuildGoal(target).step {
        case .missions:
            WorldControlIcon(symbol: "checklist").frame(width: 48, height: 44)
        case .grow(.food), .collect(.food, _):
            HomesteadFarmGoodIcon(good: .meal)
        case .earn:
            WorldControlIcon(symbol: "star.fill").frame(width: 48, height: 44)
        case .landFirst:
            Image("WorldLand_west").resizable().scaledToFit()
        default:
            ready()
        }
    }
    private var farmGoalTitle: String {
        guard let farm, let goal = farmGoal else { return "Farm" }
        switch goal {
        case .collect(_, let good): return "Collect " + good.title.lowercased()
        case .wheat: return farm.fields.contains { $0.stage(at: Date()) == 4 } ? "Harvest wheat" : "Grow wheat"
        case .windmill: return readyTitle(.expansion(.windmill), "Build windmill")
        case .bread: return "Bake bread"
        case .meals: return "Pack 3 meals"
        case .nook: return readyTitle(.project(.nook), "Build nook")
        case .picnic: return "Serve picnic"
        case .meadow: return readyTitle(.expansion(.meadow), "Open meadow")
        case .orchard: return readyTitle(.expansion(.orchard), "Build orchard")
        case .shareBread: return "Share bread"
        case .tart: return farm[.tart] > 0 ? "Deliver tart" : "Grow fruit"
        case .barn: return readyTitle(.expansion(.barn), "Build barn")
        case .sheep: return farm.jobs[.barn] != nil ? "Raise sheep" : "Feed sheep"
        case .grill: return readyTitle(.expansion(.grill), "Build grill")
        case .grillMeals: return "Grill meals"
        case .dog: return readyTitle(.expansion(.doghouse), "Welcome a dog")
        case .waterside: return readyTitle(.expansion(.waterside), "Open waterside")
        case .remaining:
            #if DEBUG
            if let next = playground?.nextBuild { return next.title }
            #endif
            return "Orders"
        }
    }
    private func openFromMenu(_ action: () -> Void) {
        worldMenu = false
        action()
        updateBridge(); updateLandPreview()
    }
    private var worldMenuContent: some View {
        HomesteadItemStrip(items: Array(0..<6), minimumWidth: 64, rowHeight: 64) { index in
            switch index {
            case 0:
                utilityAction("Settings", icon: "settings", id: "homestead.settings") { openSettings { settingsOpen = true } }
            case 1: checkInButton
            case 2:
                utilityAction("Farm", icon: "garden", id: "homestead.opening.open") { openBottomMenu("farm") }
                    .disabled(showsChapter)
            case 3:
                utilityAction("Oven", icon: "farm.bread", id: "homestead.bread.open") {
                    openFromMenu { farmStation = .oven; breadStoryOpen = true }
                }.disabled(showsChapter)
                    .opacity(ovenIntroduced ? 1 : 0).allowsHitTesting(ovenIntroduced).accessibilityHidden(!ovenIntroduced)
            case 4:
                utilityAction("Orders", icon: "material.food", id: "homestead.story.open") {
                    openFromMenu { farmStation = .orders; meadowStoryOpen = true }
                }.disabled(showsChapter)
            default: utilityAction("Warehouse", icon: "archivebox", id: "homestead.warehouse.open", action: openWarehousePage)
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("homestead.actions.pages")
    }
    private func utilityAction(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button { menuSession.control("control:" + title); WorldMenuFeedback.touch(.paper); action() } label: {
            // Icon only, on the same tile as every World control; the word is spoken.
            Group {
                if icon == "farm.bread" { HomesteadFarmGoodIcon(good: .bread) }
                else { WorldControlIcon(symbol: icon) }
            }.frame(width: 40, height: 40).frame(width: 60, height: 60)
                .background(HomesteadControlSurface())
                .frame(maxWidth: .infinity).frame(height: 64).contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle()).worldMenuAnchor("control:" + title).accessibilityIdentifier(id)
            .accessibilityLabel(Text(LocalizedStringKey(title)))
    }
    private var settingsContent: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                audioSetting("Sounds", symbol: soundsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", enabled: soundsEnabled) {
                    soundsEnabled.toggle()
                }.accessibilityIdentifier("homestead.settings.sound")
                AudioLevelControl(title: "Effects volume", level: $effectsLevel, compact: true)
                    .disabled(!soundsEnabled).accessibilityIdentifier("homestead.audio.effects")
            }.frame(width: 100)
            VStack(spacing: 0) {
                audioSetting("Music", symbol: musicEnabled ? "music.note" : "music.note.slash", enabled: soundsEnabled && musicEnabled) {
                    musicEnabled.toggle()
                }.disabled(!soundsEnabled).accessibilityIdentifier("homestead.settings.music")
                AudioLevelControl(title: "Music volume", level: $musicLevel, compact: true)
                    .disabled(!soundsEnabled || !musicEnabled).accessibilityIdentifier("homestead.audio.music")
            }.frame(width: 100)
            settingsTile("Look", icon: "person.crop.circle") { openSettings { look = true }; frameCharacter() }
                .disabled(!allowsChanges).accessibilityIdentifier("homestead.settings.look")
            settingsTile("Details", icon: "tshirt.fill") { openSettings { extras = true }; frameCharacter() }
                .accessibilityIdentifier("homestead.settings.details")
            settingsTile("How to play", icon: "questionmark.circle") {
                resetPanels(); replayIntroduction = true; updateBridge()
            }.accessibilityIdentifier("homestead.introduction.replay")
            #if DEBUG
            if playground != nil {
                HomesteadIconButton(title: "Sandbox", icon: "hammer") { openSettings { sandboxTools = true } }
                    .accessibilityIdentifier("homestead.sandbox.menu")
            }
            #endif
        }.frame(maxWidth: .infinity).accessibilityElement(children: .contain).accessibilityIdentifier("homestead.settings.content")
    }
    private var settingsWindow: some View {
        GeometryReader { area in
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    WorldControlIcon(symbol: "settings").frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    Text("World settings").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    #if DEBUG
                    if playground != nil {
                        WorldFlowGuideButton(worldContext: true).labelStyle(.iconOnly).font(.title2)
                            .frame(width: 48, height: 48)
                    }
                    #endif
                    HomesteadIconButton(title: "Close window", icon: "xmark", action: closePanel)
                        .accessibilityIdentifier("homestead.panel.close")
                }
                settingsContent
            }
            .padding(16)
            .frame(width: max(0, min(560, area.size.width - 32)))
            .background {
                Button { } label: {
                    RoundedRectangle(cornerRadius: 24).fill(Color(livingWorldHex: "#F3EBD6"))
                        .contentShape(RoundedRectangle(cornerRadius: 24))
                }.buttonStyle(.plain).accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .environment(\.colorScheme, .light)
            .shadow(color: .black.opacity(0.2), radius: 18, y: 6)
            .worldMenuArrival()
            .accessibilityElement(children: .contain).accessibilityLabel("World settings")
            .accessibilityIdentifier("homestead.panel")
            .accessibilityAction(.escape, closePanel)
            .position(x: area.size.width / 2, y: area.size.height / 2)
        }
    }
    /// Same tile and column as the audio settings, so the row reads as one set.
    private func settingsTile(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button { menuSession.control("control:" + title); WorldMenuFeedback.touch(.paper); action() } label: {
                WorldControlIcon(symbol: icon).frame(width: 32, height: 32).frame(width: 48, height: 48)
                    .background(HomesteadControlSurface()).contentShape(Rectangle())
            }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(Text(LocalizedStringKey(title)))
            Spacer(minLength: 0)
        }.frame(width: 72, height: 84)
    }
    private func audioSetting(_ title: String, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WorldControlIcon(symbol: symbol).frame(width: 32, height: 32)
                .saturation(enabled ? 1 : 0).opacity(enabled ? 1 : 0.55)
                .frame(width: 48, height: 48)
                .background(HomesteadControlSurface(selected: enabled))
                .contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle())
            .accessibilityLabel(Text(LocalizedStringKey(title)))
            .accessibilityValue(enabled ? "On" : "Off")
            .accessibilityAddTraits(enabled ? .isSelected : [])
    }
    private func openSettings(_ action: () -> Void) {
        guard !projectBusy else { return }
        if selected != nil {
            cancelSelection()
            guard error == nil else { return }
        }
        resetPanels(); action(); updateBridge()
    }

    private func zoomCamera(_ factor: Double) {
        bridge.send("camera", payload: ["zoom": factor])
        // A menu pauses gameplay callbacks; mirror Overview's transition here too.
        if camera == "overview" { camera = "pan" }
    }
    @ViewBuilder private var overlayWindow: some View {
        if let error {
            VStack {
                Spacer(minLength: 0)
                HomesteadWorldDialog(title: projection == nil ? "Couldn't open World" : "Couldn't update", icon: "exclamationmark.triangle.fill", message: error) {
                    if projection == nil {
                        HStack(spacing: 12) {
                            HomesteadActionButton(title: "Try again", icon: "rotate.right") {
                                self.error = nil
                                Task { await refresh() }
                            }.accessibilityIdentifier("homestead.error.retry")
                            HomesteadActionButton(title: "Tuvlo", icon: "arrow.left") { exitRequested = true }
                                .accessibilityIdentifier("homestead.error.exit")
                        }
                    } else {
                        HomesteadActionButton(title: "Back", icon: "chevron.backward") { self.error = nil }
                            .accessibilityIdentifier("homestead.error.back")
                    }
                }.padding(.horizontal, 16).accessibilityIdentifier("world.dialog.error")
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity)
        } else if introductionVisible {
            VStack {
                Spacer(minLength: 0)
                KidIntroductionView(kid: kid, guide: .world, finished: finishIntroduction)
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity)
        } else if let page = placementPage, let selected,
                  let object = projection?.items.first(where: { $0.id == selected }) {
            HomesteadOverlay(title: page == .info ? object.kind.title : "Look", icon: page == .info ? "info.circle" : "paintpalette.fill",
                modal: false, back: closeBuilderPage, close: closeBuilderPage) {
                if page == .info { builderInfo(object) } else { builderLooks(object) }
            }
        } else if warehouseOpen, let farm {
            WorldWarehousePage(farm: farm, source: warehouseSource, close: closePanel)
        } else if walletOpen {
            WorldWalletPage(kid: kid, materials: showsMaterials ? materials.balance : nil, close: closePanel)
        } else if settingsOpen {
            settingsWindow
        } else if checkInOpen {
            WorldCheckInWindow(kid: kid, close: closePanel)
        } else if let kind = constructionKind {
            WorldPlacePage(title: kind.title, icon: kind.controlIcon, needsTitle: "Place", recipeTitle: "Construction",
                move: {
                    if let object = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) { selectCatalogueObject(object) }
                }, allowsMove: allowsChanges, back: { openBottomMenu("build") }, close: closePanel) {
                HomesteadSlotText(text: kind.purpose, size: 12).frame(width: 128, height: 48)
            } recipe: {
                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    if let build = HomesteadConstruction.current(kind, kid: kid, now: clock.date) {
                        VStack(spacing: 8) {
                            HomesteadSunRing(state: .clock(end: build.finish, duration: Double(build.seconds), now: clock.date), size: 56)
                                .accessibilityIdentifier("homestead.construction.timer")
                            HomesteadActionButton(title: "Building", icon: "hourglass", state: .working) {}
                        }
                    } else {
                        HomesteadActionButton(title: "Open", icon: "checkmark", state: .ready) { openFinishedConstruction(kind) }
                            .accessibilityIdentifier("homestead.construction.ready")
                    }
                }
            } hero: { Color.clear }
        } else if let id = placeOverview, let object = projection?.items.first(where: { $0.id == id }) {
            ownedPlacePage(object)
        } else if let farm, openingOpen || breadStoryOpen || meadowStoryOpen {
            if farmMenu {
                HomesteadOverlay(title: "Farm", icon: "garden", modal: false, close: closePanel) {
                    WorldFarmStationMenu(farm: farm, placed: Set((projection?.items ?? []).filter(\.isPlaced).map(\.kind))) { openFarm($0) }
                }
            } else {
                WorldProductionPage(farm: farm, station: $farmStation, ovenRecipe: $ovenRecipe,
                    placed: Set((projection?.items ?? []).filter { $0.isPlaced && HomesteadConstruction.current($0.kind, kid: kid) == nil }.map(\.kind)),
                    nookOwned: projects.isBuilt(.nook), allowsChanges: allowsChanges,
                    inspect: inspectOpeningPlace, source: openRecipeSource, collectRecipe: collectFarmRecipe,
                    committed: { productionSaved($0, $1, $2) }, celebrate: celebrateWorldMusic, ring: { productionRing = $0 },
                    // Back only when another page led here; a place tapped on the map just closes.
                    back: recipeReturns.isEmpty && !recipeFromWarehouse ? nil : {
                        if let previous = recipeReturns.popLast() { farmStation = previous.station; ovenRecipe = previous.recipe }
                        else { openWarehousePage() }
                        updateBridge()
                    }, close: closePanel, move: {
                        let kind: HomesteadKind = farmStation == .orders && projects.isBuilt(.nook) ? .nook : farmStation.kind
                        if let object = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) { selectCatalogueObject(object) }
                    })
            }
        } else if openingOpen {
            HomesteadOverlay(title: "Your homestead", icon: "windmill", modal: false, expands: true, close: closePanel) {
                HomesteadOpeningView(ledger: opening, wins: projects.approvedWins, wheatReady: openingWheatReady,
                    placed: Set((projection?.items ?? []).filter(\.isPlaced).map(\.kind)),
                    windmillOwned: LivingWorldExpansion.windmill.isOwned(by: kid), nookOwned: projects.isBuilt(.nook),
                    nookFood: materials.balance.food, allowsChanges: allowsChanges,
                    perform: { action, round in try await performOpening(action, round: round) }, buildGoal: openingBuildGoal, inspect: inspectOpeningPlace, missions: openMissions)
            }
        } else if breadStoryOpen {
            HomesteadOverlay(title: "Field to flour", icon: "windmill", modal: false, expands: true, close: closePanel) {
                HomesteadBreadStoryActivity(progress: breadStory,
                    placedKinds: Set((projection?.items ?? []).filter(\.isPlaced).map(\.kind)),
                    allowsChanges: allowsChanges, complete: { step in
                        try HomesteadBreadStoryActions.complete(step, kid: kid, in: context, allowsChanges: demoAuthorization)
                        updateBridge(); Haptics.selection()
                    }, inspect: inspectStoryPlace)
            }
        } else if meadowStoryOpen {
            HomesteadOverlay(title: "Meadow table", icon: "material.food", modal: false, expands: true, close: closePanel) {
                HomesteadMeadowStoryActivity(progress: meadowStory,
                    placedKinds: Set((projection?.items ?? []).filter(\.isPlaced).map(\.kind)),
                    allowsChanges: allowsChanges, complete: { step in
                        try HomesteadMeadowStoryActions.complete(step, kid: kid, in: context, allowsChanges: demoAuthorization)
                        updateBridge(); Haptics.selection()
                    }, inspect: inspectStoryPlace)
            }
        } else if let shelfSelection {
            shelfPage(shelfSelection)
        } else if let assetDetails {
            HomesteadOverlay(title: assetDetails.title, icon: assetDetails.icon, modal: false,
                back: { self.assetDetails = nil; inventory = true }, backIdentifier: "homestead.details.back", close: closePanel) {
                HomesteadAssetDetails(selection: assetDetails, kid: kid, objects: projection?.items ?? [], allowsChanges: allowsChanges,
                    move: { object in if allowsChanges { selectCatalogueObject(object) } },
                    story: { closePanel(); meadowStoryOpen = true },
                    bread: { closePanel(); breadStoryOpen = true },
                    millLook: { value in
                        try HomesteadActions.apply(.windmillLook(value), commandID: UUID(), kid: kid, in: context, allowsChanges: demoAuthorization)
                        Task { await refresh() }
                    })
            }
        } else if missionsOpen {
            HomesteadMissionPage(kid: kid, currency: projects.currency, project: missionGoal,
                                  allowsRequests: demoAuthorization, close: closePanel)
        } else if orchardActivity {
            HomesteadOverlay(title: "Orchard", icon: "tree.fill", modal: false, expands: true, close: closePanel) {
                HomesteadOrchardActivity(variety: projection?.items.first { $0.kind == .orchard }?.style ?? 0,
                    allowsChanges: allowsChanges, chooseVariety: { value in
                        do {
                            try HomesteadActions.apply(.orchardVariety(value), commandID: UUID(), kid: kid, in: context, allowsChanges: demoAuthorization)
                            projection = try renderedProjection(); updateBridge(); Haptics.selection()
                        } catch { self.error = error.localizedDescription }
                    })
            }
        } else if greenhouseActivity {
            HomesteadOverlay(title: "Greenhouse", icon: "garden", modal: false, expands: true, close: closePanel) { HomesteadGreenhouseActivity() }
        } else if workshopActivity {
            HomesteadOverlay(title: "Maker workshop", icon: "hammer", modal: false, expands: true, close: closePanel) {
                HomesteadWorkshopActivity()
            }
        } else if let item = expansionChoice {
            expansionPanel(item)
        } else if inventory, let requestedProject {
            projectPanel(requestedProject).id(requestedProject)
        } else if inventory && (!showsChapter || catalogueSection == "land") && requestedProject == nil && catalogueKind == nil {
            HomesteadAssetDrawer(title: catalogueSection == "land" ? "Land" : effectiveShelfCategory.title, icon: catalogueSection == "land" ? "map.fill" : "build", close: closePanel, content: { inventoryContent })
        } else if inventory {
            HomesteadOverlay(title: requestedProject?.title ?? catalogueKind?.title ?? "Build", icon: requestedProject?.worldKind.controlIcon ?? "square.grid.2x2.fill", allowsClose: !projectBusy, modal: false,
                back: requestedProject != nil || catalogueKind != nil ? {
                    guard !projectBusy else { return }
                    requestedProject = nil; catalogueKind = nil; updateBridge(); updateLandPreview()
                } : nil, backIdentifier: requestedProject != nil ? "homestead.project.back" : "homestead.catalog.back", close: closePanel) {
                if showsChapter {
                    chapterGuide
                } else { inventoryContent }
            }.id(requestedProject)
        } else if look {
            HomesteadOverlay(title: "Look", icon: "person.crop.circle", modal: false, expands: true, close: closePanel) {
                HomesteadLookEditor(kid: kid, allowsChanges: allowsChanges, preview: { value in
                    previewLook = value; updateBridge()
                }, save: { value in
                    try HomesteadActions.saveCharacter(value, kid: kid, in: context, allowsChanges: demoAuthorization)
                    savedCharacter()
                    closePanel(); Task { await refresh() }
                })
            }
        } else if extras {
            HomesteadOverlay(title: "Details", icon: "slider.horizontal.3", modal: false, expands: true, close: closePanel) {
                HomesteadExtrasEditor(kid: kid, allowsChanges: demoAuthorization, preview: { value in
                    previewExtras = value; updateBridge()
                }) { savedCharacter(); closePanel(); Task { await refresh() } }
            }
        } else if worldMenu {
            HomesteadAssetDrawer(title: "More", icon: "ellipsis", close: closePanel, content: { worldMenuContent })
        } else if sandboxTools {
            #if DEBUG
            HomesteadOverlay(title: "Sandbox", icon: "ellipsis", modal: false, close: closePanel) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HomesteadActionButton(title: "First visit", icon: "house.fill") { startFromBeginning?() }
                            .accessibilityIdentifier("homestead.sandbox.firstVisit")
                        HomesteadActionButton(title: "Production", icon: "arrow.uturn.backward") { resetPlayground?(false) }
                            .accessibilityIdentifier("homestead.sandbox.reset")
                        HomesteadIconButton(title: "Refill test Stars", icon: "checkmark") {
                            do { try playground?.refillTestStars() } catch { self.error = error.localizedDescription }
                        }
                        HomesteadIconButton(title: "Approve a sample mission", icon: "missions") {
                            do { try playground?.approveSampleMission(); Task { await refresh() } } catch { self.error = error.localizedDescription }
                        }.accessibilityIdentifier("homestead.sandbox.mission")
                    }
                }
            }
            #endif
        }
    }
    private func openMissions() {
        guard !projectBusy else { return }
        let goal = requestedProject
        error = nil
        if selected != nil {
            cancelSelection()
            guard error == nil else { return }
        }
        openBottomMenu("missions")
        missionGoal = goal
        updateLandPreview()
    }
    private func openBottomMenu(_ section: String) {
        guard !projectBusy else { return }
        error = nil
        if selected != nil {
            cancelSelection()
            guard error == nil else { return }
        }
        resetPanels()
        switch section {
        case "missions": missionsOpen = true
        case "more": worldMenu = true
        case "farm": farmStation = .field; openingOpen = true
        default: catalogueSection = section; inventory = true; catalogueScrollVersion += 1
        }
        updateBridge(); updateLandPreview()
    }
    private func closePanel() {
        guard !projectBusy else { return }
        resetPanels()
        updateBridge(); updateLandPreview()
        clearSpotPreview()
        // A place page borrows the camera; closing it hands the view back.
        if let previous = cameraBeforePlace {
            let view = previous == "place" ? "overview" : previous
            cameraBeforePlace = nil; camera = view; focusedPlace = nil
            bridge.send("camera", payload: ["mode": view, "resetZoom": true])
        }
    }
    /// Dismiss the whole menu in one tap, including an error over another panel.
    /// A purchase already saving keeps its controls blocked until it completes.
    private func dismissMenu() {
        guard !introductionVisible else { return }
        guard !projectBusy, error == nil else { return }
        error = nil
        closePanel()
    }
    private func resetPanels() {
        warehouseOpen = false; walletOpen = false; recipeFromWarehouse = false; recipeReturns = []; farmMenu = false; placeOverview = nil
        placementPage = nil
        openingOpen = false; shelfSelection = nil; assetDetails = nil; meadowStoryOpen = false; breadStoryOpen = false
        constructionKind = nil
        missionsOpen = false; inventory = false; requestedProject = nil; catalogueKind = nil; look = false; extras = false
        worldMenu = false; settingsOpen = false; checkInOpen = false; sandboxTools = false; previewLook = nil; previewExtras = nil
        catalogueSection = "build"; shelfCategory = nil
        expansionChoice = nil; expansionQuote = false; expansionCurrency = nil; workshopActivity = false; greenhouseActivity = false; orchardActivity = false
    }
    private func updateLandPreview() {
        guard isVisible, hasLandscapeSpace, phase == .active else { return }
        let land: HomesteadLand?
        if case .land(let selectedLand) = shelfSelection { land = selectedLand }
        else { land = expansionChoice?.land }
        bridge.send("landPreview", payload: ["side": land?.rawValue ?? ""])
    }
    private func controlLegend(_ title: LocalizedStringKey, icon: String) -> some View {
        Label { Text(title) } icon: { WorldControlIcon(symbol: icon).frame(width: 28, height: 28) }
    }
    private func refresh() async {
        do {
            #if DEBUG
            if UITestLaunchConfiguration.isEnabled,
               ProcessInfo.processInfo.arguments.contains("-ui-testing-world-entry-failure"), !injectedEntryFailure {
                injectedEntryFailure = true
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            if allowsChanges && !starter.isLoading { try HomesteadActions.ensureMigration(for: kid, in: context, allowsChanges: demoAuthorization) }
            var state = try HomesteadActions.state(for: kid)
            if !state.discovered && HomesteadGeometry.hasDuckHabitat(state.objects.filter { HomesteadConstruction.current($0.kind, kid: kid) == nil }) && allowsChanges {
                try HomesteadActions.apply(.discovery("pip-duck"), commandID: HomesteadIdentity.stable(childID: kid.id, key: "discovery:pip-duck"), kid: kid, in: context, allowsChanges: demoAuthorization)
                state = try HomesteadActions.state(for: kid)
            }
            // A70: existing places move into their yard spots once, as ordinary saved moves.
            if allowsChanges && !starter.isLoading && !sequentialPlayground {
                let settled = HomesteadSpots.settlement(state.objects.filter { HomesteadConstruction.current($0.kind, kid: kid) == nil }, land: state.land)
                for object in settled {
                    guard let cell = object.cell else { continue }
                    _ = try? HomesteadActions.apply(.arrange(object), commandID: HomesteadIdentity.stable(childID: kid.id, key: "settle:\(object.id.uuidString):\(cell.x):\(cell.z)"),
                                                    kid: kid, in: context, allowsChanges: demoAuthorization)
                }
                if !settled.isEmpty { state = try HomesteadActions.state(for: kid) }
            }
            if !sequentialPlayground {
                if allowsChanges && starter.count == 3 && starter.introduced {
                    try HomesteadFarmJournal.perform(.begin, kid: kid, in: context)
                }
                normalFarm.restore(HomesteadFarmJournal(kid: kid).farm)
                normalFarm.clearNotice()
                normalFarm.commit = persistFarm
            }
            constructionClocks = HomesteadConstruction.pending(kid: kid)
            projectionDay = FamilyDay.key(for: Date(), in: .current)
            projection = try renderedProjection()
            if let farm {
                farm.reconcileMeals(materials.balance.food)
                if projects.isBuilt(.nook) { farm.fundPicnic() }
            }
            bridge.onMessage = handle
            updateBridge(projection)
            queueTips()
        } catch { self.error = error.localizedDescription }
    }
    private func renderedProjection() throws -> HomesteadProjection {
        try HomesteadProjection(kid: kid, reducedMotion: reducedMotion, look: previewLook, extras: previewExtras,
                                project: inventory && requestedProject.map({ projects.isBuilt($0) }) == true ? requestedProject : nil, style: previewStyle, starterPreview: starterPlacement,
                                farmStages: farm?.fields.map { $0.stage(at: Date()) },
                                farmFruitStage: farm.map { $0.orchardWatered == nil ? 0 : $0.orchardRemaining(at: Date()) > 0 ? 1 : 2 },
                                bakerPresent: farm.map { $0.breadMade > 0 },
                                storytellerPresent: farm.map { $0.picnicServed },
                                production: farm?.production(at: Date()) ?? [], ovenRevealed: ovenIntroduced)
    }
    private func updateBridge(_ prepared: HomesteadProjection? = nil) {
        do {
            let snapshot = try prepared ?? renderedProjection()
            projection = snapshot
            bridge.update(snapshot, active: active, previewing: panelOpen && isVisible && hasLandscapeSpace && phase == .active)
            updateLandPreview()
            noteSunnyDay()
            noteTreeThirst(watering: noteTreeWatering())
        } catch { self.error = error.localizedDescription }
    }
    private func handle(_ type: String, _ payload: [String: Any]) {
        if type == "feedbackAnchor" { menuSession.receiveAnchor(payload); return }
        if let origin = payload["origin"] as? [String: Double], let x = origin["x"], let y = origin["y"],
           x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) {
            menuSession.mapControl(.init(x: worldCanvasFrame.minX + x * worldCanvasFrame.width,
                                        y: worldCanvasFrame.minY + y * worldCanvasFrame.height))
        }
        guard active else { return }
        if type == "productionRequested", payload["station"] as? String == "construction",
           let id = payload["id"] as? String,
           let object = projection?.items.first(where: { $0.id.uuidString == id }),
           HomesteadConstruction.current(object.kind, kid: kid) != nil {
            openConstruction(object.kind); return
        }
        if type == "visited", selected == nil, let id = payload["id"] as? String,
           let object = projection?.items.first(where: { $0.id.uuidString == id }),
           HomesteadConstruction.current(object.kind, kid: kid) != nil {
            openConstruction(object.kind); return
        }
        if type == "productionRequested", selected == nil, starterPlacement == nil,
           let raw = payload["station"] as? String, let station = HomesteadFarm.Station(rawValue: raw),
           let placeID = payload["id"] as? String,
           let status = projection?.production.first(where: { $0.station == raw && $0.placeID == placeID }) {
            // A ready bubble collects on the map; anything else opens its card.
            if status.state == 2, allowsChanges, collectFromMap(station) { return }
            openFarm(station); return
        }
        if type == "cameraPanned" { camera = "pan" }
        if type == "landRequested", selected == nil, !showsChapter,
           let raw = payload["side"] as? String, let land = HomesteadLand(rawValue: raw) {
            openBottomMenu("land"); inspectShelf(.land(land))
        }
        if type == "selected", let raw = payload["id"] as? String, let id = UUID(uuidString: raw),
           let held = projection?.items.first(where: { $0.id == id }), HomesteadSpots.catalogue[held.kind] != nil {
            bridge.send("cancel", payload: [:]); return
        }
        if type == "selected", allowsChanges, starterPlacement == nil, let raw = payload["id"] as? String, let id = UUID(uuidString: raw), projection?.items.contains(where: { $0.id == id }) == true {
            selected = id; previewCell = nil; previewRotation = nil; placementFailure = nil; previewValid = false; hasEditedMap = true
            Haptics.selection()
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.Announcement("Piece selected. Move it, then choose Place or Cancel.").post()
            }
            bridge.send("select", payload: ["id": raw, "fromHold": payload["gesture"] as? String == "hold"])
        }
        if type == "gather", selected == nil, starterPlacement == nil,
           let raw = payload["producer"] as? String, let producer = HomesteadProducer(rawValue: raw) {
            collect(producer)
        }
        if type == "visited", selected == nil, starterPlacement == nil,
           let raw = payload["id"] as? String, let id = UUID(uuidString: raw),
           let object = projection?.items.first(where: { $0.id == id && $0.isPlaced }) {
            openOwnedPlace(object)
            return
        }
        if type == "activity" {
            if payload["text"] as? String == "A sunny day" {
                activity = String(localized: "A sunny day")
            } else {
            switch payload["key"] as? String {
            case "walking": activity = String(localized: "Walking through your homestead")
            case "water": activity = String(localized: "Watering the garden")
            case "rest", "seating": activity = String(localized: "Resting on a sunny seat")
            case "wave": activity = String(localized: "Waving hello")
            default: activity = String(localized: "Enjoying your homestead")
            }
            }
        }
        if type == "preview", let selected,
           let cell = payload["cell"] as? [String: Int], let x = cell["x"], let z = cell["z"],
           let rotation = payload["rotation"] as? Int, let revision = payload["revision"] as? Int,
           (-32...32).contains(x), (-32...32).contains(z), (0..<4).contains(rotation),
           var object = projection?.items.first(where: { $0.id == selected }) {
            object.cell = .init(x: x, z: z); object.rotation = rotation
            let items = projection?.items ?? []
            let land = Set((projection?.land ?? []).compactMap(HomesteadLand.init(rawValue:)))
            let moved = previewCell != object.cell
            previewCell = object.cell
            previewRotation = rotation
            previewValid = payload["valid"] as? Bool == true
                && HomesteadGeometry.canPlace(object, among: items, land: land)
                && HomesteadNavigationRules.hasUsableRoutes(objects: items.map { $0.id == selected ? object : $0 }, land: land)
            if moved && UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.Announcement("Column \(x + 1), row \(z + 1). " + (previewValid ? "Clear spot" : "Choose another spot")).post()
            }
            bridge.send("previewVerdict", payload: ["revision": revision, "valid": previewValid])
        }
        if type == "placementIntent", let selected,
           let raw = payload["id"] as? String, UUID(uuidString: raw) == selected,
           let rawCommand = payload["commandID"] as? String, let commandID = UUID(uuidString: rawCommand),
           let cell = payload["cell"] as? [String: Int], let x = cell["x"], let z = cell["z"],
           let rotation = payload["rotation"] as? Int,
           var object = projection?.items.first(where: { $0.id == selected }) {
            object.cell = .init(x: x, z: z); object.rotation = rotation
            do {
                if let starterPlacement {
                    try HomesteadActions.placeStarter(starterPlacement, object: object, commandID: commandID,
                        kid: kid, in: context, allowsChanges: demoAuthorization)
                } else {
                    try HomesteadActions.apply(.arrange(object), commandID: commandID, kid: kid, in: context, allowsChanges: demoAuthorization)
                }
                savedPlace(object.kind, identity: commandID.uuidString, from: "action:Place")
                cancelSelection(); Task { await refresh() }
            } catch { placementFailure = error.localizedDescription; self.error = error.localizedDescription }
        }
    }
    private func collect(_ producer: HomesteadProducer) {
        guard allowsChanges else { return }
        if farm != nil && [.garden, .windmill, .orchard].contains(producer) {
            openFarm(producer == .garden ? .field : producer == .windmill ? .mill : .orchard); return
        }
        if producer == .garden { openingOpen = true; return }
        do {
            let amount = try HomesteadMaterialActions.collect(producer, kid: kid, in: context, allowsChanges: demoAuthorization)
            guard !amount.isEmpty else { return }
            #if DEBUG
            try playground?.advanceProduction()
            #endif
            SoundEffects.playPlaceSet(); Haptics.selection()
            withAnimation(reducedMotion ? nil : .snappy) { collected = amount }
            if UIAccessibility.isVoiceOverRunning {
                AccessibilityNotification.Announcement("Collected \(amount.label)").post()
            }
            Task { await refresh() }
        } catch { self.error = error.localizedDescription }
    }
    private func persistFarm(_ action: HomesteadFarmEvent.Action, now: Date) -> Bool {
        do {
            #if DEBUG
            let injectable: Bool
            switch action { case .tend, .make: injectable = true; default: injectable = false }
            if injectable, UITestLaunchConfiguration.isEnabled, ProcessInfo.processInfo.arguments.contains("-ui-testing-world-save-failure"), !injectedFarmFailure {
                injectedFarmFailure = true
                throw CocoaError(.fileWriteOutOfSpace)
            }
            #endif
            try HomesteadFarmJournal.perform(action, kid: kid, in: context, now: now)
            normalFarm.restore(HomesteadFarmJournal(kid: kid).farm)
            normalFarm.reconcileMeals(materials.balance.food)
            if projects.isBuilt(.nook) { normalFarm.fundPicnic() }
            updateBridge()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    /// Same saved actions as the card's Collect; only the entry point differs.
    private func collectFromMap(_ station: HomesteadFarm.Station) -> Bool {
        guard let farm, !projectBusy else { return false }
        let now = Date()
        switch station {
        case .field:
            let ripe = farm.fields.indices.filter { farm.fields[$0].stage(at: now) == 4 }
            let saved = ripe.filter { farm.tend($0, now: now) }
            guard let first = saved.first else { return false }
            productionSaved(.wheat, true, "field:\(first):4:" + UUID().uuidString, count: 2 * saved.count)
        case .orchard:
            guard farm.orchardRemaining(at: now) == 0, farm.tendOrchard(now: now) else { return false }
            productionSaved(.fruit, true, "orchard:" + UUID().uuidString)
        default:
            guard let job = farm.jobs[station], job.remaining(at: now) == 0, collectFarmRecipe(station) else { return false }
            productionSaved(job.recipe.output, true, "collect:" + job.recipe.rawValue + ":" + String(job.started.timeIntervalSince1970), count: job.recipe.quantity)
        }
        return true
    }
    private func collectFarmRecipe(_ station: HomesteadFarm.Station) -> Bool {
        #if DEBUG
        if let playground {
            do {
                let collected = try playground.collectFarmRecipe(station)
                if collected { updateBridge() }
                return collected
            } catch { self.error = error.localizedDescription; return false }
        }
        #endif
        return persistFarm(.collect(station), now: Date())
    }
    private func performOpening(_ action: HomesteadOpeningEvent.Action, round: Bool) async throws {
        #if DEBUG
        let transport = try playground.map { try CloudSpendingTransport.makePlayground($0) }
        try await HomesteadOpeningActions.perform(action, expected: opening.nextSequence, roundLoaf: round,
            kid: kid, in: context, transport: transport, access: demoAuthorization)
        if action == .begin || action == .harvest { try playground?.advanceProduction() }
        #else
        try await HomesteadOpeningActions.perform(action, expected: opening.nextSequence, roundLoaf: round, kid: kid, in: context)
        #endif
        await refresh(); Haptics.selection()
    }
    private func openingBuildGoal(_ target: HomesteadBuildTarget) -> HomesteadGoal {
        HomesteadGoal.forTarget(target, kid: kid, ledger: materials, projects: projects)
    }
    private func openFinishedConstruction(_ kind: HomesteadKind) {
        closePanel()
        switch kind {
        case .barn: openFarm(.barn)
        case .grill: openFarm(.grill)
        case .windmill: openFarm(.mill)
        case .orchard: openFarm(.orchard)
        case .nook: openFarm(.orders)
        case .workshop: workshopActivity = true
        case .greenhouse: greenhouseActivity = true
        default: inspectOpeningPlace(kind)
        }
        updateBridge()
    }
    private func openConstruction(_ kind: HomesteadKind) {
        resetPanels(); constructionKind = kind; updateBridge()
        framePlaced(kind)
    }
    /// One timed building at a time. The child is taken to that site; the receipt clock is unchanged.
    private func presentConstruction(_ kind: HomesteadKind) {
        openConstruction(kind)
        if let item = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) {
            bridge.send("visit", payload: ["id": item.id.uuidString])
        }
    }
    private func inspectOpeningPlace(_ kind: HomesteadKind) {
        if HomesteadConstruction.current(kind, kid: kid) != nil { openConstruction(kind); return }
        closePanel()
        if let object = projection?.items.first(where: { $0.kind == kind }),
           object.isPlaced == false { selectCatalogueObject(object); return }
        if let expansion = LivingWorldExpansion.allCases.first(where: { $0.kind == kind }), !expansion.isOwned(by: kid) {
            followGoal(openingBuildGoal(.expansion(expansion)))
        } else if kind == .nook && !projects.isBuilt(.nook) {
            followGoal(openingBuildGoal(.project(.nook)))
        } else if let object = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) {
            // A cached Building action may be tapped just after its receipt
            // clock finishes. Keep the completed site reachable through Ready.
            if [.windmill, .nook, .orchard, .barn, .grill, .workshop, .greenhouse].contains(kind) {
                openConstruction(kind)
                return
            }
            framePlaced(kind)
            bridge.send("visit", payload: ["id": object.id.uuidString])
        }
        updateBridge(); updateLandPreview()
    }
    private func resolveBuildRequirement(_ target: HomesteadBuildTarget) {
        guard !projectBusy else { return }
        resetPanels()
        #if DEBUG
        if let playground {
            let step: WorldSandboxSession.BuildStep
            switch target {
            case .project(let project): step = .project(project)
            case .expansion(let item): step = .expansion(item)
            }
            if let requirement = playground.requirementStep(for: step) {
                switch requirement {
                case .wheat: openFarm(.field)
                case .mill: inspectOpeningPlace(.windmill)
                case .meals: openFarm(.pantry)
                case .picnic:
                    if projects.isBuilt(.nook) { openFarm(.orders) } else { inspectOpeningPlace(.nook) }
                case .meadow: expansionChoice = .meadow; expansionCurrency = projects.currency
                case .orchard: inspectOpeningPlace(.orchard)
                case .tart: openFarm(.orders)
                case .bread: openFarm(.oven)
                }
                updateBridge(); return
            }
        }
        #endif
        followGoal(openingBuildGoal(target)); updateBridge()
    }
    private func followGoal(_ goal: HomesteadGoal) {
        switch goal.step {
        case .grow(.food):
            if farm != nil { openFarm(.pantry) } else { openingOpen = true }
        case .missions, .grow, .earn: openMissions()
        case .landFirst: openBottomMenu("land")
        case .collect(_, let producer): focusProducer(producer)
        case .build:
            closePanel()
            switch goal.target {
            case .project(let project):
                requestedProject = project; previewStyle = projects.style(project); inventory = true
            case .expansion(let item):
                expansionChoice = item; expansionCurrency = projects.currency
            }
            updateBridge(); updateLandPreview()
        }
    }
    private func resolveMaterialRequirement(_ material: HomesteadMaterial) {
        resetPanels()
        if material == .food { openFarm(.pantry) }
        else if let source = materials.source(for: material), materials.ready(source)[material] > 0 {
            focusProducer(source)
        } else { openMissions() }
        updateBridge()
    }
    /// The card's ring is a window onto the real place: centre it there at one fixed scale.
    private func frameProduction() {
        guard let key = productionFocusKey, let station = HomesteadFarm.Station(rawValue: key), productionRing.width > 0,
              sceneFrame.width > 0, sceneFrame.height > 0 else { return }
        let kind: HomesteadKind = station == .orders && projects.isBuilt(.nook) ? .nook : station.kind
        guard let item = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) else { return }
        cameraBeforePlace = cameraBeforePlace ?? camera
        camera = "place"; focusedPlace = item.id
        let shift = ["x": (productionRing.midX - sceneFrame.minX) / sceneFrame.width - 0.5, "y": (productionRing.midY - sceneFrame.minY) / sceneFrame.height - 0.5]
        // The ring's height share lets the camera fit the whole place inside it.
        bridge.send("camera", payload: ["mode": "place", "id": item.id.uuidString, "station": station.rawValue,
                                        "production": true, "focusShift": shift, "ring": productionRing.height / sceneFrame.height, "resetZoom": true])
    }
    /// Dressing the character brings the camera close to them; Close hands the view back.
    private func frameCharacter() {
        cameraBeforePlace = cameraBeforePlace ?? camera
        camera = "detail"
        bridge.send("camera", payload: ["mode": "detail", "resetZoom": true])
    }
    private func framePlaced(_ kind: HomesteadKind) {
        guard let item = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) else { return }
        cameraBeforePlace = cameraBeforePlace ?? camera
        camera = "place"
        focusedPlace = item.id
        bridge.send("camera", payload: ["mode": "place", "id": item.id.uuidString, "resetZoom": true])
    }
    private func focusProducer(_ producer: HomesteadProducer) {
        camera = "place"
        if let kind = producer.kind, let item = projection?.items.first(where: { $0.kind == kind && $0.isPlaced }) {
            focusedPlace = item.id
            bridge.send("camera", payload: ["mode": "place", "id": item.id.uuidString, "resetZoom": true])
        } else {
            bridge.send("camera", payload: ["mode": "place", "id": "edge:" + producer.rawValue, "resetZoom": true])
        }
        enqueue(.bubbles(), force: true)
    }
    /// One message at a time; each tip shows once per child on this device.
    private func enqueue(_ next: HomesteadTip, force: Bool = false) {
        let memory = HomesteadTipMemory()
        guard force || !memory.hasShown(next, childID: kid.id),
              tip?.key != next.key, !tipQueue.contains(where: { $0.key == next.key }) else { return }
        tipQueue.append(next)
        showNextTip()
    }
    /// At most one new tip per refresh, so a returning child is never flooded.
    private func queueTips() {
        guard showsMaterials, isVisible, bridge.status == .ready, tip == nil, tipQueue.isEmpty else { return }
        let ledger = materials
        var candidates: [HomesteadTip] = [.materials(), .moving()]
        if !ledger.readyProducers.isEmpty { candidates.append(.bubbles()) }
        // A place built with materials announces what it now adds, once.
        candidates += HomesteadBuildTarget.ordered.filter(ledger.isUsed).map { HomesteadTip.built($0) }
        if let goal, goal.winsLeft == 0, goal.step != .landFirst { candidates.append(.unlocked(goal.target)) }
        candidates += ledger.active.sorted { $0.rawValue < $1.rawValue }.filter(ledger.isFull).map { HomesteadTip.full($0) }
        let memory = HomesteadTipMemory()
        if let next = candidates.first(where: { !memory.hasShown($0, childID: kid.id) }) { enqueue(next) }
    }
    private func showNextTip() {
        guard canShowNewTip, tip == nil, !tipQueue.isEmpty else { return }
        let next = tipQueue.removeFirst()
        HomesteadTipMemory().markShown(next, childID: kid.id)
        withAnimation(reducedMotion ? nil : .snappy) { tip = next }
        if UIAccessibility.isVoiceOverRunning { AccessibilityNotification.Announcement(next.text).post() }
    }
    private func dismissTip() {
        withAnimation(reducedMotion ? nil : .snappy) { tip = nil }
        Task { try? await Task.sleep(for: .milliseconds(450)); showNextTip() }
    }
    private func cancelSelection() {
        selected = nil; previewCell = nil; previewValid = false; previewRotation = nil; placementPage = nil; placementFailure = nil
        starterPlacement = nil; buildingDraft = nil; bridge.send("cancel")
        // Discard a chapter draft without saving its ownership or position.
        do { projection = try renderedProjection(); updateBridge() }
        catch { self.error = error.localizedDescription }
    }
    private func beginStarterPlacement(_ event: LivingWorldStarter.Event) {
        guard allowsChanges, let key = event.homesteadObjectKey else { return }
        closePanel()
        starterPlacement = event
        do {
            projection = try renderedProjection()
            let id = HomesteadIdentity.stable(childID: kid.id, key: key)
            guard let object = projection?.items.first(where: { $0.id == id }) else { throw HomesteadActions.Failure.invalid }
            selected = id; previewCell = object.cell; previewRotation = nil; placementFailure = nil; previewValid = false
            updateBridge()
            bridge.send("select", payload: ["id": id.uuidString])
        } catch { self.error = error.localizedDescription }
    }
    private func placementControls(_ object: HomesteadObject) -> some View {
        var draft = object
        draft.cell = previewCell
        draft.rotation = previewRotation ?? object.rotation
        let status = HomesteadPlacementStatus.text(object: draft, items: projection?.items ?? [],
            land: Set((projection?.land ?? []).compactMap(HomesteadLand.init(rawValue:))), hasPreview: previewCell != nil,
            engineValid: previewValid, allowsChanges: allowsChanges, failure: placementFailure)
        return HomesteadBuilderBar(title: object.kind.title, icon: object.kind.controlIcon,
            location: previewCell.map { "Column \($0.x + 1), row \($0.z + 1). " + (previewValid ? "Clear spot" : "Choose another spot") } ?? "Choose a spot",
            status: status, valid: previewValid, statusIsReady: previewValid && allowsChanges && placementFailure == nil, allowsChanges: allowsChanges,
            infoEnabled: true, lookEnabled: allowsChanges && starterPlacement == nil && buildingDraft == nil && !builderLookNames(object).isEmpty,
            info: { placementPage = .info; updateBridge() }, look: { placementPage = .look; updateBridge() },
            rotate: { bridge.send("rotate") }, place: { bridge.send("confirm") }, cancel: cancelSelection,
            nudge: { x, z in bridge.send("nudge", payload: ["x": x, "z": z]) })
    }
    private func closeBuilderPage() { placementPage = nil; updateBridge() }
    private func updateBuilderFraming() {
        let fraction = selected == nil ? 0 : min(0.65, (104 + 24) / max(1, worldWindowSize.height))
        bridge.send("camera", payload: ["framing": fraction])
    }
    private func builderLookNames(_ object: HomesteadObject) -> [String] {
        if let project = LivingWorldProject.allCases.first(where: { $0.worldKind == object.kind }) { return project.styles }
        if object.kind == .windmill { return ["Sage roof", "Clay roof"] }
        if object.kind == .orchard { return ["Apple trees", "Pear trees", "Plum trees"] }
        return []
    }
    private func builderLooks(_ object: HomesteadObject) -> some View {
        HomesteadItemStrip(items: Array(builderLookNames(object).enumerated()), minimumWidth: 60, rowHeight: 64) { entry in
            Button {
                do {
                    if let project = LivingWorldProject.allCases.first(where: { $0.worldKind == object.kind }) {
                        try LivingWorldProjectActions.apply(.style, project: project, style: entry.offset, kid: kid, context: context, allowsChanges: demoAuthorization)
                    } else {
                        let action: HomesteadChange = object.kind == .windmill ? .windmillLook(entry.offset) : .orchardVariety(entry.offset)
                        try HomesteadActions.apply(action, commandID: UUID(), kid: kid, in: context, allowsChanges: demoAuthorization)
                    }
                    updateBridge(); savedPlace(object.kind, identity: "look:" + UUID().uuidString)
                } catch { self.error = error.localizedDescription }
            } label: {
                // A colour swatch says the look; its name is spoken.
                WorldLookSwatch(color: WorldLookSwatch.color(for: entry.element), selected: object.style == entry.offset)
                    .frame(width: 56, height: 56).contentShape(Circle())
            }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges)
                .accessibilityLabel(Text(LocalizedStringKey(entry.element))).accessibilityAddTraits(object.style == entry.offset ? .isSelected : [])
                .accessibilityIdentifier("homestead.builder.look.\(entry.offset)")
        }
    }
    private func builderInfo(_ object: HomesteadObject) -> some View {
        let owned = starterPlacement == nil && buildingDraft == nil
        let activity = [.barn, .grill, .orchard, .greenhouse, .workshop].contains(object.kind)
        let entries = ["Move"] + (owned && activity ? ["Play"] : []) + (owned ? ["Put away"] : []) + ["Left", "Right", "Up", "Down"]
        return HStack(spacing: 8) {
            Text(LocalizedStringKey(object.kind.purpose)).font(.caption).frame(width: 140).accessibilityIdentifier("homestead.details.purpose")
            HomesteadItemStrip(items: entries, minimumWidth: 80, rowHeight: 64) { entry in
                Button {
                    closeBuilderPage()
                    switch entry {
                    case "Move": break
                    case "Right": bridge.send("nudge", payload: ["x": 1])
                    case "Left": bridge.send("nudge", payload: ["x": -1])
                    case "Up": bridge.send("nudge", payload: ["z": -1])
                    case "Down": bridge.send("nudge", payload: ["z": 1])
                    case "Put away":
                        do {
                            try HomesteadActions.apply(.remove(object.id), commandID: UUID(), kid: kid, in: context, allowsChanges: demoAuthorization)
                            cancelSelection(); Task { await refresh() }
                        } catch { self.error = error.localizedDescription }
                    default:
                        cancelSelection()
                        guard error == nil else { return }
                        if HomesteadConstruction.current(object.kind, kid: kid) != nil { openConstruction(object.kind) }
                        else if object.kind == .orchard { orchardActivity = true }
                        else if object.kind == .greenhouse { greenhouseActivity = true }
                        else if object.kind == .workshop { workshopActivity = true }
                        else { openFarm(object.kind == .barn ? .barn : .grill) }
                    }
                } label: {
                    VStack(spacing: 4) {
                        WorldControlIcon(symbol: entry == "Put away" ? "archivebox" : entry == "Play" ? object.kind.controlIcon : entry == "Move" ? "figure.walk" : "arrow." + (entry == "Up" ? "up" : entry == "Down" ? "down" : entry.lowercased())).frame(width: 24, height: 24)
                        Text(LocalizedStringKey(entry)).font(.caption.bold())
                    }.frame(width: 80, height: 64).background(HomesteadJournalControlSurface(state: .available))
                }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges)
                    .accessibilityIdentifier(entry == "Move" ? "homestead.details.move" : entry == "Play" ? "homestead.\(object.kind.rawValue).play" : "homestead.builder." + entry.lowercased())
            }.accessibilityIdentifier("homestead.builder.info.actions")
        }
    }
    private var canShowTip: Bool { allowsChanges && !accessHelpOpen && isVisible && hasLandscapeSpace && phase == .active && selected == nil && !panelOpen && !exitRequested && !starter.isLoading }
    private var canShowNewTip: Bool { canShowTip && farm?.notice == nil && collected == nil }
    private func dismissAttachedTip() {
        if farm?.notice != nil { farm?.clearNotice() }
        else if collected != nil { collected = nil }
        else { dismissTip() }
    }
    private var attachedTip: HomesteadTip? {
        if let notice = farm?.notice { return .init(key: "farm-notice", icon: "material.food", text: notice) }
        if let collected { return .init(key: "collected", icon: collected.parts.first?.material.icon ?? "material.food", text: "+" + collected.label) }
        return tip
    }
    private func beginBuildingPlacement(_ item: LivingWorldExpansion) {
        guard allowsChanges, buildRequirement(item) == nil else { return }
        let pending = kid.rewardClaims.first { $0.status == .pending && $0.storeDetails?.worldProjectRaw == item.rawValue && $0.storeDetails?.currency == projects.currency }
        if let raw = pending?.storeDetails?.worldPlacementRaw,
           let frozen = LivingWorldExpansion.decodeObject(raw, childID: kid.id, item: item) {
            buildingDraft = frozen; expansionCurrency = pending?.storeDetails?.currency
            buyExpansion()
            return
        }
        do {
            let state = try HomesteadActions.state(for: kid)
            var object = item.draftObject(childID: kid.id)
            object.cell = HomesteadGeometry.nearestPlacement(for: object, among: state.objects, land: state.land, requiringRoutes: true)
            guard object.cell != nil else { throw HomesteadActions.Failure.blocked }
            buildingDraft = object
            expansionCurrency = projects.currency
            buyExpansion()
        } catch { self.error = error.localizedDescription }
    }

    private func requestExpansion(_ item: LivingWorldExpansion, currency: RewardCurrency) throws -> RewardClaim {
        let object = item.kind != nil ? buildingDraft : nil
        #if DEBUG
        if let playground { return try playground.requestExpansion(item, currency: currency, object: object, timedConstruction: true) }
        #endif
        return try OnlineSpending.requestExpansion(item, currency: currency, object: object,
            kid: kid, in: context, allowsChanges: demoAuthorization?(), timedConstruction: true)
    }

    private func buyExpansion() {
        guard !projectBusy, let item = expansionChoice, let currency = expansionCurrency,
              buildRequirement(item) == nil else { return }
        if let kind = item.kind, HomesteadConstruction.duration(for: kind) != nil,
           let site = HomesteadConstruction.pending(kid: kid).first {
            presentConstruction(site.kind)
            return
        }
        // A frozen pending request already passed this check when it was made.
        let resuming = kid.rewardClaims.contains { $0.status == .pending && $0.storeDetails?.worldProjectRaw == item.rawValue }
        if !resuming {
            do { try HomesteadMaterialActions.requireMaterials(for: .expansion(item), kid: kid) }
            catch { cancelSelection(); self.error = error.localizedDescription; return }
        }
        projectBusy = true
        Task {
            defer { projectBusy = false }
            do {
                let claim = try requestExpansion(item, currency: currency)
                #if DEBUG
                let transport = try playground.map { try CloudSpendingTransport.makePlayground($0) }
                try await OnlineSpending.approve(claim, in: context, giveNow: true, transport: transport, access: demoAuthorization)
                #else
                try await OnlineSpending.approve(claim, in: context, giveNow: true)
                #endif
                // The receipt is committed; materials follow under the place's identity.
                try HomesteadMaterialActions.recordUse(for: .expansion(item), kid: kid, in: context)
                if let kind = item.kind { savedPlace(kind, identity: claim.id.uuidString, from: "build.confirm") }
                else { _ = menuSession.saved(claim.id.uuidString, picture: .place(.cottage), from: "build.confirm", destination: "dock.build", request: requestFeedbackAnchor) }
                projectBusy = false; closePanel(); cancelSelection(); await refresh()
                if let kind = item.kind, let object = projection?.items.first(where: { $0.kind == kind }) {
                    selectCatalogueObject(object)
                }
            } catch { self.error = OnlineSpending.worldPurchaseMessage(for: error) }
        }
    }
    private func expansionPanel(_ item: LivingWorldExpansion) -> HomesteadExpansionPanel {
        HomesteadExpansionPanel(item: item, kid: kid, currency: expansionCurrency ?? projects.currency,
            confirming: expansionQuote, busy: projectBusy, allowsChanges: allowsChanges,
            choose: { if item.kind != nil { beginBuildingPlacement(item) } else { expansionQuote = true; expansionCurrency = projects.currency } },
            buy: buyExpansion, back: {
                expansionQuote = false; expansionChoice = nil; inventory = true
                catalogueSection = item.land == nil ? "build" : "land"
                shelfSelection = item.land.map { .land($0) } ?? item.kind.map { .piece($0) }
                if let kind = item.kind { shelfCategory = .of(kind) }
                updateBridge(); updateLandPreview()
            }, resolveRequirement: { resolveBuildRequirement(.expansion(item)) }, resolveMaterial: resolveMaterialRequirement,
            missions: openMissions, buildRequirement: buildRequirement(item), showsMissionRequirement: !sequentialPlayground, close: closePanel)
    }
    private func projectPanel(_ project: LivingWorldProject) -> HomesteadProjectPanel {
        var panel = HomesteadProjectPanel(kid: kid, project: project,
            missions: openMissions, resolveRequirement: { resolveBuildRequirement(.project(project)) }, resolveMaterial: resolveMaterialRequirement,
            finished: {
                projectBusy = false; closePanel()
                Task {
                    await refresh()
                    if let object = projection?.items.first(where: { $0.kind == project.worldKind }) {
                        selectCatalogueObject(object)
                    }
                }
            },
            visit: {
                if let item = projection?.items.first(where: { $0.kind == project.worldKind }) { openOwnedPlace(item) }
            }, preview: { style in
                previewStyle = style; updateBridge()
            }, busyChanged: { projectBusy = $0 })
        #if DEBUG
        panel.playground = playground
        #endif
        panel.showSite = { presentConstruction($0) }
        panel.close = closePanel
        panel.back = { requestedProject = nil; inventory = true; shelfSelection = .piece(project.worldKind); updateBridge() }
        panel.committed = { target, identity in
            if case .project(let value) = target { savedPlace(value.worldKind, identity: identity, from: "build.confirm") }
        }
        return panel
    }
    private func openRequestedProject() {
        guard !introductionVisible, isVisible, !showsChapter, !starter.isLoading, !projectBusy, let projectRequest else { return }
        closePanel()
        switch projectRequest {
        case .project(let project):
            if let object = projection?.items.first(where: { $0.kind == project.worldKind }) { openOwnedPlace(object) }
            else { requestedProject = project; inventory = true }
        case .expansion(let item):
            if let kind = item.kind, let object = projection?.items.first(where: { $0.kind == kind }) { openOwnedPlace(object) }
            else { expansionChoice = item; expansionCurrency = projects.currency }
        }
        onProjectHandled()
    }
    private func inspectStoryPlace(_ kind: HomesteadKind) {
        closePanel()
        if let item = LivingWorldExpansion.allCases.first(where: { $0.kind == kind }), !item.isOwned(by: kid) {
            expansionChoice = item; expansionCurrency = projects.currency
        } else { assetDetails = .piece(kind) }
    }
    private func catalogueObjects(_ kind: HomesteadKind) -> [HomesteadObject] {
        (projection?.items ?? []).filter { $0.kind == kind }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    private func selectCatalogueObject(_ object: HomesteadObject) {
        // A70: pieces with yard spots never free-drag; they go to, or hop between, their spots.
        if HomesteadSpots.catalogue[object.kind] != nil { placeInSpot(object); return }
        guard let projection else { return }
        let land = Set(projection.land.compactMap(HomesteadLand.init(rawValue:)))
        let cell = object.isPlaced ? HomesteadGeometry.nearestPlacement(for: object, among: projection.items, land: land, requiringRoutes: true)
            : HomesteadGeometry.bestPlacement(for: object, among: projection.items, land: land)
        guard let cell else {
            self.error = HomesteadActions.Failure.blocked.localizedDescription
            return
        }
        closePanel(); selected = object.id; previewRotation = nil; placementFailure = nil; previewValid = false; hasEditedMap = true
        previewCell = cell
        camera = "place"; focusedPlace = object.id
        Haptics.selection()
        bridge.send("select", payload: ["id": object.id.uuidString, "cell": ["x": cell.x, "z": cell.z]])
    }
    /// Unplaced or off-spot pieces take their first free spot; a piece already on a
    /// spot hops to its kind's next free spot. Saved as one ordinary `.arrange`.
    private func placeInSpot(_ object: HomesteadObject) {
        guard let projection, allowsChanges, let spots = HomesteadSpots.catalogue[object.kind] else { return }
        let land = Set(projection.land.compactMap(HomesteadLand.init(rawValue:)))
        var target: HomesteadCell?
        if object.isPlaced, object.rotation == 0, let index = spots.firstIndex(where: { $0.cell == object.cell }) {
            for step in 1..<max(1, spots.count) {
                var candidate = object; candidate.cell = spots[(index + step) % spots.count].cell
                if HomesteadGeometry.canPlace(candidate, among: projection.items, land: land),
                   HomesteadNavigationRules.hasUsableRoutes(objects: projection.items.map { $0.id == object.id ? candidate : $0 }, land: land) {
                    target = candidate.cell; break
                }
            }
        } else {
            target = HomesteadSpots.firstFree(for: object, among: projection.items, land: land)
        }
        guard let target else { Haptics.selection(); return }
        var moved = object; moved.cell = target; moved.rotation = 0; moved.landGridVersion = 2
        do {
            try HomesteadActions.apply(.arrange(moved), commandID: UUID(), kid: kid, in: context, allowsChanges: demoAuthorization)
            closePanel()
            _ = menuSession.saved(UUID().uuidString, picture: .place(object.kind), destination: "map:" + object.id.uuidString, request: requestFeedbackAnchor)
            Task { await refresh() }
        } catch { self.error = error.localizedDescription }
    }
    private func catalogueIdentifier(_ object: HomesteadObject) -> String {
        object.id == HomesteadIdentity.stable(childID: kid.id, key: "base:tree") ? "homestead.object.growthTree" : "homestead.object.\(object.id.uuidString)"
    }
    private func cataloguePosition(_ object: HomesteadObject) -> String {
        object.cell.map { "Column \($0.x + 1), row \($0.z + 1)" } ?? "Put away"
    }
    private var selectedToolbeltTab: HomesteadToolbeltTab? {
        guard panelOpen else { return nil }
        if missionsOpen { return .missions }
        if worldMenu || settingsOpen || look || extras || sandboxTools { return .more }
        if inventory || placeOverview != nil { return catalogueSection == "land" ? .land : .build }
        if let item = expansionChoice { return item.land == nil ? .build : .land }
        if openingOpen || breadStoryOpen || meadowStoryOpen || orchardActivity || greenhouseActivity || workshopActivity { return .farm }
        if assetDetails != nil || constructionKind != nil { return .build }
        return nil
    }
    /// The map keeps only places, ready goods and Build (owner update 2026-11-03):
    /// orders open from their place or the goal ticket, the streak lives on Today,
    /// and both stay in More.
    @ViewBuilder private var railControls: some View { EmptyView() }
    /// Build dot: the goal names a place whose gates, materials and price are met.
    private var buildReady: Bool {
        guard allowsChanges, !showsChapter else { return false }
        let target: HomesteadBuildTarget
        switch farmGoal {
        case .windmill: target = .expansion(.windmill)
        case .nook: target = .project(.nook)
        case .meadow: target = .expansion(.meadow)
        case .orchard: target = .expansion(.orchard)
        case .barn: target = .expansion(.barn)
        case .grill: target = .expansion(.grill)
        case .dog: target = .expansion(.doghouse)
        case .waterside: target = .expansion(.waterside)
        default: return false
        }
        return openingBuildGoal(target).isReady
    }
    /// Up to two extra goal cards for finished jobs, besides the one the goal
    /// ticket already names, so a harvest round is one tap per station.
    @ViewBuilder private var goalCards: some View {
        if let farm, !showsChapter && !starter.isLoading {
            TimelineView(.periodic(from: .now, by: 5)) { clock in
                let ticket: HomesteadFarm.Station? = { if case .collect(let station, _)? = farmGoal { return station }; return nil }()
                let ready = HomesteadFarm.Station.allCases.filter { station in
                    station != ticket && farm.jobs[station].map { $0.remaining(at: clock.date) == 0 } == true
                }.prefix(2)
                ForEach(Array(ready), id: \.self) { station in
                    if let job = farm.jobs[station] {
                        HomesteadRailButton(title: job.recipe.output.title, identifier: "homestead.goal.collect." + station.rawValue, spokenTitle: "Collect " + job.recipe.output.title,
                                            picture: { HomesteadFarmGoodIcon(good: job.recipe.output) }) { openFarm(station) }
                            .disabled(projectBusy || !allowsChanges)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
    private var bottomPlaceButtons: some View {
        HomesteadToolbelt(selected: selectedToolbeltTab, missionCount: projects.approvedWins, buildReady: buildReady, map: { overviewControl }, rail: { railControls }, goals: { goalCards }) { tab in
            if tab == .missions { openMissions() }
            else { openBottomMenu(tab.rawValue) }
        }.disabled(projectBusy)
    }
    private func inspectShelf(_ selection: HomesteadAssetSelection) {
        shelfSelection = selection
        switch selection {
        case .piece(let kind, _): shelfCategory = .of(kind)
        case .future(let id): shelfCategory = .of(futurePlace: id)
        case .land: break
        }
        updateBridge(); updateLandPreview()
        previewSpot(for: selection)
    }
    /// Before buying, the map glides to where the new piece would first go and
    /// marks its footprint. Nothing is granted or saved.
    private func previewSpot(for selection: HomesteadAssetSelection) {
        guard case .piece(let kind, _) = selection, catalogueObjects(kind).isEmpty, let projection else { clearSpotPreview(); return }
        let land = Set(projection.land.compactMap(HomesteadLand.init(rawValue:)))
        let draft = HomesteadObject(id: UUID(), kind: kind, cell: nil, rotation: 0)
        guard let cell = HomesteadGeometry.bestPlacement(for: draft, among: projection.items, land: land) else { clearSpotPreview(); return }
        cameraBeforePlace = cameraBeforePlace ?? camera
        camera = "pan"; spotPreview = cell
        bridge.send("spotPreview", payload: ["cell": ["x": cell.x, "z": cell.z], "w": draft.width, "d": draft.depth, "kind": kind.rawValue])
    }
    private func clearSpotPreview() {
        guard spotPreview != nil else { return }
        spotPreview = nil
        bridge.send("spotPreview", payload: ["clear": true])
    }
    private func shelfTarget(_ selection: HomesteadAssetSelection) -> HomesteadBuildTarget? {
        switch selection {
        case .piece(let kind, _):
            if let project = LivingWorldProject.allCases.first(where: { $0.worldKind == kind }) { return .project(project) }
            return LivingWorldExpansion.allCases.first(where: { $0.kind == kind }).map { .expansion($0) }
        case .land(let land): return LivingWorldExpansion.expansion(for: land).map { .expansion($0) }
        case .future: return nil
        }
    }
    private func shelfOwned(_ selection: HomesteadAssetSelection) -> Bool {
        switch selection {
        case .piece(let kind, _): return !catalogueObjects(kind).isEmpty
        case .land(let land): return projection?.land.contains(land.rawValue) == true
        case .future: return false
        }
    }
    private func shelfPage(_ selection: HomesteadAssetSelection) -> some View {
        let owned = shelfOwned(selection)
        let target = shelfTarget(selection)
        let building: HomesteadConstruction? = {
            if case .piece(let kind, _) = selection { return constructionClocks.first { $0.kind == kind } }
            return nil
        }()
        let canPrepare = owned || target != nil || (sequentialPlayground && {
            if case .piece(let kind, _) = selection { return [.bench, .rocks].contains(kind) }
            return false
        }())
        let landItem: LivingWorldExpansion? = {
            if case .land(let land) = selection { return LivingWorldExpansion.expansion(for: land) }
            return nil
        }()
        let landReady = landItem.map { HomesteadExpansionPanel.isReady(item: $0, kid: kid, currency: projects.currency, allowsChanges: allowsChanges, buildRequirement: buildRequirement($0)) } ?? false
        let state: HomesteadControlState = !owned && selection.shelfIsLand && landItem != nil
            ? (!allowsChanges ? .disabled : landReady ? .available : .locked)
            : canPrepare && (allowsChanges || selection.shelfIsLand) ? .available : .disabled
        return HomesteadShelfPage(selection: selection, requirements: shelfRequirements(selection), construction: building, clock: timeClock, affordable: owned || target.map { worldShelfBalance >= $0.price } ?? true,
            shownOnMap: spotPreview != nil, actionTitle: owned ? (selection.shelfIsLand ? "Done" : "Open") : selection.shelfIsLand ? "Review" : "Review",
            actionState: state, primaryIdentifier: !owned && landItem != nil ? "homestead.expansion.choose" : "homestead.shelf.primary",
            back: { self.shelfSelection = nil; clearSpotPreview(); updateLandPreview() }, close: closePanel) {
                shelfContinue(selection)
            }
    }
    private func shelfRequirements(_ selection: HomesteadAssetSelection) -> [HomesteadShelfRequirement] {
        if shelfOwned(selection) {
            let saved: Bool
            if case .piece(let kind, _) = selection { saved = catalogueObjects(kind).allSatisfy { !$0.isPlaced } }
            else { saved = false }
            return [.init(id: "owned", title: saved ? "Saved" : "Owned",
                icon: selection.shelfIsLand ? "map.fill" : saved ? "archivebox" : "house.fill", met: true, resolve: {})]
        }
        var chips: [HomesteadShelfRequirement] = []
        if let target = shelfTarget(selection) {
            if !allowsChanges {
                chips.append(.init(id: "access", title: "Parent access", icon: "lock.fill", resolve: { if accessIssue != nil { accessHelpOpen = true } else { error = "This view is read only." } }))
            }
            if starter.count < 3 {
                chips.append(.init(id: "chapter", title: "First chapter", icon: "place.cottage", resolve: {
                    openBottomMenu("build")
                }))
            }
            if !sequentialPlayground {
                chips.append(.init(id: "missions", title: "\(min(projects.approvedWins, target.requiredWins))/\(target.requiredWins) missions",
                    met: projects.approvedWins >= target.requiredWins, resolve: openMissions))
            }
            chips.append(.init(id: "currency", title: projects.currency.amountLabel(target.price), currency: projects.currency,
                met: worldShelfBalance >= target.price, resolve: openMissions))
            if case .expansion(let item) = target, !item.hasRequiredLand(for: kid) {
                chips.append(.init(id: "land", title: "West meadow", icon: "land", resolve: {
                    openBottomMenu("land"); inspectShelf(.land(.west))
                }))
            }
            for part in target.materials.parts {
                chips.append(.init(id: part.material.rawValue, title: "\(min(materials.balance[part.material], part.amount))/\(part.amount) \(part.material.title)",
                    icon: "material." + part.material.rawValue, met: materials.balance[part.material] >= part.amount,
                    resolve: { resolveMaterialRequirement(part.material) }))
            }
            let requirement: String?
            switch target { case .project(let p): requirement = buildRequirement(p); case .expansion(let e): requirement = buildRequirement(e) }
            if let requirement {
                // Picture the place that has to come first, not an arrow and a sentence.
                let needed = HomesteadKind.allCases.first { requirement.localizedCaseInsensitiveContains($0.title) }
                chips.append(.init(id: "sequence", title: requirement, icon: needed.map { "place." + $0.rawValue } ?? "arrow.up.forward.circle", resolve: { resolveBuildRequirement(target) }))
            }
        } else if case .piece(let kind, _) = selection, sequentialPlayground && [.bench, .rocks].contains(kind) {
            if let requirement = testDecorationRequirement(kind) {
                chips.append(.init(id: "sequence", title: requirement, icon: "arrow.right", resolve: { buildTestDecoration(kind) }))
            }
        } else {
            chips.append(.init(id: "future", title: "Coming soon", icon: "lock.fill", resolve: { error = "This place is not available yet." }))
            let land: HomesteadLand? = {
                if case .land(.north) = selection { return .east }
                if case .future(let id) = selection { return HomesteadFuturePlace.places.first { $0.id == id }?.land == "East waterside" ? .east : .north }
                return nil
            }()
            let futureTerms: (price: Double, wins: Int)? = {
                if case .land(.north) = selection { return (110, 70) }
                if case .future(let id) = selection, let place = HomesteadFuturePlace.places.first(where: { $0.id == id }) { return (place.price, place.wins) }
                return nil
            }()
            if let terms = futureTerms {
                chips.append(.init(id: "missions", title: "\(min(projects.approvedWins, terms.wins))/\(terms.wins) missions", met: projects.approvedWins >= terms.wins, resolve: openMissions))
                chips.append(.init(id: "currency", title: projects.currency.amountLabel(terms.price), currency: projects.currency, met: worldShelfBalance >= terms.price, resolve: openMissions))
            }
            if let land {
                chips.append(.init(id: "land", title: HomesteadAssetSelection.land(land).title, icon: "map.fill",
                    met: projection?.land.contains(land.rawValue) == true, resolve: { openBottomMenu("land"); inspectShelf(.land(land)) }))
            }
        }
        return chips
    }
    private func shelfContinue(_ selection: HomesteadAssetSelection) {
        guard !projectBusy else { return }
        shelfSelection = nil
        if case .land(let land) = selection {
            if let item = LivingWorldExpansion.expansion(for: land), !item.isOwned(by: kid) {
                guard HomesteadExpansionPanel.isReady(item: item, kid: kid, currency: projects.currency, allowsChanges: allowsChanges, buildRequirement: buildRequirement(item)) else {
                    resolveBuildRequirement(.expansion(item)); return
                }
                expansionChoice = item; expansionCurrency = projects.currency; expansionQuote = true
            }
            updateBridge(); updateLandPreview(); return
        }
        guard allowsChanges else { return }
        if case .piece(let kind, _) = selection {
            let objects = catalogueObjects(kind)
            if let object = objects.first {
                if objects.count == 1 { openOwnedPlace(object) }
                else { catalogueKind = kind }
            } else if let target = shelfTarget(selection) {
                switch target {
                case .project(let project): requestedProject = project; previewStyle = projects.style(project)
                case .expansion(let item): expansionChoice = item; expansionCurrency = projects.currency
                }
            } else if sequentialPlayground && [.bench, .rocks].contains(kind) { buildTestDecoration(kind) }
        }
        updateBridge(); updateLandPreview()
    }
    @ViewBuilder private func catalogueTile(_ kind: HomesteadKind, active: Bool = false) -> some View {
        let objects = catalogueObjects(kind)
        let saved = !objects.isEmpty && objects.allSatisfy { !$0.isPlaced }
        if let item = LivingWorldExpansion.allCases.first(where: { $0.kind == kind }) {
            let owned = item.isOwned(by: kid)
            HomesteadPlaceTile(kind: kind, state: owned ? .owned : projects.approvedWins >= item.requiredWins && item.hasRequiredLand(for: kid) && buildRequirement(item) == nil ? .available : .locked,
                cost: owned ? nil : item.price, currency: projects.currency,
                approvedWins: projects.approvedWins, requiredWins: owned || sequentialPlayground ? nil : item.requiredWins,
                active: active, affordable: owned || worldShelfBalance >= item.price, saved: saved,
                construction: constructionClocks.first { $0.kind == kind }, clock: timeClock) {
                inspectShelf(.piece(kind))
            }.accessibilityIdentifier("homestead.expansion.\(kind.rawValue)")
        } else if let project = LivingWorldProject.allCases.first(where: { $0.worldKind == kind }) {
            let owned = projects.isBuilt(project)
            HomesteadPlaceTile(kind: kind, state: owned ? .owned : projects.approvedWins >= project.requiredWins && buildRequirement(project) == nil ? .available : .locked,
                cost: owned ? nil : project.price, currency: projects.currency,
                approvedWins: projects.approvedWins, requiredWins: owned || sequentialPlayground ? nil : project.requiredWins,
                active: active, affordable: owned || worldShelfBalance >= project.price, saved: saved,
                construction: constructionClocks.first { $0.kind == kind }, clock: timeClock) {
                inspectShelf(.piece(kind))
            }.accessibilityIdentifier("homestead.project.\(project.rawValue)")
        } else {
            HomesteadPlaceTile(kind: kind, state: !objects.isEmpty ? .owned : sequentialPlayground && [.bench, .rocks].contains(kind) && testDecorationRequirement(kind) == nil ? .available : .locked,
                quantity: max(1, objects.count), active: active, saved: saved,
                location: !saved && objects.count == 1 ? cataloguePosition(objects[0]) : nil) { inspectShelf(.piece(kind)) }
                .accessibilityIdentifier(objects.count == 1 ? catalogueIdentifier(objects[0]) : "homestead.catalog.\(kind.rawValue)")
        }
    }
    private var worldShelfBalance: Double { EconomyLedger.forChild(kid).worldBalance(in: projects.currency) }
    private func catalogueRank(_ kind: HomesteadKind, current: LivingWorldProjects, owned: Set<HomesteadKind>) -> (Int, Int) {
        if owned.contains(kind) { return (2, 0) }
        if let project = LivingWorldProject.allCases.first(where: { $0.worldKind == kind }) {
            return (current.approvedWins >= project.requiredWins && buildRequirement(project) == nil ? 0 : 1, project.requiredWins)
        }
        if let item = LivingWorldExpansion.allCases.first(where: { $0.kind == kind }) {
            let available = current.approvedWins >= item.requiredWins && item.hasRequiredLand(for: kid) && buildRequirement(item) == nil
            return (available ? 0 : 1, item.requiredWins)
        }
        if sequentialPlayground && [.bench, .rocks].contains(kind), testDecorationRequirement(kind) == nil { return (0, 0) }
        return (1, Int.max)
    }
    /// The chosen shelf group, else the group of the best next piece, so Build
    /// opens on what the child can do now.
    /// Land shares the Build shelf once the free chapter is done; during the
    /// chapter Build shows the guided step instead.
    private var showsLandChip: Bool { catalogueSection == "build" && !showsChapter }
    private var effectiveShelfCategory: HomesteadShelfCategory {
        if let shelfCategory { return shelfCategory }
        let owned = Set((projection?.items ?? []).map(\.kind))
        return (catalogueKinds.first { !owned.contains($0) }).map { HomesteadShelfCategory.of($0) } ?? .home
    }
    private var catalogueKinds: [HomesteadKind] {
        let current = projects
        let owned = Set((projection?.items ?? []).map(\.kind))
        let ranked: [(kind: HomesteadKind, rank: (Int, Int), index: Int)] = HomesteadKind.allCases.enumerated().map { entry in
            (kind: entry.element, rank: catalogueRank(entry.element, current: current, owned: owned), index: entry.offset)
        }
        let sorted = ranked.sorted { left, right in
            if left.rank.0 != right.rank.0 { return left.rank.0 < right.rank.0 }
            if left.rank.1 != right.rank.1 { return left.rank.1 < right.rank.1 }
            return left.index < right.index
        }
        return sorted.map { $0.kind }
    }

    private var catalogueLands: [HomesteadLand] {
        HomesteadLand.allCases.enumerated().sorted {
            let left = projection?.land.contains($0.element.rawValue) == true
            let right = projection?.land.contains($1.element.rawValue) == true
            return left == right ? $0.offset < $1.offset : !left
        }.map(\.element)
    }
    private func landTile(_ land: HomesteadLand, active: Bool) -> some View {
        HomesteadLandTile(land: land, currency: projects.currency,
            owned: projection?.land.contains(land.rawValue) == true,
            buildRequirement: LivingWorldExpansion.expansion(for: land).flatMap { buildRequirement($0) },
            showsMissionRequirement: !sequentialPlayground,
            available: LivingWorldExpansion.expansion(for: land).map {
                projects.approvedWins >= $0.requiredWins && $0.hasRequiredLand(for: kid) && buildRequirement($0) == nil
            } == true, active: active,
            affordable: LivingWorldExpansion.expansion(for: land).map { worldShelfBalance >= $0.price || $0.isOwned(by: kid) } ?? false) {
            inspectShelf(.land(land))
        }.accessibilityIdentifier("homestead.land." + land.rawValue)
    }
    private var inventoryContent: some View {
        let kinds = catalogueKinds
        let owned = Set((projection?.items ?? []).map(\.kind))
        return VStack(alignment: .leading, spacing: 12) {
            if let catalogueKind {
                // One catalogue tile per kind. Existing piece IDs and placements
                // remain independent, including paths stored by older worlds.
                HomesteadItemStrip(items: Array(catalogueObjects(catalogueKind).enumerated()), minimumWidth: 180, rowHeight: 64) { entry in
                    let (index, object) = entry
                    Button { selectCatalogueObject(object) } label: {
                        HStack(spacing: 8) {
                            Text("\(index + 1)").font(.subheadline.bold()).frame(width: 24)
                            Text(cataloguePosition(object)).font(.caption)
                            Spacer(minLength: 0)
                            WorldControlIcon(symbol: "arrow.right").frame(width: 22, height: 22)
                        }.frame(minHeight: 48).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!allowsChanges)
                        .accessibilityIdentifier(catalogueIdentifier(object))
                        .accessibilityLabel(catalogueKind.title + " \(index + 1)")
                        .accessibilityValue("Owned · " + cataloguePosition(object))
                }
            } else {
                // Build is one row of places to build: no group buttons. Land plots
                // follow the places; owned pieces come last with a check.
                let sortedKinds = kinds.filter { !owned.contains($0) } + kinds.filter { owned.contains($0) }
                let future = catalogueSection == "build" ? HomesteadFuturePlace.places : []
                let lands = catalogueSection == "land" || showsLandChip ? catalogueLands : []
                let entries = (catalogueSection == "land" ? [] : sortedKinds.map { HomesteadShelfEntry(id: $0.rawValue, kind: $0, future: nil) }
                    + future.map { HomesteadShelfEntry(id: $0.id, kind: nil, future: $0) })
                    + lands.map { HomesteadShelfEntry(id: "land." + $0.rawValue, kind: nil, future: nil, land: $0) }
                HomesteadShelfStrip(items: entries) { entry, active in
                    if let kind = entry.kind { catalogueTile(kind, active: active) }
                    else if let place = entry.future {
                        HomesteadFuturePlaceTile(place: place, currency: projects.currency, approvedWins: projects.approvedWins) {
                            inspectShelf(.future(place.id))
                        }
                    } else if let land = entry.land { landTile(land, active: active) }
                }.id(catalogueScrollVersion).accessibilityIdentifier(catalogueSection == "land" ? "homestead.land.pages" : "homestead.catalog.pages")
            }
            if catalogueKind != nil, let issues = (try? HomesteadActions.state(for: kid))?.baseline?.issues.filter({ $0.reason == "no-3d-model-yet" }), !issues.isEmpty {
                Text("\(issues.count) treasures awaiting 3D artwork").font(.caption)
            }
        }
    }

}

struct HomesteadControlButtonStyle: ButtonStyle {
    var showsDisabledMark = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1)
            .overlay(alignment: .topTrailing) {
                if !isEnabled && showsDisabledMark { HomesteadControlMark(state: .disabled).frame(width: 16, height: 16).accessibilityHidden(true) }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}
