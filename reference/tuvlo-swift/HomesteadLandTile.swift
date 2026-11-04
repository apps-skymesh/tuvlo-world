import SwiftUI

/// Implemented regions can be previewed; north remains an informative locked plan.
struct HomesteadLandTile: View {
    let land: HomesteadLand
    let currency: RewardCurrency
    let owned: Bool
    var buildRequirement: String? = nil
    var showsMissionRequirement = true
    var available = false
    var active = false
    var affordable = true
    let action: () -> Void
    private var item: LivingWorldExpansion? { LivingWorldExpansion.expansion(for: land) }
    private var price: Double { item?.price ?? 110 }
    private var wins: Int { item?.requiredWins ?? 70 }
    private var status: String {
        if owned { return "Owned" }
        var text = currency.amountLabel(price)
        if showsMissionRequirement { text += " · \(wins) approved missions" }
        if let buildRequirement { text += " · " + buildRequirement }
        if showsMissionRequirement && land == .east { text += " · West meadow first" }
        if land == .north { text = "Locked · Coming soon · " + text + " · East waterside first" }
        return text
    }

    @Environment(\.worldPictureTiles) private var pictures
    var body: some View {
        Button(action: action) {
            HomesteadItemTile(title: HomesteadAssetSelection.land(land).title, badge: owned ? "flag.fill" : nil, state: owned ? .selected : available ? .available : .locked) {
                HomesteadShelfArtwork(asset: "WorldLand_" + land.rawValue, active: active, affordable: affordable)
            } detail: {
                    if owned { if !pictures { Text("Owned").font(.caption2.weight(.semibold)) } }
                    else if land == .north { if !pictures { Text("Coming soon").font(.caption2) } }
                    else {
                        RewardCurrencyAmount(amount: price, currency: currency, iconSize: 16).font(.caption.weight(.semibold))
                    }
            }
        }.buttonStyle(HomesteadMenuButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(land.rawValue.capitalized + " plot" + (owned ? " · Owned" : "")))
            .accessibilityValue(Text(status))
            .accessibilityHint("View land details")
    }
}
