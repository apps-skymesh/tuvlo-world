import SwiftUI

/// Missions are a full vertical page within World; the wallet stays above it.
struct HomesteadMissionPage: View {
    let kid: Child
    let currency: RewardCurrency
    var project: LivingWorldProject?
    var allowsRequests: (() -> Bool)?
    let close: () -> Void

    var body: some View {
        GeometryReader { area in
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    WorldControlIcon(symbol: "missions").frame(width: 30, height: 30)
                        .frame(width: 44, height: 44).background(Circle().fill(WorldCardFinish.well.opacity(0.55)))
                    Text("Missions").font(.system(.title3, design: .rounded).weight(.heavy)).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    WorldCardCorner(label: "Close missions", icon: "xmark", size: 40, action: close)
                        .accessibilityIdentifier("homestead.panel.close")
                }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                HomesteadMissionReminder(kid: kid, currency: currency, project: project,
                                          showsBalance: false, allowsRequests: allowsRequests,
                                          maxListHeight: max(80, area.size.height - 24 - 78))
                    .padding(.horizontal, 14).padding(.bottom, 12).padding(.top, 6)
            }
            .frame(width: max(0, min(640, area.size.width - 32)))
            .background {
                // Swallows taps so the map beneath stays still.
                Button { } label: { WorldCardFrame().contentShape(RoundedRectangle(cornerRadius: 28)) }
                    .buttonStyle(.plain).accessibilityHidden(true)
            }
            .foregroundStyle(WorldCardFinish.ink)
            .environment(\.colorScheme, .light)
            .worldMenuArrival()
            .accessibilityElement(children: .contain).accessibilityIdentifier("homestead.panel")
            .accessibilityAction(.escape, close)
            .position(x: area.size.width / 2, y: area.size.height / 2)
        }
    }
}
