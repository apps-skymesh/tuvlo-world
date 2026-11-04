import SwiftUI

/// A priced confirmation, not a crafting mini-game. Services still freeze and commit the terms.
struct WorldBuildConfirmation<Needs: View>: View {
    let title: String
    let icon: String
    let asset: String
    let price: Double
    let currency: RewardCurrency
    let ready: Bool
    let allowsChanges: Bool
    let busy: Bool
    var actionTitle = "Build"
    var plannedSeconds: Int? = nil
    var error: String? = nil
    var failure: String? = nil
    @State private var showingFailure = false
    let identifier: String
    let back: () -> Void
    let close: () -> Void
    let confirm: () -> Void
    var resolve: (() -> Void)? = nil
    @ViewBuilder let needs: Needs
    @Environment(\.worldMapShowsPlace) private var mapShowsPlace
    var body: some View {
        WorldPlacePage(title: title, icon: icon, needsTitle: "Requirements", recipeTitle: "Build", material: .paper, allowsClose: !busy, back: back, close: close) {
            ScrollView(.vertical) { needs }.scrollIndicators(.visible).frame(maxHeight: 152)
                .accessibilityIdentifier("homestead.build.requirements")
        } recipe: {
            VStack(spacing: 6) {
                if busy { ProgressView().frame(height: 32).accessibilityLabel("Saving") }
                else if let plannedSeconds { HomesteadDurationLabel(seconds: plannedSeconds).frame(height: 32) }
                else { Color.clear.frame(height: 32).accessibilityHidden(true) }
                HomesteadSlotText(text: error ?? (!allowsChanges ? "Ask your parent to check access" : ""), size: 11)
                    .frame(width: 152, height: 30).accessibilityIdentifier("homestead.build.status")
                Button {
                    WorldMenuFeedback.touch(.brass)
                    if ready { confirm() } else { resolve?() }
                } label: {
                    HStack(spacing: 5) {
                        HomesteadControlMark(state: busy || !allowsChanges ? .disabled : ready ? .available : .locked)
                        Text(LocalizedStringKey(actionTitle)).font(.system(size: 12, weight: .bold))
                        RewardCurrencyAmount(amount: price, currency: currency, iconSize: 18).font(.system(size: 12, weight: .bold))
                    }.frame(width: 152, height: 48)
                        .background(HomesteadJournalControlSurface(state: busy || !allowsChanges ? .disabled : ready ? .available : .locked))
                }.buttonStyle(HomesteadMenuButtonStyle()).disabled(busy || !allowsChanges || (!ready && resolve == nil))
                    .accessibilityLabel(actionTitle + " · " + currency.amountLabel(price))
                    .accessibilityValue(busy ? "Saving" : ready ? "Ready" : "Requirements not met")
                    .worldMenuAnchor("build.confirm").accessibilityIdentifier(identifier)
            }
        } hero: {
            // The real model already stands at its spot; otherwise show the sharp render, not the miniature.
            if mapShowsPlace { Color.clear } else {
                HomesteadShelfArtwork(asset: asset, active: false, affordable: ready)
                    .environment(\.worldPictureTiles, true).frame(maxWidth: 220, maxHeight: 220)
            }
        }.accessibilityHidden(showingFailure).allowsHitTesting(!showingFailure)
            .overlay {
                if showingFailure, let failure {
                    ZStack {
                        Color.black.opacity(0.16).contentShape(Rectangle()).onTapGesture {}.accessibilityHidden(true)
                        HomesteadWorldDialog(title: "Couldn't update", icon: "exclamationmark.triangle.fill", message: failure) {
                            HomesteadActionButton(title: "Back", icon: "chevron.backward") { showingFailure = false }
                        }.frame(maxWidth: 420).padding(8)
                    }
                }
            }
            .onChange(of: failure) { _, message in showingFailure = message != nil }
    }
}

struct WorldBuildNeeds: View {
    let wins: Int
    let requiredWins: Int
    let food: Int
    let requiredFood: Int
    let chapterComplete: Bool
    let allowsChanges: Bool
    var requiresWest = false
    var ownsWest = true
    let missions: () -> Void
    let meals: () -> Void
    let chapter: () -> Void
    let land: () -> Void
    var body: some View {
        VStack(spacing: 6) {
            if !allowsChanges { HomesteadRequirementChip(title: "Parent access", icon: "lock.fill", state: .locked, action: missions) }
            if !chapterComplete { HomesteadRequirementChip(title: "First chapter", icon: "house.fill", state: .locked, action: chapter) }
            HomesteadRequirementChip(title: "\(min(wins, requiredWins))/\(requiredWins) missions", state: wins >= requiredWins ? .ready : .locked, action: missions)
                .accessibilityIdentifier("homestead.build.missions")
            if requiredFood > 0 {
                HomesteadRequirementChip(title: "\(food)/\(requiredFood) meals", icon: "material.food", state: food >= requiredFood ? .ready : .locked, action: meals)
                    .accessibilityIdentifier("homestead.build.meals")
            }
            if requiresWest { HomesteadRequirementChip(title: "West meadow", icon: "map.fill", state: ownsWest ? .ready : .locked, action: land)
                    .accessibilityIdentifier("homestead.build.land") }
        }
    }
}
