import SwiftUI

struct HomesteadExpansionPanel: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let item: LivingWorldExpansion
    let kid: Child
    let currency: RewardCurrency
    let confirming: Bool
    let busy: Bool
    let allowsChanges: Bool
    let choose: () -> Void
    let buy: () -> Void
    let back: () -> Void
    var resolveRequirement: (() -> Void)? = nil
    var resolveMaterial: ((HomesteadMaterial) -> Void)? = nil
    var missions: (() -> Void)? = nil
    var buildRequirement: String? = nil
    var showsMissionRequirement = true
    var close: () -> Void = {}
    private var balance: Double { EconomyLedger.forChild(kid).worldBalance(in: currency) }
    private var wins: Int { EconomyLedger.forChild(kid).approvedWins }
    private var materials: HomesteadMaterialLedger { .init(kid: kid) }
    static func isReady(item: LivingWorldExpansion, kid: Child, currency: RewardCurrency, allowsChanges: Bool, buildRequirement: String?) -> Bool {
        let ledger = EconomyLedger.forChild(kid)
        return allowsChanges && buildRequirement == nil && HomesteadMaterialLedger(kid: kid).canAfford(.expansion(item))
            && LivingWorldEconomy.currency(for: kid) == currency && item.hasRequiredLand(for: kid)
            && ledger.approvedWins >= item.requiredWins && ledger.worldBalance(in: currency) >= item.price
            && LivingWorldStarter(kid: kid).count == 3
    }
    private var ready: Bool { Self.isReady(item: item, kid: kid, currency: currency, allowsChanges: allowsChanges, buildRequirement: buildRequirement) }
    var body: some View {
        WorldBuildConfirmation(title: item.title, icon: item.icon,
            asset: item.land.map { "WorldLand_" + $0.rawValue } ?? "WorldPlace_" + (item.kind?.rawValue ?? "cottage"),
            price: item.price, currency: currency, ready: ready, allowsChanges: allowsChanges, busy: busy,
            actionTitle: item.kind == nil ? "Buy" : "Build",
            plannedSeconds: HomesteadTimePresentation.plannedBuild(.expansion(item), kid: kid, currency: currency),
            error: buildRequirement, identifier: item.kind == nil ? "homestead.expansion.confirm" : "homestead.expansion.choose",
            back: back, close: close, confirm: { if item.kind == nil { buy() } else { choose() } }, resolve: resolveRequirement) {
                WorldBuildNeeds(wins: wins, requiredWins: item.requiredWins,
                    food: materials.balance.food, requiredFood: HomesteadBuildTarget.expansion(item).materials.food,
                    chapterComplete: LivingWorldStarter(kid: kid).count == 3, allowsChanges: allowsChanges,
                    requiresWest: !item.hasRequiredLand(for: kid) || [.orchard, .greenhouse].contains(item), ownsWest: item.hasRequiredLand(for: kid),
                    missions: { missions?() }, meals: { resolveMaterial?(.food) }, chapter: { resolveRequirement?() }, land: { resolveRequirement?() })
            }
    }
}

