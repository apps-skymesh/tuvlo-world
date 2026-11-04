import SwiftUI

/// Original paper-and-clay recipe illustrations, drawn in the World palette.
struct HomesteadBreadArt: View {
    enum Scene { case seeds, patch, wheat, wheel, sack, dough, loaf, slice, plate, recipe }
    let scene: Scene
    let amount: Int
    var round = false
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 100, size.height / 76)
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 76 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let sage = Color(livingWorldHex: "#8FA88A"), gold = Color(livingWorldHex: "#C09A60")
            let cream = Color(livingWorldHex: "#F4E3BD"), clay = Color(livingWorldHex: "#BC8065")
            func fill(_ rect: CGRect, _ color: Color, radius: CGFloat = 8) {
                context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
            }
            func stroke(_ points: [CGPoint], _ color: Color, width: CGFloat = 2) {
                var path = Path(); path.addLines(points)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func wheat(_ x: CGFloat, _ y: CGFloat) {
                stroke([.init(x: x, y: y), .init(x: x + 2, y: y - 38)], gold)
                for i in 0..<4 {
                    let dy = y - 13 - CGFloat(i) * 6
                    context.fill(Path(ellipseIn: CGRect(x: x - 7, y: dy - 7, width: 7, height: 10)), with: .color(gold))
                    context.fill(Path(ellipseIn: CGRect(x: x + 2, y: dy - 9, width: 7, height: 10)), with: .color(cream))
                }
            }
            func loaf(_ rect: CGRect) {
                fill(rect.offsetBy(dx: 0, dy: 3), gold.opacity(0.3), radius: rect.height / 2)
                fill(rect, gold, radius: rect.height / 2)
                for i in 0..<3 {
                    let x = rect.minX + rect.width * (0.28 + CGFloat(i) * 0.21)
                    stroke([.init(x: x + 5, y: rect.minY + 6), .init(x: x - 2, y: rect.maxY - 6)], cream, width: 3)
                }
            }
            switch scene {
            case .seeds:
                fill(CGRect(x: 28, y: 13, width: 44, height: 48), sage.opacity(0.5), radius: 6)
                fill(CGRect(x: 31, y: 13, width: 38, height: 8), cream, radius: 2)
                for i in 0..<3 { context.fill(Path(ellipseIn: CGRect(x: 39 + i * 7, y: 32 + i % 2 * 7, width: 6, height: 11)), with: .color(gold)) }
            case .patch:
                fill(CGRect(x: 7, y: 42, width: 86, height: 24), gold.opacity(0.65), radius: 10)
                for x in [22, 43, 64] { stroke([.init(x: CGFloat(x), y: 48), .init(x: CGFloat(x + 7), y: 59)], clay.opacity(0.6)) }
                if amount == 1 {
                    for x in [28, 50, 72] {
                        stroke([.init(x: CGFloat(x), y: 49), .init(x: CGFloat(x), y: 32)], sage)
                        context.fill(Path(ellipseIn: CGRect(x: x - 9, y: 31, width: 11, height: 6)), with: .color(sage))
                    }
                } else if amount == 3 { for x in [27, 50, 73] { wheat(CGFloat(x), 53) } }
                else if amount == 4 {
                    stroke([.init(x: 38, y: 49), .init(x: 47, y: 57), .init(x: 63, y: 39)], sage, width: 4)
                }
            case .wheat:
                for x in [38, 50, 62] { wheat(CGFloat(x), 65) }
                stroke([.init(x: 35, y: 51), .init(x: 66, y: 51)], clay, width: 4)
            case .wheel:
                context.stroke(Path(ellipseIn: CGRect(x: 15, y: 3, width: 70, height: 70)), with: .color(gold), lineWidth: 8)
                context.stroke(Path(ellipseIn: CGRect(x: 22, y: 10, width: 56, height: 56)), with: .color(cream), lineWidth: 2)
                for i in 0..<8 {
                    let a = Double(i) * .pi / 4
                    stroke([.init(x: 50, y: 38), .init(x: 50 + cos(a) * 31, y: 38 + sin(a) * 31)], sage, width: 4)
                }
                context.fill(Path(ellipseIn: CGRect(x: 41, y: 29, width: 18, height: 18)), with: .color(gold))
                context.fill(Path(ellipseIn: CGRect(x: 66, y: 14, width: 10, height: 10)), with: .color(clay))
            case .sack:
                var sack = Path(); sack.move(to: .init(x: 34, y: 18))
                sack.addCurve(to: .init(x: 25, y: 64), control1: .init(x: 32, y: 38), control2: .init(x: 15, y: 58))
                sack.addQuadCurve(to: .init(x: 75, y: 64), control: .init(x: 50, y: 76))
                sack.addCurve(to: .init(x: 66, y: 18), control1: .init(x: 85, y: 58), control2: .init(x: 68, y: 38)); sack.closeSubpath()
                context.fill(sack, with: .color(cream))
                context.fill(Path(ellipseIn: CGRect(x: 33, y: 12, width: 34, height: 14)), with: .color(amount > 0 ? .white.opacity(0.8) : gold.opacity(0.4)))
                stroke([.init(x: 33, y: 25), .init(x: 68, y: 25)], gold, width: 3)
                wheat(50, 66)
            case .dough:
                fill(CGRect(x: 8, y: 16, width: 84, height: 52), gold.opacity(0.25))
                context.fill(Path(ellipseIn: CGRect(x: 25, y: 27, width: 50, height: 31)), with: .color(cream))
                for i in 0..<amount { stroke([.init(x: 37 + CGFloat(i) * 9, y: 34), .init(x: 34 + CGFloat(i) * 9, y: 49)], gold.opacity(0.55)) }
            case .loaf:
                loaf(round ? CGRect(x: 24, y: 14, width: 52, height: 49) : CGRect(x: 12, y: 23, width: 76, height: 36))
            case .slice:
                fill(CGRect(x: 29, y: 16, width: 42, height: 47), gold, radius: 15)
                fill(CGRect(x: 33, y: 20, width: 34, height: 39), cream, radius: 12)
                for i in 0..<5 { context.fill(Path(ellipseIn: CGRect(x: 40 + i % 3 * 7, y: 31 + i / 3 * 12, width: 3, height: 4)), with: .color(gold.opacity(0.5))) }
            case .plate:
                fill(CGRect(x: 5, y: 5, width: 90, height: 66), sage.opacity(0.3))
                context.fill(Path(ellipseIn: CGRect(x: 16, y: 16, width: 68, height: 49)), with: .color(cream))
                context.stroke(Path(ellipseIn: CGRect(x: 22, y: 21, width: 56, height: 39)), with: .color(gold.opacity(0.4)), lineWidth: 1)
                if amount > 0 { loaf(CGRect(x: 28, y: 29, width: 44, height: 25)) }
            case .recipe:
                fill(CGRect(x: 18, y: 3, width: 64, height: 70), cream, radius: 6)
                stroke([.init(x: 29, y: 15), .init(x: 71, y: 15)], sage, width: 3)
                loaf(CGRect(x: 26, y: 25, width: 48, height: 28))
                stroke([.init(x: 39, y: 61), .init(x: 47, y: 66), .init(x: 62, y: 56)], sage, width: 3)
            }
        }
    }
}
