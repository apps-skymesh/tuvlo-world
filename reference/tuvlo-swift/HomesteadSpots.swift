import Foundation

/// Fixed build spots (owner decision 2026-11-02, A70). Each kind has one or two
/// authored spots in its yard around the starting cottage, fields and paths;
/// a new piece goes to the first free one. Coordinates are version-2 land cells.
/// Saved placements are not moved here; the one-time move is a later step.
nonisolated enum HomesteadSpots {
    enum Yard: String, CaseIterable { case house, farm, animal, garden, play, meadow }
    struct Spot: Equatable { let yard: Yard; let cell: HomesteadCell }
    static let catalogue: [HomesteadKind: [Spot]] = [
        // Beside the house. Cells x 6–9, z 1–4 stay free for the kitchen bench (A70).
        .grill: [.init(yard: .house, cell: .init(x: 0, z: 6))],
        // Farm yard, south-west by the fields.
        .windmill: [.init(yard: .farm, cell: .init(x: 1, z: 13)), .init(yard: .farm, cell: .init(x: 1, z: 16))],
        // Animal yard, south-east.
        .barn: [.init(yard: .animal, cell: .init(x: 13, z: 13)), .init(yard: .animal, cell: .init(x: 13, z: 16))],
        .doghouse: [.init(yard: .animal, cell: .init(x: 17, z: 10)), .init(yard: .animal, cell: .init(x: 17, z: 13))],
        // Garden yard, in the middle by the path.
        .pond: [.init(yard: .garden, cell: .init(x: 8, z: 8)), .init(yard: .garden, cell: .init(x: 11, z: 9))],
        // Play yard, north-east by the tree.
        .nook: [.init(yard: .play, cell: .init(x: 10, z: 2)), .init(yard: .play, cell: .init(x: 9, z: 11))],
        .treehouse: [.init(yard: .play, cell: .init(x: 14, z: 2)), .init(yard: .play, cell: .init(x: 16, z: 6))],
        .workshop: [.init(yard: .play, cell: .init(x: 7, z: 14)), .init(yard: .play, cell: .init(x: 4, z: 16))],
        // West meadow (its own yard, only once that land is owned).
        .orchard: [.init(yard: .meadow, cell: .init(x: -10, z: 2)), .init(yard: .meadow, cell: .init(x: -10, z: 6))],
        .greenhouse: [.init(yard: .meadow, cell: .init(x: -6, z: 2)), .init(yard: .meadow, cell: .init(x: -6, z: 6))],
        // Decoration spots along the paths.
        .bench: [.init(yard: .garden, cell: .init(x: 11, z: 4)), .init(yard: .garden, cell: .init(x: 12, z: 6)), .init(yard: .play, cell: .init(x: 14, z: 8))],
        .flowers: [HomesteadCell(x: 4, z: 7), .init(x: 6, z: 7), .init(x: 8, z: 7), .init(x: 10, z: 7), .init(x: 4, z: 9), .init(x: 11, z: 7), .init(x: 6, z: 5), .init(x: 9, z: 5)]
            .map { .init(yard: .garden, cell: $0) },
        .rocks: [HomesteadCell(x: 18, z: 1), .init(x: 1, z: 19), .init(x: 18, z: 18), .init(x: 0, z: 0)].map { .init(yard: .garden, cell: $0) },
    ]
    /// The one-time move into spots (A70 step 3): every placed piece of a kind with
    /// spots that is not already on one takes the first free spot it fits. Pieces
    /// on a spot are never touched, so applying the result twice changes nothing.
    /// Pure: callers save each result through the canonical `.arrange` event.
    static func settlement(_ objects: [HomesteadObject], land: Set<HomesteadLand>) -> [HomesteadObject] {
        var current = objects
        var moved: [UUID: HomesteadObject] = [:]
        // A second pass lets a piece use a spot freed by an earlier move.
        for _ in 0..<2 {
            for object in current.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where object.isPlaced {
                guard let spots = catalogue[object.kind] else { continue }
                if object.rotation == 0, spots.contains(where: { $0.cell == object.cell }) { continue }
                guard let cell = firstFree(for: object, among: current, land: land) else { continue }
                var next = object; next.cell = cell; next.rotation = 0; next.landGridVersion = 2
                current = current.map { $0.id == object.id ? next : $0 }
                moved[object.id] = next
            }
        }
        return moved.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    /// The first authored spot this unrotated piece fits, on owned land and with walkable routes.
    static func firstFree(for object: HomesteadObject, among objects: [HomesteadObject], land: Set<HomesteadLand>) -> HomesteadCell? {
        guard let spots = catalogue[object.kind] else { return nil }
        for spot in spots {
            var candidate = object; candidate.cell = spot.cell; candidate.rotation = 0
            if HomesteadGeometry.canPlace(candidate, among: objects, land: land),
               HomesteadNavigationRules.hasUsableRoutes(objects: objects.filter { $0.id != candidate.id } + [candidate], land: land) {
                return spot.cell
            }
        }
        return nil
    }
}
