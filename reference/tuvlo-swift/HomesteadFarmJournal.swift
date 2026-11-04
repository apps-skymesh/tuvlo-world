import CloudKit
import Foundation
import SwiftData

/// Append-only production, carried by the existing placement sync/backup path.
/// Inputs identify individual goods, not a mutable balance: offline contenders
/// cannot both consume the same wheat, flour or station cycle after merging.
nonisolated struct HomesteadFarmEvent: Codable, Equatable, Sendable {
    enum Action: Codable, Equatable, Sendable {
        case begin, tend(Int), make(HomesteadFarm.Recipe), collect(HomesteadFarm.Station), orchard, picnic, deliver
        var slot: String {
            switch self {
            case .begin: return "begin"
            case .tend(let index): return "field:\(index)"
            case .make(let recipe): return recipe.station.rawValue
            case .collect(let station): return station.rawValue
            case .orchard: return "orchard"
            case .picnic: return "picnic"
            case .deliver: return "orders"
            }
        }
    }
    static let prefix = "living-world:v1:farm:"
    let key: UUID
    let action: Action
    let date: Date
    let rank: Int
    let previous: String
    let inputs: [String]
    func id(child: UUID) -> UUID { HomesteadIdentity.stable(childID: child, key: "farm:" + key.uuidString) }
    func encoded() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return Self.prefix + (try encoder.encode(self)).base64EncodedString()
    }
    static func decode(_ raw: String) -> Self? {
        guard raw.hasPrefix(prefix), raw.utf8.count < 8192,
              let data = Data(base64Encoded: String(raw.dropFirst(prefix.count))),
              let event = try? JSONDecoder().decode(Self.self, from: data),
              (1...1_000_000).contains(event.rank), event.inputs.count <= 8,
              Set(event.inputs).count == event.inputs.count,
              event.inputs.allSatisfy({ $0.utf8.count <= 160 }), event.previous.utf8.count <= 160,
              (0...253_402_300_799).contains(event.date.timeIntervalSince1970) else { return nil }
        if case .tend(let index) = event.action, !(0..<2).contains(index) { return nil }
        return event
    }
}

@MainActor
struct HomesteadFarmJournal {
    let farm = HomesteadFarm()
    private(set) var events: [HomesteadFarmEvent] = []
    private var slots: [String: (token: String, rank: Int, date: Date)] = [:]
    private var goods: [String: (good: HomesteadFarm.Good, rank: Int, date: Date)] = [:]
    private(set) var conflicts = 0
    var started: Bool { slots["begin"] != nil }
    var meals: Int { farm.mealsPacked }

