import SwiftUI

/// Compact presentation only. Exact saved amounts remain available to speech
/// and in the wallet popover; no abbreviated number reaches a purchase action.
enum HomesteadWalletDisplay {
    static func compact(_ amount: Double, locale: Locale = .current) -> String {
        guard amount.isFinite else { return "—" }
        if abs(amount) < 1_000 {
            let exact = RewardAmount.text(amount, locale: locale)
            if exact.count <= 6 { return exact }
            if abs(amount) >= 999.5 { return amount < 0 ? "≈-1K" : "≈1K" }
            let short = amount.formatted(.number.grouping(.never).precision(.significantDigits(3)).locale(locale))
            return "≈" + (short.count <= 7 ? short : amount.formatted(.number.notation(.scientific).precision(.significantDigits(2)).locale(locale)))
        }
        let powers: [(Double, String)] = [(1e18, "Qi"), (1e15, "Qa"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        if var index = powers.firstIndex(where: { abs(amount) >= $0.0 }), abs(amount) < 1e21 {
            // Promote a rounded 1,000 to the next unit before formatting, so
            // boundary values never grow into a wider label such as 1,000K.
            if (abs(amount) / powers[index].0 * 10).rounded() >= 10_000 {
                if index == 0 { return scientific(amount, locale: locale) }
                index -= 1
            }
            let (divisor, suffix) = powers[index]
            return "≈" + (amount / divisor).formatted(.number.grouping(.never).precision(.fractionLength(0...1)).locale(locale)) + suffix
        }
        return scientific(amount, locale: locale)
    }
    private static func scientific(_ amount: Double, locale: Locale) -> String {
        "≈" + amount.formatted(.number.notation(.scientific).precision(.significantDigits(1)).locale(locale))
    }
}

struct HomesteadWorldBalance: View {
    let kid: Child
    var materials: HomesteadMaterialAmounts? = nil
    var displaysMeals = false
    /// Every collected good; without a farm the crate keeps showing Food alone.
    var storedGoods: Int? = nil
    var openDetails: (() -> Void)? = nil
    var openWarehouse: (() -> Void)? = nil
    /// World's HUD shows the level as its own ring beside Return (A44).
    var showsLevel = true
    @State private var expanded = false
    @Environment(\.worldMenuSession) private var session
    var body: some View {
        let wallet = EconomyLedger.forChild(kid)
        HStack(spacing: 3) {
            if showsLevel {
            VStack(spacing: 0) {
                Text("Lv").font(.system(size: 10, weight: .bold))
                Text(HomesteadWalletDisplay.compact(Double(wallet.level))).font(.system(size: 11, weight: .bold)).lineLimit(1)
            }.frame(width: 48).contentShape(Rectangle()).onTapGesture(perform: showExact)
                .accessibilityElement(children: .ignore).accessibilityLabel("Level \(wallet.level)")
                .accessibilityIdentifier("homestead.level")
            }
            amount(wallet.worldBalance(in: .coins), currency: .coins).contentShape(Rectangle()).onTapGesture(perform: showExact)
            amount(wallet.worldBalance(in: .stars), currency: .stars).contentShape(Rectangle()).onTapGesture(perform: showExact)
            if let materials {
                Button {
                    session?.control("hud.warehouse"); WorldMenuFeedback.touch(.paper)
                    if let openWarehouse { openWarehouse() } else { showExact() }
                } label: {
                    VStack(spacing: 0) {
                        WorldControlIcon(symbol: openWarehouse == nil ? HomesteadMaterial.food.icon : "archivebox").frame(width: 22, height: 22).accessibilityHidden(true)
                        Text(HomesteadWalletDisplay.compact(Double(storedGoods ?? materials.food))).font(.caption.bold()).lineLimit(1)
                    }.frame(maxWidth: .infinity).frame(height: 52).contentShape(Rectangle())
                }.buttonStyle(.plain).modifier(WorldLandingBounce(target: "hud.warehouse")).worldMenuAnchor("hud.warehouse")
                    .accessibilityLabel(openWarehouse == nil ? "\(materials.food) Food" : "Warehouse")
                    .accessibilityValue("\(materials.food) \(displaysMeals ? "Meals" : "Food") stored")
                    .accessibilityIdentifier("homestead.wallet.food")
            }
        }.monospacedDigit().padding(.horizontal, 7).frame(height: HomesteadToolbeltGeometry.height)
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .background(Color(livingWorldHex: "#F3EEDC"), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.85), lineWidth: 1))
            .accessibilityAction(named: Text("Exact balances"), showExact)
            .popover(isPresented: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Label { Text("Wallet").font(.headline).accessibilityAddTraits(.isHeader) } icon: { WorldControlIcon(symbol: "coins").frame(width: 24, height: 24) }
                    ViewThatFits(in: .vertical) {
                        exactValues(wallet).fixedSize(horizontal: false, vertical: true)
                        ScrollView { exactValues(wallet) }
                            .accessibilityIdentifier("homestead.wallet.exact.scroll")
                    }
                    HomesteadActionButton(title: "Done", icon: "checkmark") { expanded = false }
                        .accessibilityIdentifier("homestead.wallet.done")
                }.font(.subheadline).padding(20).frame(width: 300).frame(maxHeight: 300)
                    .presentationBackground(Color(livingWorldHex: "#F3EBD6"))
                    .presentationCompactAdaptation(.popover)
            }
            .environment(\.colorScheme, .light)
            .accessibilityElement(children: .contain).accessibilityIdentifier("homestead.wallet")
    }
    private func showExact() {
        session?.control("hud.wallet"); WorldMenuFeedback.touch(.paper)
        if let openDetails { openDetails() } else { expanded = true }
    }
    private func exactValues(_ wallet: EconomyLedger) -> some View {
        HomesteadExactBalanceValues(wallet: wallet, materials: materials, displaysMeals: displaysMeals)
    }
    private func amount(_ value: Double, currency: RewardCurrency) -> some View {
        VStack(spacing: 0) {
            Image(currency.singleArtwork).resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true)
            Text(HomesteadWalletDisplay.compact(value)).font(.caption.bold()).lineLimit(1)
        }.frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore).accessibilityLabel(currency.amountLabel(value))
            .accessibilityIdentifier("homestead.wallet." + currency.rawValue)
    }
}

