import SwiftUI

/// The World's shared coordinate space, so a card's ring and the map agree in any orientation.
enum HomesteadWorldSpace { static let name = "homesteadWorld" }

/// Shared finish for the centred place card: a warm frame, raised tiles and
/// recessed wells, so a drop target reads as a place to put something.
enum WorldCardFinish {
    static let cream = Color(livingWorldHex: "#FFF5DC")
    static let parchment = Color(livingWorldHex: "#F5E4BE")
    static let well = Color(livingWorldHex: "#E7D1A3")
    static let rim = Color(livingWorldHex: "#B98547")
    static let walnut = Color(livingWorldHex: "#5C3A1B")
    static let ink = Color(livingWorldHex: "#3B2A17")
    static let gold = Color(livingWorldHex: "#F2B632")
    static let leaf = Color(livingWorldHex: "#6FA850")
    static let short = Color(livingWorldHex: "#C85A3C")
    static let tileEdge = Color(livingWorldHex: "#C9A468")
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
}

extension EnvironmentValues {
    /// Build shelf and Warehouse draw picture tiles: larger art, no visible name.
    @Entry var worldPictureTiles = false
    /// The real model stands at its spot on the map, so a page shows no second picture of it.
    @Entry var worldMapShowsPlace = false
}

/// Production at a place. The real place stays on the map, framed at a fixed
/// scale inside the clear ring; goods and products sit around it. Words live
/// only in accessibility labels.
struct WorldPlaceCard<Inputs: View, Place: View, Output: View, Action: View>: View {
    static var space: String { "worldPlaceCard" }
    static var ringDiameter: CGFloat { 212 }
    /// Half the gap and action row below the ring (10 + 48).
    static var actionLift: CGFloat { 29 }
    let title: String
    /// Drives the arrows between goods, place and product.
    var flow: WorldFlowArrows.Phase? = nil
    var contentIdentifier = "homestead.production.page"
    var move: (() -> Void)? = nil
    /// Shown only when the card was reached from another page.
    var back: (() -> Void)? = nil
    let close: () -> Void
    /// Reports the ring's screen frame so the camera can put the place inside it.
    var ring: (CGRect) -> Void = { _ in }
    @ViewBuilder let inputs: Inputs
    @ViewBuilder let place: Place
    @ViewBuilder let output: Output
    @ViewBuilder let action: Action
    @AccessibilityFocusState private var headingFocused: Bool
    var body: some View {
        GeometryReader { area in
            let width = min(680, max(0, area.size.width - 24)), height = min(330, max(0, area.size.height - 4))
            ZStack {
                HStack(spacing: 6) {
                    inputs.frame(width: 128).padding(.vertical, 14).background(WorldCardFrame(cornerRadius: 26))
                    if let flow { WorldFlowArrows(phase: flow, leg: 0) }
                    VStack(spacing: 10) {
                        place.frame(width: Self.ringDiameter, height: Self.ringDiameter)
                        action
                    }.frame(maxWidth: .infinity)
                    if let flow { WorldFlowArrows(phase: flow, leg: 1) }
                    output.frame(width: 128).padding(.vertical, 14).background(WorldCardFrame(cornerRadius: 26))
                }.padding(.horizontal, 4)
                corners
            }.frame(width: width, height: height)
                .coordinateSpace(name: Self.space)
                .position(x: area.size.width / 2, y: area.size.height / 2)
                .worldMenuArrival()
                .foregroundStyle(WorldCardFinish.ink).environment(\.colorScheme, .light)
                .accessibilityElement(children: .contain).accessibilityIdentifier(contentIdentifier)
                .accessibilityAction(.escape, close)
        }
        // The ring sits at the card's centre, raised by half the action row beneath it. Measured
        // from this stable layout, never from the arriving (scaled, shifted) card.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(HomesteadWorldSpace.name)) } action: { area in
            let side = Self.ringDiameter
            ring(CGRect(x: area.midX - side / 2, y: area.midY - Self.actionLift - side / 2, width: side, height: side))
        }
        .onAppear { headingFocused = true }.onChange(of: title) { _, _ in headingFocused = true }
            .environment(\.worldMenuMaterial, .wood).accessibilityElement(children: .contain).accessibilityIdentifier("homestead.panel")
    }
    /// Quiet utilities at the ring's shoulders, never competing with the action.
    private var corners: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                if let back { corner("Back", icon: "chevron.backward", id: "homestead.panel.back", action: back) } else { Color.clear.frame(width: 40, height: 40) }
                // Kept for VoiceOver and rotor navigation; the place itself is the visible title.
                Text(title).font(.system(size: 2)).opacity(0.02).accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($headingFocused).accessibilityIdentifier("homestead.panel.title")
                    .frame(width: Self.ringDiameter + 8)
                corner("Close window", icon: "xmark", id: "homestead.panel.close", action: close)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if let move { corner("Move " + title, icon: "tool.move", id: "homestead.details.move", action: move) } else { Color.clear.frame(width: 40, height: 40) }
                Color.clear.frame(width: Self.ringDiameter + 8, height: 1)
                Color.clear.frame(width: 40, height: 40)
                Spacer(minLength: 0)
            }.padding(.bottom, 58)
        }
    }
    private func corner(_ label: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        WorldCardCorner(label: label, icon: icon, size: 40, action: action).accessibilityIdentifier(id)
    }
}