    init(opening: HomesteadOpeningLedger, events input: [HomesteadFarmEvent]) {
        farm.importOpening(opening)
        for good in HomesteadFarm.Good.allCases where good != .meal {
            for index in 0..<max(0, farm[good]) {
                goods["legacy:\(good.rawValue):\(index)"] = (good, 0, .distantPast)
            }
        }
        var seen = Set<UUID>()
        var waitingWelcomes: [HomesteadFarmEvent] = []
        for event in input.sorted(by: { $0.rank == $1.rank ? $0.key.uuidString < $1.key.uuidString : $0.rank < $1.rank }) where seen.insert(event.key).inserted {
            if !apply(event) {
                // The first welcome observes a loaf without consuming an input.
                // Its saved rank can therefore precede the baking that enabled it,
                // and later deliveries chain from it, so they wait in order behind it.
                if event.action == .deliver,
                   !waitingWelcomes.isEmpty || (event.inputs.isEmpty && farm.orders == 0 && farm[.bread] == 0) {
                    waitingWelcomes.append(event)
                } else { conflicts += 1 }
            }
            if farm[.bread] > 0, !waitingWelcomes.isEmpty {
                let pending = waitingWelcomes
                waitingWelcomes.removeAll()
                for welcome in pending where !apply(welcome) { conflicts += 1 }
            }
        }
        conflicts += waitingWelcomes.count
    }
    init(kid: Child) {
        self.init(opening: HomesteadOpeningLedger(kid: kid), events: kid.worldPlacements.compactMap { row in
            guard !row.isDeleted, let event = HomesteadFarmEvent.decode(row.discoveryID), row.id == event.id(child: kid.id) else { return nil }
            return event
        })
    }
    static func fromCloud(_ rows: [CKRecord], child: UUID) -> Self {
        .init(opening: HomesteadOpeningActions.ledger(rows, child: child),
              events: HomesteadOpeningActions.placements(rows, child: child).compactMap { row in
            guard let event = HomesteadFarmEvent.decode(row["discoveryID"] as? String ?? ""),
                  FamilyShareRecordCodec.uuid(row, "id") == event.id(child: child) else { return nil }
            return event
        })
    }
    private func slot(_ name: String) -> (token: String, rank: Int, date: Date) {
        slots[name] ?? ("initial:" + name, 0, .distantPast)
    }
    private func required(_ action: HomesteadFarmEvent.Action, recorded: [String]? = nil) -> [HomesteadFarm.Good: Int] {
        switch action {
        case .make(let recipe): return recipe.input
        case .deliver:
            if farm.orders > 0 { return [.tart: 1] }
            // A recorded loaf is the older welcome. A new welcome lists no loaf.
            if let recorded, !recorded.isEmpty { return [.bread: 1] }
            return [:]
        default: return [:]
        }
    }
    func proposal(_ action: HomesteadFarmEvent.Action, now: Date) -> HomesteadFarmEvent? {
        guard (0...253_402_300_799).contains(now.timeIntervalSince1970) else { return nil }
        // Historic bread deliveries remain replayable, but new barn cycles raise livestock.
        if case .make(.meatDelivery) = action { return nil }
        let previous = slot(action.slot)
        var inputs: [String] = []
        for good in HomesteadFarm.Good.allCases {
            let count = required(action)[good, default: 0]
            let available = goods.keys.filter { goods[$0]?.good == good }.sorted()
            guard available.count >= count else { return nil }
            inputs += available.prefix(count)
        }
        let depth = max(previous.rank, inputs.compactMap { goods[$0]?.rank }.max() ?? 0, action == .begin ? 0 : slot("begin").rank)
        guard depth < 1_000_000 else { return nil }
        return .init(key: UUID(), action: action, date: now, rank: depth + 1, previous: previous.token, inputs: inputs)
    }
    @discardableResult private mutating func apply(_ event: HomesteadFarmEvent) -> Bool {
        let previous = slot(event.action.slot)
        guard started || event.action == .begin,
              event.previous == previous.token, event.date >= previous.date,
              event.inputs.allSatisfy({ goods[$0] != nil && event.date >= goods[$0]!.date }),
              event.rank == max(previous.rank, event.inputs.compactMap { goods[$0]?.rank }.max() ?? 0, event.action == .begin ? 0 : slot("begin").rank) + 1 else { return false }
        var supplied: [HomesteadFarm.Good: Int] = [:]
        for input in event.inputs { supplied[goods[input]!.good, default: 0] += 1 }
        guard supplied == required(event.action, recorded: event.inputs) else { return false }
        if event.action == .deliver, event.inputs.isEmpty, farm.orders == 0 {
            guard goods.values.contains(where: { $0.good == .bread && $0.date <= event.date }) else { return false }
        }
        let before = Dictionary(uniqueKeysWithValues: HomesteadFarm.Good.allCases.map { ($0, farm[$0]) })
        let succeeded: Bool
        switch event.action {
        case .begin: succeeded = !started
        case .tend(let index): succeeded = farm.tend(index, now: event.date)
        case .make(let recipe): succeeded = farm.make(recipe, now: event.date)
        case .collect(let station): succeeded = farm.collect(station, now: event.date)
        case .orchard: succeeded = farm.tendOrchard(now: event.date)
        case .picnic: farm.fundPicnic(); succeeded = farm.servePicnic()
        case .deliver: succeeded = farm.deliver(consumingLoaf: farm.orders == 0 && !event.inputs.isEmpty)
        }
        guard succeeded else { return false }
        for input in event.inputs { goods[input] = nil }
        for good in HomesteadFarm.Good.allCases where good != .meal {
            let output = max(0, farm[good] - before[good, default: 0])
            for index in 0..<output {
                goods["\(event.key.uuidString):\(good.rawValue):\(index)"] = (good, event.rank, event.date)
            }
        }
        slots[event.action.slot] = (event.key.uuidString, event.rank, event.date)
        events.append(event)
        return true
    }

