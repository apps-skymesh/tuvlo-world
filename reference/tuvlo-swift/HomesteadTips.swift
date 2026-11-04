import SwiftUI

/// One short message for one new thing. Shown once per child on this device
/// and erased with the family; it never changes saved World data.
struct HomesteadTip: Equatable, Identifiable {
    let key: String
    let icon: String
    let text: String
    var id: String { key }

    static func moving() -> Self {
        .init(key: "moving", icon: "build", text: String(localized: "Each place has its own spot in its yard."))
    }
    static func materials() -> Self {
        .init(key: "materials", icon: "material.food", text: String(localized: "Pack meals for building."))
    }
    static func bubbles() -> Self {
        .init(key: "bubbles", icon: "material.food", text: String(localized: "Tap a bubble to collect."))
    }
    static func unlocked(_ target: HomesteadBuildTarget) -> Self {
        .init(key: "unlocked:" + target.key, icon: target.icon, text: String(localized: "Build \(target.title)"))
    }
    static func built(_ target: HomesteadBuildTarget) -> Self {
        let text: String
        switch target {
        case .project(.pond): text = String(localized: "Flowers nearby welcome a duck.")
        case .expansion(.windmill): text = String(localized: "Mill wheat into flour.")
        case .expansion(.greenhouse), .expansion(.orchard):
            text = String(localized: "\(target.title) makes food now.")
        case .expansion(.workshop): text = String(localized: "Fold paper toys at the workshop.")
        case .expansion(.meadow), .expansion(.waterside): text = String(localized: "More room to build!")
        case .project(.nook), .project(.treehouse): text = String(localized: "Try a new look.")
        case .expansion(.barn): text = String(localized: "Feed wheat to raise sheep.")
        case .expansion(.grill): text = String(localized: "Grill bread and meat.")
        default: text = String(localized: "Each place has its own spot in its yard.")
        }
        return .init(key: "built:" + target.key, icon: target.icon, text: text)
    }
    static func full(_ producer: HomesteadProducer) -> Self {
        .init(key: "full:" + producer.rawValue, icon: producer.mainMaterial.icon,
              text: String(localized: "Collect from the \(producer.title.lowercased())."))
    }
}

struct HomesteadTipMemory {
    static let keyPrefix = "livingWorld.tips."
    var defaults: UserDefaults = .standard
    func hasShown(_ tip: HomesteadTip, childID: UUID) -> Bool {
        defaults.stringArray(forKey: Self.keyPrefix + childID.uuidString)?.contains(tip.key) == true
    }
    func markShown(_ tip: HomesteadTip, childID: UUID) {
        let key = Self.keyPrefix + childID.uuidString
        var shown = defaults.stringArray(forKey: key) ?? []
        guard !shown.contains(tip.key) else { return }
        shown.append(tip.key)
        defaults.set(Array(shown.suffix(200)), forKey: key)
    }
}

/// A compact toast: icon and one line. Tap dismisses; it also leaves by itself.
struct HomesteadTipBanner: View {
    let tip: HomesteadTip
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 8) {
                WorldControlIcon(symbol: tip.icon).frame(width: 26, height: 26)
                Text(tip.text).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.leading).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(.horizontal, 14).padding(.vertical, 9)
                .frame(maxWidth: 240)
                .foregroundStyle(Color(livingWorldHex: "#243C32"))
                .background(Color(livingWorldHex: "#F3EEDC").opacity(reduceTransparency ? 1 : 0.95), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
        }.buttonStyle(.plain)
            .environment(\.colorScheme, .light)
            .accessibilityLabel(Text(tip.text))
            .accessibilityHint("Dismiss")
            .accessibilityIdentifier("homestead.tip")
    }
}

/// A brief trail reveal below the persistent wallet; never blocks gameplay.
struct WorldCheckInBanner: View {
    let kid: Child
    let grant: WorldCheckInBonus.Grant
    let dismiss: () -> Void
    var body: some View {
        CheckInStreakView(kid: kid, celebration: grant, onCelebrationFinished: dismiss)
            .frame(maxWidth: 520)
            .environment(\.colorScheme, .light)
            .padding(.horizontal, 12)
            .allowsHitTesting(false)
            .accessibilityIdentifier("homestead.checkin")
    }
}

/// Control anchors are layout preferences, not an engine polling/projection loop.
struct HomesteadTipAnchors: PreferenceKey {
    static var defaultValue: [HomesteadToolbeltTab: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [HomesteadToolbeltTab: Anchor<CGRect>], nextValue: () -> [HomesteadToolbeltTab: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension HomesteadTip {
    /// The map control a tip points at. Land opens inside Build and Farm from More.
    var control: HomesteadToolbeltTab {
        if ["unlocked:", "built:"].contains(where: { key == $0 + LivingWorldExpansion.meadow.rawValue || key == $0 + LivingWorldExpansion.waterside.rawValue }) { return .build }
        if key.hasPrefix("unlocked:") || key == "moving" { return .build }
        if key.hasPrefix("built:") {
            let farmPlaces: [LivingWorldExpansion] = [.windmill, .greenhouse, .orchard, .barn, .grill]
            return farmPlaces.contains(where: { key == "built:" + $0.rawValue }) ? .more : .build
        }
        return .more
    }
}

struct HomesteadAttachedTip: View {
    let tip: HomesteadTip
    let target: CGRect
    let bounds: CGSize
    let dismiss: () -> Void
    var body: some View {
        let width = min(240.0, max(0, bounds.width - 24))
        // A control on the right rail has Orders and Streak stacked above it,
        // so its tip sits to the left instead of covering them.
        let onRail = target.midX > bounds.width * 0.75 && target.maxY < bounds.height - HomesteadToolbeltGeometry.buildControl - 8
        if onRail {
            HomesteadTipBanner(tip: tip, dismiss: dismiss)
                .frame(width: width, height: 56)
                .overlay(alignment: .trailing) {
                    TriangleTipPointer().fill(Color(livingWorldHex: "#F3EEDC"))
                        .frame(width: 14, height: 7).rotationEffect(.degrees(-90)).offset(x: 9).accessibilityHidden(true)
                }
                .position(x: max(width / 2 + 12, target.minX - 12 - width / 2), y: target.midY)
        } else {
            above
        }
    }
    private var above: some View {
        let width = min(240.0, max(0, bounds.width - 24))
        let x = min(bounds.width - width / 2 - 12, max(width / 2 + 12, target.midX))
        return HomesteadTipBanner(tip: tip, dismiss: dismiss)
            .frame(width: width, height: 56)
            .overlay(alignment: .bottom) {
                TriangleTipPointer().fill(Color(livingWorldHex: "#F3EEDC"))
                    .frame(width: 14, height: 7).offset(x: target.midX - x, y: 6).accessibilityHidden(true)
            }
            .position(x: x, y: max(36, target.minY - 36))
    }
}
private struct TriangleTipPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: rect.maxX, y: 0)); p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)); p.closeSubpath() }
    }
}
