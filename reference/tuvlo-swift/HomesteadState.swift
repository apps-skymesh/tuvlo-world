import Foundation

nonisolated struct HomesteadSavedEvent: Equatable, Sendable {
    let id: UUID
    let date: Date
    let event: HomesteadEvent
}

/// Pure deterministic replay. Discovery/land are monotonic; removing a placement
/// puts it in inventory and never revokes original ownership or refunds currency.
nonisolated struct HomesteadState: Equatable, Sendable {
    let childID: UUID
    private(set) var objects: [HomesteadObject] = []
    private(set) var land: Set<HomesteadLand> = []
    private(set) var discovered = false
    private(set) var extras: HomesteadAppearanceExtras?
    private(set) var baseline: HomesteadBaseline?
    private(set) var retainedMigrationCount = 0

    init(childID: UUID, saved: [HomesteadSavedEvent], canonicalObjects: [HomesteadObject]? = nil, allowsExpansion: Bool = true, canonicalLand: Set<HomesteadLand> = []) {
        self.childID = childID
        land = canonicalLand
        let rows = saved.filter { $0.event.childID == childID && $0.event.isValid }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        if allowsExpansion {
            land.formUnion(rows.compactMap { row in
                if case .expand(let side) = row.event.change { return side }; return nil
            })
        }
        let bases = rows.compactMap { row -> HomesteadBaseline? in
            if case .migration(let value) = row.event.change { return value }; return nil
        }
        retainedMigrationCount = bases.count
        baseline = bases.first
        objects = canonicalObjects ?? baseline?.objects ?? []
        var seen = Set<UUID>()
        var translated = Set<UUID>()
        for row in rows where seen.insert(row.event.commandID).inserted {
            switch row.event.change {
            case .migration: break
            case .expand(let side): if allowsExpansion { land.insert(side) }
            case .discovery(let id): if id == "pip-duck" { discovered = true }
            case .appearance(let value): extras = value
            case .windmillLook(let value):
                if let index = objects.firstIndex(where: { $0.kind == .windmill }) { objects[index].style = value }
            case .orchardVariety(let value):
                // Cosmetic choices stay independent of layout, including moves
                // arriving later from a device which saw an earlier variety.
                if let index = objects.firstIndex(where: { $0.kind == .orchard }) { objects[index].style = value }
            case .arrange(let savedObject):
                let object = HomesteadGeometry.currentCoordinates(savedObject, land: land)
                if object.cell != savedObject.cell { translated.insert(object.id) } else { translated.remove(object.id) }
                if let index = objects.firstIndex(where: { $0.id == object.id }) {
                    guard objects[index].kind == object.kind else { continue }
                    objects[index].cell = object.cell
                    objects[index].rotation = object.rotation
                    objects[index].landGridVersion = object.landGridVersion
                } // A placement never grants ownership.
            case .remove(let id):
                if let index = objects.firstIndex(where: { $0.id == id }) { objects[index].cell = nil }
            }
        }
        objects = objects.map { original in
            let object = HomesteadGeometry.currentCoordinates(original, land: land)
            if object.cell != original.cell { translated.insert(object.id) }
            return object
        }
        // A moved boundary-spanning piece must not displace a clearing piece.
        // Only translated legacy pieces yield to the existing overlap recovery.
        objects.sort {
            if translated.contains($0.id) != translated.contains($1.id) { return !translated.contains($0.id) }
            return $0.id.uuidString < $1.id.uuidString
        }
        // Concurrent individually valid edits can overlap after synchronization.
        // Resolve only the rendered projection; retain every original event.
        var settled: [HomesteadObject] = []
        for var object in objects {
            if object.isPlaced && !HomesteadGeometry.canPlace(object, among: settled, land: land) {
                object.cell = HomesteadGeometry.nearestPlacement(for: object, among: settled, land: land)
            }
            settled.append(object)
        }
        objects = settled.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