/// Replayable play never creates mission wins, currency, XP or paid inventory.
/// Each shape can be dragged to its outline or placed with an accessible button.
struct HomesteadWorkshopActivity: View {
    @State private var placed: Set<Int> = []
    @State private var color = 0
    private let names = ["Body", "Wing", "Tail"]
    private let colors = [Color(livingWorldHex: "#C68C6E"), Color(livingWorldHex: "#8DAA9A"), Color(livingWorldHex: "#A6A3C5")]
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
            Text(placed.count == 3 ? "Made by you" : "Make a paper bird").font(.subheadline.bold())
                .accessibilityIdentifier("homestead.workshop.activity.status")
            if placed.count < 3 { Text("Match the pieces").font(.caption) }
            }.frame(width: 124, alignment: .leading)
            VStack(spacing: 2) {
            if placed.count == 3 {
                Canvas { context, size in
                    let scale = min(size.width / 90, size.height / 62)
                    let transform = CGAffineTransform(translationX: (size.width - 90 * scale) / 2, y: 0).scaledBy(x: scale, y: scale)
                    let outlines: [[CGPoint]] = [
                        [.init(x: 18, y: 43), .init(x: 76, y: 26), .init(x: 55, y: 52)],
                        [.init(x: 33, y: 37), .init(x: 48, y: 2), .init(x: 58, y: 35)],
                        [.init(x: 20, y: 43), .init(x: 1, y: 20), .init(x: 4, y: 49)]
                    ]
                    for (index, outline) in outlines.enumerated() {
                        var path = Path(); path.addLines(outline); path.closeSubpath()
                        context.fill(path.applying(transform), with: .color(colors[color].opacity(index == 1 ? 0.72 : 1)))
                        context.stroke(path.applying(transform), with: .color(.white.opacity(0.6)), lineWidth: 1)
                    }
                }.frame(height: 76).accessibilityLabel("Your finished paper bird")
            } else {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Button { placed.insert(index) } label: {
                        VStack(spacing: 4) {
                            paper(index).fill(placed.contains(index) ? colors[color] : colors[color].opacity(0.14))
                                .overlay { paper(index).stroke(colors[color], style: StrokeStyle(lineWidth: 1.5, dash: placed.contains(index) ? [] : [3, 3])) }
                                .frame(height: 28)
                            Text(LocalizedStringKey(names[index])).font(.caption2)
                        }.frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                    }.buttonStyle(HomesteadMenuButtonStyle())
                        .accessibilityLabel("Place " + names[index].lowercased())
                        .accessibilityValue(placed.contains(index) ? "Placed" : "Empty outline")
                        .accessibilityIdentifier("homestead.workshop.piece.\(index)")
                        .dropDestination(for: String.self) { values, _ in
                            guard values.contains("tuvlo-paper-\(index)") else { return false }
                            placed.insert(index); return true
                        }
                }
            }
            }
            if placed.count < 3 {
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    paper(index).fill(colors[color]).frame(width: 48, height: 32).frame(minHeight: 48)
                        .contentShape(Rectangle())
                        .draggable("tuvlo-paper-\(index)")
                        .accessibilityLabel("Drag " + names[index].lowercased())
                }
                Spacer(minLength: 0)
            }
            }
            }.frame(maxWidth: .infinity)
            HStack(spacing: 0) {
                HomesteadIconButton(title: "Next paper color", icon: "paintpalette.fill") { color = (color + 1) % colors.count }
                HomesteadIconButton(title: "Make another bird", icon: "arrow.uturn.backward") { placed = [] }
                    .accessibilityIdentifier("homestead.workshop.again")
            }
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier("homestead.workshop.activity")
    }
    private func paper(_ index: Int) -> Path {
        Path { path in
            let points: [CGPoint]
            switch index {
            case 0: points = [.init(x: 4, y: 28), .init(x: 44, y: 3), .init(x: 33, y: 39)]
            case 1: points = [.init(x: 2, y: 37), .init(x: 42, y: 4), .init(x: 30, y: 38)]
            default: points = [.init(x: 3, y: 5), .init(x: 44, y: 24), .init(x: 5, y: 38)]
            }
            path.addLines(points); path.closeSubpath()
        }
    }
}

