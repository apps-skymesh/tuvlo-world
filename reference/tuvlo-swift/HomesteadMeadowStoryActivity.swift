import SwiftUI

/// A short, tactile making journey. Recipes create play, never saleable stock.
struct HomesteadMeadowStoryActivity: View {
    let progress: HomesteadMeadowStory
    let placedKinds: Set<HomesteadKind>
    let allowsChanges: Bool
    let complete: (HomesteadMeadowStory.Step) throws -> Void
    let inspect: (HomesteadKind) -> Void
    @State private var replayIndex: Int?
    @State private var saveError: String?
    private var count: Int { replayIndex ?? progress.count }
    private var step: HomesteadMeadowStory.Step? { HomesteadMeadowStory.Step.allCases.dropFirst(count).first }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 4) {
                ForEach(Array(HomesteadMeadowStory.Step.allCases.enumerated()), id: \.element) { index, item in
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
            }.frame(width: 90, alignment: .leading).accessibilityIdentifier("homestead.story.trail")
            VStack(alignment: .leading, spacing: 4) {
            if let step {
                if placedKinds.contains(step.kind) {
                    HomesteadStoryWork(step: step, allowsChanges: allowsChanges) {
                        if let replayIndex { self.replayIndex = replayIndex + 1 }
                        else {
                            do { try complete(step); saveError = nil }
                            catch { saveError = error.localizedDescription }
                        }
                    }.id(step)
                } else {
                    Image("WorldPlace_" + step.kind.rawValue).resizable().scaledToFit().frame(height: 32).frame(maxWidth: .infinity)
                    Text("\(step.kind.title) first").font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("homestead.story.lock")
                    Button { inspect(step.kind) } label: { Label("See place", systemImage: "arrow.right").font(.subheadline.weight(.semibold)).frame(minHeight: 48) }
                        .buttonStyle(.plain).accessibilityIdentifier("homestead.story.place")
                }
            } else {
                HomesteadStoryIllustration(step: .share, amount: 3).frame(height: 40).accessibilityHidden(true)
                Text("Made a little happiness").font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("homestead.story.finished")
                Button { replayIndex = 0 } label: { Label("Make another", systemImage: "arrow.uturn.backward").font(.subheadline.weight(.semibold)).frame(minHeight: 48) }
                    .buttonStyle(.plain).disabled(!allowsChanges).accessibilityIdentifier("homestead.story.replay")
            }
            if let saveError {
                Text(saveError).font(.caption).accessibilityIdentifier("homestead.story.error")
            }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("homestead.story")
    }
}

