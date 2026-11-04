import CloudKit
import Foundation
import SwiftData

/// Opening goods are separate from earned currency and the original material
/// history. Original cloud sequences stay intact; offline recipes use fixed
/// unit identities, so merging devices cannot multiply ingredients or outputs.
nonisolated struct HomesteadOpeningEvent: Codable, Equatable, Sendable {
    enum Action: String, Codable, Sendable { case begin, harvest, mill, bake, pack, picnic }
    static let prefix = "living-world:v1:opening:"
    let sequence: Int
    let action: Action
    let wins: Int
    let day: String
    let daily: Bool
    let roundLoaf: Bool
    /// Fixed recipe unit, absent on the original cloud-serialized history.
    /// The same nth recipe on two offline devices is one economic operation.
    var offlineUnit: Int? = nil
    var offlineKey: String? {
        guard let offlineUnit else { return nil }
        switch action {
        case .begin: return "begin:\(wins):\(day):\(daily)"
        case .harvest: return "harvest:\(wins):\(day)"
        case .bake: return "bake:\(offlineUnit):\(roundLoaf)"
        default: return "\(action.rawValue):\(offlineUnit)"
        }
    }
    func id(child: UUID) -> UUID {
        HomesteadIdentity.stable(childID: child, key: offlineKey.map { "opening-offline:" + $0 } ?? "opening:\(sequence)")
    }
    func encoded() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return Self.prefix + (try encoder.encode(self)).base64EncodedString()
    }
    static func decode(_ raw: String) -> Self? {
        guard raw.hasPrefix(prefix), raw.utf8.count < 2048,
              let bytes = Data(base64Encoded: String(raw.dropFirst(prefix.count))),
              let event = try? JSONDecoder().decode(Self.self, from: bytes),
              (0...100_000).contains(event.sequence), (0...100_000).contains(event.wins),
              event.offlineUnit.map({ (0...100_000).contains($0) }) ?? true,
              event.day.count == 10, FamilyDay.noon(forKey: event.day) != nil else { return nil }
        return event
    }
}

