import SwiftUI

/// One focused window, with the map and its current wallet outside the paper.
struct WorldJournalWindow<Content: View>: View {
    let title: String
    let icon: String
    var preferredWidth: CGFloat = 640
    var preferredHeight: CGFloat = 268
    var closeIdentifier = "homestead.panel.close"
    let close: () -> Void
    @ViewBuilder let content: Content
    @AccessibilityFocusState private var headingFocused: Bool
    var body: some View {
        GeometryReader { area in
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    WorldControlIcon(symbol: icon).frame(width: 34, height: 34).accessibilityHidden(true)
                    WorldSpokenTitle(title: title).accessibilityFocused($headingFocused).accessibilityIdentifier("homestead.panel.title")
                    Spacer(minLength: 0)
                    WorldCardCorner(label: "Close window", icon: "xmark", action: close).accessibilityIdentifier(closeIdentifier)
                }
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.padding(12).frame(width: min(preferredWidth, max(0, area.size.width - 24)), height: min(preferredHeight, max(0, area.size.height - 16)))
                .background(WorldCardFrame(cornerRadius: 24)).foregroundStyle(WorldCardFinish.ink).environment(\.colorScheme, .light)
                .worldMenuArrival().accessibilityElement(children: .contain).accessibilityLabel(Text(LocalizedStringKey(title)))
                .accessibilityIdentifier("homestead.panel").accessibilityAction(.escape, close)
                .position(x: area.size.width / 2, y: area.size.height / 2)
        }.onAppear { headingFocused = true }.environment(\.worldMenuMaterial, .paper)
    }
}

/// Only collected, saved stock is shown. No capacity, new storage record or grant.
struct WorldWarehousePage: View {
    let farm: HomesteadFarm
    let source: (HomesteadFarm.Good) -> Void
    let close: () -> Void
    var body: some View {
        WorldJournalWindow(title: "Warehouse", icon: "archivebox", preferredWidth: 600, preferredHeight: 310, close: close) {
            ScrollView(.vertical) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 124, maximum: 124), spacing: 10)], spacing: 8) {
                    ForEach(HomesteadFarm.Good.allCases, id: \.self) { good in
                        let count = farm[good]
                        Button { WorldMenuFeedback.touch(.paper); source(good) } label: {
                            HomesteadItemTile(title: good.title, badge: count > 0 ? "archivebox" : "plus.circle", state: .available) {
                                HomesteadFarmGoodIcon(good: good).frame(width: 76, height: 76)
                            } detail: {
                                Text(HomesteadWalletDisplay.compact(Double(count))).font(WorldCardFinish.number(14)).monospacedDigit()
                            }.background(HomesteadJournalControlSurface(state: .available))
                        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(good.title)
                            .accessibilityValue(count == 0 ? "Empty" : "\(count) stored").accessibilityHint("Open production place")
                            .accessibilityIdentifier("homestead.warehouse." + good.rawValue)
                    }
                }.padding(.vertical, 2)
            }.environment(\.worldPictureTiles, true).scrollIndicators(.visible).accessibilityIdentifier("homestead.warehouse.goods")
        }
    }
}

struct WorldWalletPage: View {
    let kid: Child
    let materials: HomesteadMaterialAmounts?
    let close: () -> Void
    var body: some View {
        let wallet = EconomyLedger.forChild(kid)
        WorldJournalWindow(title: "Wallet", icon: "coins", preferredWidth: 600, preferredHeight: 250, closeIdentifier: "homestead.wallet.done", close: close) {
            ScrollView {
                // Exact amounts, pictured; the spoken labels keep the full words.
                HStack(spacing: 14) {
                    tile(Image(RewardCurrency.coins.singleArtwork).resizable(), RewardAmount.text(wallet.worldBalance(in: .coins)),
                         RewardCurrency.coins.amountLabel(wallet.worldBalance(in: .coins)))
                    tile(Image(RewardCurrency.stars.singleArtwork).resizable(), RewardAmount.text(wallet.worldBalance(in: .stars)),
                         RewardCurrency.stars.amountLabel(wallet.worldBalance(in: .stars)))
                    tile(Circle().strokeBorder(WorldCardFinish.gold, lineWidth: 7).overlay { Text("Lv").font(WorldCardFinish.number(20)) }, "\(wallet.level)", "Level \(wallet.level)")
                    if let materials { tile(HomesteadFarmGoodIcon(good: .meal), "\(materials.food)", "\(materials.food) Meals") }
                }.frame(maxWidth: .infinity).padding(.vertical, 6)
            }.accessibilityIdentifier("homestead.wallet.exact.scroll")
        }
    }
    private func tile<Picture: View>(_ picture: Picture, _ value: String, _ spoken: String, badge: String? = nil) -> some View {
        VStack(spacing: 6) {
            picture.scaledToFit().frame(width: 60, height: 60)
                .overlay(alignment: .topTrailing) { if let badge { Text(badge).font(WorldCardFinish.number(13)).offset(x: 8, y: -4) } }
            Text(value).font(WorldCardFinish.number(20)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
        }.frame(width: 120, height: 124).background(WorldTileSurface())
            .accessibilityElement(children: .ignore).accessibilityLabel(Text(spoken))
    }
}