/// The warm frame every focused World page shares: one fine rim, a soft lift.
struct WorldCardFrame: View {
    var cornerRadius: CGFloat = 28
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius).fill(LinearGradient(colors: [WorldCardFinish.cream, WorldCardFinish.parchment], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(WorldCardFinish.rim.opacity(0.55), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6).allowsHitTesting(false)
    }
}

/// Round Back / Move / Close buttons; the word lives in the accessibility label.
struct WorldCardCorner: View {
    let label: String
    let icon: String
    var size: CGFloat = 48
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button { WorldMenuFeedback.touch(.wood); action() } label: {
            WorldControlIcon(symbol: icon).frame(width: size * 0.5, height: size * 0.5).frame(width: size, height: size)
                .background(Circle().fill(WorldCardFinish.cream).shadow(color: .black.opacity(0.16), radius: 3, y: 2))
                .overlay(Circle().strokeBorder(WorldCardFinish.rim.opacity(0.4), lineWidth: 1))
                .frame(minWidth: 44, minHeight: 44).contentShape(Circle().inset(by: -4))
                .opacity(enabled ? 1 : 0.45)
        }.buttonStyle(WorldCardPress()).disabled(!enabled).accessibilityLabel(Text(LocalizedStringKey(label)))
    }
}

/// A heading that VoiceOver and the rotor find; sighted players see the picture instead.
struct WorldSpokenTitle: View {
    let title: String
    var body: some View {
        Text(LocalizedStringKey(title)).font(.system(size: 2)).opacity(0.02).frame(width: 1, height: 1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Raised tiles sink under a finger.
struct WorldCardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct WorldTileSurface: View {
    var cornerRadius: CGFloat = 22
    var lit = false
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius).fill(LinearGradient(colors: [Color(livingWorldHex: "#FFFDF4"), Color(livingWorldHex: "#FBEFD2")], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(lit ? WorldCardFinish.gold : WorldCardFinish.tileEdge.opacity(0.6), lineWidth: lit ? 2.5 : 1))
            .shadow(color: lit ? WorldCardFinish.gold.opacity(0.6) : .black.opacity(0.10), radius: lit ? 6 : 3, y: lit ? 0 : 2)
    }
}

/// A count sits on the picture, never in a label beneath it.
struct WorldCountBadge: View {
    let text: String
    var alert = false
    var body: some View {
        Text(text).font(WorldCardFinish.number(15)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(WorldCardFinish.cream).padding(.horizontal, 7).frame(minWidth: 30, minHeight: 24)
            .background(alert ? WorldCardFinish.short : WorldCardFinish.ink.opacity(0.82), in: Capsule())
    }
}

/// A clear ring over the live place: nothing painted inside, so the place
/// looks exactly as it does in the World. Goods drop here; progress runs around it.
struct WorldPlaceLens<Slots: View>: View {
    let state: HomesteadTimeState
    var hot = false
    var diameter: CGFloat = 212
    var locked = false
    @ViewBuilder let slots: Slots
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3)
                .background(Circle().strokeBorder(.black.opacity(0.16), lineWidth: 7).blur(radius: 4))
                .overlay { if locked { Circle().strokeBorder(WorldCardFinish.cream, style: StrokeStyle(lineWidth: 3, dash: [8, 7])) } }
            if hot { Circle().strokeBorder(WorldCardFinish.gold, lineWidth: 5).shadow(color: WorldCardFinish.gold, radius: 10) }
            if state.phase == .working {
                Circle().trim(from: 0, to: state.progress).stroke(WorldCardFinish.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(3.5)
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: state.progress)
            } else if state.phase == .ready {
                Circle().strokeBorder(WorldCardFinish.leaf, lineWidth: 6).shadow(color: WorldCardFinish.leaf.opacity(0.8), radius: 8)
            }
            // Smoke and the product come from the place itself on the map, never painted here.
            slots.offset(y: 24)
        }.frame(width: diameter, height: diameter)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: state.phase) { view, scale in view.scaleEffect(reduceMotion ? 1 : scale) } keyframes: { _ in
                // A start or finish lands with a small thump.
                SpringKeyframe(1.06, duration: 0.14)
                SpringKeyframe(0.98, duration: 0.12)
                SpringKeyframe(1, duration: 0.2)
            }
            .scaleEffect(hot && !reduceMotion ? 1.04 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.62), value: hot)
    }
}