    /// Save first; leave the displayed inventory/timer unchanged on failure.
    static func perform(_ action: HomesteadFarmEvent.Action, kid: Child, in context: ModelContext,
                        now: Date = Date(), access: (() -> Bool)? = nil,
                        save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        typealias Failure = HomesteadOpeningActions.Failure
        guard access?() ?? HomesteadActions.permitsChanges(), kid.modelContext === context, !kid.isDeleted,
              !FamilyDataDeletion.hasPendingLocalCleanup else { throw Failure.access }
        if context.hasChanges { try save(context) }
        guard !context.hasChanges else { throw SpendingConfirmation.Failure.localSave }
        let starter = LivingWorldStarter(kid: kid)
        guard starter.count == 3, starter.introduced else { throw Failure.place }
        for win in kid.completions {
            let history = try CompletionApprovalHistory.decode(win.approvalHistoryRaw, completionID: win.id)
            guard !history.needsResolution else { throw SpendingConfirmation.Failure.review }
        }
        let scene = try HomesteadActions.state(for: kid)
        let placed = Set(scene.objects.filter(\.isPlaced).map(\.kind))
        let kind: HomesteadKind?
        switch action {
        case .begin: kind = nil
        case .tend: kind = .garden
        case .make(let recipe): kind = recipe.station.kind
        case .collect(let station):
            guard [.mill, .oven, .pantry, .barn, .grill].contains(station) else { throw Failure.place }
            kind = station.kind
        case .orchard: kind = .orchard
        case .picnic: kind = .nook
        case .deliver: kind = .cottage
        }
        if let kind {
            guard placed.contains(kind) else { throw Failure.place }
            if let build = HomesteadConstruction.current(kind, kid: kid, now: now) { throw HomesteadConstruction.Failure.building(build.remaining(at: now)) }
        }
        if kind == .windmill { guard LivingWorldExpansion.windmill.isOwned(by: kid) else { throw Failure.place } }
        if let kind, let expansion = LivingWorldExpansion.allCases.first(where: { $0.kind == kind }), !expansion.isOwned(by: kid) { throw Failure.place }
        if kind == .orchard { guard LivingWorldExpansion.orchard.isOwned(by: kid) else { throw Failure.place } }
        if kind == .nook { guard LivingWorldProjects(kid: kid, approvedWins: EconomyLedger.forChild(kid).approvedWins).isBuilt(.nook) else { throw Failure.place } }
        guard HomesteadOpeningLedger(kid: kid).valid else { throw Failure.changed }
        var journal = Self(kid: kid)
        if action == .begin, journal.started { return }
        guard journal.started || action == .begin,
              let event = journal.proposal(action, now: now), journal.apply(event) else { throw Failure.ingredients }
        let zone = CKRecordZone.ID(zoneName: "LocalWorldFarm")
        var additions = [HomesteadOpeningActions.record(raw: try event.encoded(), id: event.id(child: kid.id), child: kid.id, zone: zone, now: now)]
        if action == .begin {
            // Snapshot outstanding old producer yields once, in the activation
            // transaction. Already saved food and old recipes retain their units.
            let old = HomesteadMaterialLedger(kid: kid, now: now)
            for producer in HomesteadProducer.allCases where !producer.isEdge {
                var retained: [HomesteadMaterialRecord] = []
                if old.harvests(producer) > 0 { retained.append(.collect(producer, through: old.wins)) }
                if old.hasDailyFind(producer) { retained.append(.find(producer, day: old.day)) }
                additions += retained.map { HomesteadOpeningActions.record(raw: $0.rawValue, id: $0.recordID(childID: kid.id), child: kid.id, zone: zone, now: now) }
            }
        }
        try SpendingLocalCommit.apply(additions, in: context, save: save)
    }
}