private struct HomesteadStoryWork: View {
    let step: HomesteadMeadowStory.Step
    let allowsChanges: Bool
    let finish: () -> Void
    @State private var pieces: Set<Int> = []
    @State private var stirs = 0
    @State private var usedSources: Set<Int> = []
    private var ready: Bool { step == .bake ? stirs >= 3 : pieces.count == 3 }
    private var instruction: String {
        switch step {
        case .gather: return "Drag fruit into the basket. Or tap to pick."
        case .craft: return "Fold each panel. A basket for your harvest."
        case .bake: return "Stir the filling, then bake."
        case .share: return "A little tart on every plate. Drag or tap."
        }
    }
    private var actionTitle: String {
        switch step { case .gather: return "Take to workshop"; case .craft: return "Take to cottage"; case .bake: return "Bake for the picnic"; case .share: return "Share the picnic" }
    }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 2) {
            if step == .bake {
                Text(ready ? "Ready for the oven" : "Tap the bowl to stir").font(.caption)
                    .accessibilityIdentifier("homestead.story.stir.hint")
                bowl
            }
            else if step == .craft && ready {
                HomesteadStoryIllustration(step: .craft, amount: 3).frame(height: 48).frame(maxWidth: .infinity)
            } else {
                pieceRow
                if step != .craft && !ready { sources }
            }
            }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(step.title)).font(.caption.weight(.semibold)).accessibilityIdentifier("homestead.story.step")
            Button(action: finish) {
                Label(LocalizedStringKey(actionTitle), systemImage: "arrow.right")
                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 48)
                    .background(Color(livingWorldHex: "#9FBD78").opacity(ready ? 1 : 0.22), in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain).disabled(!allowsChanges || !ready).accessibilityIdentifier("homestead.story.continue")
            }.frame(width: 132)
        }
    }
    private var bowl: some View {
        Button { if allowsChanges { stirs = min(3, stirs + 1) } } label: {
            HomesteadStoryIllustration(step: step, amount: stirs).frame(height: 76)
                .frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!allowsChanges || ready)
            .accessibilityLabel("Stir fruit filling").accessibilityValue("\(stirs) of 3 stirs")
            .accessibilityIdentifier("homestead.story.stir")
    }
    private var pieceRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Button { place(index) } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13).fill(Color(livingWorldHex: "#B7C7AE").opacity(0.18))
                        if step == .craft { HomesteadStoryFold(folded: pieces.contains(index)).padding(8) }
                        else { HomesteadStoryIllustration(step: step, amount: pieces.contains(index) ? 3 : 0).padding(4) }
                    }.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(!allowsChanges)
                    .accessibilityLabel(pieceLabel(index))
                    .accessibilityValue(pieces.contains(index) ? "Ready" : "Waiting")
                    .accessibilityIdentifier("homestead.story.piece.\(index)")
                    .dropDestination(for: String.self) { values, _ in
                        guard allowsChanges, let source = (0..<3).first(where: { values.contains("meadow-\(step.rawValue)-\($0)") }),
                              !usedSources.contains(source), !pieces.contains(index) else { return false }
                        usedSources.insert(source); pieces.insert(index); return true
                    }
            }
        }.frame(height: 48)
    }
    private var sources: some View {
        HStack(spacing: 14) {
            ForEach(0..<3) { index in
                HomesteadStoryToken(fruit: step == .gather)
                    .frame(maxWidth: .infinity, minHeight: 44).opacity(usedSources.contains(index) ? 0.25 : 1)
                    .allowsHitTesting(allowsChanges && !usedSources.contains(index))
                    .draggable("meadow-\(step.rawValue)-\(index)")
                    .accessibilityLabel(step == .gather ? "Drag fruit \(index + 1)" : "Drag tart \(index + 1)")
                    .accessibilityIdentifier("homestead.story.source.\(index)")
            }
        }.frame(height: 44)
    }
    private func pieceLabel(_ index: Int) -> String {
        step == .gather ? "Pick fruit \(index + 1)" : step == .craft ? "Fold panel \(index + 1)" : "Fill plate \(index + 1)"
    }
    private func place(_ index: Int) {
        guard allowsChanges, !pieces.contains(index), let source = (0..<3).first(where: { !usedSources.contains($0) }) else { return }
        pieces.insert(index); usedSources.insert(source)
    }
}

