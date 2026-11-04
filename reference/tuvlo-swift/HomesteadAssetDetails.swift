import SwiftUI

/// Browsing a plan never grants ownership or starts a purchase.
enum HomesteadAssetSelection: Equatable {
    case piece(HomesteadKind, id: UUID? = nil)
    case future(String)
    case land(HomesteadLand)

    var title: String {
        switch self {
        case .piece(let kind, _): return kind.title
        case .future(let id): return HomesteadFuturePlace.places.first { $0.id == id }?.title ?? "Future place"
        case .land(let land): return land == .west ? "West meadow" : land == .east ? "East waterside" : "North woodland"
        }
    }
    var icon: String {
        switch self {
        case .piece(let kind, _): return kind.controlIcon
        case .future(let id): return HomesteadFuturePlace.places.first { $0.id == id }?.icon ?? "sparkles"
        case .land: return "map.fill"
        }
    }
}

extension HomesteadKind {
    var purpose: String {
        switch self {
        case .barn: return "Feed wheat to raise sheep for meat."
        case .doghouse: return "Welcome your own dog."
        case .grill: return "Cook a meal for the family."
        case .windmill: return "Turn wheat into flour."
        case .cottage: return "Your home."
        case .tree: return "Approved missions grow your tree."
        case .garden: return "Grow wheat and share a picnic."
        case .flowers, .pond: return "Three flowers near a pond attract a duck."
        case .workshop: return "Fold paper toys and harvest baskets."
        case .greenhouse: return "Grow potted plants."
        case .orchard: return "Pick apples, pears and plums."
        case .path, .rocks, .bench, .nook, .treehouse: return ""
        }
    }
}

struct HomesteadAssetDetails: View {
    let selection: HomesteadAssetSelection
    let kid: Child
    let objects: [HomesteadObject]
    let allowsChanges: Bool
    let move: (HomesteadObject) -> Void
    let story: () -> Void
    let bread: () -> Void
    let millLook: (Int) throws -> Void
    @State private var saveError: String?
    private var currency: RewardCurrency { LivingWorldEconomy.currency(for: kid) }
    private var wins: Int { EconomyLedger.forChild(kid).approvedWins }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch selection {
            case .future(let id):
                if let place = HomesteadFuturePlace.places.first(where: { $0.id == id }) {
                    Label("Coming soon", systemImage: "lock.fill").font(.caption.weight(.semibold))
                    Text(LocalizedStringKey(place.activity)).font(.subheadline)
                        .accessibilityIdentifier("homestead.details.purpose")
                    terms(price: place.price, required: place.wins, land: place.land)
                }
            case .land(let land):
                Text("12 × 12 squares").font(.subheadline)
                if LivingWorldExpansion.expansion(for: land)?.isOwned(by: kid) != true {
                    Label("Coming soon", systemImage: "lock.fill").font(.caption.weight(.semibold))
                    terms(price: 110, required: 70, land: "East waterside")
                }
            case .piece(let kind, let id):
                HStack {
                    if !kind.purpose.isEmpty {
                        Text(LocalizedStringKey(kind.purpose)).font(.subheadline)
                            .accessibilityIdentifier("homestead.details.purpose")
                    }
                    Spacer(minLength: 0)
                    Text("\(kind.width) × \(kind.depth)").font(.caption)
                        .accessibilityLabel("\(kind.width) by \(kind.depth) spaces")
                }
                HStack(spacing: 20) {
                    if let object = objects.first(where: { $0.kind == kind && (id == nil || $0.id == id) }) {
                        HomesteadActionButton(title: "Move", icon: "figure.walk", state: allowsChanges ? .available : .disabled) { move(object) }.accessibilityIdentifier("homestead.details.move")
                    } else { Label("Unavailable", systemImage: "lock.fill").font(.caption) }
                    if HomesteadBreadStory.Step.allCases.contains(where: { $0.kind == kind }) {
                        Button(action: bread) { Label("Bake", systemImage: "leaf").frame(minHeight: 48) }
                            .buttonStyle(HomesteadMenuButtonStyle()).accessibilityIdentifier("homestead.details.bread")
                    }
                    if HomesteadMeadowStory.Step.allCases.contains(where: { $0.kind == kind }) {
                        Button(action: story) { Label("Picnic", systemImage: "leaf.fill").frame(minHeight: 48) }
                            .buttonStyle(HomesteadMenuButtonStyle()).accessibilityIdentifier("homestead.details.story")
                    }
                    if kind == .windmill, let object = objects.first(where: { $0.kind == kind }) {
                        HStack(spacing: 0) {
                            millLookButton("Sage roof", value: 0, selected: object.style == 0)
                            millLookButton("Clay roof", value: 1, selected: object.style == 1)
                        }
                    }
                }.font(.subheadline.weight(.semibold))
            }
            if let saveError { Text(saveError).font(.caption) }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain).accessibilityIdentifier("homestead.details")
    }
    private func millLookButton(_ title: String, value: Int, selected: Bool) -> some View {
        Button {
            do { try millLook(value); saveError = nil } catch { saveError = error.localizedDescription }
        } label: {
            Circle().fill(Color(livingWorldHex: value == 0 ? "#54785C" : "#AD624A")).frame(width: 28, height: 28)
                .overlay { if selected { TuvloCheckMark().frame(width: 16, height: 16) } }
                .frame(width: 48, height: 48).contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges).accessibilityLabel(Text(LocalizedStringKey(title))).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("homestead.windmill.look.\(value)")
    }
    private func terms(price: Double, required: Int, land: String) -> some View {
        HStack(spacing: 12) {
            RewardCurrencyAmount(amount: price, currency: currency, iconSize: 20).font(.subheadline.weight(.semibold))
            HomesteadRequirementChip(title: "\(min(wins, required))/\(required) missions", state: wins >= required ? .ready : .locked)
                .accessibilityLabel("\(min(wins, required)) of \(required) missions approved")
            HomesteadRequirementChip(title: land + " first", icon: "map.fill", state: .locked)
        }.accessibilityIdentifier("homestead.details.requirements")
    }
}
