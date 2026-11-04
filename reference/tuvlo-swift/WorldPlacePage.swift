import SwiftUI

/// A place is the scene. Framed wings sit either side of the real building without a second 3D viewport.
struct WorldPlacePage<Needs: View, Recipe: View, Hero: View>: View {
    let title: String
    let icon: String
    var needsTitle = "Ingredients"
    var recipeTitle = "Recipe"
    var material: WorldMenuMaterial = .wood
    var allowsClose = true
    var contentIdentifier = "homestead.place.page"
    var move: (() -> Void)? = nil
    var allowsMove = true
    let back: () -> Void
    let close: () -> Void
    @ViewBuilder let needs: Needs
    @ViewBuilder let recipe: Recipe
    @ViewBuilder let hero: Hero
    @AccessibilityFocusState private var headingFocused: Bool
    var body: some View {
        GeometryReader { area in
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    WorldCardCorner(label: "Back", icon: "chevron.backward", enabled: allowsClose, action: back)
                        .accessibilityIdentifier("homestead.panel.back")
                    if let move {
                        WorldCardCorner(label: "Move " + title, icon: "tool.move", enabled: allowsMove, action: move)
                            .accessibilityIdentifier("homestead.details.move")
                    } else { Color.clear.frame(width: 48, height: 48).accessibilityHidden(true) }
                    Spacer(minLength: 0)
                    // The real building is framed on the map; its name is spoken, not printed.
                    WorldSpokenTitle(title: title).accessibilityFocused($headingFocused).accessibilityIdentifier("homestead.panel.title")
                    Spacer(minLength: 0)
                    Color.clear.frame(width: 48, height: 48).accessibilityHidden(true)
                    WorldCardCorner(label: "Close window", icon: "xmark", enabled: allowsClose, action: close)
                        .accessibilityIdentifier("homestead.panel.close")
                }
                HStack(alignment: .center, spacing: 12) {
                    wing(needsTitle) { needs }.frame(width: 148)
                    hero.frame(maxWidth: .infinity, maxHeight: .infinity)
                    wing(recipeTitle) { recipe }.frame(width: 176)
                }.frame(width: min(720, max(0, area.size.width - 24))).frame(maxHeight: .infinity)
            }.padding(.horizontal, 12).padding(.bottom, 8)
                .frame(width: area.size.width, height: area.size.height)
                .foregroundStyle(Color(livingWorldHex: "#243C32")).environment(\.colorScheme, .light)
                .worldMenuArrival()
                .accessibilityElement(children: .contain).accessibilityIdentifier(contentIdentifier)
                .accessibilityAction(.escape) { if allowsClose { close() } }
        }.onAppear { headingFocused = true }.onChange(of: title) { _, _ in headingFocused = true }
            .environment(\.worldMenuMaterial, material).accessibilityElement(children: .contain).accessibilityIdentifier("homestead.panel")
    }
    private func wing<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 4) {
            WorldSpokenTitle(title: title)
            content()
        }.padding(10).background(WorldCardFrame(cornerRadius: 22))
    }
}

struct WorldPlacePaper: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16).fill(Color(livingWorldHex: "#F3EBD6"))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(livingWorldHex: "#BCAE8C"), lineWidth: 1))
            .overlay(alignment: .top) { Capsule().fill(Color(livingWorldHex: "#FFF9E9")).frame(height: 2).padding(.horizontal, 16) }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .allowsHitTesting(false)
    }
}
