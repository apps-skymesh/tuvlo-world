import Foundation
import SwiftData

/// World-only building materials. They never change Coins, Stars, XP, approved
/// wins, receipts or mission history. Approved missions drive production.
nonisolated enum HomesteadMaterial: String, CaseIterable, Sendable {
    case wood, stone, food
    var title: String {
        switch self { case .wood: return String(localized: "Wood"); case .stone: return String(localized: "Stone"); case .food: return String(localized: "Food") }
    }
    var icon: String { "material." + rawValue }
}

nonisolated struct HomesteadMaterialAmounts: Equatable, Hashable, Sendable {
    var wood = 0, stone = 0, food = 0
    static let zero = Self()
    subscript(material: HomesteadMaterial) -> Int {
        get { switch material { case .wood: return wood; case .stone: return stone; case .food: return food } }
        set { switch material { case .wood: wood = newValue; case .stone: stone = newValue; case .food: food = newValue } }
    }
    static func + (a: Self, b: Self) -> Self { .init(wood: a.wood + b.wood, stone: a.stone + b.stone, food: a.food + b.food) }
    static func * (a: Self, n: Int) -> Self { .init(wood: a.wood * n, stone: a.stone * n, food: a.food * n) }
    var isEmpty: Bool { wood <= 0 && stone <= 0 && food <= 0 }
    func covers(_ cost: Self) -> Bool { HomesteadMaterial.allCases.allSatisfy { self[$0] >= cost[$0] } }
    /// What is still missing to pay `cost`, never negative.
    func shortfall(for cost: Self) -> Self {
        var result = Self.zero
        for material in HomesteadMaterial.allCases { result[material] = max(0, cost[material] - self[material]) }
        return result
    }
    var parts: [(material: HomesteadMaterial, amount: Int)] {
        HomesteadMaterial.allCases.compactMap { self[$0] > 0 ? ($0, self[$0]) : nil }
    }
    var label: String { parts.map { "\($0.amount) \($0.material.title.lowercased())" }.joined(separator: ", ") }
}

/// A producer adds its yield once per approved mission. The edge woods and
/// quarry are fixed scenery; every other producer is an owned, placed piece.
nonisolated enum HomesteadProducer: String, CaseIterable, Sendable {
    case woods, quarry, garden, pond, windmill, greenhouse, orchard, workshop, waterside
    static let storageHarvests = 10
    /// Retain historical yields/identities; only food producers remain collectible.
    var isCollectible: Bool { yield.food > 0 }
    var yield: HomesteadMaterialAmounts {
        switch self {
        case .woods: return .init(wood: 2)
        case .quarry: return .init(stone: 1)
        case .garden, .pond, .windmill, .greenhouse: return .init(food: 1)
        case .orchard: return .init(food: 2)
        case .workshop: return .init(wood: 1, stone: 1)
        case .waterside: return .init(stone: 1)
        }
    }
    /// One free extra each family day, so a visit always has something to tap.
    var dailyFind: HomesteadMaterialAmounts? {
        switch self {
        case .woods: return .init(wood: 1)
        case .quarry: return .init(stone: 1)
        case .garden: return .init(food: 1)
        default: return nil
        }
    }
    var kind: HomesteadKind? {
        switch self {
        case .garden: return .garden; case .pond: return .pond; case .windmill: return .windmill
        case .greenhouse: return .greenhouse; case .orchard: return .orchard; case .workshop: return .workshop
        case .woods, .quarry, .waterside: return nil
        }
    }
    static func producer(for kind: HomesteadKind) -> Self? { allCases.first { $0.kind == kind } }
    var title: String {
        switch self {
        case .woods: return String(localized: "Woods"); case .quarry: return String(localized: "Quarry")
        case .waterside: return String(localized: "East waterside")
        default: return kind?.title ?? rawValue
        }
    }
    var mainMaterial: HomesteadMaterial { yield.parts.first?.material ?? .wood }
    /// Runtime key for the scene bubble: edge producers have fixed names.
    var isEdge: Bool { self == .woods || self == .quarry }
}

