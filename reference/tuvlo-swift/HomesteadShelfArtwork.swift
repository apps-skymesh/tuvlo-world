import SwiftUI
import UIKit

/// Offline Godot renders only. One visible shelf entry owns the playback clock.
struct HomesteadShelfArtwork: View {
    let asset: String
    var active = false
    var affordable = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @Environment(\.worldPictureTiles) private var pictureTiles
    @State private var fill: CGFloat
    init(asset: String, active: Bool = false, affordable: Bool = true) {
        self.asset = asset; self.active = active; self.affordable = affordable
        _fill = State(initialValue: affordable ? 1 : 0)
    }
    /// Picture tiles use the sharp 540-point menu render when the place has one; lands keep the miniature.
    private var hero: String? {
        let name = asset + "_Hero"
        return pictureTiles && UIImage(named: name) != nil ? name : nil
    }
    var body: some View {
        if let hero { heroBody(hero) } else { miniatureBody }
    }
    /// A pale copy shows what it will be; the colour washes in once it can be bought.
    private func heroBody(_ name: String) -> some View {
        ZStack {
            Image(name).resizable().interpolation(.high).scaledToFit().saturation(0.1).opacity(0.5)
            Image(name).resizable().interpolation(.high).scaledToFit()
                .mask { HomesteadWatercolorWash(progress: fill).fill(.white).blur(radius: 2.5) }
                .opacity(fill == 0 ? 0 : 1)
        }.scaleEffect(1.14).aspectRatio(1, contentMode: .fit)
            .onAppear { fill = affordable ? 1 : 0 }
            .onChange(of: affordable) { old, new in
                if old != new { withAnimation(new && !reduceMotion ? .easeOut(duration: 0.8) : nil) { fill = new ? 1 : 0 } }
            }
            .accessibilityHidden(true)
    }
    private var miniatureBody: some View {
        TimelineView(.animation(minimumInterval: 0.125, paused: !active || reduceMotion || !affordable || phase != .active)) { tick in
            let frame = active && !reduceMotion && affordable && phase == .active
                ? Int(tick.date.timeIntervalSinceReferenceDate * 8) % 12 : 0
            ZStack {
                Image(asset + "_Ink").resizable().scaledToFit()
                Group {
                    if active && !reduceMotion && affordable && phase == .active {
                        HomesteadShelfFrame(asset: asset + "_Loop", frame: frame)
                    } else { Image(asset + "_Still").resizable().scaledToFit() }
                }
                    .mask { HomesteadWatercolorWash(progress: fill).fill(.white).blur(radius: 2.5) }
                    .opacity(fill == 0 ? 0 : 1)
            }
        }.aspectRatio(1, contentMode: .fit)
            .onAppear { fill = affordable ? 1 : 0 }
            .onChange(of: affordable) { old, new in
                // No celebration on initial display or repeated renders. Only a
                // real affordability transition paints this mounted miniature.
                if old != new { withAnimation(new && !reduceMotion ? .easeOut(duration: 0.8) : nil) { fill = new ? 1 : 0 } }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { withAnimation(nil) { fill = affordable ? 1 : 0 } }
            }
            .accessibilityHidden(true)
    }
}

private struct HomesteadShelfFrame: UIViewRepresentable {
    let asset: String
    let frame: Int
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>(); cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()
    func makeUIView(context: Context) -> UIView {
        let view = UIView(); view.isUserInteractionEnabled = false
        view.layer.contentsGravity = .resize
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        let image: UIImage?
        if let cached = Self.cache.object(forKey: asset as NSString) { image = cached }
        else {
            image = UIImage(named: asset)
            if let image { Self.cache.setObject(image, forKey: asset as NSString, cost: Int(image.size.width * image.size.height * 4)) }
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        view.layer.contents = image?.cgImage
        view.layer.contentsRect = CGRect(x: Double(frame % 4) / 4, y: Double(frame / 4) / 3, width: 0.25, height: 1.0 / 3)
        CATransaction.commit()
    }
}

/// Centring is measured in the viewport, never inferred from catalogue order.
struct HomesteadShelfStrip<Item: Identifiable, Content: View>: View where Item.ID: Hashable {
    let items: [Item]
    @ViewBuilder let content: (Item, Bool) -> Content
    @State private var centered: Item.ID?
    var body: some View {
        GeometryReader { area in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(items) { item in
                        content(item, centered == item.id)
                            .frame(width: 124, height: 124)
                            .background {
                                GeometryReader { tile in
                                    Color.clear.preference(key: HomesteadShelfCenters<Item.ID>.self,
                                        value: [item.id: abs(tile.frame(in: .named("shelf")).midX - area.size.width / 2)])
                                }
                            }
                    }
                }.frame(minWidth: area.size.width).frame(height: 124)
            }.environment(\.worldPictureTiles, true).coordinateSpace(name: "shelf").scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .onPreferenceChange(HomesteadShelfCenters<Item.ID>.self) { distances in
                    centered = distances.min { $0.value < $1.value }?.key
                }
        }.frame(height: 124).clipped().accessibilityIdentifier("homestead.items.scroll")
    }
}
private struct HomesteadShelfCenters<ID: Hashable>: PreferenceKey {
    static var defaultValue: [ID: CGFloat] { [:] }
    static func reduce(value: inout [ID: CGFloat], nextValue: () -> [ID: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

/// A soft, uneven wash front; the model itself remains its authored render.
private struct HomesteadWatercolorWash: Shape {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let edge = (rect.width + 28) * progress - 14
        var path = Path()
        path.move(to: CGPoint(x: -16, y: -8))
        for y in stride(from: CGFloat(-8), through: rect.height + 8, by: 2) {
            let bleed = sin(y * 0.17) * 3 + cos(y * 0.39) * 1.5
            path.addLine(to: CGPoint(x: edge + bleed, y: y))
        }
        path.addLine(to: CGPoint(x: -16, y: rect.height + 8)); path.closeSubpath()
        return path
    }
}

/// The reserved picture band keeps the baked model and the shared countdown
/// beside each other. The host clock supplies samples; no second timer is added.
struct HomesteadShelfTimedArtwork: View {
    let asset: String
    var active = false
    var affordable = true
    var size: CGFloat = 32
    let construction: HomesteadConstruction
    let clock: HomesteadTimeClock
    var body: some View {
        HStack(spacing: 4) {
            HomesteadShelfArtwork(asset: asset, active: active, affordable: affordable).frame(width: size, height: size)
            HomesteadSunRing(state: .clock(end: construction.finish, duration: Double(construction.seconds), now: clock.now), size: size)
                .accessibilityIdentifier("homestead.shelf.timer")
        }.frame(width: size * 2 + 4, height: size)
    }
}