nonisolated struct HomesteadOpeningLedger: Equatable {
    private(set) var events: [HomesteadOpeningEvent] = []
    private(set) var wheat = 0
    private(set) var flour = 0
    private(set) var bread = 0
    private(set) var provisions = 0
    private(set) var harvestedThrough = 0
    private(set) var picnic = false
    private(set) var hasBaked = false
    private(set) var roundLoaf = false
    private(set) var valid = true
    var started: Bool { !events.isEmpty }
    var nextSequence: Int { events.count }
    var requestHearts: Int { (hasBaked ? 1 : 0) + (picnic ? 2 : 0) }
    var bonusWood: Int { picnic ? 1 : 0 }
    var gardenCutoff: Int? { events.first?.wins }
    func ready(wins: Int, day: String) -> Int {
        guard started, valid else { return 0 }
        let daily = events.contains { $0.day == day && $0.daily }
        return min(10, max(0, wins - harvestedThrough)) + (daily ? 0 : 1)
    }
    init(events input: [HomesteadOpeningEvent]) {
        let legacy = input.filter { $0.offlineUnit == nil }.sorted { $0.sequence < $1.sequence }
        for event in legacy {
            guard event.sequence == events.count else { valid = false; break }
            switch event.action {
            case .begin:
                guard events.isEmpty else { valid = false; return }
                harvestedThrough = event.wins
            case .harvest:
                guard started, event.wins >= harvestedThrough else { valid = false; return }
                let bonus = event.daily && !events.contains { $0.day == event.day && $0.daily }
                let count = min(10, event.wins - harvestedThrough) + (bonus ? 1 : 0)
                guard count > 0 else { valid = false; return }
                wheat += count; harvestedThrough = event.wins
            case .mill:
                guard wheat >= 2 else { valid = false; return }
                wheat -= 2; flour += 1
            case .bake:
                guard flour >= 1 else { valid = false; return }
                flour -= 1; bread += 1; hasBaked = true; roundLoaf = event.roundLoaf
            case .pack:
                guard bread >= 1 else { valid = false; return }
                bread -= 1; provisions += 1
            case .picnic:
                guard hasBaked, !picnic else { valid = false; return }
                picnic = true
            }
            events.append(event)
        }
        guard valid else { return }
        var seen = Set<String>()
        let offline = input.filter { event in
            event.offlineKey.map { seen.insert($0).inserted } ?? false
        }.sorted {
            if $0.action == .begin && $1.action != .begin { return true }
            if $1.action == .begin && $0.action != .begin { return false }
            if $0.wins != $1.wins { return $0.wins < $1.wins }
            return ($0.offlineKey ?? "") < ($1.offlineKey ?? "")
        }
        guard !offline.isEmpty else { return }
        events += offline
        guard let begin = events.first(where: { $0.action == .begin }) else { valid = false; return }
        // Harvest checkpoints and daily finds are sets, so a replay or a second
        // device cannot grant the same sunny day or daily wheat twice.
        var previous = begin.wins
        var produced = 0
        let harvests = events.filter { $0.action == .harvest }
        for through in Set(harvests.map(\.wins)).sorted() where through > previous {
            produced += min(10, through - previous); previous = through
        }
        let blocked = Set(events.filter { $0.action == .begin && $0.daily }.map(\.day))
        produced += Set(harvests.filter(\.daily).map(\.day)).subtracting(blocked).count
        harvestedThrough = previous
        // Each transform consumes a fixed ordinal: mill n uses wheat 2n/2n+1;
        // bake n uses flour n; pack n uses bread n. Unioning logs can only
        // advance these prefixes, never double-consume or double-produce them.
        func count(_ action: HomesteadOpeningEvent.Action) -> Int {
            var result = legacy.filter { $0.action == action }.count
            let units = Set(offline.filter { $0.action == action }.compactMap(\.offlineUnit))
            while units.contains(result) { result += 1 }
            return result
        }
        let milled = min(count(.mill), produced / 2)
        let baked = min(count(.bake), milled)
        let packed = min(count(.pack), baked)
        wheat = produced - milled * 2; flour = milled - baked
        bread = baked - packed; provisions = packed
        hasBaked = baked > 0
        picnic = hasBaked && events.contains { $0.action == .picnic }
        if let shape = offline.filter({ $0.action == .bake && $0.offlineUnit == baked - 1 }).last {
            roundLoaf = shape.roundLoaf
        }
    }
    func completed(_ action: HomesteadOpeningEvent.Action) -> Int {
        let legacyCount = events.filter { $0.offlineUnit == nil && $0.action == action }.count
        let units = Set(events.filter { $0.action == action }.compactMap(\.offlineUnit))
        var count = legacyCount
        while units.contains(count) { count += 1 }
        return count
    }
    @MainActor init(kid: Child) {
        self.init(events: kid.worldPlacements.filter { !$0.isDeleted }.compactMap { row in
            guard let event = HomesteadOpeningEvent.decode(row.discoveryID), row.id == event.id(child: kid.id) else { return nil }
            return event
        })
    }
    static func level(hearts: Int) -> Int {
        [0, 4, 6, 9, 16, 20, 25, 35, 40, 70, 90].filter { hearts >= $0 }.count
    }
}

@MainActor
enum HomesteadOpeningActions {
    enum Failure: LocalizedError {
        case changed, ingredients, place, access
        var errorDescription: String? {
            switch self {
            case .changed: return "Your supplies changed. Sync and try again."
            case .ingredients: return "Collect the missing ingredient first."
            case .place: return "Place it in your World to continue."
            case .access: return "Parent access is needed to change your World."
            }
        }
    }
    static func wins(_ records: [CKRecord], child: UUID) -> Int {
        let deleted = Set(records.filter { $0.recordType == FamilyShareRecordType.tombstone && $0["recordTypeRaw"] as? String == FamilyShareRecordType.completion }.compactMap { FamilyShareRecordCodec.uuid($0, "id") })
        return records.filter { $0.recordType == FamilyShareRecordType.completion && FamilyShareRecordCodec.uuid($0, "childID") == child
            && !deleted.contains(FamilyShareRecordCodec.uuid($0, "id") ?? UUID())
            && ($0["bonusCoins"] as? Double ?? 0) == 0
            && (($0["earnedCoins"] as? Double ?? 0) > 0 || ($0["earnedXP"] as? Double ?? 0) > 0 || ($0["earnedScreenMinutes"] as? Double ?? 0) > 0) }.count
    }
    static func placements(_ records: [CKRecord], child: UUID) -> [CKRecord] {
        let deleted = Set(records.filter { $0.recordType == FamilyShareRecordType.tombstone && $0["recordTypeRaw"] as? String == FamilyShareRecordType.placement }.compactMap { FamilyShareRecordCodec.uuid($0, "id") })
        return records.filter { $0.recordType == FamilyShareRecordType.placement && FamilyShareRecordCodec.uuid($0, "childID") == child && !deleted.contains(FamilyShareRecordCodec.uuid($0, "id") ?? UUID()) }
    }
    static func ledger(_ rows: [CKRecord], child: UUID) -> HomesteadOpeningLedger {
        .init(events: placements(rows, child: child).compactMap { row in
            guard let event = HomesteadOpeningEvent.decode(row["discoveryID"] as? String ?? ""), FamilyShareRecordCodec.uuid(row, "id") == event.id(child: child) else { return nil }
            return event
        })
    }
    static func materialLedger(_ rows: [CKRecord], child: UUID, wins: Int, day: String) -> HomesteadMaterialLedger {
        let opening = ledger(rows, child: child)
        let records = placements(rows, child: child).compactMap { row -> HomesteadMaterialRecord? in
            guard let event = HomesteadMaterialRecord(rawValue: row["discoveryID"] as? String ?? ""), FamilyShareRecordCodec.uuid(row, "id") == event.recordID(childID: child) else { return nil }
            return event
        }
        let farm = HomesteadFarmJournal.fromCloud(rows, child: child)
        return .init(wins: wins, day: day, active: [], records: records, provisionFood: opening.provisions, bonusWood: opening.bonusWood,
                     farmMeals: farm.started ? farm.meals : nil)
    }
    static func record(raw: String, id: UUID, child: UUID, zone: CKRecordZone.ID, now: Date) -> CKRecord {
        let row = WorldPlacement(discoveryID: raw, zone: .village, placedAt: now); row.id = id
        let record = FamilyShareRecordCodec.encode(row, zoneID: zone)
        record["childID"] = child.uuidString as CKRecordValue
        FamilyShareRecordCodec.attachToShareRoot(record, zoneID: zone)
        return record
    }

