import SwiftUI
import Observation

/// Transient drag presentation for the place card. Only the carried picture
/// reads the finger position, so the card itself does not redraw per touch.
@MainActor @Observable final class WorldDragModel {
    enum Held: Equatable { case good(HomesteadFarm.Good), tool(String) }
    private(set) var held: Held?
    private(set) var point = CGPoint.zero
    private(set) var hot = false
    private(set) var landing = false
    /// Plots a tool has already touched during this stroke.
    var swept: Set<Int> = []
    @ObservationIgnored var sweepStage = -1
    @ObservationIgnored var wellFrame = CGRect.zero
    @ObservationIgnored var plotFrames: [Int: CGRect] = [:]

    func lift(_ item: Held, at location: CGPoint) {
        if held == nil { WorldMenuFeedback.touch(.wood) }
        if held != item { held = item }
        point = location
        let over = overWell(location)
        if over != hot { hot = over; if over { Haptics.selection() } }
    }
    func overWell(_ location: CGPoint) -> Bool { wellFrame.insetBy(dx: -24, dy: -24).contains(location) }
    /// A good dropped on the place glides into it before the slot fills.
    func release(into hit: Bool, reduceMotion: Bool) {
        hot = false
        guard hit, !reduceMotion, held != nil, !wellFrame.isEmpty else { held = nil; return }
        withAnimation(.easeIn(duration: 0.16)) { point = CGPoint(x: wellFrame.midX, y: wellFrame.midY); landing = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            held = nil; landing = false
        }
    }
}

struct WorldDragGhost: View {
    let model: WorldDragModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if let held = model.held {
            Group {
                switch held {
                case .good(let good): HomesteadFarmGoodIcon(good: good)
                case .tool(let icon): WorldToolPicture(icon: icon)
                }
            }.frame(width: 88, height: 88)
                .scaleEffect(model.landing ? 0.35 : model.hot ? 1.28 : 1.15)
                .rotationEffect(.degrees(reduceMotion || model.landing ? 0 : -8))
                .shadow(color: .black.opacity(model.hot ? 0.22 : 0.38), radius: model.hot ? 6 : 12, y: model.hot ? 6 : 16)
                .opacity(model.landing ? 0.2 : 1)
                .position(model.point)
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.6), value: model.hot)
                .accessibilityHidden(true)
        }
    }
}

