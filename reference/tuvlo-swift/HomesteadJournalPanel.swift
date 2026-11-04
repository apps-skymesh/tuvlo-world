import SwiftUI

/// Identity and navigation occupy independent columns. Background alone bleeds
/// below the safe area; content never moves into the home-indicator region.
struct HomesteadJournalPanel<Content: View>: View {
    let title: String
    let icon: String
    var allowsClose = true
    var modal = true
    var back: (() -> Void)? = nil
    var backIdentifier = "homestead.panel.back"
    /// Picture shelves give their row the whole width; the title stays for VoiceOver.
    var showsIdentity = true
    let close: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HomesteadJournalSurface(title: title, identifier: "homestead.panel", modal: modal, close: { if allowsClose { close() } }) {
            ViewThatFits(in: .vertical) {
                HStack(alignment: .bottom, spacing: 8) {
                    if !showsIdentity {
                        Text(LocalizedStringKey(title)).font(.system(size: 2)).opacity(0.02).frame(width: 1)
                            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("homestead.panel.title")
                    } else {
                    Group {
                        if let back {
                            HomesteadIconButton(title: "Back", icon: "chevron.backward", action: back)
                                .disabled(!allowsClose).accessibilityIdentifier(backIdentifier)
                        } else { Color.clear.accessibilityHidden(true) }
                    }.frame(width: 48, height: 72)
                    VStack(spacing: 4) {
                        WorldControlIcon(symbol: icon).frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                        HomesteadSlotText(text: title, size: 13, weight: .semibold)
                            .frame(height: 34)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("homestead.panel.title")
                    }.frame(width: 112, height: 72)
                    Rectangle().fill(Color(livingWorldHex: "#C8BEA3")).frame(width: 1, height: 56)
                        .accessibilityHidden(true)
                    }
                    content.frame(maxWidth: .infinity, alignment: .leading)
                    HomesteadIconButton(title: "Close window", icon: "xmark", action: close)
                        .disabled(!allowsClose).accessibilityIdentifier("homestead.panel.close")
                        .frame(height: 72)
                }.padding(.horizontal, 12).padding(.vertical, 4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Group {
                        if let back {
                            HomesteadIconButton(title: "Back", icon: "chevron.backward", action: back)
                                .disabled(!allowsClose).accessibilityIdentifier(backIdentifier)
                        } else { Color.clear.accessibilityHidden(true) }
                    }.frame(width: 48, height: 48)
                    WorldControlIcon(symbol: icon).frame(width: 28, height: 28).accessibilityHidden(true)
                    HomesteadSlotText(text: title, size: 13, weight: .semibold).frame(width: 112, height: 34)
                        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("homestead.panel.title")
                    Text("Expand window").font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
                        .accessibilityIdentifier("homestead.panel.expand")
                    HomesteadIconButton(title: "Close window", icon: "xmark", action: close)
                        .disabled(!allowsClose).accessibilityIdentifier("homestead.panel.close")
                }.padding(.horizontal, 12).padding(.vertical, 3)
            }

        }
    }
}

/// Shared bounded paper for journal pages and the builder's fixed control row.
struct HomesteadJournalSurface<Content: View>: View {
    var title = ""
    var identifier = ""
    var modal = false
    var close: (() -> Void)? = nil
    @ViewBuilder let content: Content
    var body: some View {
        GeometryReader { area in
            let width = area.size.width + area.safeAreaInsets.leading + area.safeAreaInsets.trailing
            let limit = max(0, min(area.size.height, width / 5 - area.safeAreaInsets.bottom))
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HomesteadBottomPanelLayout(maximumHeight: limit) { content }
                    .background { HomesteadJournalPaper().padding(.bottom, -area.safeAreaInsets.bottom) }
                    .foregroundStyle(Color(livingWorldHex: "#243C32"))
                    .environment(\.colorScheme, .light)
                    .worldMenuArrival()
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(modal ? .isModal : [])
                    .accessibilityLabel(Text(LocalizedStringKey(title)))
                    .accessibilityIdentifier(identifier)
                    .accessibilityAction(.escape) { close?() }
            }
        }
    }
}

struct HomesteadJournalPaper: View {
    var body: some View {
        // Same warm frame as the place card: cream body, one fine honey rim, a soft lift.
        let shape = UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
        shape.fill(LinearGradient(colors: [WorldCardFinish.cream, WorldCardFinish.parchment], startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(WorldCardFinish.rim.opacity(0.55), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.22), radius: 12, y: -3)
            .contentShape(Rectangle()).onTapGesture { }
            .accessibilityHidden(true)
    }
}
