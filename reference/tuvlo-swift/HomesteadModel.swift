import Foundation
import CryptoKit

/// Renderer-independent data. Economic ownership is supplied by Tuvlo, never by a scene.
nonisolated enum HomesteadKind: String, Codable, CaseIterable, Sendable {
    case cottage, tree, path, garden, flowers, rocks, bench, pond, nook, treehouse, workshop, greenhouse, orchard, windmill, barn, doghouse, grill
    var title: String {
        switch self {
        case .barn: return String(localized: "Barn")
        case .doghouse: return String(localized: "Dog house")
        case .grill: return String(localized: "Grill")
        case .windmill: return String(localized: "Windmill")
        case .orchard: return String(localized: "Orchard")
        case .greenhouse: return String(localized: "Greenhouse")
        case .workshop: return String(localized: "Maker workshop")
        case .cottage: return String(localized: "Cottage")
        case .tree: return String(localized: "Tree")
        case .path: return String(localized: "Path")
        case .garden: return String(localized: "Garden")
        case .flowers: return String(localized: "Flowers")
        case .rocks: return String(localized: "Rocks")
        case .bench: return String(localized: "Bench")
        case .pond: return String(localized: "Pond")
        case .nook: return String(localized: "Reading nook")
        case .treehouse: return String(localized: "Treehouse")
        }
    }
    var width: Int {
        switch self { case .cottage, .barn: return 4; case .garden, .pond, .treehouse, .workshop, .greenhouse, .windmill: return 3; case .bench, .nook, .orchard, .doghouse, .grill: return 2; default: return 1 }
    }
    var menuTitle: String {
        switch self { case .workshop: return String(localized: "Workshop"); case .nook: return String(localized: "Nook"); default: return title }
    }
    var depth: Int {
        switch self { case .cottage, .barn, .pond, .treehouse, .workshop, .windmill: return 3; case .garden, .nook, .greenhouse, .orchard, .doghouse, .grill: return 2; default: return 1 }
    }
    var blocksWalking: Bool { self != .path && self != .flowers }
    var projectID: String? { [.pond, .nook, .treehouse].contains(self) ? rawValue : nil }
}

nonisolated struct HomesteadCell: Codable, Equatable, Hashable, Sendable {
    var x: Int
    var z: Int
}

nonisolated enum HomesteadLand: String, Codable, CaseIterable, Sendable { case west, east, north }

nonisolated struct HomesteadObject: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: HomesteadKind
    var cell: HomesteadCell?
    var rotation: Int
    var style: Int = 0
    var sourceID: UUID?
    // Missing on saved v1 objects; current coordinates travel with new moves.
    var landGridVersion: Int? = 2
    var isPlaced: Bool { cell != nil }
    var width: Int { rotation % 2 == 0 ? kind.width : kind.depth }
    var depth: Int { rotation % 2 == 0 ? kind.depth : kind.width }
    var cells: Set<HomesteadCell> {
        guard let cell, (-32...32).contains(cell.x), (-32...32).contains(cell.z), (0..<4).contains(rotation) else { return [] }
        return Set((0..<depth).flatMap { dz in (0..<width).map { dx in .init(x: cell.x + dx, z: cell.z + dz) } })
    }
}