/// Tools are drawn as the thing in hand: a seed sack, a watering can and a sickle,
/// shaded on a 64-point grid so they hold up at card size and while carried.
struct WorldToolPicture: View {
    let icon: String
    var body: some View {
        switch icon {
        case "tool.seed", "tool.can", "tool.sickle":
            Canvas { context, size in
                context.scaleBy(x: size.width / 64, y: size.height / 64)
                switch icon {
                case "tool.seed": Self.seedSack(&context)
                case "tool.can": Self.wateringCan(&context)
                default: Self.sickle(&context)
                }
            }.accessibilityHidden(true)
        default: WorldControlIcon(symbol: icon)
        }
    }
    private static func gradient(_ top: String, _ bottom: String, _ from: CGPoint, _ to: CGPoint) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [Color(livingWorldHex: top), Color(livingWorldHex: bottom)]), startPoint: from, endPoint: to)
    }
    private static func seedSack(_ c: inout GraphicsContext) {
        let ink = Color(livingWorldHex: "#6B4421")
        var sack = Path()
        sack.move(to: .init(x: 20, y: 24))
        sack.addCurve(to: .init(x: 12, y: 50), control1: .init(x: 12, y: 30), control2: .init(x: 9, y: 42))
        sack.addCurve(to: .init(x: 52, y: 50), control1: .init(x: 16, y: 62), control2: .init(x: 48, y: 62))
        sack.addCurve(to: .init(x: 44, y: 24), control1: .init(x: 55, y: 42), control2: .init(x: 52, y: 30))
        sack.closeSubpath()
        c.fill(sack, with: gradient("#EFD39C", "#C38F52", .init(x: 32, y: 24), .init(x: 32, y: 60)))
        c.stroke(sack, with: .color(ink), lineWidth: 2.2)
        for x in stride(from: 18.0, through: 46.0, by: 5) {
            var stitch = Path(); stitch.move(to: .init(x: x, y: 52)); stitch.addLine(to: .init(x: x + 2.5, y: 52))
            c.stroke(stitch, with: .color(ink.opacity(0.5)), lineWidth: 1.4)
        }
        var shine = Path(); shine.move(to: .init(x: 19, y: 32)); shine.addQuadCurve(to: .init(x: 17, y: 46), control: .init(x: 14, y: 38))
        c.stroke(shine, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        // Grain spilling from the open neck.
        for (x, y, r) in [(26.0, 18.0, 0.0), (32.0, 14.0, 0.0), (38.0, 18.0, 0.0), (29.0, 21.0, 0.0), (35.0, 21.0, 0.0)] {
            let seed = Path(ellipseIn: CGRect(x: x - 3, y: y - 4.5 + r, width: 6, height: 9))
            c.fill(seed, with: gradient("#FBE19A", "#E0A93F", .init(x: x, y: y - 4), .init(x: x, y: y + 4)))
            c.stroke(seed, with: .color(Color(livingWorldHex: "#A8741F")), lineWidth: 1)
        }
        let tie = Path(roundedRect: CGRect(x: 18, y: 22, width: 28, height: 6), cornerRadius: 3)
        c.fill(tie, with: .color(Color(livingWorldHex: "#8A5A2B"))); c.stroke(tie, with: .color(ink), lineWidth: 1.6)
    }
    private static func wateringCan(_ c: inout GraphicsContext) {
        let ink = Color(livingWorldHex: "#1F4B63")
        var handle = Path(); handle.move(to: .init(x: 16, y: 28)); handle.addCurve(to: .init(x: 40, y: 26), control1: .init(x: 14, y: 6), control2: .init(x: 42, y: 6))
        c.stroke(handle, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        c.stroke(handle, with: .color(Color(livingWorldHex: "#3E8DB5")), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        var spout = Path()
        spout.move(to: .init(x: 42, y: 38)); spout.addLine(to: .init(x: 55, y: 22)); spout.addLine(to: .init(x: 59, y: 25)); spout.addLine(to: .init(x: 44, y: 46)); spout.closeSubpath()
        c.fill(spout, with: gradient("#6CC0E0", "#2E7FA8", .init(x: 44, y: 24), .init(x: 56, y: 46))); c.stroke(spout, with: .color(ink), lineWidth: 2)
        let rose = Path(ellipseIn: CGRect(x: 52, y: 16, width: 11, height: 11))
        c.fill(rose, with: gradient("#B9DDEB", "#5DA9CB", .init(x: 57, y: 16), .init(x: 57, y: 27))); c.stroke(rose, with: .color(ink), lineWidth: 1.8)
        for (x, y) in [(56.0, 20.0), (59.0, 22.0), (56.0, 23.5)] { c.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(ink)) }
        var body = Path()
        body.move(to: .init(x: 12, y: 30)); body.addLine(to: .init(x: 46, y: 30))
        body.addLine(to: .init(x: 43, y: 54)); body.addQuadCurve(to: .init(x: 15, y: 54), control: .init(x: 29, y: 58)); body.closeSubpath()
        c.fill(body, with: gradient("#73C6E6", "#2B79A1", .init(x: 29, y: 30), .init(x: 29, y: 57))); c.stroke(body, with: .color(ink), lineWidth: 2.2)
        let rim = Path(ellipseIn: CGRect(x: 11, y: 27, width: 36, height: 7))
        c.fill(rim, with: .color(Color(livingWorldHex: "#2B6E92"))); c.stroke(rim, with: .color(ink), lineWidth: 1.8)
        var band = Path(); band.move(to: .init(x: 14, y: 43)); band.addLine(to: .init(x: 44.5, y: 43))
        c.stroke(band, with: .color(ink.opacity(0.35)), lineWidth: 2)
        var shine = Path(); shine.move(to: .init(x: 18, y: 35)); shine.addLine(to: .init(x: 19.5, y: 50))
        c.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        // Three falling drops.
        for (x, y) in [(60.0, 33.0), (55.0, 37.0), (61.0, 41.0)] {
            var drop = Path(); drop.move(to: .init(x: x, y: y - 4)); drop.addQuadCurve(to: .init(x: x, y: y + 3), control: .init(x: x + 4, y: y + 2)); drop.addQuadCurve(to: .init(x: x, y: y - 4), control: .init(x: x - 4, y: y + 2))
            c.fill(drop, with: .color(Color(livingWorldHex: "#8FD3EE")))
        }
    }
    private static func sickle(_ c: inout GraphicsContext) {
        var blade = Path()
        blade.move(to: .init(x: 28, y: 36))
        blade.addCurve(to: .init(x: 52, y: 8), control1: .init(x: 30, y: 14), control2: .init(x: 44, y: 4))
        blade.addCurve(to: .init(x: 56, y: 32), control1: .init(x: 60, y: 12), control2: .init(x: 61, y: 24))
        blade.addCurve(to: .init(x: 48, y: 15), control1: .init(x: 56, y: 22), control2: .init(x: 53, y: 16))
        blade.addCurve(to: .init(x: 32, y: 38), control1: .init(x: 40, y: 15), control2: .init(x: 33, y: 26))
        blade.closeSubpath()
        c.fill(blade, with: gradient("#F7FAFB", "#9EABB2", .init(x: 40, y: 8), .init(x: 46, y: 36)))
        c.stroke(blade, with: .color(Color(livingWorldHex: "#46555E")), lineWidth: 2)
        var edge = Path(); edge.move(to: .init(x: 49, y: 17)); edge.addCurve(to: .init(x: 55, y: 29), control1: .init(x: 53, y: 19), control2: .init(x: 55, y: 24))
        c.stroke(edge, with: .color(.white), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        var handle = Path(); handle.move(to: .init(x: 12, y: 57)); handle.addLine(to: .init(x: 29, y: 37))
        c.stroke(handle, with: .color(Color(livingWorldHex: "#5E3818")), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        c.stroke(handle, with: gradient("#D08A4B", "#8E5326", .init(x: 12, y: 50), .init(x: 22, y: 56)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        var grain = Path(); grain.move(to: .init(x: 15, y: 50)); grain.addLine(to: .init(x: 24, y: 40))
        c.stroke(grain, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        let ferrule = Path(roundedRect: CGRect(x: 26, y: 33, width: 8, height: 7), cornerRadius: 2)
        c.fill(ferrule, with: gradient("#D9DEE1", "#7E8A91", .init(x: 30, y: 33), .init(x: 30, y: 40)))
        c.stroke(ferrule, with: .color(Color(livingWorldHex: "#46555E")), lineWidth: 1.4)
    }
}

/// A wooden raised bed seen from the World camera's angle, so the field reads like
/// the other 3D places: plank sides, a soil top in perspective and crops in rows.
struct WorldFieldPlot: View {
    let stage: Int
    let state: HomesteadTimeState
    var selected = false
    var targeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let front: CGFloat = 26, inset: CGFloat = 14
            let top = CGRect(x: 6, y: 8, width: w - 12, height: h - front - 22)
            // Ground shadow.
            context.fill(Path(ellipseIn: CGRect(x: 4, y: h - 22, width: w - 8, height: 18)), with: .color(.black.opacity(0.22)))
            // Rim (top of the planks) as a trapezoid narrower at the back.
            let rim = Self.trapezoid(top, back: inset)
            context.fill(rim, with: .linearGradient(Gradient(colors: [Color(livingWorldHex: "#D79A5B"), Color(livingWorldHex: "#B8783F")]), startPoint: CGPoint(x: 0, y: top.minY), endPoint: CGPoint(x: 0, y: top.maxY)))
            // Front planks.
            var face = Path()
            face.move(to: .init(x: top.minX, y: top.maxY)); face.addLine(to: .init(x: top.maxX, y: top.maxY))
            face.addLine(to: .init(x: top.maxX, y: top.maxY + front)); face.addLine(to: .init(x: top.minX, y: top.maxY + front)); face.closeSubpath()
            context.fill(face, with: .linearGradient(Gradient(colors: [Color(livingWorldHex: "#A86A35"), Color(livingWorldHex: "#7A4A22")]), startPoint: CGPoint(x: 0, y: top.maxY), endPoint: CGPoint(x: 0, y: top.maxY + front)))
            for k in 1..<2 { let y = top.maxY + front * CGFloat(k) / 2; var seam = Path(); seam.move(to: .init(x: top.minX + 2, y: y)); seam.addLine(to: .init(x: top.maxX - 2, y: y)); context.stroke(seam, with: .color(.black.opacity(0.25)), lineWidth: 1.5) }
            for x in [top.minX + 10, top.maxX - 10] { context.fill(Path(ellipseIn: CGRect(x: x - 2, y: top.maxY + 6, width: 4, height: 4)), with: .color(.black.opacity(0.35))) }
            context.stroke(face, with: .color(Color(livingWorldHex: "#5C3A1B")), lineWidth: 2)
            // Soil inside the rim.
            let soilRect = top.insetBy(dx: 9, dy: 8)
            let soil = Self.trapezoid(soilRect, back: inset * 0.8)
            context.fill(soil, with: .linearGradient(Gradient(colors: [Color(livingWorldHex: "#4E301A"), Color(livingWorldHex: "#6E4527")]), startPoint: CGPoint(x: 0, y: soilRect.minY), endPoint: CGPoint(x: 0, y: soilRect.maxY)))
            context.stroke(rim, with: .color(Color(livingWorldHex: "#5C3A1B")), lineWidth: 2)
            // Rows from back (small) to front (large).
            let rows = 4
            for row in 0..<rows {
                let f = CGFloat(row) / CGFloat(rows - 1)
                let y = soilRect.minY + 10 + f * (soilRect.height - 20)
                let squeeze = inset * 0.8 * (1 - f)
                let left = soilRect.minX + squeeze + 6, right = soilRect.maxX - squeeze - 6
                var furrow = Path(); furrow.move(to: .init(x: left, y: y + 3)); furrow.addLine(to: .init(x: right, y: y + 3))
                context.stroke(furrow, with: .color(.black.opacity(0.28)), style: StrokeStyle(lineWidth: 3 + 2 * f, lineCap: .round))
                let scale = 0.65 + 0.35 * f
                for column in 0..<3 {
                    let x = left + (right - left) * (CGFloat(column) + 0.5) / 3
                    draw(&context, at: CGPoint(x: x, y: y), height: (soilRect.height / CGFloat(rows)) * 1.25 * scale, scale: scale)
                }
            }
        }
        .overlay { if stage == 4 && !reduceMotion { WorldReadyShimmer().mask(RoundedRectangle(cornerRadius: 16).padding(.bottom, 30)) } }
        .overlay(alignment: .bottom) { if state.phase == .working { HomesteadSunRing(state: state, size: 50).padding(.bottom, 34) } }
        .overlay(alignment: .topTrailing) {
            if stage == 4 { TuvloCheckMark().frame(width: 22, height: 22).padding(5).background(Circle().fill(WorldCardFinish.leaf)).padding(2) }
        }
        .background {
            if selected || targeted {
                RoundedRectangle(cornerRadius: 20).fill(WorldCardFinish.gold.opacity(0.28)).blur(radius: 8).padding(-4)
            }
        }
        .scaleEffect(targeted && !reduceMotion ? 1.04 : selected ? 1.02 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: targeted)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: stage)
        .frame(width: 150).frame(maxHeight: .infinity)
    }
    private static func trapezoid(_ r: CGRect, back: CGFloat) -> Path {
        Path { p in
            p.move(to: .init(x: r.minX + back, y: r.minY)); p.addLine(to: .init(x: r.maxX - back, y: r.minY))
            p.addLine(to: .init(x: r.maxX, y: r.maxY)); p.addLine(to: .init(x: r.minX, y: r.maxY)); p.closeSubpath()
        }
    }
    private func draw(_ context: inout GraphicsContext, at base: CGPoint, height: CGFloat, scale: CGFloat) {
        let leaf = Color(livingWorldHex: stage == 2 ? "#8CC765" : "#5E9E45"), leafLight = Color(livingWorldHex: "#A8D97F")
        switch stage {
        case 1:
            context.fill(Path(ellipseIn: CGRect(x: base.x - 6 * scale, y: base.y - 2, width: 12 * scale, height: 5 * scale)), with: .color(Color(livingWorldHex: "#3E2613")))
            for dx in [-3.0, 3.0] { context.fill(Path(ellipseIn: CGRect(x: base.x + dx * scale - 2, y: base.y - 3, width: 4 * scale, height: 4 * scale)), with: .color(Color(livingWorldHex: "#F1D493"))) }
        case 2, 3:
            let tall = height * (stage == 2 ? 0.45 : 0.95)
            for lean in [-0.4, 0.0, 0.4] {
                var blade = Path()
                blade.move(to: base)
                blade.addQuadCurve(to: CGPoint(x: base.x + lean * tall * 0.7, y: base.y - tall), control: CGPoint(x: base.x + lean * 3, y: base.y - tall * 0.55))
                context.stroke(blade, with: .color(leaf), style: StrokeStyle(lineWidth: 3.2 * scale + 0.6, lineCap: .round))
                context.stroke(blade, with: .color(leafLight.opacity(0.6)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        case 4:
            let tall = height * 1.1
            for lean in [-0.32, 0.0, 0.32] {
                let tip = CGPoint(x: base.x + lean * tall * 0.55, y: base.y - tall)
                var stalk = Path(); stalk.move(to: base); stalk.addQuadCurve(to: tip, control: CGPoint(x: base.x + lean * 4, y: base.y - tall * 0.5))
                context.stroke(stalk, with: .color(Color(livingWorldHex: "#B98227")), style: StrokeStyle(lineWidth: 2.4 * scale + 0.4, lineCap: .round))
                let head = CGRect(x: tip.x - 4.5 * scale, y: tip.y - 11 * scale, width: 9 * scale, height: 17 * scale)
                context.fill(Path(ellipseIn: head), with: .linearGradient(Gradient(colors: [Color(livingWorldHex: "#FFE08A"), Color(livingWorldHex: "#E2A73A")]), startPoint: CGPoint(x: head.minX, y: head.minY), endPoint: CGPoint(x: head.maxX, y: head.maxY)))
                context.stroke(Path(ellipseIn: head), with: .color(Color(livingWorldHex: "#A8741F")), lineWidth: 0.9)
            }
        default: break
        }
    }
}

/// A soft light sweep across something ready to collect.
struct WorldReadyShimmer: View {
    @State private var offset: CGFloat = -1
    var body: some View {
        GeometryReader { area in
            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: area.size.width * 0.45).rotationEffect(.degrees(18))
                .offset(x: offset * area.size.width * 1.3)
                .onAppear { withAnimation(.easeInOut(duration: 1.5).delay(0.4).repeatForever(autoreverses: false)) { offset = 1.2 } }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