private struct HomesteadStoryIllustration: View {
    let step: HomesteadMeadowStory.Step
    let amount: Int
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 100, size.height / 72)
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 72 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let sage = Color(livingWorldHex: "#8FA88A"), clay = Color(livingWorldHex: "#BC8065"), cream = Color(livingWorldHex: "#F4E3BD")
            let brass = Color(livingWorldHex: "#B58C52")
            func fruit(_ point: CGPoint) {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 8, width: 18, height: 18)), with: .color(clay))
                context.fill(Path(ellipseIn: CGRect(x: point.x + 1, y: point.y - 11, width: 8, height: 4)), with: .color(sage))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 4, width: 3, height: 6)), with: .color(cream.opacity(0.6)))
            }
            switch step {
            case .gather:
                context.fill(Path(roundedRect: CGRect(x: 15, y: 39, width: 70, height: 27), cornerRadius: 10), with: .color(brass.opacity(0.65)))
                for x in stride(from: 23, through: 78, by: 9) { context.fill(Path(CGRect(x: CGFloat(x), y: 42, width: 2, height: 20)), with: .color(cream.opacity(0.5))) }
                if amount > 0 { fruit(.init(x: 36, y: 36)); fruit(.init(x: 59, y: 36)); fruit(.init(x: 48, y: 22)) }
                else { fruit(.init(x: 50, y: 19)) }
            case .craft:
                if amount > 0 {
                    var handle = Path(); handle.addArc(center: .init(x: 50, y: 35), radius: 20, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    context.stroke(handle, with: .color(brass), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    context.fill(Path(roundedRect: CGRect(x: 20, y: 32, width: 60, height: 32), cornerRadius: 7), with: .color(brass))
                    context.fill(Path(roundedRect: CGRect(x: 25, y: 35, width: 50, height: 11), cornerRadius: 4), with: .color(sage))
                } else {
                    var paper = Path(); paper.addLines([.init(x: 50, y: 9), .init(x: 84, y: 35), .init(x: 50, y: 62), .init(x: 16, y: 35)]); paper.closeSubpath()
                    context.fill(paper, with: .color(sage.opacity(0.6)))
                    var fold = Path(); fold.move(to: .init(x: 50, y: 13)); fold.addLine(to: .init(x: 50, y: 58))
                    context.stroke(fold, with: .color(cream), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }
            case .bake:
                context.fill(Path(ellipseIn: CGRect(x: 20, y: 24, width: 60, height: 36)), with: .color(sage))
                context.fill(Path(ellipseIn: CGRect(x: 22, y: 22, width: 56, height: 18)), with: .color(cream))
                for i in 0..<max(1, amount) { fruit(.init(x: 38 + CGFloat(i) * 12, y: 30)) }
                var spoon = Path(); spoon.move(to: .init(x: 57, y: 32)); spoon.addLine(to: .init(x: 75 - CGFloat(amount) * 7, y: 7))
                context.stroke(spoon, with: .color(brass), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            case .share:
                context.fill(Path(roundedRect: CGRect(x: 8, y: 12, width: 84, height: 52), cornerRadius: 11), with: .color(sage.opacity(0.5)))
                context.fill(Path(ellipseIn: CGRect(x: 23, y: 17, width: 54, height: 43)), with: .color(cream))
                if amount > 0 {
                    context.fill(Path(ellipseIn: CGRect(x: 31, y: 22, width: 38, height: 31)), with: .color(brass))
                    context.fill(Path(ellipseIn: CGRect(x: 36, y: 26, width: 28, height: 22)), with: .color(clay))
                    for x in [40, 50, 60] { context.fill(Path(roundedRect: CGRect(x: CGFloat(x), y: 24, width: 3, height: 26), cornerRadius: 1), with: .color(cream.opacity(0.85))) }
                }
            }
        }.accessibilityHidden(true)
    }
}

private struct HomesteadStoryToken: View {
    let fruit: Bool
    var body: some View {
        Canvas { context, size in
            let x = size.width / 2
            let clay = Color(livingWorldHex: "#BC8065")
            if fruit {
                context.fill(Path(ellipseIn: CGRect(x: x - 11, y: 12, width: 22, height: 23)), with: .color(clay))
                context.fill(Path(ellipseIn: CGRect(x: x, y: 8, width: 11, height: 5)), with: .color(Color(livingWorldHex: "#729179")))
                context.fill(Path(ellipseIn: CGRect(x: x - 6, y: 17, width: 4, height: 8)), with: .color(.white.opacity(0.3)))
            } else {
                context.fill(Path(ellipseIn: CGRect(x: x - 15, y: 11, width: 30, height: 25)), with: .color(Color(livingWorldHex: "#B58C52")))
                context.fill(Path(ellipseIn: CGRect(x: x - 11, y: 14, width: 22, height: 18)), with: .color(clay))
                for offset in [-5, 3] {
                    context.fill(Path(CGRect(x: x + CGFloat(offset), y: 14, width: 3, height: 17)), with: .color(Color(livingWorldHex: "#F4E3BD")))
                }
            }
        }
    }
}

private struct HomesteadStoryFold: View {
    let folded: Bool
    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 5
            let rect = CGRect(x: inset, y: inset, width: max(1, size.width - inset * 2), height: max(1, size.height - inset * 2))
            context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Color(livingWorldHex: "#8FA88A").opacity(folded ? 1 : 0.5)))
            var crease = Path(); crease.move(to: .init(x: rect.midX, y: rect.minY)); crease.addLine(to: .init(x: rect.midX, y: rect.maxY))
            context.stroke(crease, with: .color(Color(livingWorldHex: "#F4E3BD")), style: StrokeStyle(lineWidth: 2, dash: folded ? [] : [3, 3]))
            if folded {
                var corner = Path(); corner.addLines([.init(x: rect.midX, y: rect.minY), .init(x: rect.maxX, y: rect.midY), .init(x: rect.midX, y: rect.maxY)]); corner.closeSubpath()
                context.fill(corner, with: .color(Color(livingWorldHex: "#D5C49D")))
            }
        }.accessibilityHidden(true)
    }
}
