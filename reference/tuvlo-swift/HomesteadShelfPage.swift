import SwiftUI

struct HomesteadShelfRequirement: Identifiable {
    let id: String
    let title: String
    var icon = "checklist"
    var currency: RewardCurrency? = nil
    var met = false
    let resolve: () -> Void
}

/// The same reserved picture, description, chip rail and action slots for every
/// Build/Land selection. Buying remains in the existing confirmation.
struct HomesteadShelfPage: View {
    let selection: HomesteadAssetSelection
    let requirements: [HomesteadShelfRequirement]
    var construction: HomesteadConstruction? = nil
    var clock: HomesteadTimeClock? = nil
    var affordable = true
    /// The real model already stands at its best spot on the map; leave the centre clear for it.
    var shownOnMap = false
    let actionTitle: String
    var actionState: HomesteadControlState = .available
    var primaryIdentifier = "homestead.shelf.primary"
    var back: () -> Void = {}
    var close: () -> Void = {}
    let action: () -> Void
    var body: some View {
        WorldPlacePage(title: selection.title, icon: selection.icon, needsTitle: "Requirements", recipeTitle: "Place",
                       material: .paper, contentIdentifier: "homestead.shelf.details", back: back, close: close) {
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    ForEach(requirements) { requirement in
                        HomesteadRequirementChip(title: requirement.title, icon: requirement.icon, currency: requirement.currency,
                            state: requirement.met ? .ready : .locked, action: requirement.resolve)
                            .accessibilityIdentifier("homestead.shelf.requirement." + requirement.id)
                    }
                }
            }.scrollIndicators(.visible).frame(maxHeight: 152).accessibilityIdentifier("homestead.details.requirements")
        } recipe: {
            VStack(spacing: 8) {
                // Spoken, not printed: the place itself is the description.
                Text(LocalizedStringKey(selection.shelfPurpose)).font(.system(size: 2)).opacity(0.02).frame(width: 1, height: 1)
                    .accessibilityIdentifier("homestead.details.purpose")
                // Building wears the hammer; an owned place keeps its own icon.
                HomesteadActionButton(title: actionTitle, icon: actionTitle == "Review" ? "build" : selection.icon, state: actionState, action: action)
                    .accessibilityIdentifier(primaryIdentifier)
            }
        } hero: {
            if shownOnMap { Color.clear }
            else if case .piece(let kind, _) = selection {
                WorldPlacePedestal(kind: kind, affordable: affordable, construction: construction, clock: clock)
            } else if let asset = selection.shelfAsset {
                if let construction, let clock {
                    HomesteadShelfTimedArtwork(asset: asset, active: false, affordable: affordable,
                        size: 48, construction: construction, clock: clock).frame(maxWidth: 220, maxHeight: 220)
                } else { HomesteadShelfArtwork(asset: asset, active: false, affordable: affordable).environment(\.worldPictureTiles, true).frame(maxWidth: 220, maxHeight: 220) }
            } else { WorldControlIcon(symbol: selection.icon).frame(width: 80, height: 80) }
        }
    }

}

extension HomesteadAssetSelection {
    var shelfIsLand: Bool { if case .land = self { return true }; return false }
    var shelfAsset: String? {
        switch self {
        case .piece(let kind, _): return "WorldPlace_" + kind.rawValue
        case .land(let land): return "WorldLand_" + land.rawValue
        case .future: return nil // No real model exists; never fabricate a miniature.
        }
    }
    var shelfPurpose: String {
        switch self {
        case .land: return "12 × 12 squares"
        case .future(let id): return HomesteadFuturePlace.places.first { $0.id == id }?.activity ?? "Coming soon"
        case .piece(let kind, _):
            switch kind {
            case .path: return "Connect your places"
            case .bench: return "A spot to rest"
            case .rocks: return "Shape your garden"
            case .nook: return "A reading picnic"
            case .treehouse: return "A hideaway in the leaves"
            default: return kind.purpose
            }
        }
    }
}

struct HomesteadShelfEntry: Identifiable {
    let id: String
    let kind: HomesteadKind?
    let future: HomesteadFuturePlace?
    var land: HomesteadLand? = nil
}

struct HomesteadShelfLandEntry: Identifiable {
    let land: HomesteadLand
    var id: String { land.rawValue }
}