/// A small, pressure-free garden: arrangement and watering are play, never rewards.
struct HomesteadGreenhouseActivity: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var order = [0, 1, 2]
    @State private var selected = 0
    @State private var watering = false
    @State private var pickedPot: Int?
    @State private var watered: Set<Int> = []
    private let names = ["Daisy", "Fern", "Lavender"]
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
            Text(watering ? watered.isEmpty ? "Water the plants" : "Water the plants" : "Arrange your pots")
                .font(.subheadline.bold()).accessibilityIdentifier("homestead.greenhouse.status")
            Text(watering ? "Choose a plant" : "Tap two pots to swap")
                .font(.caption)
            }.frame(width: 124, alignment: .leading)
            HStack(spacing: 8) {
                ForEach(0..<3) { slot in
                    let plant = order[slot]
                    Button {
                        if watering { selected = slot }
                        else {
                            if let source = pickedPot, source != slot { order.swapAt(source, slot); pickedPot = nil }
                            else { pickedPot = slot }
                            selected = slot
                        }
                    } label: {
                        VStack(spacing: 2) {
                            plantArt(plant, grown: watered.contains(plant)).frame(height: 54)
                            Text(names[plant]).font(.caption2)
                        }.frame(maxWidth: .infinity, minHeight: 76)
                            .background(Color(livingWorldHex: "#B7C7AE").opacity(selected == slot ? 0.35 : 0.12), in: RoundedRectangle(cornerRadius: 12))
                            .overlay { if selected == slot { RoundedRectangle(cornerRadius: 12).stroke(Color(livingWorldHex: "#637E70"), lineWidth: 1.5) } }
                            .contentShape(Rectangle())
                    }.buttonStyle(HomesteadMenuButtonStyle())
                        .accessibilityLabel(names[plant] + ", pot \(slot + 1)")
                        .accessibilityValue(watered.contains(plant) ? "Watered" : selected == slot ? "Selected" : "Ready")
                        .accessibilityIdentifier("homestead.greenhouse.pot.\(slot)")
                        .draggable("tuvlo-pot-slot-\(slot)")
                        .dropDestination(for: String.self) { values, _ in
                            guard !watering, let source = (0..<3).first(where: { values.contains("tuvlo-pot-slot-\($0)") }) else { return false }
                            order.swapAt(source, slot); selected = slot; pickedPot = nil; return true
                        }
                }
            }
            HStack(spacing: 4) {
                HomesteadIconButton(title: "Arrange again", icon: "arrow.uturn.backward") { watering = false; watered = []; pickedPot = nil }
                    .accessibilityIdentifier("homestead.greenhouse.again")
                Button {
                    if watering {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { _ = watered.insert(order[selected]) }
                    } else { watering = true }
                } label: {
                    Label(watering ? watered.contains(order[selected]) ? "Watered" : "Water plant" : "Water", systemImage: watering ? "drop.fill" : "arrow.right")
                        .font(.subheadline.bold()).padding(.horizontal, 12).frame(minHeight: 48)
                        .background(Color(livingWorldHex: "#9FBD78"), in: Capsule())
                }.buttonStyle(HomesteadMenuButtonStyle()).disabled(watering && watered.contains(order[selected]))
                    .accessibilityIdentifier("homestead.greenhouse.water")
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("homestead.greenhouse.activity")
    }
    private func plantArt(_ plant: Int, grown: Bool) -> some View {
        Canvas { context, size in
            let center = size.width / 2
            let green = Color(livingWorldHex: "#648773")
            let height: CGFloat = grown ? 30 : 23
            var stem = Path(); stem.move(to: .init(x: center, y: 40)); stem.addLine(to: .init(x: center, y: 40 - height))
            context.stroke(stem, with: .color(green), lineWidth: 2)
            for side in [-1.0, 1.0] {
                context.fill(Path(ellipseIn: CGRect(x: center + side * 9 - 7, y: 21, width: 14, height: 7)), with: .color(green))
            }
            let petals = plant == 0 ? Color(livingWorldHex: "#E8C98D") : plant == 1 ? green : Color(livingWorldHex: "#ABA1BD")
            context.fill(Path(ellipseIn: CGRect(x: center - 7, y: 34 - height, width: 14, height: plant == 2 ? 15 : 11)), with: .color(petals))
            var pot = Path(); pot.addLines([.init(x: center - 13, y: 37), .init(x: center + 13, y: 37), .init(x: center + 9, y: 53), .init(x: center - 9, y: 53)]); pot.closeSubpath()
            context.fill(pot, with: .color(Color(livingWorldHex: "#C59478")))
            context.fill(Path(roundedRect: CGRect(x: center - 15, y: 35, width: 30, height: 5), cornerRadius: 2), with: .color(Color(livingWorldHex: "#DFB496")))
            if grown {
                for index in 0..<3 {
                    context.fill(Path(ellipseIn: CGRect(x: center + 18 + CGFloat(index % 2) * 5, y: 8 + CGFloat(index) * 7, width: 3, height: 5)), with: .color(Color(livingWorldHex: "#7CAFB4")))
                }
            }
        }.scaleEffect(grown ? 1.04 : 1)
            .overlay {
                Image(systemName: "drop.fill").font(.caption).foregroundStyle(Color(livingWorldHex: "#7CAFB4"))
                    .phaseAnimator([0.0, 1.0], trigger: grown) { drop, phase in
                        drop.offset(x: 18, y: CGFloat(phase * 18 - 12)).opacity(grown && !reduceMotion ? 1 - phase : 0)
                    } animation: { _ in .easeOut(duration: 0.6) }
            }.accessibilityHidden(true)
    }
}