    /// Expected sequence is also the restart-safe request identity. An ambiguous
    /// result may retry it, but cannot silently become the following operation.
    static func perform(_ action: HomesteadOpeningEvent.Action, expected: Int, roundLoaf: Bool = false,
                        kid: Child, in context: ModelContext, now: Date = Date(),
                        transport: (CKRecordZone.ID, SpendingConfirmation.Transport)? = nil,
                        access: (() -> Bool)? = nil,
                        save: (ModelContext) throws -> Void = { try $0.save() }) async throws {
        // The farm journal is the production start. Beginning again is the same
        // introduction, so it must not surface a false supply conflict. Later
        // opening recipes stay refused and cannot produce a second set of goods.
        if HomesteadFarmJournal(kid: kid).started {
            guard action == .begin else { throw Failure.changed }
            return
        }
        let permitted = { access?() ?? HomesteadActions.permitsChanges() }
        if transport == nil {
            try HomesteadOfflineOpening.perform(action, expected: expected, roundLoaf: roundLoaf,
                kid: kid, in: context, now: now, access: permitted, save: save)
            return
        }
        guard permitted(), kid.modelContext === context, !kid.isDeleted else { throw Failure.access }
        // A prior failed local application removes only its inserted rows.
        // Persist that cleanup before replaying the same cloud-confirmed command.
        if context.hasChanges { try save(context) }
        guard !context.hasChanges else { throw SpendingConfirmation.Failure.localSave }
        let starter = LivingWorldStarter(kid: kid)
        guard starter.count == 3, starter.introduced else { throw Failure.place }
        let day = FamilyDay.key(for: now, in: .current)
        let prepared: (CKRecordZone.ID, SpendingConfirmation.Transport)
        if let transport { prepared = transport } else { prepared = try await CloudSpendingTransport.make(context: context) }
        let (zone, channel) = prepared
        for attempt in 0..<3 {
            try Task.checkCancellation()
            let root = try await channel.root()
            let rows = try await channel.ledger()
            guard permitted(), !kid.isDeleted, !FamilyDataDeletion.hasPendingLocalCleanup,
                  rows.contains(where: { $0.recordType == FamilyShareRecordType.child && FamilyShareRecordCodec.uuid($0, "id") == kid.id }),
                  !rows.contains(where: { $0.recordType == FamilyShareRecordType.tombstone && $0["recordTypeRaw"] as? String == FamilyShareRecordType.child && FamilyShareRecordCodec.uuid($0, "id") == kid.id }) else { throw Failure.access }
            let state = ledger(rows, child: kid.id)
            let openingRows = placements(rows, child: kid.id).filter {
                let raw = $0["discoveryID"] as? String ?? ""
                return raw.hasPrefix(HomesteadOpeningEvent.prefix) || HomesteadMaterialRecord(rawValue: raw) != nil
            }
            if let saved = state.events.first(where: { $0.sequence == expected }) {
                try SpendingLocalCommit.apply(openingRows, in: context, save: save)
                guard saved.action == action, action != .bake || saved.roundLoaf == roundLoaf else { throw Failure.changed }
                return
            }
            guard state.valid, state.nextSequence == expected, state.started || action == .begin else {
                try SpendingLocalCommit.apply(openingRows, in: context, save: save)
                throw Failure.changed
            }
            for row in rows where row.recordType == FamilyShareRecordType.completion && FamilyShareRecordCodec.uuid(row, "childID") == kid.id {
                if let id = FamilyShareRecordCodec.uuid(row, "id") {
                    let history = try CompletionApprovalHistory.decode(row["approvalHistoryRaw"] as? String, completionID: id)
                    guard !history.needsResolution else { throw SpendingConfirmation.Failure.review }
                }
            }
            let wins = wins(rows, child: kid.id)
            let old = materialLedger(rows, child: kid.id, wins: wins, day: day)
            let legacyGarden = kid.worldStarterVersion != 1 || wins > 0 || old.through[.garden] != nil || old.found.contains(.garden)
            let event = HomesteadOpeningEvent(sequence: expected, action: action, wins: wins, day: day,
                daily: action == .harvest ? !state.events.contains(where: { $0.day == day && $0.daily }) : action == .begin && legacyGarden,
                roundLoaf: roundLoaf)
            // Ownership and placement are checked against the authoritative saved
            // scene, including free storage, rather than a preview or a stale tap.
            if [.harvest, .mill, .bake, .picnic].contains(action) {
                let kind: HomesteadKind = action == .harvest ? .garden : action == .mill ? .windmill : action == .bake ? .cottage : .nook
                let local = try HomesteadActions.state(for: kid)
                guard local.objects.contains(where: { $0.kind == kind && $0.isPlaced }) else { throw Failure.place }
                if action == .mill || action == .picnic {
                    let raw = action == .mill ? LivingWorldExpansion.windmill.rawValue : LivingWorldProject.nook.rawValue
                    guard rows.contains(where: { $0.recordType == FamilyShareRecordType.payment && FamilyShareRecordCodec.uuid($0, "childID") == kid.id && StoreRewardDetails.decode($0["storeDetailsRaw"] as? String)?.worldProjectRaw == raw })
                        || placements(rows, child: kid.id).contains(where: { row in
                            let value = row["discoveryID"] as? String ?? ""
                            return action == .mill ? value == LivingWorldExpansion.windmill.ownershipRaw : LivingWorldProjectEvent(rawValue: value).map { $0.project == .nook && $0.action == .built } == true
                        }) else { throw Failure.place }
                }
            }
            let projected = HomesteadOpeningLedger(events: state.events + [event])
            guard projected.valid else { throw Failure.ingredients }
            var additions = [record(raw: try event.encoded(), id: event.id(child: kid.id), child: kid.id, zone: zone, now: now)]
            if action == .begin {
                // Freeze outstanding old garden Food in its original record type.
                // No collected Food or old collect checkpoint is reinterpreted.
                if legacyGarden && !old.found.contains(.garden) {
                    let find = HomesteadMaterialRecord.find(.garden, day: day)
                    additions.append(record(raw: find.rawValue, id: find.recordID(childID: kid.id), child: kid.id, zone: zone, now: now))
                }
                let owned = Set(try HomesteadActions.state(for: kid).objects.map(\.kind))
                for producer in [HomesteadProducer.garden, .pond, .windmill] {
                    guard let kind = producer.kind, owned.contains(kind) else { continue }
                    let prior = old.through[producer] ?? 0
                    if wins > prior {
                        let frozen = HomesteadMaterialRecord.collect(producer, through: wins)
                        additions.append(record(raw: frozen.rawValue, id: frozen.recordID(childID: kid.id), child: kid.id, zone: zone, now: now))
                    }
                }
            }
            root["updatedAt"] = max(now, (root["updatedAt"] as? Date ?? .distantPast).addingTimeInterval(0.001)) as CKRecordValue
            do { try await channel.commit([root] + additions) }
            catch { if attempt < 2, SpendingConfirmation.isConflict(error) { continue }; throw error }
            guard permitted(), !kid.isDeleted else { throw SpendingConfirmation.Failure.localSave }
            try SpendingLocalCommit.apply(openingRows + additions, in: context, save: save)
            return
        }
        throw SpendingConfirmation.Failure.waiting
    }
}
