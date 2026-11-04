import SwiftUI

/// Screen geometry, never balance text, allocates the HUD's fixed Return, goal, activity and wallet zones.
enum HomesteadToolbeltGeometry {
    static let returnControl: CGFloat = 48
    static let levelRing: CGFloat = 48
    static let ticket: CGFloat = 96
    static let activity: CGFloat = 48
    static let height: CGFloat = 52
    /// Bottom corner height reserved under bars that share the map with the corner controls.
    static let dockHeight: CGFloat = 76
    static let cornerControl: CGFloat = 56
    static let buildControl: CGFloat = 72
    static func walletWidth(in width: CGFloat) -> CGFloat { min(320, max(0, width - returnControl - levelRing - ticket - activity - 40)) }
}

enum HomesteadToolbeltTab: String, CaseIterable {
    case build, land, farm, missions, more
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .build: return "build"
        case .land: return "land"
        case .farm: return "garden"
        case .missions: return "missions"
        case .more: return "more"
        }
    }
    var identifier: String {
        switch self {
        case .build: return "homestead.inventory"
        case .land: return "homestead.land.open"
        case .farm: return "homestead.opening.open"
        case .missions: return "homestead.missions"
        case .more: return "homestead.world.menu"
        }
    }
}

/// The quiet map's four corners (A44 slice C): Map and Missions bottom-left,
/// a large Build bottom-right and More on the right rail. Land lives inside
/// Build and Farm opens from places, goal cards and More, so the map keeps
/// three controls. Identifiers and menu anchors are unchanged.
struct HomesteadToolbelt<MapControl: View, Rail: View, Goals: View>: View {
    let selected: HomesteadToolbeltTab?
    var missionCount = 0
    /// A dot on Build when the next goal's place can be bought now.
    var buildReady = false
    @ViewBuilder var map: MapControl
    /// Orders and streak ride above More on the right rail.
    @ViewBuilder var rail: Rail
    /// Extra goal cards (ready harvests) ride the left edge below the goal ticket.
    @ViewBuilder var goals: Goals
    let action: (HomesteadToolbeltTab) -> Void
    var body: some View {
        GeometryReader { area in
            // A short window (e.g. a 320-point iPad slot) folds the rail into the bottom row.
            let tall = area.size.height >= HomesteadToolbeltGeometry.cornerControl * 3 + HomesteadToolbeltGeometry.buildControl + 32
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if tall {
                    HStack(alignment: .center, spacing: 0) {
                        VStack(spacing: 8) { goals }
                        Spacer(minLength: 0)
                        VStack(spacing: 8) { rail; button(.more) }
                    }
                    Spacer(minLength: 0)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    map
                    button(.missions)
                    Spacer(minLength: 0)
                    if !tall { rail; button(.more) }
                    button(.build)
                }
            }
        }
        .foregroundStyle(Color(livingWorldHex: "#243C32"))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain).accessibilityIdentifier("homestead.dock")
    }
    private func button(_ tab: HomesteadToolbeltTab) -> some View {
        HomesteadCornerButton(tab: tab, selected: selected == tab, missionCount: missionCount, buildReady: buildReady) { action(tab) }
    }
}

