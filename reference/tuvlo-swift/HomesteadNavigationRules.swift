import Foundation

/// Shared placement constraint independent of a resident's transient position.
/// Diagonal movement cannot pass blocked corners, so four-neighbor components
/// give the same reachability boundary as the runtime's AStar navigation.
nonisolated enum HomesteadNavigationRules {
    static func hasUsableRoutes(objects: [HomesteadObject], land: Set<HomesteadLand>) -> Bool {
        let blocked = objects.filter { $0.kind.blocksWalking }.reduce(into: Set<HomesteadCell>()) { $0.formUnion($1.cells) }
        var remaining = Set(HomesteadGeometry.allCells
            .filter { HomesteadGeometry.buildable($0, land: land) && !blocked.contains($0) })
        var largest = Set<HomesteadCell>()
        func neighbors(_ cell: HomesteadCell) -> [HomesteadCell] {
            [.init(x: cell.x - 1, z: cell.z), .init(x: cell.x + 1, z: cell.z),
             .init(x: cell.x, z: cell.z - 1), .init(x: cell.x, z: cell.z + 1)]
        }
        while let first = remaining.min(by: { $0.z == $1.z ? $0.x < $1.x : $0.z < $1.z }) {
            remaining.remove(first)
            var component: Set<HomesteadCell> = [first]
            var queue = [first]; var cursor = 0
            while cursor < queue.count {
                for next in neighbors(queue[cursor]) where remaining.remove(next) != nil {
                    component.insert(next); queue.append(next)
                }
                cursor += 1
            }
            if component.count > largest.count { largest = component }
        }
        guard largest.count >= 4 else { return false }
        return objects.filter { $0.isPlaced && [.cottage, .garden, .bench, .pond, .nook, .treehouse, .workshop, .greenhouse, .orchard, .windmill].contains($0.kind) }.allSatisfy { object in
            object.cells.contains { cell in neighbors(cell).contains { largest.contains($0) } }
        }
    }
}
