import SwiftUI

/// The next place and its checks. Tap for one line of what to do and one action.
struct HomesteadGoalCard: View {
    let goal: HomesteadGoal
    let balance: HomesteadMaterialAmounts
    let approvedWins: Int
    @Binding var expanded: Bool
    let go: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.snappy(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    WorldControlIcon(symbol: goal.isReady ? "build" : "goal")
                        .frame(width: 16, height: 16)
                        .frame(width: 28, height: 28)
                        .background(HomesteadControlSurface())
                    Text(goal.target.title).font(.subheadline.weight(.bold)).lineLimit(1)
                    checks
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel(Text("Next goal: \(goal.target.title)"))
                .accessibilityValue(Text(goal.instruction))
                .accessibilityHint(expanded ? "Hide" : "Show what to do")
                .accessibilityIdentifier("homestead.goal")
            if expanded {
                HStack(spacing: 8) {
                    Text(goal.instruction).font(.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("homestead.goal.instruction")
                    Spacer(minLength: 0)
                    Button(action: go) {
                        Text(actionTitle).font(.caption.weight(.bold))
                            .padding(.horizontal, 14).frame(minHeight: 40)
                            .background(Color(livingWorldHex: goal.isReady ? "#9DBF8A" : "#C4D4B3"), in: Capsule())
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("homestead.goal.go")
                }
            }
        }
        .foregroundStyle(Color(livingWorldHex: "#243C32"))
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: textSize.isAccessibilitySize ? 420 : 330, alignment: .leading)
        .background(Color(livingWorldHex: "#F3EEDC").opacity(reduceTransparency ? 1 : 0.92), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
        // The whole card is a control surface: taps never reach the map below.
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }

    private var actionTitle: LocalizedStringKey {
        switch goal.step {
        case .grow(.food): return "Bake"
        case .missions, .grow, .earn: return "Missions"
        case .collect: return "Show me"
        case .landFirst: return "See land"
        case .build: return "Build"
        }
    }

    private var checks: some View {
        HStack(spacing: 6) {
            chip(icon: "missions", text: "\(min(approvedWins, goal.target.requiredWins))/\(goal.target.requiredWins)", met: goal.winsLeft == 0)
            ForEach(goal.target.materials.parts, id: \.material) { part in
                chip(icon: part.material.icon, text: "\(min(balance[part.material], part.amount))/\(part.amount)",
                     met: goal.missing[part.material] == 0)
            }
            chip(icon: "currency", text: RewardAmount.text(goal.target.price), met: goal.currencyLeft == 0)
        }.font(.caption2.weight(.bold)).monospacedDigit().lineLimit(1).fixedSize()
            .accessibilityHidden(true)
    }

    @ViewBuilder private func chip(icon: String, text: String, met: Bool) -> some View {
        HStack(spacing: 2) {
            if icon == "currency" {
                Image(goal.currency.singleArtwork).resizable().scaledToFit().frame(width: 16, height: 16)
            } else {
                WorldControlIcon(symbol: icon).frame(width: 16, height: 16)
            }
            Text(text)
        }.padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color(livingWorldHex: met ? "#C4D4B3" : "#E9DFC8"), in: Capsule())
            .overlay(alignment: .topTrailing) {
                if met { TuvloCheckMark().frame(width: 12, height: 12).offset(x: 3, y: -3) }
            }
    }
}

/// Material needs for one place: have/need per material, plus one short hint.
struct HomesteadMaterialNeeds: View {
    let target: HomesteadBuildTarget
    let ledger: HomesteadMaterialLedger
    var resolve: ((HomesteadMaterial) -> Void)? = nil
    var body: some View {
        let cost = target.materials
        let missing = ledger.shortfall(for: target)
        // Quiet when covered: the row appears only while something is missing.
        if !missing.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ForEach(cost.parts, id: \.material) { part in
                        Button { resolve?(part.material) } label: {
                            HStack(spacing: 3) {
                                if part.material == .food && ledger.displaysMeals {
                                    HomesteadFarmGoodIcon(good: .meal).frame(width: 20, height: 20)
                                } else { WorldControlIcon(symbol: part.material.icon).frame(width: 20, height: 20) }
                                Text("\(min(ledger.balance[part.material], part.amount))/\(part.amount)").monospacedDigit()
                                if missing[part.material] == 0 {
                                    TuvloCheckMark().frame(width: 14, height: 14)
                                }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(HomesteadMenuButtonStyle()).disabled(resolve == nil)
                            .accessibilityLabel(Text("\(part.material == .food && ledger.displaysMeals ? "Meals" : part.material.title): \(min(ledger.balance[part.material], part.amount)) of \(part.amount)"))
                            .accessibilityHint("Open material source")
                            .accessibilityIdentifier("homestead.materials.source." + part.material.rawValue)
                    }
                }.font(.caption.weight(.bold))
                if let first = missing.parts.first {
                    let source = ledger.source(for: first.material)
                    Text(source.map { ledger.ready($0)[first.material] > 0 } == true
                         ? "Collect " + first.material.title.lowercased()
                         : first.material == .food ? ledger.displaysMeals ? "Pack meals" : "Pack provisions" : "Missions → " + first.material.title.lowercased())
                        .font(.caption).lineLimit(1)
                }
            }.accessibilityElement(children: .contain).accessibilityIdentifier("homestead.materials.needs")
        }
    }
}
