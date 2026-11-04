import SwiftUI

/// The World's common control glyphs in the same shaded style as the tools and
/// goods: a gradient body, a soft highlight and a dark ink outline, on a 64 grid.
struct WorldShadedGlyph: View {
    let symbol: String
    static let symbols: Set<String> = ["lock", "lock.fill", "archivebox", "plus", "plus.circle", "play.fill", "xmark", "chevron.backward",
                                       "arrow.left", "hourglass", "info.circle", "paintpalette.fill", "rotate.right", "rotate.left", "tool.move", "arrow.up.forward.circle"]
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 64, y: size.height / 64)
            Self.draw(symbol, in: &context)
        }.accessibilityHidden(true)
    }
    private static let ink = Color(livingWorldHex: "#3B2A17")
    private static func shade(_ top: String, _ bottom: String, _ y0: CGFloat = 4, _ y1: CGFloat = 60) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [Color(livingWorldHex: top), Color(livingWorldHex: bottom)]), startPoint: .init(x: 32, y: y0), endPoint: .init(x: 32, y: y1))
    }
    private static func outlined(_ path: Path, _ fill: GraphicsContext.Shading, _ c: inout GraphicsContext, width: CGFloat = 3) {
        c.fill(path, with: fill); c.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width, lineJoin: .round))
    }
    private static func shine(_ path: Path, _ c: inout GraphicsContext) {
        c.stroke(path, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
    }
    private static func bold(_ path: Path, _ color: Color, _ c: inout GraphicsContext, width: CGFloat = 9) {
        c.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width + 4, lineCap: .round, lineJoin: .round))
        c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    private static func coin(_ top: String, _ bottom: String, _ c: inout GraphicsContext) {
        let disc = Path(ellipseIn: CGRect(x: 6, y: 6, width: 52, height: 52))
        outlined(disc, shade(top, bottom), &c)
        var arc = Path(); arc.addArc(center: .init(x: 32, y: 32), radius: 20, startAngle: .degrees(200), endAngle: .degrees(260), clockwise: false); shine(arc, &c)
    }
    static func draw(_ symbol: String, in c: inout GraphicsContext) {
        switch symbol {
        case "lock", "lock.fill":
            var shackle = Path(); shackle.addArc(center: .init(x: 32, y: 26), radius: 12, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            shackle.move(to: .init(x: 20, y: 26)); shackle.addLine(to: .init(x: 20, y: 32)); shackle.move(to: .init(x: 44, y: 26)); shackle.addLine(to: .init(x: 44, y: 32))
            c.stroke(shackle, with: .color(ink), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            c.stroke(shackle, with: shade("#E9EEF1", "#9AA6AD"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            let body = Path(roundedRect: CGRect(x: 12, y: 30, width: 40, height: 28), cornerRadius: 8)
            outlined(body, shade("#FFD978", "#D99A2B", 30, 58), &c)
            let hole = Path(ellipseIn: CGRect(x: 28, y: 38, width: 8, height: 8)); c.fill(hole, with: .color(ink))
            var key = Path(); key.move(to: .init(x: 32, y: 44)); key.addLine(to: .init(x: 32, y: 51)); c.stroke(key, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            var gleam = Path(); gleam.move(to: .init(x: 18, y: 36)); gleam.addLine(to: .init(x: 18, y: 50)); shine(gleam, &c)
        case "archivebox":
            let body = Path(roundedRect: CGRect(x: 8, y: 22, width: 48, height: 34), cornerRadius: 5)
            outlined(body, shade("#D99A5B", "#9C6230", 22, 56), &c)
            for y in [33.0, 44.0] { var plank = Path(); plank.move(to: .init(x: 10, y: y)); plank.addLine(to: .init(x: 54, y: y)); c.stroke(plank, with: .color(ink.opacity(0.45)), lineWidth: 2) }
            let lid = Path(roundedRect: CGRect(x: 5, y: 12, width: 54, height: 12), cornerRadius: 4)
            outlined(lid, shade("#EDB574", "#B87A3E", 12, 24), &c)
            let latch = Path(roundedRect: CGRect(x: 27, y: 20, width: 10, height: 10), cornerRadius: 2)
            outlined(latch, shade("#F2F4F5", "#A9B3B9", 20, 30), &c, width: 2)
            var gleam = Path(); gleam.move(to: .init(x: 12, y: 16)); gleam.addLine(to: .init(x: 26, y: 16)); shine(gleam, &c)
        case "plus", "plus.circle":
            coin("#8FD06A", "#4E9A3A", &c)
            var cross = Path(); cross.move(to: .init(x: 32, y: 20)); cross.addLine(to: .init(x: 32, y: 44)); cross.move(to: .init(x: 20, y: 32)); cross.addLine(to: .init(x: 44, y: 32))
            c.stroke(cross, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        case "play.fill":
            coin("#8FD06A", "#4E9A3A", &c)
            var tri = Path(); tri.move(to: .init(x: 26, y: 19)); tri.addLine(to: .init(x: 46, y: 32)); tri.addLine(to: .init(x: 26, y: 45)); tri.closeSubpath()
            c.fill(tri, with: .color(.white)); c.stroke(tri, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
        case "arrow.up.forward.circle":
            coin("#FFE08A", "#E2A73A", &c)
            var arrow = Path(); arrow.move(to: .init(x: 22, y: 42)); arrow.addLine(to: .init(x: 42, y: 22)); arrow.move(to: .init(x: 28, y: 22)); arrow.addLine(to: .init(x: 42, y: 22)); arrow.addLine(to: .init(x: 42, y: 36))
            c.stroke(arrow, with: .color(ink), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        case "xmark":
            var x = Path(); x.move(to: .init(x: 18, y: 18)); x.addLine(to: .init(x: 46, y: 46)); x.move(to: .init(x: 46, y: 18)); x.addLine(to: .init(x: 18, y: 46))
            bold(x, Color(livingWorldHex: "#C85A3C"), &c)
        case "chevron.backward", "arrow.left":
            var a = Path(); a.move(to: .init(x: 38, y: 14)); a.addLine(to: .init(x: 20, y: 32)); a.addLine(to: .init(x: 38, y: 50))
            bold(a, Color(livingWorldHex: "#6FA850"), &c)
        case "hourglass":
            let frame = Path(roundedRect: CGRect(x: 14, y: 6, width: 36, height: 7), cornerRadius: 3)
            let base = Path(roundedRect: CGRect(x: 14, y: 51, width: 36, height: 7), cornerRadius: 3)
            var glass = Path(); glass.move(to: .init(x: 19, y: 13)); glass.addLine(to: .init(x: 45, y: 13)); glass.addLine(to: .init(x: 34, y: 32)); glass.addLine(to: .init(x: 45, y: 51)); glass.addLine(to: .init(x: 19, y: 51)); glass.addLine(to: .init(x: 30, y: 32)); glass.closeSubpath()
            outlined(glass, shade("#EAF6FB", "#BFE0EC"), &c, width: 2.5)
            var sand = Path(); sand.move(to: .init(x: 22, y: 50)); sand.addLine(to: .init(x: 42, y: 50)); sand.addLine(to: .init(x: 32, y: 38)); sand.closeSubpath()
            c.fill(sand, with: shade("#FFE08A", "#E2A73A", 38, 50))
            outlined(frame, shade("#D99A5B", "#9C6230", 6, 13), &c, width: 2.5); outlined(base, shade("#D99A5B", "#9C6230", 51, 58), &c, width: 2.5)
        case "info.circle":
            coin("#7CC3E3", "#2E7FA8", &c)
            c.fill(Path(ellipseIn: CGRect(x: 28, y: 16, width: 8, height: 8)), with: .color(.white))
            var stem = Path(); stem.move(to: .init(x: 32, y: 30)); stem.addLine(to: .init(x: 32, y: 46)); c.stroke(stem, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        case "paintpalette.fill":
            var palette = Path(); palette.addEllipse(in: CGRect(x: 6, y: 10, width: 52, height: 44))
            outlined(palette, shade("#F2D29C", "#C9925A", 10, 54), &c)
            c.fill(Path(ellipseIn: CGRect(x: 38, y: 34, width: 10, height: 10)), with: .color(Color(livingWorldHex: "#F3E7C9")))
            for (x, y, hex) in [(16.0, 20.0, "#E3584A"), (28.0, 16.0, "#F2B632"), (40.0, 20.0, "#4E9A3A"), (16.0, 34.0, "#3E8DB5")] {
                outlined(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 11, height: 11)), .color(Color(livingWorldHex: hex)), &c, width: 2)
            }
        case "rotate.right", "rotate.left":
            var arc = Path(); arc.addArc(center: .init(x: 32, y: 34), radius: 18, startAngle: .degrees(150), endAngle: .degrees(30), clockwise: false)
            bold(arc, Color(livingWorldHex: "#6FA850"), &c, width: 7)
            var head = Path(); head.move(to: .init(x: 54, y: 30)); head.addLine(to: .init(x: 48, y: 44)); head.addLine(to: .init(x: 38, y: 34)); head.closeSubpath()
            outlined(head, .color(Color(livingWorldHex: "#6FA850")), &c, width: 2.5)
        case "tool.move":
            var cross = Path()
            cross.move(to: .init(x: 32, y: 10)); cross.addLine(to: .init(x: 32, y: 54)); cross.move(to: .init(x: 10, y: 32)); cross.addLine(to: .init(x: 54, y: 32))
            bold(cross, Color(livingWorldHex: "#F2B632"), &c, width: 6)
            for (dx, dy) in [(0.0, -1.0), (0.0, 1.0), (-1.0, 0.0), (1.0, 0.0)] {
                let tip = CGPoint(x: 32 + dx * 24, y: 32 + dy * 24)
                var head = Path(); head.move(to: tip)
                head.addLine(to: .init(x: tip.x - dx * 10 - dy * 8, y: tip.y - dy * 10 - dx * 8)); head.addLine(to: .init(x: tip.x - dx * 10 + dy * 8, y: tip.y - dy * 10 + dx * 8)); head.closeSubpath()
                outlined(head, .color(Color(livingWorldHex: "#F2B632")), &c, width: 2.5)
            }
        default: break
        }
    }
}