/// Everything that can be built with materials, in mission-gate order.
enum HomesteadBuildTarget: Hashable {
    case project(LivingWorldProject)
    case expansion(LivingWorldExpansion)
    static let ordered: [Self] = [.project(.pond), .expansion(.windmill), .project(.nook), .expansion(.doghouse), .expansion(.grill), .expansion(.barn), .project(.treehouse),
                                  .expansion(.meadow), .expansion(.workshop), .expansion(.greenhouse),
                                  .expansion(.orchard), .expansion(.waterside)]
    var key: String {
        switch self { case .project(let p): return p.rawValue; case .expansion(let e): return e.rawValue }
    }
    var title: String {
        switch self { case .project(let p): return p.worldKind.title; case .expansion(let e): return e.title }
    }
    var requiredWins: Int {
        switch self { case .project(let p): return p.requiredWins; case .expansion(let e): return e.requiredWins }
    }
    var price: Double {
        switch self { case .project(let p): return p.price; case .expansion(let e): return e.price }
    }
    var icon: String {
        switch self { case .project(let p): return p.worldKind.controlIcon; case .expansion(let e): return e.icon }
    }
    var materials: HomesteadMaterialAmounts {
        // New builds use meals only. Legacy wood/stone records replay unchanged.
        switch self {
        case .project(.nook): return .init(food: 3)
        case .project(.treehouse), .expansion(.workshop): return .init(food: 4)
        case .expansion(.meadow): return .init(food: 8)
        case .expansion(.orchard): return .init(food: 6)
        case .expansion(.waterside): return .init(food: 10)
        default: return .zero
        }
    }
}

/// Append-only records on the existing WorldPlacement sync, backup and deletion paths.
nonisolated enum HomesteadMaterialRecord: Equatable, Sendable {
    case collect(HomesteadProducer, through: Int)
    case find(HomesteadProducer, day: String)
    case use(target: String, HomesteadMaterialAmounts)
    static let prefix = "living-world:v1:materials:"
    var rawValue: String {
        switch self {
        case .collect(let p, let through): return Self.prefix + "collect:\(p.rawValue):\(through)"
        case .find(let p, let day): return Self.prefix + "find:\(p.rawValue):\(day)"
        case .use(let target, let a): return Self.prefix + "use:\(target):\(a.wood):\(a.stone):\(a.food)"
        }
    }
    /// Identity excludes amounts, so a place uses materials at most once.
    var identityKey: String {
        switch self {
        case .collect(let p, let through): return "materials:collect:\(p.rawValue):\(through)"
        case .find(let p, let day): return "materials:find:\(p.rawValue):\(day)"
        case .use(let target, _): return "materials:use:\(target)"
        }
    }
    func recordID(childID: UUID) -> UUID { HomesteadIdentity.stable(childID: childID, key: identityKey) }
    init?(rawValue: String) {
        guard rawValue.hasPrefix(Self.prefix), rawValue.utf8.count < 256 else { return nil }
        let parts = rawValue.dropFirst(Self.prefix.count).split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch parts.first {
        case "collect":
            guard parts.count == 3, let p = HomesteadProducer(rawValue: parts[1]), let n = Int(parts[2]), (1...100_000).contains(n) else { return nil }
            self = .collect(p, through: n)
        case "find":
            guard parts.count == 3, let p = HomesteadProducer(rawValue: parts[1]), p.dailyFind != nil,
                  parts[2].count == 10, FamilyDay.noon(forKey: parts[2]) != nil else { return nil }
            self = .find(p, day: parts[2])
        case "use":
            guard parts.count == 5, !parts[1].isEmpty, parts[1].count < 64,
                  let w = Int(parts[2]), let s = Int(parts[3]), let f = Int(parts[4]),
                  [w, s, f].allSatisfy({ (0...1000).contains($0) }) else { return nil }
            self = .use(target: parts[1], .init(wood: w, stone: s, food: f))
        default: return nil
        }
    }
}

/// Pure replay of a child's material records against their approved wins.
struct HomesteadMaterialLedger {
    let wins: Int
    let day: String
    let active: Set<HomesteadProducer>
    private var usesOpeningProduction = false
    private var usesFarmProduction = false
    var displaysMeals: Bool { usesFarmProduction }
    private(set) var through: [HomesteadProducer: Int] = [:]
    private(set) var collected = HomesteadMaterialAmounts.zero
    private(set) var found: Set<HomesteadProducer> = []
    private(set) var used = HomesteadMaterialAmounts.zero
    private(set) var usedTargets: Set<String> = []

