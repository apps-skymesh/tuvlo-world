import SwiftUI

/// A saved four-stop recipe. Work within a stop is playful, temporary input;
/// only the action owner can advance durable progress after a successful save.
struct HomesteadBreadStoryActivity: View {
    let progress: HomesteadBreadStory
    let placedKinds: Set<HomesteadKind>
    let allowsChanges: Bool
    let complete: (HomesteadBreadStory.Step) throws -> Void
    let inspect: (HomesteadKind) -> Void
    @State private var replayIndex: Int?
    @State private var saveError: String?
    private var count: Int { replayIndex ?? progress.count }
    private var step: HomesteadBreadStory.Step? { HomesteadBreadStory.Step.allCases.dropFirst(count).first }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 4) {
                ForEach(Array(HomesteadBreadStory.Step.allCases.enumerated()), id: \.element) { index, item in
                    HStack(spacing: 4) {
                        if index < count {
                            TuvloCheckMark().frame(width: 14, height: 14)
                        } else {
                            Image(systemName: index == count ? "circle.inset.filled" : "circle")
                        }
                        Text(LocalizedStringKey(item.verb)).font(.caption)
                    }.foregroundStyle(Color(livingWorldHex: "#243C32").opacity(index > count ? 0.35 : 1))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(index + 1). \(item.kind.title). \(item.verb)")
                        .accessibilityValue(index < count ? "Complete" : index == count ? "Next" : "Later")
                }
            }.frame(width: 90, alignment: .leading).accessibilityIdentifier("homestead.bread.trail")
            VStack(alignment: .leading, spacing: 4) {
            if let step {
                if placedKinds.contains(step.kind) {
                    HomesteadBreadWork(step: step, allowsChanges: allowsChanges) {
                        guard allowsChanges else { return }
                        if let replayIndex { self.replayIndex = replayIndex + 1 }
                        else {
                            do { try complete(step); saveError = nil }
                            catch { saveError = error.localizedDescription }
                        }
                    }.id(step)
                } else {
                    Image("WorldPlace_" + step.kind.rawValue).resizable().scaledToFit().frame(height: 32).frame(maxWidth: .infinity)
                    Text("\(step.kind.title) first").font(.subheadline.weight(.semibold)).accessibilityIdentifier("homestead.bread.lock")
                    Button { inspect(step.kind) } label: {
                        Label("See place", systemImage: "arrow.right").font(.subheadline.weight(.semibold)).frame(minHeight: 48)
                    }.buttonStyle(.plain).accessibilityIdentifier("homestead.bread.place")
                }
            } else {
                HomesteadBreadArt(scene: .recipe, amount: 3).frame(height: 40).frame(maxWidth: .infinity)
                Text("From your garden, with love").font(.subheadline.weight(.semibold)).accessibilityIdentifier("homestead.bread.finished")
                Button { replayIndex = 0 } label: {
                    Label("Bake another", systemImage: "arrow.uturn.backward").font(.subheadline.weight(.semibold)).frame(minHeight: 48)
                }.buttonStyle(.plain).disabled(!allowsChanges).accessibilityIdentifier("homestead.bread.replay")
            }
            if let saveError { Text(saveError).font(.caption).accessibilityIdentifier("homestead.bread.error") }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("homestead.bread")
    }
}

