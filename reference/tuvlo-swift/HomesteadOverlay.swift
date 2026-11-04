import SwiftUI

/// All bottom pages use the same journal, including catalogue drawers.
struct HomesteadOverlay<Content: View>: View {
    let title: String
    let icon: String
    var allowsClose = true
    var modal = true
    var expands = false
    var back: (() -> Void)? = nil
    var backIdentifier = "homestead.panel.back"
    let close: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HomesteadJournalPanel(title: title, icon: icon, allowsClose: allowsClose, modal: modal,
            back: back, backIdentifier: backIdentifier, close: close) { content }
    }
}

struct HomesteadIconButton: View {
    let title: String
    let icon: String
    var selected = false
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    @Environment(\.worldMenuSession) private var menuSession
    @Environment(\.worldMenuMaterial) private var material
    var body: some View {
        Button { menuSession?.control("control:" + title); WorldMenuFeedback.touch(material); action() } label: {
            WorldControlIcon(symbol: icon, accented: selected).frame(width: 28, height: 28)
                .frame(width: 48, height: 48)
                .background(HomesteadJournalControlSurface(state: enabled ? (selected ? .selected : .available) : .disabled))
                .overlay(alignment: .topTrailing) {
                    if selected { HomesteadControlMark(state: .selected).frame(width: 16, height: 16) }
                }.contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle()).worldMenuAnchor("control:" + title).accessibilityLabel(Text(LocalizedStringKey(title)))
            .accessibilityAddTraits(selected ? .isSelected : []).help(Text(LocalizedStringKey(title)))
    }
}

extension HomesteadKind {
    var controlIcon: String {
        switch self {
        case .barn: return "barn"
        case .doghouse: return "doghouse"
        case .grill: return "grill"
        case .windmill: return "windmill"
        case .orchard: return "tree.fill"
        case .greenhouse: return "garden"
        case .workshop: return "hammer"
        case .cottage: return "house.fill"
        case .tree: return "tree.fill"
        case .path: return "path"
        case .garden: return "garden"
        case .flowers: return "flower"
        case .rocks: return "rocks"
        case .bench: return "bench"
        case .pond: return "water.waves"
        case .nook: return "book.closed.fill"
        case .treehouse: return "treehouse"
        }
    }
}

/// Navigation changes only which controls are visible, never the saved draft.
struct HomesteadMenuSteps: View {
    let titles: [String]
    @Binding var selection: Int
    /// App-art picture for each step; the title then stays spoken only.
    var icons: [String]? = nil
    var body: some View {
        HStack(spacing: 4) {
            stepButton("Previous step", mirrored: false) { selection = max(0, selection - 1) }
                .disabled(selection == 0).accessibilityIdentifier("homestead.steps.previous")
            VStack(spacing: 2) {
                if let icons, icons.indices.contains(selection) {
                    WorldControlIcon(symbol: icons[selection]).frame(width: 34, height: 34).id(selection)
                        .transition(.scale.combined(with: .opacity))
                    WorldSpokenTitle(title: titles[selection])
                } else { Text(LocalizedStringKey(titles[selection])).font(.subheadline.bold()) }
                HStack(spacing: 4) {
                    ForEach(titles.indices, id: \.self) { index in
                        Capsule().fill(Color(livingWorldHex: "#496F56").opacity(index == selection ? 1 : 0.2))
                            .frame(width: index == selection ? 12 : 4, height: 4)
                    }
                }.accessibilityHidden(true)
            }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
                .accessibilityValue("Step \(selection + 1) of \(titles.count)")
                .accessibilityIdentifier("homestead.steps.current")
            stepButton("Next step", mirrored: true) { selection = min(titles.count - 1, selection + 1) }
                .disabled(selection == titles.count - 1).accessibilityIdentifier("homestead.steps.next")
        }.animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
    }
    /// Back and next are one matching pair: the same arrow, mirrored.
    private func stepButton(_ title: String, mirrored: Bool, action: @escaping () -> Void) -> some View {
        StepArrow(title: title, mirrored: mirrored, action: action)
    }
    private struct StepArrow: View {
        let title: String
        let mirrored: Bool
        let action: () -> Void
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            Button { WorldMenuFeedback.touch(.paper); action() } label: {
                Image("WorldIconLeave").resizable().scaledToFit().frame(width: 26, height: 26)
                    .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                    .saturation(enabled ? 1 : 0).opacity(enabled ? 1 : 0.35)
                    .frame(width: 48, height: 48).background(HomesteadControlSurface()).contentShape(Rectangle())
            }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(Text(LocalizedStringKey(title)))
        }
    }
}

/// A native horizontal rail for catalogue choices. Navigation stays outside
/// the scroll view, and a swipe cancels the tile tap instead of selecting it.
struct HomesteadItemStrip<Item, Content: View>: View {
    let items: [Item]
    var minimumWidth: CGFloat = 96
    var rowHeight: CGFloat = 88
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        GeometryReader { area in
            let width = max(48, min(minimumWidth, area.size.width))
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { index in
                        content(items[index]).frame(width: width, height: rowHeight)
                    }
                }.frame(height: rowHeight)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.all, 0, for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(height: rowHeight)
            .accessibilityIdentifier("homestead.items.scroll")
        }.frame(height: rowHeight)
            .accessibilityElement(children: .contain)
    }
}

/// A quiet pressed state shared by menu tiles and controls.
struct HomesteadMenuButtonStyle: ButtonStyle {
    var showsDisabledMark = true
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(Color(livingWorldHex: "#496F56").opacity(configuration.isPressed ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .overlay(alignment: .topTrailing) {
                if !isEnabled && showsDisabledMark {
                    HomesteadControlMark(state: .disabled).frame(width: 16, height: 16)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
    }
}

/// Measure at the available width without asking controls to fill the scene.
/// The bounded proposal still lets child stacks adapt to a short window.
struct HomesteadBottomPanelLayout: Layout {
    let maximumHeight: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let ideal = content.sizeThatFits(.init(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(maximumHeight, ideal.height))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                             proposal: .init(width: bounds.width, height: bounds.height))
    }
}

private struct HomesteadTicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, r: CGFloat = 12, n: CGFloat = 5
        var p = Path()
        p.move(to: CGPoint(x: r, y: 0)); p.addLine(to: CGPoint(x: w-r, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h/2-n))
        p.addQuadCurve(to: CGPoint(x: w, y: h/2+n), control: CGPoint(x: w-2*n, y: h/2))
        p.addLine(to: CGPoint(x: w, y: h-r)); p.addQuadCurve(to: CGPoint(x: w-r, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: r, y: h)); p.addQuadCurve(to: CGPoint(x: 0, y: h-r), control: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h/2+n))
        p.addQuadCurve(to: CGPoint(x: 0, y: h/2-n), control: CGPoint(x: 2*n, y: h/2))
        p.addLine(to: CGPoint(x: 0, y: r)); p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        p.closeSubpath(); return p
    }
}

/// A single quiet border pulse on entry; the picture is never covered.
struct HomesteadRecommendationSurface: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var pulsed: Bool
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .background(Color(livingWorldHex: "#E5EDCF"), in: HomesteadTicketShape())
            .overlay {
                HomesteadTicketShape().stroke(Color(livingWorldHex: "#60804A"), lineWidth: pulsed ? 1 : 2.5)
                    .opacity(pulsed ? 0.5 : 1).allowsHitTesting(false)
            }
            .task {
                guard !pulsed else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 1.2)) { pulsed = true }
            }
    }
}