/// The one thing to press: start, collect, or a running clock.
struct WorldPrimaryAction: View {
    enum Kind { case start, collect, working }
    let kind: Kind
    let state: HomesteadTimeState
    var product: HomesteadFarm.Good? = nil
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                switch kind {
                case .start: WorldControlIcon(symbol: "play.fill").frame(width: 26, height: 26)
                case .collect: if let product { HomesteadFarmGoodIcon(good: product).frame(width: 34, height: 34) }; WorldControlIcon(symbol: "checkmark").frame(width: 24, height: 24)
                case .working: HomesteadSunRing(state: state, size: 30)
                }
            }.frame(width: 112, height: 48)
                .background(Capsule().fill(LinearGradient(colors: kind == .working ? [WorldCardFinish.cream, WorldCardFinish.parchment] : [Color(livingWorldHex: "#8FCB63"), Color(livingWorldHex: "#5FA63F")], startPoint: .top, endPoint: .bottom)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.55), lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                .opacity(enabled ? 1 : 0.5)
        }.buttonStyle(WorldCardPress()).disabled(!enabled || kind == .working)
    }
}

/// One empty or filled slot on the place: a grey picture says what it wants.
struct WorldGoodSlot: View {
    let good: HomesteadFarm.Good
    let filled: Bool
    var size: CGFloat = 52
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HomesteadFarmGoodIcon(good: good).frame(width: size * 0.78, height: size * 0.78)
            .grayscale(filled ? 0 : 1).opacity(filled ? 1 : 0.35)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? Color.white : Color(livingWorldHex: "#FBEBC5")))
            .overlay(Circle().strokeBorder(filled ? WorldCardFinish.leaf : WorldCardFinish.rim, style: StrokeStyle(lineWidth: 2, dash: filled ? [] : [4, 3])))
            .keyframeAnimator(initialValue: CGFloat(1), trigger: filled) { view, scale in view.scaleEffect(reduceMotion ? 1 : scale) } keyframes: { _ in
                SpringKeyframe(1.3, duration: 0.12)
                SpringKeyframe(1, duration: 0.22)
            }
            .accessibilityHidden(true)
    }
}

