import SwiftUI

/// One saved opening, with a person and a use for each ingredient. The World
/// wallet stays outside this panel; ingredients are contextual, never currency.
struct HomesteadOpeningView: View {
    let ledger: HomesteadOpeningLedger
    let wins: Int
    let wheatReady: Int
    let placed: Set<HomesteadKind>
    let windmillOwned: Bool
    let nookOwned: Bool
    let nookFood: Int
    let allowsChanges: Bool
    let perform: (HomesteadOpeningEvent.Action, Bool) async throws -> Void
    let buildGoal: (HomesteadBuildTarget) -> HomesteadGoal
    let inspect: (HomesteadKind) -> Void
    let missions: () -> Void
    @State private var busy = false
    @State private var error: String?
    @State private var roundLoaf = false
    @State private var practice = false
    private var stage: HomesteadBreadStory.Step? {
        if !ledger.started { return nil }
        if !ledger.hasBaked {
            if ledger.flour > 0 { return .bake }
            if ledger.wheat >= 2 && placed.contains(.windmill) { return .mill }
            if wheatReady > 0 && ledger.wheat < 2 && placed.contains(.garden) { return .grow }
            return nil
        }
        return nil
    }
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                roundTitle
                stocks
            }.frame(width: 168, alignment: .leading)
            Rectangle().fill(Color(livingWorldHex: "#243C32").opacity(0.15)).frame(width: 1)
            activity.opacity(error == nil ? 1 : 0)
                .accessibilityHidden(error != nil).allowsHitTesting(error == nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if let error {
                        HStack(spacing: 12) {
                            Text(error).font(.caption).accessibilityIdentifier("homestead.opening.error")
                            Button("Retry") { self.error = nil }.frame(minWidth: 48, minHeight: 48)
                                .accessibilityIdentifier("homestead.opening.error.dismiss")
                        }
                    }
                }
            if busy { ProgressView().accessibilityLabel("Saving your recipe") }
        }.disabled(busy).accessibilityElement(children: .contain).accessibilityIdentifier("homestead.opening")
    }
    private var roundTitle: some View {
        Text(ledger.picnic ? "A place for stories" : ledger.hasBaked ? "Reading picnic" : "Your first loaf")
            .font(.subheadline.weight(.bold)).accessibilityIdentifier("homestead.opening.round")
            .accessibilityHint(ledger.hasBaked ? "A picnic for the storyteller" : "A welcome loaf for the baker")
    }
    private var stocks: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow { stock(.wheat, count: ledger.wheat, title: "Wheat"); stock(.sack, count: ledger.flour, title: "Flour") }
            GridRow {
                stock(.loaf, count: ledger.bread, title: "Bread")
                Label("\(nookFood)", systemImage: "basket.fill").font(.caption.weight(.bold))
                    .accessibilityLabel("\(nookFood) provisions available")
            }
        }.accessibilityIdentifier("homestead.opening.stock")
    }
    @ViewBuilder private var activity: some View {
            if !ledger.started {
                action("Plant", id: "begin") { run(.begin) }
            } else if ledger.picnic {
                if practice {
                    HomesteadBreadWork(step: .bake, allowsChanges: allowsChanges) { practice = false }
                } else {
                    HStack {
                        HomesteadBreadArt(scene: .recipe, amount: 3, round: ledger.roundLoaf).frame(width: 80, height: 64)
                        action("Visit nook", id: "visit") { inspect(.nook) }
                        action("Practice", id: "practice") { practice = true }
                    }
                }
            } else if let stage {
                HomesteadBreadWork(step: stage, allowsChanges: allowsChanges && !busy,
                    shapeChanged: { roundLoaf = $0 },
                    finish: { run(stage == .grow ? .harvest : stage == .mill ? .mill : .bake) })
                    .id("\(ledger.nextSequence):\(stage.rawValue)")
            } else if !ledger.hasBaked {
                if ledger.wheat < 2 {
                    if !placed.contains(.garden) { action("Place garden", id: "garden") { inspect(.garden) } }
                    else { action("Missions needed", id: "missions", locked: true, action: missions) }
                } else {
                    let goal = buildGoal(.expansion(.windmill))
                    if !windmillOwned && !goal.isReady { Text(goal.instruction).font(.caption) }
                    action(windmillOwned ? "Place windmill" : goal.isReady ? "Build windmill" : "Next step", id: "windmill", locked: !windmillOwned && !goal.isReady) { inspect(.windmill) }
                }
            } else {
                if ledger.bread > 0 && (!nookOwned && nookFood < 3) {
                    HomesteadBreadArt(scene: .loaf, amount: 1, round: ledger.roundLoaf).frame(height: 40).frame(maxWidth: .infinity)
                    action("Pack 1 provision", id: "pack") { run(.pack) }
                } else if !nookOwned && nookFood < 3 {
                    if ledger.flour > 0 {
                        HomesteadBreadArt(scene: .loaf, amount: 1, round: ledger.roundLoaf).frame(height: 40).frame(maxWidth: .infinity)
                        action("Bake 1 loaf", id: "bake") { run(.bake, shape: ledger.roundLoaf) }
                    } else if ledger.wheat >= 2 {
                        if placed.contains(.windmill) {
                            Text("2 wheat → 1 flour").font(.caption.weight(.semibold))
                            action("Mill", id: "mill") { run(.mill) }
                        } else { action("Place windmill", id: "windmill") { inspect(.windmill) } }
                    } else if !placed.contains(.garden) {
                        action("Place garden", id: "garden") { inspect(.garden) }
                    } else if wheatReady > 0 {
                        action("Harvest \(wheatReady) wheat", id: "harvest") { run(.harvest) }
                    } else {
                        action("Missions needed", id: "missions", locked: true, action: missions)
                    }
                } else if !nookOwned || !placed.contains(.nook) {
                    let goal = buildGoal(.project(.nook))
                    if !nookOwned && !goal.isReady { Text(goal.instruction).font(.caption) }
                    action(nookOwned ? "Place nook" : goal.isReady ? "Build nook" : "Next step", id: "nook", locked: !nookOwned && !goal.isReady) { inspect(.nook) }
                } else {
                    HomesteadBreadWork(step: .share, allowsChanges: allowsChanges && !busy) { run(.picnic) }
                }
            }
    }
    private func stock(_ scene: HomesteadBreadArt.Scene, count: Int, title: String) -> some View {
        HStack(spacing: 2) {
            HomesteadBreadArt(scene: scene, amount: 1).frame(width: 28, height: 22)
            Text("\(count)").font(.caption.weight(.bold)).monospacedDigit()
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(title): \(count)")
    }
    private func action(_ title: String, id: String, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(LocalizedStringKey(title)); Spacer(); Image(systemName: locked ? "lock.fill" : "arrow.right") }
                .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 48)
                .background(Color(livingWorldHex: locked ? "#DDDCCB" : "#9FBD78"), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges).accessibilityIdentifier("homestead.opening." + id)
    }
    private func run(_ action: HomesteadOpeningEvent.Action, shape: Bool? = nil) {
        guard !busy else { return }; busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do { try await perform(action, shape ?? roundLoaf); if action == .bake { roundLoaf = false } }
            catch { self.error = error.localizedDescription }
        }
    }
}