nonisolated enum HomesteadIdentity {
    static func stable(childID: UUID, key: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data("homestead:v1:\(childID.uuidString):\(key)".utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

nonisolated struct HomesteadCellBounds: Sendable {
    let x: Range<Int>
    let z: Range<Int>
    func contains(_ cell: HomesteadCell) -> Bool { x.contains(cell.x) && z.contains(cell.z) }
    var cells: [HomesteadCell] { z.flatMap { z in x.map { .init(x: $0, z: z) } } }
}

nonisolated enum HomesteadGeometry {
    // Enlarge outward from the shipped regions; saved cells never move.
    static let squaresPerPlot = 5
    static let starterPlots = 4
    static let expansionSide = 12
    static let baseBounds = HomesteadCellBounds(x: 0..<20, z: 0..<20)
    static func bounds(for land: HomesteadLand) -> HomesteadCellBounds {
        switch land {
        case .west: return .init(x: -12..<0, z: 0..<12)
        case .east: return .init(x: 20..<32, z: 0..<12)
        case .north: return .init(x: 0..<12, z: -12..<0)
        }
    }
    /// Translate only old off-clearing placements. Original receipts/events
    /// stay immutable; the version prevents a later free move shifting twice.
    static func currentCoordinates(_ original: HomesteadObject, land: Set<HomesteadLand>) -> HomesteadObject {
        guard original.landGridVersion == nil else { return original }
        var object = original
        let outside = object.cells.filter { !baseBounds.contains($0) }
        if land.contains(.west), outside.contains(where: { (-10..<0).contains($0.x) && (5..<15).contains($0.z) }) {
            object.cell?.z -= 5
        } else if land.contains(.east), outside.contains(where: { (20..<30).contains($0.x) && (5..<15).contains($0.z) }) {
            object.cell?.z -= 5
        } else if land.contains(.north), outside.contains(where: { (5..<15).contains($0.x) && (-10..<0).contains($0.z) }) {
            object.cell?.x -= 5
        }
        object.landGridVersion = 2
        return object
    }
    static let allCells = baseBounds.cells + HomesteadLand.allCases.flatMap { bounds(for: $0).cells }

    static func buildable(_ cell: HomesteadCell, land: Set<HomesteadLand>) -> Bool {
        baseBounds.contains(cell) || land.contains { bounds(for: $0).contains(cell) }
    }

    static func canPlace(_ object: HomesteadObject, among objects: [HomesteadObject], land: Set<HomesteadLand>) -> Bool {
        guard let cell = object.cell, (-32...32).contains(cell.x), (-32...32).contains(cell.z),
              (0..<4).contains(object.rotation), object.cells.allSatisfy({ buildable($0, land: land) }) else { return false }
        guard ![HomesteadKind.greenhouse, .orchard].contains(object.kind) || object.cells.allSatisfy({ bounds(for: .west).contains($0) }) else { return false }
        return !objects.contains { other in
            guard other.id != object.id, let occupied = other.cell else { return false }
            guard (-32...32).contains(occupied.x), (-32...32).contains(occupied.z), (0..<4).contains(other.rotation) else { return true }
            return cell.x < occupied.x + other.width && occupied.x < cell.x + object.width
                && cell.z < occupied.z + other.depth && occupied.z < cell.z + object.depth
        }
    }
    static func nearestPlacement(for object: HomesteadObject, among objects: [HomesteadObject], land: Set<HomesteadLand>, requiringRoutes: Bool = false) -> HomesteadCell? {
        let preferred = object.cell ?? .init(x: 8, z: 8)
        guard (-32...32).contains(preferred.x), (-32...32).contains(preferred.z), (0..<4).contains(object.rotation) else { return nil }
        let occupied = objects.filter { $0.id != object.id && $0.isPlaced }.reduce(into: Set<HomesteadCell>()) { $0.formUnion($1.cells) }
        guard allCells.contains(where: { buildable($0, land: land) && !occupied.contains($0) }) else { return nil }
        let candidates = allCells.sorted {
            let a = abs($0.x - preferred.x) + abs($0.z - preferred.z)
            let b = abs($1.x - preferred.x) + abs($1.z - preferred.z)
            return a == b ? ($0.z == $1.z ? $0.x < $1.x : $0.z < $1.z) : a < b
        }
        return candidates.first { cell in
            var candidate = object; candidate.cell = cell
            guard canPlace(candidate, among: objects, land: land) else { return false }
            return !requiringRoutes || HomesteadNavigationRules.hasUsableRoutes(
                objects: objects.filter { $0.id != candidate.id } + [candidate], land: land)
        }
    }
    /// Where a newly built piece should first appear: beside the places it works
    /// with (the mill by the fields, the grill by the cottage), with a square of
    /// breathing room, reachable, and on buildable land. Presentation only; the
    /// child can still move it anywhere valid before placing.
    static func bestPlacement(for object: HomesteadObject, among objects: [HomesteadObject], land: Set<HomesteadLand>) -> HomesteadCell? {
        // Fixed yard spots come first (A70); scoring only covers pieces without one.
        if object.rotation == 0, let spot = HomesteadSpots.firstFree(for: object, among: objects, land: land) { return spot }
        let placed = objects.filter { $0.id != object.id && $0.isPlaced }
        let occupied = placed.reduce(into: Set<HomesteadCell>()) { $0.formUnion($1.cells) }
        func centre(_ other: HomesteadObject) -> (Double, Double) {
            (Double(other.cell?.x ?? 0) + Double(other.width) / 2, Double(other.cell?.z ?? 0) + Double(other.depth) / 2)
        }
        let partners = placed.filter { object.kind.workPartners.contains($0.kind) }.map(centre)
        let everyone = placed.map(centre)
        var anchor: (Double, Double) = (10, 10)
        if let partner = partners.first { anchor = partner }
        else if !everyone.isEmpty {
            let count = Double(everyone.count)
            let sumX = everyone.reduce(0.0) { $0 + $1.0 }, sumZ = everyone.reduce(0.0) { $0 + $1.1 }
            anchor = (sumX / count, sumZ / count)
        }
        var scored: [(cell: HomesteadCell, score: Double)] = []
        for cell in allCells where buildable(cell, land: land) && !occupied.contains(cell) {
            var candidate = object; candidate.cell = cell
            let footprint = candidate.cells
            guard !footprint.isEmpty, footprint.allSatisfy({ buildable($0, land: land) && !occupied.contains($0) }) else { continue }
            let x: Double = Double(cell.x) + Double(object.width) / 2
            let z: Double = Double(cell.z) + Double(object.depth) / 2
            var touching = 0
            for square in footprint {
                for (dx, dz) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where occupied.contains(.init(x: square.x + dx, z: square.z + dz)) { touching += 1 }
            }
            let distance: Double = hypot(x - anchor.0, z - anchor.1)
            scored.append((cell, distance + Double(touching) * 2.5))
        }
        scored.sort { left, right in
            if left.score != right.score { return left.score < right.score }
            return left.cell.z == right.cell.z ? left.cell.x < right.cell.x : left.cell.z < right.cell.z
        }
        return scored.first { entry in
            var candidate = object; candidate.cell = entry.cell
            return canPlace(candidate, among: objects, land: land)
                && HomesteadNavigationRules.hasUsableRoutes(objects: objects.filter { $0.id != candidate.id } + [candidate], land: land)
        }?.cell ?? nearestPlacement(for: object, among: objects, land: land, requiringRoutes: true)
    }
    static func hasDuckHabitat(_ objects: [HomesteadObject]) -> Bool {
        func center(_ o: HomesteadObject) -> (Double, Double) {
            let cell = o.cell!
            return (Double(cell.x) + Double(o.width)/2, Double(cell.z) + Double(o.depth)/2)
        }
        return objects.filter { $0.kind == .pond && $0.isPlaced }.contains { pond in
            let p = center(pond)
            return objects.filter { $0.kind == .flowers && $0.isPlaced }.filter {
                let f = center($0)
                return hypot(f.0-p.0, f.1-p.1) <= 4.25
            }.map(\.id).reduce(into: Set<UUID>()) { $0.insert($1) }.count >= 3
        }
    }
}

extension HomesteadKind {
    /// Places a new piece likes to sit beside when it is first built.
    var workPartners: [HomesteadKind] {
        switch self {
        case .windmill, .barn, .orchard, .greenhouse: return [.garden, .cottage]
        case .grill, .bench, .flowers, .doghouse, .nook, .workshop, .garden: return [.cottage]
        case .pond: return [.flowers, .cottage]
        case .treehouse: return [.tree, .cottage]
        default: return []
        }
    }
}

extension LivingWorldProject {
    var worldKind: HomesteadKind {
        switch self { case .pond: return .pond; case .nook: return .nook; case .treehouse: return .treehouse }
    }
}
