import SwiftUI

/// Shared optical bounds and state treatment for Build and Land choices.
enum HomesteadCatalogueState: Equatable { case owned, available, locked }

struct HomesteadCatalogueArtwork<Artwork: View>: View {
    let state: HomesteadCatalogueState
    @ViewBuilder let artwork: Artwork
    var body: some View {
        artwork.frame(width: 60, height: 60)
            .saturation(state == .locked ? 0 : 1.08)
            .opacity(state == .locked ? 0.38 : 1)
            .shadow(color: .black.opacity(state == .locked ? 0 : 0.12), radius: 1.5, y: 2)
            .frame(width: 64, height: 64)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color.white.opacity(state == .locked ? 0.12 : 0.5),
                                                  Color(livingWorldHex: "#B9C7A5").opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75))
            .accessibilityHidden(true)
    }
}

/// A thin raised plate. Dock, goal, and menu icons share this edge and shadow.
struct HomesteadControlSurface: View {
    var selected = false
    var prominent = false
    /// The map's one warm, raised button (Build).
    var warm = false
    var body: some View {
        let fill: [Color] = warm ? [Color(livingWorldHex: "#FFE9A8"), Color(livingWorldHex: "#F2C65A")] : prominent ? [Color(livingWorldHex: "#D3E8B4"), Color(livingWorldHex: "#9ABB7D")] :
            selected ? [Color(livingWorldHex: "#E7F0D8"), Color(livingWorldHex: "#B7CBA4")] :
            [Color(livingWorldHex: "#FBF7EC"), Color(livingWorldHex: "#E3D9C4")]
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom))
            // Honey rim shared with every World card and tile.
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WorldCardFinish.rim.opacity(selected ? 0.75 : 0.45), lineWidth: selected ? 1.5 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.92), lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            }
            .shadow(color: warm ? Color(livingWorldHex: "#B8892E") : .clear, radius: 0, y: warm ? 3 : 0)
            .shadow(color: Color(livingWorldHex: "#243C32").opacity(warm ? 0.26 : 0.16), radius: warm ? 6 : 3, y: warm ? 4 : 2)
            .allowsHitTesting(false)
    }
}