/// Three chevrons between the columns: still when idle, flowing while the place
/// works, green once the product is ready.
struct WorldFlowArrows: View {
    enum Phase { case idle, working, ready }
    let phase: Phase
    let leg: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: phase != .working || reduceMotion)) { clock in
            let t = clock.date.timeIntervalSinceReferenceDate
            HStack(spacing: -4) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = (sin(t * 5 - Double(index) * 0.9 - Double(leg) * 1.4) + 1) / 2
                    Chevron().stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 9, height: 16)
                        .opacity(phase == .working && !reduceMotion ? 0.3 + 0.7 * wave : phase == .idle ? 0.35 : 0.9)
                }
            }
        }.frame(width: 30).accessibilityHidden(true)
    }
    private var color: Color { phase == .ready ? WorldCardFinish.leaf : WorldCardFinish.gold }
    private struct Chevron: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in p.move(to: .init(x: rect.minX, y: rect.minY)); p.addLine(to: .init(x: rect.maxX, y: rect.midY)); p.addLine(to: .init(x: rect.minX, y: rect.maxY)) }
        }
    }
}

/// A look shown as its colour: a glossy disc, gold-ringed when chosen.
struct WorldLookSwatch: View {
    let color: Color
    let selected: Bool
    var body: some View {
        Circle().fill(RadialGradient(colors: [color.opacity(0.75), color], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 30))
            .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center)).padding(6))
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .padding(4)
            .overlay(Circle().strokeBorder(selected ? WorldCardFinish.gold : WorldCardFinish.tileEdge.opacity(0.5), lineWidth: selected ? 3.5 : 1))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            .scaleEffect(selected ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selected)
    }
    /// Colours for the saved look names; unknown names fall back to warm honey.
    static func color(for name: String) -> Color {
        let palette: [String: String] = [
            "Water lilies": "#E9A7C4", "Wild reeds": "#9AAE5B",
            "Rose cushions": "#D98A9B", "Sage cushions": "#8FB08A",
            "Honey roof": "#E3A93B", "Berry roof": "#9C4A6B",
            "Sage roof": "#6F9B78", "Clay roof": "#C8613E",
            "Apple trees": "#D9473C", "Pear trees": "#B9C45A", "Plum trees": "#7B4A8C"]
        return Color(livingWorldHex: palette[name] ?? "#E3A93B")
    }
}

extension HomesteadKind {
    /// Sharp 540-point renders of the production models (`render_place_heroes.gd`), for menus.
    var heroArtwork: String { "WorldPlace_" + rawValue + "_Hero" }
}

/// The building menu's centrepiece: the sharp render on a lit pedestal, floating
/// gently. Unaffordable pieces stay recognisable but quieter.
struct WorldPlacePedestal: View {
    let kind: HomesteadKind
    var affordable = true
    var construction: HomesteadConstruction? = nil
    var clock: HomesteadTimeClock? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false
    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(RadialGradient(colors: [WorldCardFinish.cream.opacity(0.95), WorldCardFinish.well.opacity(0.8), .clear], center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 250, height: 70).offset(y: 6)
            Ellipse().fill(.black.opacity(0.18)).frame(width: float ? 130 : 150, height: 22).blur(radius: 6).offset(y: -6)
            Image(kind.heroArtwork).resizable().scaledToFit().frame(width: 230, height: 230)
                .saturation(affordable ? 1 : 0.55).offset(y: float ? -16 : -8)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 10)
            if let construction, let clock {
                HomesteadSunRing(state: .clock(end: construction.finish, duration: Double(construction.seconds), now: clock.now), size: 56)
                    .offset(x: 90, y: -190).accessibilityIdentifier("homestead.shelf.timer")
            }
        }.frame(maxWidth: 260, maxHeight: 260)
            .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { float = true } } }
            .accessibilityHidden(true)
    }
}

extension HomesteadFarm.Station {
    /// The place each station happens at: bread at the oven, meals at the kitchen bench.
    var heroArtwork: String {
        switch self {
        case .oven: return "WorldPlace_oven_Hero"
        case .pantry: return "WorldPlace_kitchen_bench_Hero"
        case .orders: return HomesteadKind.nook.heroArtwork
        default: return kind.heroArtwork
        }
    }
}
