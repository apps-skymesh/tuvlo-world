import SwiftUI

/// Tuvlo mission/reward assets and original vector World controls.
/// Drawn controls use a 32-point grid; callers retain 48-point hit targets.
struct WorldControlIcon: View {
    let symbol: String
    var accented = false

    var body: some View {
        Group {
            if symbol.hasPrefix("place."), let kind = HomesteadKind(rawValue: String(symbol.dropFirst(6))) {
                Image(kind.heroArtwork).resizable().scaledToFit()
            } else if let art = Self.appArtwork[symbol] {
                Image(art).resizable().interpolation(.high).scaledToFit()
            } else if WorldShadedGlyph.symbols.contains(symbol) {
                WorldShadedGlyph(symbol: symbol)
            } else if symbol == "material.food" {
                HomesteadFarmGoodIcon(good: .meal)
            } else if symbol.hasPrefix("farm."), let good = HomesteadFarm.Good(rawValue: String(symbol.dropFirst(5))) {
                HomesteadFarmGoodIcon(good: good)
            } else if symbol == "coins" {
                Image(RewardCurrency.coins.singleArtwork).resizable().scaledToFit()
            } else if symbol == "checklist" {
                Image("MissionIconChecklist").resizable().scaledToFit()
            } else if symbol == "star.fill" {
                Image(RewardPartArt.stars).resizable().scaledToFit()
            } else if let navigation = Self.navigationArtwork[symbol] {
                Image(navigation).resizable().scaledToFit()
            } else {
                drawnIcon
            }
        }.accessibilityHidden(true)
    }
    /// Owner-approved navigation vectors (#332, A44 slice A), rendered by
    /// `scripts/prepare-world-nav.js`. Semantic keys and callers are unchanged.
    /// The app's own glossy icon family (owner request 2026-11-03), shared
    /// with the goods art so every World control reads as one set.
    static let appArtwork: [String: String] = [
        "build": "WorldIconHammer", "hammer": "WorldIconHammer", "hammer.fill": "WorldIconHammer",
        "land": "UIIconMap", "map.fill": "UIIconMap",
        "missions": "MissionIconChecklist", "more": "AppIconMore", "ellipsis": "AppIconMore",
        "house.fill": "AppIconHome",
        "chevron.backward": "WorldIconLeave", "arrow.left": "WorldIconLeave",
        "xmark": "AppIconClose", "checkmark": "UIIconCheck",
        "arrow.uturn.backward": "AppIconUndo", "rotate.right": "AppIconRefresh", "arrow.triangle.2.circlepath": "AppIconRefresh",
        "plus": "AppIconPlus", "plus.circle": "AppIconPlus",
        "lock": "AppIconLockSecure", "lock.fill": "AppIconLockSecure",
        "info.circle": "AppIconInfo", "exclamationmark.triangle.fill": "AppIconWarning",
        "paintpalette.fill": "AppIconTheme", "tshirt.fill": "MissionIconDressed",
        "settings": "AppIconChecklistSettings", "slider.horizontal.3": "AppIconChecklistSettings",
        "tool.move": "WorldIconMove", "gift.fill": "AppIconGiftReady",
        "book.closed.fill": "MissionIconRead", "moon.stars.fill": "RoutineIconBedtime",
        "overview": "WorldIconTelescope",
        "garden": "MissionIconPlant", "archivebox": "AppIconShipping", "tree.fill": "WorldIconTree",
        "category.home": "WorldIconCottage", "category.farm": "MissionIconPlant", "category.animals": "MissionIconPet", "category.decor": "WorldFlower",
        "speaker.wave.2.fill": "AppIconSound", "speaker.slash.fill": "AppIconMute",
        "music.note": "MissionIconMusic", "music.note.slash": "MissionIconMusic",
        "person.crop.circle": "AppIconAvatar", "step.hair": "MissionIconHair", "step.face": "MissionIconFace", "step.sparkles": "AppIconSparkles", "questionmark.circle": "AppIconHelp"
    ]
    static let navigationArtwork: [String: String] = [
        "build": "WorldNav_build", "land": "WorldNav_land", "map.fill": "WorldNav_land",
        "missions": "WorldNav_missions", "more": "WorldNav_more"
    ]
    private var drawnIcon: some View {
        Canvas { context, size in
            var drawing = context
            drawing.scaleBy(x: size.width / 32, y: size.height / 32)
            let ink = Color(red: 0.16, green: 0.24, blue: 0.23)
            let paper = Color(red: 0.96, green: 0.93, blue: 0.82)
            let accent = accented ? CartoonTheme.kidAccentFill : Color(red: 0.46, green: 0.61, blue: 0.51)
            let clay = Color(red: 0.72, green: 0.40, blue: 0.28)
            func line(_ points: [(CGFloat, CGFloat)], closed: Bool = false) -> Path {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.0, y: first.1))
                    for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
                    if closed { path.closeSubpath() }
                }
            }
            func stroke(_ path: Path, color: Color? = nil, width: CGFloat = 2.2) {
                drawing.stroke(path, with: .color(color ?? ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func paint(_ path: Path, color: Color) {
                let clay = Color(red: 0.28, green: 0.18, blue: 0.12)
                drawing.fill(path, with: .linearGradient(Gradient(colors: [
                    color.mix(with: .white, by: 0.28),
                    color,
                    color.mix(with: .black, by: 0.12)
                ]), startPoint: .init(x: 7, y: 3), endPoint: .init(x: 26, y: 30)))
                stroke(path, color: color.mix(with: clay, by: 0.62), width: 1.2)
            }
            func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path { Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)) }
            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 2) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
            }
            func arrow(left: Bool) {
                stroke(line(left ? [(23,16),(8,16),(14,9)] : [(9,16),(24,16),(18,9)]), color: paper, width: 5)
                stroke(line(left ? [(8,16),(14,23)] : [(24,16),(18,23)]), color: paper, width: 5)
                stroke(line(left ? [(23,16),(8,16),(14,9)] : [(9,16),(24,16),(18,9)]))
                stroke(line(left ? [(8,16),(14,23)] : [(24,16),(18,23)]))
            }
            switch symbol {
            case "sheep":
                for x in [CGFloat(10),21] { paint(box(x,22,3,7, radius: 1), color: clay) }
                for (x,y,r) in [(CGFloat(9),CGFloat(15),CGFloat(6)), (16,11,7), (22,15,6), (16,20,7)] {
                    paint(oval(x-r,y-r,r*2,r*2), color: paper)
                }
                paint(oval(20,12,9,12), color: accent)
                paint(oval(18,11,6,3), color: clay)
                paint(oval(26,11,5,3), color: clay)
                drawing.fill(oval(23,16,1.5,1.5), with: .color(ink))
                drawing.fill(oval(27,16,1.5,1.5), with: .color(ink))
                stroke(line([(25,20),(27,20)]), color: ink, width: 1)
            case "barn", "doghouse":
                paint(box(5,13,22,16), color: symbol == "barn" ? clay : accent)
                paint(line([(3,14),(16,3),(29,14)], closed: true), color: paper)
                paint(box(11,18,10,11), color: ink)
                if symbol == "barn" {
                    stroke(line([(12,19),(20,28),(20,19),(12,28)]), color: paper, width: 1.4)
                } else {
                    paint(oval(12,20,8,8), color: paper)
                    for x in [CGFloat(11),15,19] { paint(oval(x,16,3,3), color: paper) }
                }
            case "grill":
                paint(oval(4,8,24,15), color: accent)
                stroke(line([(8,20),(5,29),(26,29),(24,20)]))
                for x in [CGFloat(10),16,22] { stroke(line([(x,10),(x,18)]), color: ink, width: 1.3) }
                for x in [CGFloat(12),20] { stroke(line([(x,7),(x-2,4),(x,1)]), color: clay, width: 1.5) }
            case "settings":
                let gear = Path { p in
                    for index in 0..<32 {
                        let angle = CGFloat(index) * .pi / 16 - .pi / 2
                        let radius: CGFloat = index % 4 == 1 || index % 4 == 2 ? 14 : 11
                        let point = CGPoint(x: 16 + cos(angle) * radius, y: 16 + sin(angle) * radius)
                        if index == 0 { p.move(to: point) } else { p.addLine(to: point) }
                    }
                    p.closeSubpath()
                }
                paint(gear, color: accent)
                paint(oval(9,9,14,14), color: paper)
                paint(oval(13,13,6,6), color: clay)
                drawing.fill(oval(13.8,13.6,2,1.6), with: .color(.white.opacity(0.45)))
            case "windmill":
                paint(line([(10,28),(12,13),(20,13),(23,28)], closed: true), color: paper)
                paint(line([(10,14),(16,8),(22,14)], closed: true), color: accent)
                stroke(line([(16,18),(7,6),(4,9),(16,18),(28,9),(25,6),(16,18),(25,30),(28,27),(16,18),(4,27),(7,30)]), color: paper, width: 4)
                stroke(line([(16,18),(7,6),(4,9),(16,18),(28,9),(25,6),(16,18),(25,30),(28,27),(16,18),(4,27),(7,30)]), width: 1.5)
                paint(oval(14,16,4,4), color: clay)
            case "world":
                paint(oval(2,2,28,28), color: paper)
                paint(oval(5,18,22,9), color: accent)
                paint(box(10,12,12,11), color: paper)
                paint(line([(7,13),(16,5),(25,13)], closed: true), color: clay)
                paint(box(14,17,4,6), color: accent)
            case "play.fill":
                paint(line([(10,5),(27,16),(10,27)], closed: true), color: accent)
            case "house.fill":
                paint(box(7,13,18,15), color: paper)
                paint(line([(3,14),(16,3),(29,14),(25,16),(16,8),(7,16)], closed: true), color: clay)
                paint(box(13,19,6,9, radius: 3), color: accent)
                paint(oval(10,12,4,4), color: paper)
            case "figure.walk", "person.crop.circle", "person.crop.rectangle":
                if symbol == "person.crop.rectangle" { stroke(box(2,3,28,26), color: paper, width: 4); stroke(box(2,3,28,26)) }
                paint(oval(12,3,8,8), color: paper)
                if symbol == "figure.walk" {
                    stroke(line([(15,13),(12,21),(7,28)]), color: paper, width: 5)
                    stroke(line([(12,21),(20,23),(23,28)]), color: paper, width: 5)
                    stroke(line([(15,13),(21,17),(26,15)]), color: paper, width: 5)
                    stroke(line([(15,13),(9,15),(6,21)]), color: paper, width: 5)
                    stroke(line([(15,13),(12,21),(7,28)])); stroke(line([(12,21),(20,23),(23,28)]))
                    stroke(line([(15,13),(21,17),(26,15)])); stroke(line([(15,13),(9,15),(6,21)]))
                } else {
                    var shoulders = Path(); shoulders.move(to: CGPoint(x: 6,y: 28))
                    shoulders.addCurve(to: CGPoint(x: 26,y: 28), control1: CGPoint(x: 4,y: 10), control2: CGPoint(x: 28,y: 10))
                    shoulders.closeSubpath(); paint(shoulders, color: accent)
                }
            case "square.grid.2x2.fill":
                for (x,y) in [(3,4),(18,4),(3,19),(18,19)] as [(CGFloat,CGFloat)] {
                    paint(box(x,y,11,10), color: (x == y-1) ? clay : paper)
                }
            case "tshirt.fill":
                paint(line([(9,5),(12,4),(16,8),(20,4),(23,5),(29,12),(24,16),(22,13),(22,28),(10,28),(10,13),(8,16),(3,12)], closed: true), color: accent)
                stroke(line([(12,4),(16,8),(20,4)]), color: paper, width: 2)
            case "bag.fill":
                paint(line([(6,10),(26,10),(28,28),(4,28)], closed: true), color: paper)
                var handle = Path(); handle.move(to: CGPoint(x:11,y:12))
                handle.addCurve(to: CGPoint(x:21,y:12), control1: CGPoint(x:9,y:0), control2: CGPoint(x:23,y:0)); stroke(handle)
                paint(oval(13,18,6,6), color: accent)
            case "slider.horizontal.3":
                for y in [8,16,24] as [CGFloat] { stroke(line([(4,y),(28,y)]), color: paper, width: 5); stroke(line([(4,y),(28,y)])) }
                paint(oval(8,5,6,6), color: accent); paint(oval(19,13,6,6), color: paper); paint(oval(10,21,6,6), color: clay)
            case "info.circle":
                paint(oval(2,2,28,28), color: paper)
                paint(oval(14,7,4,4), color: accent)
                stroke(line([(16,15),(16,25)]), color: accent, width: 3)
            case "leaf.fill":
                var leaf = Path(); leaf.move(to: CGPoint(x: 5,y: 26))
                leaf.addCurve(to: CGPoint(x: 27,y: 4), control1: CGPoint(x: 1,y: 4), control2: CGPoint(x: 21,y: 12))
                leaf.addCurve(to: CGPoint(x: 5,y: 26), control1: CGPoint(x: 31,y: 23), control2: CGPoint(x: 16,y: 31))
                leaf.closeSubpath(); paint(leaf, color: accent)
                stroke(line([(5,28),(22,11)]), color: paper, width: 2)
            case "bird.fill":
                paint(oval(4,14,22,13), color: paper); paint(oval(17,5,11,12), color: accent)
                paint(line([(27,10),(31,13),(27,15)], closed: true), color: clay)
                paint(oval(23,9,2,2), color: ink); stroke(line([(8,18),(13,22),(19,18)]), color: accent)
            case "moon.stars.fill":
                paint(oval(4,4,23,23), color: paper)
                drawing.fill(oval(13,1,18,20), with: .color(accent))
                stroke(line([(26,23),(26,29),(23,26),(29,26)]), color: paper, width: 2)
            case "tent.fill":
                paint(line([(2,28),(16,4),(30,28)], closed: true), color: accent)
                paint(line([(10,28),(16,15),(22,28)], closed: true), color: paper)
            case "questionmark":
                var question = Path(); question.move(to: CGPoint(x:10,y:9))
                question.addCurve(to: CGPoint(x:21,y:12), control1: CGPoint(x:10,y:1), control2: CGPoint(x:26,y:3))
                question.addCurve(to: CGPoint(x:15,y:21), control1: CGPoint(x:20,y:16), control2: CGPoint(x:15,y:15))
                stroke(question, color: paper, width: 6); stroke(question, width: 3)
                paint(oval(13,26,4,4), color: paper)
            case "plus.magnifyingglass", "minus.magnifyingglass":
                stroke(line([(21,21),(29,29)]), color: paper, width: 6); stroke(line([(21,21),(29,29)]), width: 4)
                paint(oval(3,3,22,22), color: paper)
                stroke(line([(8,14),(20,14)]), color: accent, width: 2.5)
                if symbol == "plus.magnifyingglass" { stroke(line([(14,8),(14,20)]), color: accent, width: 2.5) }
            case "rotate.left", "rotate.right", "arrow.uturn.backward":
                let mirrored = symbol != "rotate.right"
                let transform = mirrored ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 32, ty: 0) : .identity
                var arc = Path(); arc.move(to: CGPoint(x: 25,y: 12))
                arc.addCurve(to: CGPoint(x: 25,y: 23), control1: CGPoint(x: 29,y: 15), control2: CGPoint(x: 29,y: 20))
                arc.addCurve(to: CGPoint(x: 10,y: 27), control1: CGPoint(x: 22,y: 30), control2: CGPoint(x: 16,y: 30))
                arc.addCurve(to: CGPoint(x: 5,y: 14), control1: CGPoint(x: 4,y: 24), control2: CGPoint(x: 2,y: 19))
                arc.addCurve(to: CGPoint(x: 17,y: 5), control1: CGPoint(x: 6,y: 7), control2: CGPoint(x: 11,y: 3))
                arc = arc.applying(transform)
                stroke(arc, color: paper, width: 5); stroke(arc)
                paint(line([(17,1),(25,6),(17,12)], closed: true).applying(transform), color: paper)
            case "chevron.backward", "arrow.left": arrow(left: true)
            case "arrow.right": arrow(left: false)
            case "arrow.up", "arrow.down":
                let up = symbol == "arrow.up"
                let points: [(CGFloat,CGFloat)] = up ? [(16,27),(16,6),(9,13),(16,6),(23,13)] : [(16,5),(16,26),(9,19),(16,26),(23,19)]
                stroke(line(points), color: paper, width: 5); stroke(line(points))
            case "checkmark":
                TuvloCheck.draw(&drawing)
            case "xmark":
                for points in [[(7,7),(25,25)],[(25,7),(7,25)]] as [[(CGFloat,CGFloat)]] { stroke(line(points), color: paper, width: 6); stroke(line(points)) }
            case "tool.move":
                for points in [[(16,4),(16,28)],[(4,16),(28,16)],[(12,8),(16,4),(20,8)],[(12,24),(16,28),(20,24)],[(8,12),(4,16),(8,20)],[(24,12),(28,16),(24,20)]] as [[(CGFloat,CGFloat)]] { stroke(line(points), width: 2.8) }
            case "tool.can":
                paint(box(6,13,16,14), color: Color(red: 0.42, green: 0.67, blue: 0.78))
                stroke(line([(22,18),(29,11)]), width: 3); stroke(line([(26,8),(31,13)]), width: 3)
                stroke(line([(9,13),(11,7),(17,7),(19,13)]), width: 2.6)
            case "tool.sickle":
                stroke(line([(8,28),(16,18)]), color: clay, width: 4)
                stroke(line([(16,18),(23,16),(25,10),(21,5),(26,7),(29,13),(25,20),(16,18)]), width: 2.6)
            case "archivebox":
                paint(box(6,12,20,16), color: accent); paint(box(3,5,26,8), color: paper)
                stroke(line([(13,18),(19,18)]), color: paper, width: 2.5)
            case "tree.fill", "treehouse":
                paint(box(14,17,5,12), color: clay)
                paint(oval(3,3,26,20), color: accent)
                if symbol == "treehouse" {
                    paint(box(11,12,15,10), color: paper)
                    paint(line([(8,13),(18,6),(29,13)], closed: true), color: clay)
                    stroke(line([(16,22),(13,30),(21,30),(21,22)]), width: 1.6)
                }
            case "water.waves":
                paint(oval(2,9,28,19), color: Color(red: 0.43, green: 0.61, blue: 0.64))
                stroke(line([(6,19),(11,17),(17,20),(24,18)]), color: paper)
                paint(oval(19,9,9,5), color: accent)
            case "book.closed.fill":
                paint(box(3,9,26,18), color: clay)
                paint(line([(4,6),(15,9),(16,26),(17,9),(28,6),(28,23),(17,27),(15,27),(4,23)], closed: true), color: paper)
                stroke(line([(16,10),(16,26)]))
            case "path":
                for (x,y,w) in [(5,23,15),(12,15,13),(7,7,11)] as [(CGFloat,CGFloat,CGFloat)] {
                    paint(box(x,y,w,6, radius: 3), color: paper)
                }
            case "garden", "flower":
                if symbol == "garden" { paint(box(3,18,26,11), color: clay) }
                stroke(line([(16,27),(16,10)]), color: accent, width: 4)
                paint(oval(6,13,10,6), color: accent); paint(oval(16,17,10,6), color: accent)
                if symbol == "flower" {
                    for (x,y) in [(10,2),(17,5),(13,10),(6,6)] as [(CGFloat,CGFloat)] { paint(oval(x,y,9,9), color: paper) }
                    paint(oval(12,6,6,6), color: clay)
                }
            case "rocks":
                paint(line([(3,27),(5,16),(13,12),(21,17),(23,27)], closed: true), color: accent)
                paint(line([(16,27),(19,18),(25,16),(30,23),(28,27)], closed: true), color: paper)
            case "bench":
                paint(box(4,6,24,10), color: clay); paint(box(2,18,28,6), color: paper)
                stroke(line([(7,24),(7,29)])); stroke(line([(25,24),(25,29)]))
            case "hammer":
                paint(line([(6,26),(20,8),(24,12),(11,30)], closed: true), color: clay)
                paint(line([(13,6),(19,1),(30,10),(25,16)], closed: true), color: paper)
            case "lock":
                stroke(box(9,3,14,19, radius: 7), color: paper, width: 5)
                stroke(box(9,3,14,19, radius: 7))
                paint(box(5,14,22,15), color: accent); paint(oval(14,19,4,5), color: paper)
            case "paintpalette.fill":
                paint(oval(3,3,26,26), color: paper)
                for (x,y) in [(10,7),(20,10),(8,19)] as [(CGFloat,CGFloat)] { paint(oval(x,y,5,5), color: x == 20 ? clay : accent) }
            case "eye.fill":
                paint(oval(3,8,26,16), color: paper); paint(oval(12,10,9,12), color: accent)
            case "eyeglasses":
                stroke(oval(2,10,12,12), color: paper, width: 4); stroke(oval(18,10,12,12), color: paper, width: 4)
                stroke(oval(2,10,12,12)); stroke(oval(18,10,12,12)); stroke(line([(14,15),(18,15)]))
            case "comb.fill":
                paint(box(4,4,24,8), color: clay)
                for x in [6,11,16,21,26] as [CGFloat] { stroke(line([(x,12),(x,26)]), color: paper, width: 3) }
            case "hourglass":
                paint(line([(7,4),(25,4),(25,8),(19,16),(25,24),(25,28),(7,28),(7,24),(13,16),(7,8)], closed: true), color: paper)
                paint(line([(10,25),(16,18),(22,25)], closed: true), color: accent)
                stroke(line([(6,3),(26,3)])); stroke(line([(6,29),(26,29)]))
            case "ellipsis":
                for x in [4,14,24] as [CGFloat] { paint(oval(x,13,5,5), color: paper) }
            case "material.wood":
                let bark = Color(red: 0.62, green: 0.40, blue: 0.25)
                let ring = Color(red: 0.93, green: 0.79, blue: 0.56)
                for (x, y) in [(4, 17), (14, 17), (9, 7)] as [(CGFloat, CGFloat)] {
                    paint(box(x, y, 15, 9, radius: 4.5), color: bark)
                    paint(oval(x + 9, y + 1, 7, 7), color: ring)
                    drawing.stroke(oval(x + 11, y + 3, 3, 3), with: .color(bark), lineWidth: 1)
                }
            case "material.stone":
                let light = Color(red: 0.78, green: 0.80, blue: 0.76)
                let dark = Color(red: 0.60, green: 0.64, blue: 0.62)
                paint(line([(3,27),(5,18),(12,14),(18,18),(19,27)], closed: true), color: dark)
                paint(line([(13,27),(15,15),(22,10),(29,15),(29,27)], closed: true), color: light)
                stroke(line([(20,16),(24,14)]), width: 1.2)
            case "material.food":
                let apple = Color(red: 0.84, green: 0.33, blue: 0.27)
                paint(Path { p in
                    p.move(to: CGPoint(x: 16, y: 10))
                    p.addCurve(to: CGPoint(x: 16, y: 29), control1: CGPoint(x: 2, y: 4), control2: CGPoint(x: 3, y: 29))
                    p.addCurve(to: CGPoint(x: 16, y: 10), control1: CGPoint(x: 29, y: 29), control2: CGPoint(x: 30, y: 4))
                }, color: apple)
                stroke(line([(16,11),(17,4)]), width: 2)
                paint(Path { p in
                    p.move(to: CGPoint(x: 17, y: 7))
                    p.addQuadCurve(to: CGPoint(x: 26, y: 4), control: CGPoint(x: 22, y: 1))
                    p.addQuadCurve(to: CGPoint(x: 17, y: 7), control: CGPoint(x: 22, y: 9))
                }, color: accent)
                drawing.fill(oval(9,14,4,6), with: .color(.white.opacity(0.55)))
            case "goal":
                paint(oval(3,3,26,26), color: paper)
                paint(oval(8,8,16,16), color: accent)
                paint(oval(12,12,8,8), color: paper)
                paint(oval(14,14,4,4), color: clay)
            default:
                // Safe visible fallback for a newly introduced semantic action.
                paint(oval(9,9,14,14), color: accent)
            }
        }
    }
}
