import SwiftUI
import UIKit

/// Presentation only. Locked controls may still open their canonical requirement.
enum HomesteadControlState: String, CaseIterable {
    case selected, available, disabled, locked, working, ready
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .selected: return "checkmark"
        case .available: return "plus"
        case .disabled: return "minus.circle"
        case .locked: return "lock.fill"
        case .working: return "hourglass"
        case .ready: return "seal"
        }
    }
    var acceptsAction: Bool { self != .disabled && self != .working }
}

struct HomesteadControlMark: View {
    let state: HomesteadControlState
    var body: some View {
        Group {
            if state == .selected { TuvloCheckMark().padding(3) }
            else if state == .ready {
                Image(systemName: "seal").font(.system(size: 17)).foregroundStyle(Color(livingWorldHex: "#305540"))
                    .overlay { TuvloCheckMark().frame(width: 10, height: 10) }
            } else {
                Image(systemName: state.symbol).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(livingWorldHex: "#305540"))
            }
        }.frame(width: 18, height: 18)
            .background(Color(livingWorldHex: "#FFF9E9"), in: RoundedRectangle(cornerRadius: state == .locked ? 4 : 9))
            .accessibilityHidden(true)
    }
}

/// Raised tile shared with the place card; state is a gold or green rim, never colour alone.
struct HomesteadJournalControlSurface: View {
    var state: HomesteadControlState = .available
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        shape.fill(LinearGradient(colors: state == .ready ? [Color(livingWorldHex: "#F3FAE8"), Color(livingWorldHex: "#DDEFC9")] : [Color(livingWorldHex: "#FFFDF4"), Color(livingWorldHex: "#FBEFD2")], startPoint: .top, endPoint: .bottom))
            .overlay {
                shape.strokeBorder(state == .selected ? WorldCardFinish.gold : state == .ready ? WorldCardFinish.leaf : WorldCardFinish.tileEdge,
                    style: StrokeStyle(lineWidth: state == .selected || state == .ready ? 3 : 2, dash: state == .disabled ? [4, 3] : []))
            }
            .shadow(color: state == .disabled ? .clear : WorldCardFinish.tileEdge.opacity(0.9), radius: 0, y: 3)
            .opacity(state == .disabled || state == .locked ? 0.8 : 1)
            .allowsHitTesting(false)
    }
}

/// Keep authored type readable inside the fixed slot. Overflow ends at a whole
/// word boundary; accessibility retains the complete original text.
struct HomesteadSlotText: UIViewRepresentable {
    let text: String
    var size: CGFloat = 13
    var weight: UIFont.Weight = .regular
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0; label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center; label.textColor = UIColor(red: 0.14, green: 0.24, blue: 0.20, alpha: 1)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) { label.text = String(localized: String.LocalizationValue(text)); label.accessibilityLabel = label.text }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let bounds = CGSize(width: proposal.width ?? 112, height: proposal.height ?? 34)
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        uiView.font = font
        uiView.text = HomesteadSlotTextLayout.displayText(uiView.accessibilityLabel ?? text, font: font, bounds: bounds)
        return bounds
    }
}

/// Fixed World typography takes precedence over showing an arbitrarily long
/// label in full. Truncate only between words; speech retains the original.
enum HomesteadSlotTextLayout {
    static func displayText(_ text: String, font: UIFont, bounds: CGSize) -> String {
        guard bounds.width > 0, bounds.height >= font.lineHeight else { return "" }
        func fits(_ value: String) -> Bool {
            let measured = (value as NSString).boundingRect(with: CGSize(width: bounds.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
            let widest = value.split(whereSeparator: \.isWhitespace).map {
                (String($0) as NSString).size(withAttributes: [.font: font]).width
            }.max() ?? 0
            return ceil(measured.height) <= bounds.height && widest <= bounds.width
        }
        if fits(text) { return text }
        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        while !words.isEmpty {
            words.removeLast()
            let candidate = words.joined(separator: " ") + "…"
            if fits(candidate) { return candidate }
        }
        return fits("…") ? "…" : ""
    }
}

private struct HomesteadSlotIcon: View {
    let symbol: String?
    var body: some View {
        Group {
            if let symbol { WorldControlIcon(symbol: symbol) }
            else { Color.clear }
        }.accessibilityHidden(true)
    }
}

/// Every control reserves artwork, text and state slots even when empty.
struct HomesteadActionButton: View {
    let title: String
    var icon: String? = "hammer"
    var state: HomesteadControlState = .available
    let action: () -> Void
    @Environment(\.worldMenuSession) private var session
    @Environment(\.worldMenuMaterial) private var material
    var body: some View {
        Button { session?.control("action:" + title); WorldMenuFeedback.touch(material); action() } label: {
            // A picture says what happens; the word stays for VoiceOver.
            HStack(spacing: 10) {
                if icon != nil { HomesteadSlotIcon(symbol: icon).frame(width: 34, height: 34) }
                else { HomesteadSlotText(text: title, weight: .semibold).frame(width: 86, height: 34) }
                HomesteadControlMark(state: state).scaleEffect(1.3)
            }.frame(width: 152, height: 48).background(HomesteadJournalControlSurface(state: state))
        }.worldMenuAnchor("action:" + title).buttonStyle(HomesteadMenuButtonStyle(showsDisabledMark: false)).disabled(!state.acceptsAction)
            .accessibilityLabel(Text(LocalizedStringKey(title)))
            .accessibilityValue(state.title).accessibilityAddTraits(state == .selected ? .isSelected : [])
    }
}

struct HomesteadStatusTile: View {
    let title: String
    var detail = ""
    var icon: String? = "hammer"
    var state: HomesteadControlState = .available
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                HomesteadSlotIcon(symbol: icon).frame(width: 30, height: 30)
                Text(WorldCompactValue.of(detail.isEmpty ? title : detail)).font(WorldCardFinish.number(16)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                HomesteadControlMark(state: state)
            }.frame(height: 48)
        }.frame(width: 132, height: 64).background(HomesteadJournalControlSurface(state: state))
            .accessibilityElement(children: .ignore).accessibilityLabel(Text(title + (detail.isEmpty ? "" : ", " + detail)))
            .accessibilityValue(state.title)
    }
}

