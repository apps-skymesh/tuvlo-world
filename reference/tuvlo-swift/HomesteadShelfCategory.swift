import SwiftUI

/// Build shelf groups (A44 slice B). Presentation only: every kind keeps its
/// identity, price, requirements and saved placements; categories just filter
/// which tiles share the shelf row.
enum HomesteadShelfCategory: String, CaseIterable, Identifiable {
    case home, farm, animals, decor
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .farm: return String(localized: "Farm")
        case .animals: return String(localized: "Animals")
        case .decor: return String(localized: "Decor")
        }
    }
    var icon: String {
        switch self {
        case .home: return "category.home"
        case .farm: return "category.farm"
        case .animals: return "category.animals"
        case .decor: return "category.decor"
        }
    }
    static func of(_ kind: HomesteadKind) -> Self {
        switch kind {
        case .cottage, .tree, .path, .nook, .treehouse, .workshop: return .home
        case .garden, .orchard, .windmill, .greenhouse, .grill: return .farm
        case .barn, .doghouse, .pond: return .animals
        case .flowers, .rocks, .bench: return .decor
        }
    }
    static func of(futurePlace id: String) -> Self {
        switch id {
        case "duckHouse": return .animals
        case "observatory": return .home
        default: return .decor
        }
    }
}

/// A compact icon grid that fits the shelf's 124-point picture row: two rows of
/// 52-point targets. Land joins as a third column when the family can view it
/// (A44 slice C), so the map needs no separate Land control.
struct HomesteadShelfCategoryPicker: View {
    let selected: HomesteadShelfCategory
    var landSelected = false
    var openLand: (() -> Void)? = nil
    let choose: (HomesteadShelfCategory) -> Void
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow { button(.home); button(.farm); if openLand != nil { landButton } }
            GridRow { button(.animals); button(.decor); if openLand != nil { Color.clear.frame(width: 52, height: 52) } }
        }
        .frame(width: openLand == nil ? 104 : 156, height: 104)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homestead.shelf.categories")
    }
    private func chip(icon: String, isSelected: Bool) -> some View {
        WorldControlIcon(symbol: icon, accented: isSelected)
            .frame(width: 32, height: 32)
            .frame(width: 46, height: 46)
            .background(HomesteadControlSurface(selected: isSelected))
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
    }
    private func button(_ category: HomesteadShelfCategory) -> some View {
        let isSelected = !landSelected && category == selected
        return Button { SoundEffects.playTapConfirm(); choose(category) } label: { chip(icon: category.icon, isSelected: isSelected) }
            .buttonStyle(HomesteadControlButtonStyle())
            .accessibilityLabel(Text(category.title))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("homestead.shelf.category." + category.rawValue)
    }
    private var landButton: some View {
        Button { SoundEffects.playTapConfirm(); openLand?() } label: { chip(icon: "land", isSelected: landSelected) }
            .buttonStyle(HomesteadControlButtonStyle())
            .accessibilityLabel(Text("Land"))
            .accessibilityAddTraits(landSelected ? .isSelected : [])
            .accessibilityIdentifier("homestead.land.open")
    }
}
