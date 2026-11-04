import SwiftUI

enum HomesteadBuilderPage { case info, look }

/// Same rectangles in every placement state, including unavailable tools.
struct HomesteadBuilderBar: View {
    let title: String
    let icon: String
    let location: String
    let status: String
    let valid: Bool
    let statusIsReady: Bool
    let allowsChanges: Bool
    let infoEnabled: Bool
    let lookEnabled: Bool
    let info: () -> Void
    let look: () -> Void
    let rotate: () -> Void
    let place: () -> Void
    let cancel: () -> Void
    let nudge: (Int, Int) -> Void
    @Environment(\.worldMenuSession) private var session
    var body: some View {
        HomesteadJournalSurface(title: "Builder's bar", identifier: "homestead.placement.controls", close: cancel) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        WorldControlIcon(symbol: icon).frame(width: 20, height: 20).accessibilityHidden(true)
                        Text(LocalizedStringKey(title)).font(.system(size: 2)).opacity(0.02).frame(width: 1, height: 1)
                            .accessibilityIdentifier("homestead.placement.preview").accessibilityValue(location)
                    }
                    Spacer(minLength: 0)
                    Group {
                        if statusIsReady { TuvloCheckMark() } else { WorldControlIcon(symbol: "exclamationmark.triangle.fill") }
                    }.frame(width: 16, height: 16).accessibilityHidden(true)
                    Text(LocalizedStringKey(status)).font(.system(size: 2)).opacity(0.02).frame(width: 1, height: 1)
                        .accessibilityIdentifier("homestead.placement.validity")
                }.frame(height: 20)
                HStack(spacing: 8) {
                    tool("Info", icon: "info.circle", enabled: infoEnabled, id: "details", action: info)
                    tool("Look", icon: "paintpalette.fill", enabled: lookEnabled, id: "look", action: look)
                    tool("Rotate", icon: "rotate.right", enabled: allowsChanges, id: "rotate", action: rotate)
                    HomesteadActionButton(title: "Place", icon: "checkmark", state: valid && allowsChanges ? .ready : .disabled, action: place)
                        .accessibilityIdentifier("homestead.placement.confirm")
                    tool("Cancel", icon: "xmark", enabled: true, id: "cancel", action: cancel)
                }.frame(height: 48)
            }.padding(.horizontal, 12).padding(.vertical, 2)
            .accessibilityActions {
                Button("Move left") { if allowsChanges { nudge(-1, 0) } }
                Button("Move right") { if allowsChanges { nudge(1, 0) } }
                Button("Move up") { if allowsChanges { nudge(0, -1) } }
                Button("Move down") { if allowsChanges { nudge(0, 1) } }
            }
        }.environment(\.worldMenuMaterial, .wood)
    }
    private func tool(_ title: String, icon: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button { session?.control("control:" + title); WorldMenuFeedback.touch(.wood); action() } label: {
            WorldControlIcon(symbol: icon).frame(width: 32, height: 32).frame(width: 64, height: 48)
                .background(HomesteadJournalControlSurface(state: enabled ? .available : .disabled))
        }.worldMenuAnchor("control:" + title).buttonStyle(HomesteadMenuButtonStyle(showsDisabledMark: false)).disabled(!enabled)
            .accessibilityLabel(Text(LocalizedStringKey(title))).accessibilityValue(enabled ? "" : "Unavailable")
            .accessibilityIdentifier("homestead.placement." + id)
    }
}

nonisolated enum HomesteadPlacementStatus {
    /// Describes existing validation only; never authorizes a placement.
    static func text(object: HomesteadObject, items: [HomesteadObject], land: Set<HomesteadLand>, hasPreview: Bool,
                     engineValid: Bool, allowsChanges: Bool, failure: String?) -> String {
        guard allowsChanges else { return "Ask your parent to check access" }
        guard hasPreview else { return "Choose a spot" }
        guard object.cells.allSatisfy({ HomesteadGeometry.buildable($0, land: land) }) else { return "Owned land only" }
        if [.greenhouse, .orchard].contains(object.kind), !object.cells.allSatisfy({ HomesteadGeometry.bounds(for: .west).contains($0) }) { return "West meadow only" }
        guard HomesteadGeometry.canPlace(object, among: items, land: land) else { return "Needs a clear spot" }
        guard HomesteadNavigationRules.hasUsableRoutes(objects: items.map { $0.id == object.id ? object : $0 }, land: land) else { return "Leave a path to the door" }
        guard engineValid else { return "Choose a clear spot" }
        return failure != nil ? "Couldn't save. Try again." : "Ready to place"
    }
}
