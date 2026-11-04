import SwiftUI

/// Read-only plans stay separate from purchasable kinds and saved ownership.
struct HomesteadFuturePlace: Identifiable {
    let id: String
    let title: String
    let icon: String
    let price: Double
    let wins: Int
    let land: String
    let activity: String

    static let places: [Self] = [
        .init(id: "duckHouse", title: "Duck house", icon: "bird.fill", price: 40, wins: 45,
              land: "East waterside", activity: "Guide a duck family."),
        .init(id: "footbridge", title: "Footbridge", icon: "water.waves", price: 45, wins: 55,
              land: "East waterside", activity: "Sail paper boats."),
        .init(id: "observatory", title: "Observatory", icon: "moon.stars.fill", price: 55, wins: 70,
              land: "North woodland", activity: "Trace constellations."),
        .init(id: "pavilion", title: "Pavilion", icon: "tent.fill", price: 70, wins: 90,
              land: "North woodland", activity: "Host a picnic.")
    ]
}

struct HomesteadFuturePlaceTile: View {
    let place: HomesteadFuturePlace
    let currency: RewardCurrency
    let approvedWins: Int
    let action: () -> Void
    @Environment(\.worldPictureTiles) private var pictures

    private var accessibleTerms: String {
        let price = currency.amountLabel(place.price)
        return "Locked · Coming soon · \(price) · \(place.wins) approved missions · \(place.land) · \(place.activity)"
    }
    private var progressHint: String {
        "\(min(approvedWins, place.wins)) approved missions completed. \(max(0, place.wins - approvedWins)) more to reach \(place.wins). View details."
    }
    var body: some View {
        Button(action: action) {
            HomesteadItemTile(title: place.title, state: .locked) {
                thumbnail
            } detail: {
                if pictures { RewardCurrencyAmount(amount: place.price, currency: currency, iconSize: 16).font(.caption.weight(.semibold)).opacity(0.6) } else { Text("Coming soon").font(.caption2).frame(height: 18) }
            }
        }.buttonStyle(HomesteadMenuButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(LocalizedStringKey(place.title)))
            .accessibilityValue(Text(accessibleTerms))
            .accessibilityHint(Text(progressHint))
            .accessibilityIdentifier("homestead.future." + place.id)
    }
    private var thumbnail: some View {
        HomesteadCatalogueArtwork(state: .locked) {
            Image(systemName: place.icon).font(.system(size: 42, weight: .regular))
                .foregroundStyle(Color(livingWorldHex: "#637E70"))
        }
    }
}