struct HomesteadBreadWork: View {
    let step: HomesteadBreadStory.Step
    let allowsChanges: Bool
    var shapeChanged: (Bool) -> Void = { _ in }
    let finish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var planted: Set<Int> = []
    @State private var watered: Set<Int> = []
    @State private var gathered: Set<Int> = []
    @State private var usedSources: Set<Int> = []
    @State private var filled: Set<Int> = []
    @State private var turns = 0
    @State private var lastAngle: Double?
    @State private var angleTravel = 0.0
    @State private var folds = 0
    @State private var poured = false
    @State private var roundLoaf = false
    private var ready: Bool {
        switch step { case .grow: return gathered.count == 3; case .mill: return turns == 8 && filled.count == 3; case .bake: return poured && folds == 3; case .share: return filled.count == 3 }
    }
    private var hint: String {
        switch step {
        case .grow: return planted.count < 3 ? "Plant seeds" : watered.count < 3 ? "Water the patches" : gathered.count < 3 ? "Gather wheat" : "Harvest ready"
        case .mill: return turns < 8 ? "Turn the wheel" : filled.count < 3 ? "Fill the sacks" : "Flour ready"
        case .bake: return !poured ? "Pour flour" : folds < 3 ? "Fold the dough" : "Choose a shape"
        case .share: return ready ? "Picnic ready" : "Fill the plates"
        }
    }
    private var action: String {
        switch step { case .grow: return "Harvest"; case .mill: return "Mill"; case .bake: return "Bake"; case .share: return "Serve" }
    }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(step.title)).font(.caption.weight(.semibold)).accessibilityIdentifier("homestead.bread.step")
                Text(LocalizedStringKey(hint)).font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("homestead.bread.hint")
                Button(action: finish) {
                    Label(LocalizedStringKey(action), systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 48)
                        .background(Color(livingWorldHex: "#9FBD78").opacity(ready ? 1 : 0.22), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges || !ready)
                    .accessibilityIdentifier("homestead.bread.continue")
            }.frame(width: 128, alignment: .leading)
            VStack(spacing: 4) { workScene }.saturation(1.25).contrast(1.1).frame(maxWidth: .infinity)
        }.accessibilityLabel(Text(LocalizedStringKey(step.title)))
    }
    @ViewBuilder private var workScene: some View {
        switch step {
        case .grow:
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Button { tend(index) } label: {
                        HomesteadBreadArt(scene: .patch, amount: gathered.contains(index) ? 4 : watered.contains(index) ? 3 : planted.contains(index) ? 1 : 0)
                            .frame(maxWidth: .infinity).frame(height: 48).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!allowsChanges || gathered.contains(index))
                        .accessibilityLabel("Wheat patch \(index + 1)")
                        .accessibilityValue(gathered.contains(index) ? "Gathered" : watered.contains(index) ? "Ready to harvest" : planted.contains(index) ? "Needs water" : "Needs seeds")
                        .accessibilityIdentifier("homestead.bread.patch.\(index)")
                        .dropDestination(for: String.self) { values, _ in
                            guard allowsChanges, planted.count < 3, !planted.contains(index),
                                  let source = unusedSource(values, prefix: "bread-seed") else { return false }
                            planted.insert(index); usedSources.insert(source); return true
                        }
                }
            }
            if planted.count < 3 { sources(scene: .seeds, prefix: "bread-seed") }
        case .mill:
            if turns < 8 { wheel }
            else {
                transferRow(scene: .sack, prefix: "bread-grain")
                if !ready { sources(scene: .wheat, prefix: "bread-grain") }
            }
        case .bake:
            if ready {
                HStack {
                    shapeButton("Rustic oval", round: false)
                    shapeButton("Round loaf", round: true)
                }
            } else {
                Button {
                    guard allowsChanges else { return }
                    if !poured { poured = true } else { folds = min(3, folds + 1) }
                } label: {
                    HomesteadBreadArt(scene: !poured ? .sack : .dough, amount: folds)
                        .frame(height: 72).frame(maxWidth: .infinity).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!allowsChanges)
                    .accessibilityLabel(!poured ? "Pour flour" : "Fold dough")
                    .accessibilityValue("\(folds) of 3 folds").accessibilityIdentifier("homestead.bread.dough")
            }
        case .share:
            transferRow(scene: .plate, prefix: "bread-slice")
            if !ready { sources(scene: .slice, prefix: "bread-slice") }
        }
    }
    private var wheel: some View {
        Button { if allowsChanges { turns = min(8, turns + 1) } } label: {
            HomesteadBreadArt(scene: .wheel, amount: turns)
                .rotationEffect(.degrees(reducedMotion ? 0 : Double(turns) * 45))
                .frame(width: 80, height: 80).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!allowsChanges)
            .accessibilityLabel("Turn the mill wheel").accessibilityValue("\(turns) of 8 turns")
            .accessibilityIdentifier("homestead.bread.wheel")
            .simultaneousGesture(DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    guard allowsChanges, turns < 8 else { return }
                    // Measure around the button's center; bounded angle differences
                    // avoid a jump across ±pi becoming a whole turn.
                    let angle = atan2(Double(value.location.y - 40), Double(value.location.x - 40))
                    if let lastAngle {
                        var difference = angle - lastAngle
                        if difference > .pi { difference -= 2 * .pi }
                        if difference < -.pi { difference += 2 * .pi }
                        angleTravel += abs(difference)
                        if angleTravel >= .pi / 4 { turns = min(8, turns + 1); angleTravel = 0 }
                    }
                    lastAngle = angle
                }.onEnded { _ in lastAngle = nil; angleTravel = 0 })
            .frame(maxWidth: .infinity)
    }
    private func shapeButton(_ title: String, round: Bool) -> some View {
        Button { roundLoaf = round; shapeChanged(round) } label: {
            VStack(spacing: 2) {
                HomesteadBreadArt(scene: .loaf, amount: 3, round: round).frame(height: 32).accessibilityHidden(true)
                Text(LocalizedStringKey(title)).font(.caption.weight(.semibold))
            }.padding(.vertical, 4).frame(maxWidth: .infinity, minHeight: 64)
                .background(Color(livingWorldHex: "#B7C7AE").opacity(roundLoaf == round ? 0.6 : 0.15), in: Capsule())
        }.buttonStyle(.plain).disabled(!allowsChanges).accessibilityAddTraits(roundLoaf == round ? .isSelected : [])
            .accessibilityIdentifier(round ? "homestead.bread.shape.round" : "homestead.bread.shape.oval")
    }
    private func tend(_ index: Int) {
        guard allowsChanges else { return }
        if planted.count < 3 {
            guard !planted.contains(index), let source = (0..<3).first(where: { !usedSources.contains($0) }) else { return }
            planted.insert(index); usedSources.insert(source)
        } else if watered.count < 3 { watered.insert(index) }
        else { gathered.insert(index) }
    }
    private func unusedSource(_ values: [String], prefix: String) -> Int? {
        (0..<3).first { !usedSources.contains($0) && values.contains("\(prefix)-\($0)") }
    }
    private func transferRow(scene: HomesteadBreadArt.Scene, prefix: String) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Button { fill(index) } label: {
                    HomesteadBreadArt(scene: scene, amount: filled.contains(index) ? 3 : 0)
                        .frame(maxWidth: .infinity).frame(height: 56).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!allowsChanges || filled.contains(index))
                    .accessibilityLabel(scene == .sack ? "Fill flour sack \(index + 1)" : "Fill plate \(index + 1)")
                    .accessibilityValue(filled.contains(index) ? "Ready" : "Waiting")
                    .accessibilityIdentifier("homestead.bread.piece.\(index)")
                    .dropDestination(for: String.self) { values, _ in
                        guard allowsChanges, !filled.contains(index), let source = unusedSource(values, prefix: prefix) else { return false }
                        usedSources.insert(source); filled.insert(index); return true
                    }
            }
        }
    }
    private func fill(_ index: Int) {
        guard allowsChanges, !filled.contains(index), let source = (0..<3).first(where: { !usedSources.contains($0) }) else { return }
        usedSources.insert(source); filled.insert(index)
    }
    private func sources(scene: HomesteadBreadArt.Scene, prefix: String) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                HomesteadBreadArt(scene: scene, amount: 3).frame(maxWidth: .infinity).frame(height: 44)
                    .opacity(usedSources.contains(index) ? 0.2 : 1).contentShape(Rectangle())
                    .allowsHitTesting(allowsChanges && !usedSources.contains(index)).draggable("\(prefix)-\(index)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(scene == .seeds ? "Drag seeds \(index + 1)" : scene == .wheat ? "Drag grain \(index + 1)" : "Drag bread \(index + 1)")
                    .accessibilityIdentifier("homestead.bread.source.\(index)")
            }
        }
    }
}