struct HomesteadExactBalanceValues: View {
    let wallet: EconomyLedger
    let materials: HomesteadMaterialAmounts?
    let displaysMeals: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Level \(wallet.level)")
            Text(RewardCurrency.coins.amountLabel(wallet.worldBalance(in: .coins)))
            Text(RewardCurrency.stars.amountLabel(wallet.worldBalance(in: .stars)))
            if let materials { Text("\(materials.food) \(displaysMeals ? "Meals" : "Food")") }
        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The crate (or any flight target) squashes and springs back as goods land.
struct WorldLandingBounce: ViewModifier {
    let target: String
    @Environment(\.worldMenuSession) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var gained = 0
    @State private var rise: CGFloat = 0
    func body(content: Content) -> some View {
        content.scaleEffect(scale)
            .overlay(alignment: .top) {
                if gained > 0 {
                    Text("+\(gained)").font(WorldCardFinish.number(20)).foregroundStyle(WorldCardFinish.ink)
                        .shadow(color: .white, radius: 2).offset(y: 46 - rise).opacity(Double(1 - rise / 40))
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .onChange(of: session?.landedCount ?? 0) { _, _ in
            guard !reduceMotion, session?.landedTarget == target else { return }
            gained = session?.landedAmount ?? 1; rise = 0
            withAnimation(.easeOut(duration: 0.8)) { rise = 36 }
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(820)); gained = 0 }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.4)) { scale = 1.3 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { scale = 1 }
            }
        }
    }
}
