import SwiftUI

/// Thumbnails are exported from the actual Godot objects, never another renderer.
struct HomesteadPlaceTile: View {
    typealias State = HomesteadCatalogueState
    let kind: HomesteadKind
    let state: State
    var cost: Double? = nil
    var currency: RewardCurrency = .stars
    var approvedWins: Int = 0
    var requiredWins: Int? = nil
    var note: String? = nil
    var quantity = 1
    var active = false
    var affordable = true
    var saved = false
    var location: String? = nil
    var construction: HomesteadConstruction? = nil
    var clock: HomesteadTimeClock? = nil
    let action: () -> Void
    @Environment(\.worldPictureTiles) private var pictures
    var body: some View {
        Button(action: action) {
            HomesteadItemTile(title: kind.title, badge: state == .owned ? (saved ? "archivebox.fill" : "house.fill") : nil, state: state == .owned ? .selected : state == .available ? .available : .locked) {
                thumbnail
            } detail: {
                HStack(spacing: 4) {
                    if let cost {
                        RewardCurrencyAmount(amount: cost, currency: currency, iconSize: 16)
                            .font(.caption.weight(.semibold))
                            .accessibilityIdentifier("homestead.catalog.price." + kind.rawValue)
                    }
                    if state == .owned && !pictures { Text(saved ? "Saved" : "Owned").font(.caption2.weight(.semibold)) }
                    if quantity > 1 { Text("×\(quantity)").font(.caption.monospacedDigit()) }
                }
            }
        }.buttonStyle(HomesteadMenuButtonStyle())
            .accessibilityLabel(kind.title)
            .accessibilityValue(accessibilityState)
            .accessibilityHint(Text(requirementsHint))
    }
    private var accessibilityState: String {
        if let construction, let clock {
            return HomesteadTimeState.clock(end: construction.finish, duration: Double(construction.seconds), now: clock.now).accessibilityValue
        }
        return state == .owned ? (saved ? "Saved" : "Owned") + (location.map { " · " + $0 } ?? "") : state == .available ? (affordable ? "Available to build" : "Need currency") : "Locked"
    }
    private var thumbnail: some View {
        Group {
            if let construction, let clock {
                HomesteadShelfTimedArtwork(asset: "WorldPlace_" + kind.rawValue, active: active, affordable: affordable,
                    construction: construction, clock: clock)
                    .frame(width: 92, height: 44, alignment: .leading)
            } else {
                HomesteadShelfArtwork(asset: "WorldPlace_" + kind.rawValue, active: active, affordable: affordable)
            }
        }
    }
    private var requirementsHint: String {
        var parts: [String] = []
        if let cost { parts.append(currency.amountLabel(cost)) }
        if let requiredWins { parts.append("\(min(approvedWins, requiredWins)) of \(requiredWins) approved missions") }
        if let note { parts.append(String(localized: String.LocalizationValue(note))) }
        if quantity > 1 { parts.append("\(quantity) saved pieces; choose one to edit") }
        return parts.joined(separator: ". ")
    }
}