struct HomesteadRequirementChip: View {
    let title: String
    var icon: String? = "checklist"
    var currency: RewardCurrency? = nil
    var state: HomesteadControlState = .locked
    var action: (() -> Void)? = nil
    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 4) {
                Group {
                    if let currency { AppIconView(name: currency.artwork(for: 1), size: 30).accessibilityHidden(true) }
                    else { HomesteadSlotIcon(symbol: icon) }
                }.frame(width: 30, height: 30)
                Text(WorldCompactValue.of(title)).font(WorldCardFinish.number(16)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).frame(width: 64)
                HomesteadControlMark(state: state)
            }.frame(width: 128, height: 44).background(HomesteadJournalControlSurface(state: state))
        }.buttonStyle(HomesteadMenuButtonStyle(showsDisabledMark: false)).disabled(!state.acceptsAction || action == nil)
            .accessibilityLabel(Text(LocalizedStringKey(title)))
            .accessibilityValue(state.title)
    }
}

struct HomesteadItemTile<Artwork: View, Detail: View>: View {
    var title: String? = nil
    var badge: String? = nil
    var state: HomesteadControlState = .available
    @ViewBuilder let artwork: Artwork
    @ViewBuilder let detail: Detail
    @Environment(\.worldPictureTiles) private var pictures
    static var pictureSize: CGSize { .init(width: 124, height: 124) }
    @ViewBuilder var body: some View {
        if pictures { pictureTile } else { compactTile }
    }
    /// Build and Warehouse tiles: a lit card with the place large, and one clear state badge.
    private var pictureTile: some View {
        VStack(spacing: 2) {
            artwork.frame(width: 112, height: 92)
                .saturation(state == .locked ? 0.35 : 1).opacity(state == .locked ? 0.75 : 1)
            detail.scaleEffect(1.15).frame(width: 112, height: 22)
        }.frame(width: Self.pictureSize.width, height: Self.pictureSize.height)
            .background(WorldTileSurface(cornerRadius: 20, lit: state == .selected && badge == nil))
            .overlay(alignment: .topTrailing) {
                Group {
                    if badge == "archivebox.fill" { WorldControlIcon(symbol: "archivebox") }
                    else if badge != nil { WorldControlIcon(symbol: "checkmark") }
                    else if state == .locked { WorldControlIcon(symbol: "lock") }
                    // Buyable needs no mark: the full-colour picture and price say it.
                }.frame(width: 24, height: 24).padding(6).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
    }
    private var compactTile: some View {
        VStack(spacing: 2) {
            artwork.frame(width: title == nil ? 64 : 92, height: title == nil ? 64 : 44)
                .overlay(alignment: .bottomTrailing) {
                    if let badge {
                        Image(systemName: badge).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(livingWorldHex: "#305540"))
                            .frame(width: 18, height: 18).background(Color(livingWorldHex: "#FFF9E9"), in: RoundedRectangle(cornerRadius: 4)).accessibilityHidden(true)
                    } else { HomesteadControlMark(state: state) }
                }
            if let title { HomesteadSlotText(text: title, size: 11, weight: .semibold).frame(width: 92, height: 22) }
            detail.frame(width: 92, height: 18)
        }.frame(width: 96, height: 88).contentShape(Rectangle())
    }
}

/// The number a requirement or status is about ("4/4 missions" → "4/4"); words stay spoken only.
enum WorldCompactValue {
    static func of(_ text: String) -> String {
        guard let match = text.firstMatch(of: /[0-9][0-9\/×:.,]*(?:\s?[×x]\s?[0-9]+)?/) else { return "" }
        return String(match.output).trimmingCharacters(in: .whitespaces)
    }
}