/// A right-rail shortcut the same size as the corner controls.
struct HomesteadRailButton<Picture: View>: View {
    let title: String
    let identifier: String
    var badge: String? = nil
    var selected = false
    var spokenTitle: String? = nil
    @ViewBuilder let picture: Picture
    let action: () -> Void
    @Environment(\.worldMenuSession) private var session
    var body: some View {
        Button { session?.control("rail." + identifier); WorldMenuFeedback.touch(.paper); action() } label: {
            picture.frame(width: 34, height: 34).accessibilityHidden(true)
            .frame(width: HomesteadToolbeltGeometry.cornerControl, height: HomesteadToolbeltGeometry.cornerControl)
            .background(HomesteadControlSurface(selected: selected))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(.system(size: 10, weight: .bold, design: .rounded))
                        .frame(width: 26, height: 16)
                        .background(Color(livingWorldHex: "#D7E3BD"), in: Capsule()).offset(x: 6, y: -6)
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(HomesteadControlButtonStyle())
            .accessibilityLabel(Text(LocalizedStringKey(spokenTitle ?? title)))
            .accessibilityIdentifier(identifier)
            .worldMenuAnchor("rail." + identifier)
    }
}

struct HomesteadCornerButton: View {
    let tab: HomesteadToolbeltTab
    let selected: Bool
    var missionCount = 0
    var buildReady = false
    let action: () -> Void
    @Environment(\.worldMenuSession) private var session
    private var prominent: Bool { tab == .build }
    var body: some View {
        let side: CGFloat = prominent ? HomesteadToolbeltGeometry.buildControl : HomesteadToolbeltGeometry.cornerControl
        Button { session?.control("dock." + tab.rawValue); WorldMenuFeedback.touch(tab == .missions ? .paper : tab == .more ? .brass : .wood); action() } label: {
            WorldControlIcon(symbol: tab.icon, accented: selected || prominent)
                .frame(width: prominent ? 54 : 36, height: prominent ? 54 : 36)
            .frame(width: side, height: side)
            .background(HomesteadControlSurface(selected: selected && !prominent, warm: prominent))
            .overlay(alignment: .topTrailing) {
                if tab == .missions && missionCount > 0 {
                    Text(missionCount > 99 ? "99+" : "\(missionCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .frame(width: 26, height: 16)
                        .background(Color(livingWorldHex: "#D7E3BD"), in: Capsule()).offset(x: 6, y: -6)
                } else if prominent && buildReady {
                    Circle().fill(Color(livingWorldHex: "#3F8F5B"))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 16, height: 16).offset(x: 4, y: -4)
                        .accessibilityIdentifier("homestead.inventory.ready")
                }
            }
            .contentShape(Rectangle())
        }.buttonStyle(HomesteadControlButtonStyle())
            .accessibilityLabel(Text(LocalizedStringKey(tab.title)))
            .accessibilityValue(tab == .missions ? "\(missionCount) approved missions" : prominent && buildReady ? "Ready to build" : "")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(tab.identifier)
            .worldMenuAnchor("dock." + tab.rawValue)
            .anchorPreference(key: HomesteadTipAnchors.self, value: .bounds) { [tab: $0] }
    }
}

/// Level ring beside Return (A44): progress toward the next level; a tap opens
/// Look and Sound. Reads the same saved ledger level the wallet used to show.
struct HomesteadLevelRing: View {
    let level: Int
    let progress: CGFloat
    let action: () -> Void
    @Environment(\.worldMenuSession) private var session
    var body: some View {
        Button { session?.control("hud.level"); WorldMenuFeedback.touch(.brass); action() } label: {
            ZStack {
                Circle().stroke(Color(livingWorldHex: "#E7DFC9"), lineWidth: 5)
                Circle().trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(Color(livingWorldHex: "#B8892E"), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -1) {
                    Text("Lv").font(.system(size: 9, weight: .bold, design: .rounded))
                    Text(HomesteadWalletDisplay.compact(Double(level))).font(.system(size: 12, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6)
                }.monospacedDigit()
            }
            .padding(6)
            .frame(width: HomesteadToolbeltGeometry.levelRing, height: HomesteadToolbeltGeometry.height)
            .background(HomesteadControlSurface())
            // A small gear says the ring also opens Settings.
            .overlay(alignment: .bottomTrailing) {
                WorldControlIcon(symbol: "settings").frame(width: 16, height: 16).padding(2)
                    .background(Circle().fill(Color(livingWorldHex: "#FFF9E9"))).offset(x: 4, y: 4).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }.buttonStyle(HomesteadControlButtonStyle())
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .accessibilityLabel("Level \(level)")
            .accessibilityValue("\(Int((min(1, max(0, progress)) * 100).rounded()))% to the next level")
            .accessibilityHint("Opens Look and Sound")
            .accessibilityIdentifier("homestead.level")
    }
}

struct HomesteadNextStepTicket<Picture: View>: View {
    let title: String
    @Binding var pulsed: Bool
    var readOnly = false
    @ViewBuilder let picture: Picture
    let action: () -> Void
    @Environment(\.worldMenuSession) private var session
    var body: some View {
        Button { session?.control("hud.goal"); WorldMenuFeedback.touch(.paper); action() } label: {
            HStack(spacing: 4) {
                picture.frame(width: 44, height: 44).accessibilityHidden(true)
                WorldControlIcon(symbol: "arrow.up.forward.circle").frame(width: 26, height: 26).accessibilityHidden(true)
                Spacer(minLength: 0)
            }.padding(.horizontal, 8)
                .frame(width: HomesteadToolbeltGeometry.ticket, height: HomesteadToolbeltGeometry.height)
        }.buttonStyle(HomesteadTicketButtonStyle())
            .modifier(HomesteadRecommendationSurface(pulsed: $pulsed))
            .overlay(alignment: .topTrailing) {
                if readOnly { Image(systemName: "lock.fill").font(.caption2).padding(3).accessibilityHidden(true) }
            }
            .accessibilityLabel(Text(LocalizedStringKey(title)))
            .accessibilityValue(readOnly ? "Read only" : "Next step")
    }
}

private struct HomesteadTicketButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#if DEBUG
/// A bounded native window for screenshot QA, available only in isolated UI fixtures.
struct HomesteadHUDPreviewWindow: ViewModifier {
    func body(content: Content) -> some View {
        if UITestLaunchConfiguration.isEnabled && ProcessInfo.processInfo.arguments.contains("-ui-testing-world-hud-compact") {
            content.frame(width: 544, height: 320).clipped()
        } else { content }
    }
}
#endif