    @MainActor
    init(kid: Child, now: Date = Date(), timeZone: TimeZone = .current, objects: [HomesteadObject]? = nil, land: Set<HomesteadLand>? = nil) {
        let starter = LivingWorldStarter(kid: kid)
        let state = (objects == nil || land == nil) ? try? HomesteadActions.state(for: kid) : nil
        let building = Set(HomesteadConstruction.pending(kid: kid, now: now).map(\.kind))
        let placed = Set((objects ?? state?.objects ?? []).filter { $0.isPlaced && !building.contains($0.kind) }.map(\.kind))
        let owned = land ?? state?.land ?? []
        var active = Set<HomesteadProducer>()
        if !starter.isLoading && starter.count == 3 {
            for producer in HomesteadProducer.allCases {
                if let kind = producer.kind, placed.contains(kind) { active.insert(producer) }
            }
            if owned.contains(.east) { active.insert(.waterside) }
        }
        let records = kid.worldPlacements.compactMap { row -> HomesteadMaterialRecord? in
            guard !row.isDeleted, let record = HomesteadMaterialRecord(rawValue: row.discoveryID),
                  row.id == record.recordID(childID: kid.id) else { return nil }
            return record
        }
        let opening = HomesteadOpeningLedger(kid: kid)
        let farm = HomesteadFarmJournal(kid: kid)
        self.init(wins: EconomyLedger.forChild(kid).approvedWins, day: FamilyDay.key(for: now, in: timeZone), active: active, records: records,
                  provisionFood: opening.provisions, bonusWood: opening.bonusWood, farmMeals: farm.started ? farm.meals : nil)
        usesOpeningProduction = opening.started
        #if DEBUG
        if WorldSandboxSession.isSandbox(kid) {
            usesFarmProduction = true
            let credits = kid.worldPlacements.compactMap { row -> Int? in
                let raw = row.discoveryID
                guard !row.isDeleted, raw.hasPrefix(WorldSandboxSession.mealCreditPrefix),
                      row.id == HomesteadIdentity.stable(childID: kid.id, key: raw),
                      let value = Int(raw.dropFirst(WorldSandboxSession.mealCreditPrefix.count)),
                      (0...100_000).contains(value) else { return nil }
                return value
            }.max() ?? 0
            collected.food += credits
        }
        #endif
    }

    init(wins: Int, day: String, active: Set<HomesteadProducer>, records: [HomesteadMaterialRecord], provisionFood: Int = 0, bonusWood: Int = 0, farmMeals: Int? = nil) {
        self.wins = max(0, wins); self.day = day; self.active = Set(active.filter(\.isCollectible))
        usesFarmProduction = farmMeals != nil
        collected = .init(wood: bonusWood, food: provisionFood + (farmMeals ?? 0))
        var throughs: [HomesteadProducer: Set<Int>] = [:]
        var seen = Set<String>()
        for record in records where seen.insert(record.identityKey).inserted {
            switch record {
            case .collect(let p, let n): throughs[p, default: []].insert(n)
            case .find(let p, let d):
                collected = collected + (p.dailyFind ?? .zero)
                if d == day { found.insert(p) }
            case .use(let target, let amounts):
                used = used + amounts; usedTargets.insert(target)
            }
        }
        // Each collection adds its harvests since the previous one, capped by
        // storage. Devices collecting the same harvest share one record.
        for (producer, values) in throughs {
            var previous = 0
            for n in values.sorted() {
                collected = collected + producer.yield * min(Self.cap, n - previous)
                previous = n
            }
            through[producer] = previous
        }
    }
    static let cap = HomesteadProducer.storageHarvests

    var balance: HomesteadMaterialAmounts {
        var result = HomesteadMaterialAmounts.zero
        for material in HomesteadMaterial.allCases { result[material] = max(0, collected[material] - used[material]) }
        return result
    }
    func harvests(_ producer: HomesteadProducer) -> Int {
        guard active.contains(producer), !(usesFarmProduction && producer.yield.food > 0), !(usesOpeningProduction && [.garden, .pond, .windmill].contains(producer)) else { return 0 }
        return min(Self.cap, max(0, wins - (through[producer] ?? 0)))
    }
    func isFull(_ producer: HomesteadProducer) -> Bool { harvests(producer) >= Self.cap }
    func hasDailyFind(_ producer: HomesteadProducer) -> Bool {
        active.contains(producer) && !(usesFarmProduction && producer.yield.food > 0) && !(usesOpeningProduction && [.garden, .pond, .windmill].contains(producer)) && producer.dailyFind != nil && !found.contains(producer)
    }
    func ready(_ producer: HomesteadProducer) -> HomesteadMaterialAmounts {
        producer.yield * harvests(producer) + (hasDailyFind(producer) ? producer.dailyFind! : .zero)
    }
    var readyProducers: [HomesteadProducer] { HomesteadProducer.allCases.filter { !ready($0).isEmpty } }
    func isUsed(_ target: HomesteadBuildTarget) -> Bool { usedTargets.contains(target.key) }
    /// Materials still needed for a target; already-used targets need nothing.
    func shortfall(for target: HomesteadBuildTarget) -> HomesteadMaterialAmounts {
        isUsed(target) ? .zero : balance.shortfall(for: target.materials)
    }
    func canAfford(_ target: HomesteadBuildTarget) -> Bool { shortfall(for: target).isEmpty }
    /// The active producer that can supply this material soonest.
    func source(for material: HomesteadMaterial) -> HomesteadProducer? {
        let candidates = HomesteadProducer.allCases.filter { producer in
            active.contains(producer) && !(usesFarmProduction && producer.yield.food > 0) && !(usesOpeningProduction && [.garden, .pond, .windmill].contains(producer)) && (producer.yield[material] > 0 || (producer.dailyFind?[material] ?? 0) > 0)
        }
        return candidates.first { ready($0)[material] > 0 } ?? candidates.first
    }
}

@MainActor
enum HomesteadMaterialActions {
    enum Failure: LocalizedError {
        case needs(HomesteadMaterialAmounts)
        var errorDescription: String? {
            switch self { case .needs(let missing): return String(localized: "Collect \(missing.label) more first.") }
        }
    }

    /// Saves the ready harvest and daily find together, before any feedback.
    /// A failed save removes only these rows; repeats return nothing new.
    @discardableResult
    static func collect(_ producer: HomesteadProducer, kid: Child, in context: ModelContext, now: Date = Date(),
                        allowsChanges: (() -> Bool)? = nil,
                        save: (ModelContext) throws -> Void = { try $0.save() }) throws -> HomesteadMaterialAmounts {
        guard allowsChanges?() ?? HomesteadActions.permitsChanges() else { throw HomesteadActions.Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw HomesteadActions.Failure.missingChild }
        let ledger = HomesteadMaterialLedger(kid: kid, now: now)
        guard ledger.active.contains(producer) else { throw HomesteadActions.Failure.notOwned }
        var records: [HomesteadMaterialRecord] = []
        if ledger.harvests(producer) > 0 { records.append(.collect(producer, through: ledger.wins)) }
        if ledger.hasDailyFind(producer) { records.append(.find(producer, day: ledger.day)) }
        let amount = ledger.ready(producer)
        var inserted: [WorldPlacement] = []
        for record in records {
            let id = record.recordID(childID: kid.id)
            if kid.worldPlacements.contains(where: { !$0.isDeleted && $0.id == id }) { continue }
            let row = WorldPlacement(discoveryID: record.rawValue, zone: .village, placedAt: now)
            row.id = id; context.insert(row); row.child = kid; inserted.append(row)
        }
        guard !inserted.isEmpty else { return .zero }
        do { try save(context) }
        catch { for row in inserted { row.child = nil; context.delete(row) }; throw error }
        return amount
    }

    /// Throws before a purchase starts when materials are missing.
    static func requireMaterials(for target: HomesteadBuildTarget, kid: Child, now: Date = Date()) throws {
        let missing = HomesteadMaterialLedger(kid: kid, now: now).shortfall(for: target)
        guard missing.isEmpty else { throw Failure.needs(missing) }
    }

    /// Called after the purchase commits. The identity is the place, so a
    /// retried or synced purchase never uses materials twice.
    @discardableResult
    static func recordUse(for target: HomesteadBuildTarget, kid: Child, in context: ModelContext, now: Date = Date(),
                          save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard kid.modelContext === context, !kid.isDeleted else { throw HomesteadActions.Failure.missingChild }
        let record = HomesteadMaterialRecord.use(target: target.key, target.materials)
        let id = record.recordID(childID: kid.id)
        if kid.worldPlacements.contains(where: { !$0.isDeleted && $0.id == id }) { return false }
        let row = WorldPlacement(discoveryID: record.rawValue, zone: .village, placedAt: now)
        row.id = id; context.insert(row); row.child = kid
        do { try save(context) }
        catch { row.child = nil; context.delete(row); throw error }
        return true
    }
}
