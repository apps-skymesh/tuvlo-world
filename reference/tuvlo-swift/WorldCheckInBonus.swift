import Foundation
import SwiftData

/// Shared Kid Mode / World check-in bonus: time between visits earns a
/// little of the child's World currency. Never mission wins, XP or cash, and it
/// spends only in the World. Append-only rows on the WorldPlacement sync,
/// backup and deletion paths; the amount follows from the rule, so a row can't
/// carry a larger value.
struct WorldBonusRecord: Equatable {
    enum Rule: String { case window, daily, streak }
    static let prefix = "living-world:v1:bonus:"
    static let windowsPerDay = 4
    static let streakLength = 7
    let rule: Rule
    let day: String
    let slot: Int
    let currency: RewardCurrency

    var amount: Double {
        switch rule { case .window, .daily: return 1; case .streak: return 5 }
    }
    var rawValue: String { Self.prefix + "\(rule.rawValue):\(day):\(slot):\(currency.rawValue)" }
    /// Identity excludes the currency, so a currency change can't pay a bucket twice.
    var identityKey: String { "bonus:\(rule.rawValue):\(day):\(slot)" }
    func recordID(childID: UUID) -> UUID { HomesteadIdentity.stable(childID: childID, key: identityKey) }

    init(_ rule: Rule, day: String, slot: Int = 0, currency: RewardCurrency) {
        self.rule = rule; self.day = day; self.slot = slot; self.currency = currency
    }
    init?(rawValue: String) {
        guard rawValue.hasPrefix(Self.prefix), rawValue.utf8.count < 128 else { return nil }
        let parts = rawValue.dropFirst(Self.prefix.count).split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, let rule = Rule(rawValue: parts[0]), parts[1].count == 10, FamilyDay.noon(forKey: parts[1]) != nil,
              let slot = Int(parts[2]), let currency = RewardCurrency(rawValue: parts[3]) else { return nil }
        guard rule == .window ? (0..<Self.windowsPerDay).contains(slot) : slot == 0 else { return nil }
        self.init(rule, day: parts[1], slot: slot, currency: currency)
    }

    /// The 6-hour window `date` falls in, in the same family time as daily finds.
    static func slot(for date: Date, in timeZone: TimeZone = .current) -> Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        return min(windowsPerDay - 1, max(0, calendar.component(.hour, from: date) / (24 / windowsPerDay)))
    }
    static func previousDay(_ day: String, in timeZone: TimeZone = .current) -> String? {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        return FamilyDay.noon(forKey: day, in: timeZone)
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
            .map { FamilyDay.key(for: $0, in: timeZone) }
    }
}

/// Parent's per-child switch. Latest record wins; on by default.
@MainActor
enum WorldBonusSetting {
    static let prefix = "living-world:v1:bonus-setting:"
    static func isEnabled(for kid: Child) -> Bool {
        kid.worldPlacements.filter { !$0.isDeleted && ($0.discoveryID == prefix + "on" || $0.discoveryID == prefix + "off") }
            .sorted { $0.placedAt == $1.placedAt ? $0.id.uuidString < $1.id.uuidString : $0.placedAt < $1.placedAt }
            .last.map { $0.discoveryID == prefix + "on" } ?? true
    }
    /// Appends a newer record; nil when nothing changes. Earned bonuses stay.
    @discardableResult
    static func change(to enabled: Bool, for kid: Child, in context: ModelContext, now: Date = Date()) -> WorldPlacement? {
        guard enabled != isEnabled(for: kid) else { return nil }
        let latest = kid.worldPlacements.filter { !$0.isDeleted && $0.discoveryID.hasPrefix(prefix) }.map(\.placedAt).max() ?? .distantPast
        let row = WorldPlacement(discoveryID: prefix + (enabled ? "on" : "off"), zone: .village, placedAt: max(now, latest.addingTimeInterval(0.001)))
        context.insert(row); row.child = kid; return row
    }
}

/// Pure replay of a child's bonus records.
struct WorldBonusLedger {
    struct Dated { let date: Date; let id: String; let record: WorldBonusRecord }
    struct Prize: Equatable {
        let amount: Double
        let currency: RewardCurrency
        let collected: Bool
    }
    struct Trail {
        let streak: Int
        let days: [Prize]
        let weekly: Prize
        let window: Prize
    }
    private(set) var grants: [Dated] = []
    private(set) var keys: Set<String> = []
    private(set) var dailyDays: Set<String> = []

    init(_ rows: [Dated]) {
        for row in rows.sorted(by: { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }) where keys.insert(row.record.identityKey).inserted {
            grants.append(row)
            if row.record.rule == .daily { dailyDays.insert(row.record.day) }
        }
    }

    @MainActor
    init(kid: Child) {
        self.init(kid.worldPlacements.compactMap { row in
            guard !row.isDeleted, let record = WorldBonusRecord(rawValue: row.discoveryID),
                  row.id == record.recordID(childID: kid.id) else { return nil }
            return Dated(date: row.placedAt, id: row.id.uuidString, record: record)
        })
    }

    func granted(_ currency: RewardCurrency) -> Double {
        grants.filter { $0.record.currency == currency }.reduce(0) { $0 + $1.record.amount }
    }

    /// Read-only prize preview. Earned steps retain their original currency;
    /// future steps use the current choice. This never creates a bonus record.
    func trail(at now: Date, currency: RewardCurrency, timeZone: TimeZone = .current) -> Trail {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let count = streak(at: now, timeZone: timeZone)
        let today = FamilyDay.key(for: now, in: timeZone)
        let cycleDay = count == 0 ? 0 : (count - 1) % WorldBonusRecord.streakLength + 1
        let anchor = count == 0 || dailyDays.contains(today) ? now : calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let start = calendar.date(byAdding: .day, value: -max(0, cycleDay - 1), to: anchor) ?? anchor
        let records = Dictionary(uniqueKeysWithValues: grants.map { ($0.record.identityKey, $0.record) })
        func prize(_ rule: WorldBonusRecord.Rule, day: String, slot: Int = 0) -> Prize {
            let expected = WorldBonusRecord(rule, day: day, slot: slot, currency: currency)
            let saved = records[expected.identityKey]
            return Prize(amount: expected.amount, currency: saved?.currency ?? currency, collected: saved != nil)
        }
        let days = (0..<WorldBonusRecord.streakLength).map {
            FamilyDay.key(for: calendar.date(byAdding: .day, value: $0, to: start) ?? start, in: timeZone)
        }
        return Trail(streak: count, days: days.map { prize(.daily, day: $0) },
                     weekly: prize(.streak, day: days[WorldBonusRecord.streakLength - 1]),
                     window: prize(.window, day: today, slot: WorldBonusRecord.slot(for: now, in: timeZone)))
    }

    /// Bounded by the saved days, rather than a fixed lifetime cap. Yesterday's
    /// streak stays visible until today ends; a missed day never removes grants.
    func streak(at now: Date, timeZone: TimeZone = .current) -> Int {
        let today = FamilyDay.key(for: now, in: timeZone)
        let end = dailyDays.contains(today) ? today : WorldBonusRecord.previousDay(today, in: timeZone)
        return end.map { streak(endingOn: $0, timeZone: timeZone) } ?? 0
    }

    private func streak(endingOn day: String, timeZone: TimeZone) -> Int {
        var count = 0, cursor = day
        while count < dailyDays.count, dailyDays.contains(cursor) {
            count += 1
            guard let previous = WorldBonusRecord.previousDay(cursor, in: timeZone) else { break }
            cursor = previous
        }
        return count
    }

    /// Bonuses a visit at `now` earns: this window's, today's first visit, and a
    /// streak bonus when today completes 7, 14, 21… days in a row.
    func due(at now: Date, currency: RewardCurrency, timeZone: TimeZone = .current) -> [WorldBonusRecord] {
        let day = FamilyDay.key(for: now, in: timeZone)
        var due = [WorldBonusRecord(.window, day: day, slot: WorldBonusRecord.slot(for: now, in: timeZone), currency: currency)]
        if !dailyDays.contains(day) {
            due.append(.init(.daily, day: day, currency: currency))
            let run = 1 + (WorldBonusRecord.previousDay(day, in: timeZone).map { streak(endingOn: $0, timeZone: timeZone) } ?? 0)
            if run % WorldBonusRecord.streakLength == 0 { due.append(.init(.streak, day: day, currency: currency)) }
        }
        return due.filter { !keys.contains($0.identityKey) }
    }
}

/// Bonus spends only in the World. Replaying grants and World receipts in time
/// order, each World purchase uses unspent bonus first. The covered part is
/// added back to the ordinary balance, so Store and cash never see bonus value.
enum WorldBonusSpending {
    struct Event { let date: Date; let id: String; let amount: Double; let isGrant: Bool }
    static func replay(_ events: [Event]) -> (covered: Double, unspent: Double) {
        var pool = 0.0, covered = 0.0
        for event in events.sorted(by: { $0.date == $1.date ? ($0.isGrant != $1.isGrant ? $0.isGrant : $0.id < $1.id) : $0.date < $1.date }) {
            guard event.amount.isFinite, event.amount > 0 else { continue }
            if event.isGrant { pool += event.amount }
            else { let used = min(pool, event.amount); pool -= used; covered += used }
        }
        return (covered, pool)
    }

    @MainActor
    static func replay(kid: Child, currency: RewardCurrency) -> (covered: Double, unspent: Double) {
        let ledger = WorldBonusLedger(kid: kid)
        let grants = ledger.grants.filter { $0.record.currency == currency }
        guard !grants.isEmpty else { return (0, 0) }
        var events = grants.map { Event(date: $0.date, id: $0.id, amount: $0.record.amount, isGrant: true) }
        for payment in kid.payments {
            guard let d = payment.storeDetails, d.worldProjectRaw != nil, !d.isCanceled, d.currency == currency else { continue }
            events.append(.init(date: payment.paidAt, id: payment.id.uuidString, amount: d.coins, isGrant: false))
        }
        return replay(events)
    }
}

@MainActor
enum WorldCheckInBonus {
    struct Grant: Equatable {
        let amount: Double
        let currency: RewardCurrency
        /// Only records saved by this claim participate in its one-shot reveal.
        let rules: [WorldBonusRecord.Rule]
        let streak: Int
        var advancesDay: Bool { rules.contains(.daily) }
        var completesWeek: Bool { rules.contains(.streak) }
    }

    /// Saves this visit's due bonuses together before any feedback. Nothing is
    /// granted during the free chapter, with expired access or when switched off.
    @discardableResult
    static func claim(kid: Child, in context: ModelContext, now: Date = Date(), timeZone: TimeZone = .current,
                      allowsChanges: (() -> Bool)? = nil,
                      save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Grant? {
        guard allowsChanges?() ?? HomesteadActions.permitsChanges(), !FamilyDataDeletion.hasPendingLocalCleanup else { return nil }
        guard kid.modelContext === context, !kid.isDeleted, WorldBonusSetting.isEnabled(for: kid) else { return nil }
        #if DEBUG
        // UI journeys compare wallet amounts; only a journey that asks sees bonuses.
        if UITestLaunchConfiguration.isEnabled, !ProcessInfo.processInfo.arguments.contains("-ui-testing-checkin-bonus") { return nil }
        if WorldSandboxSession.isSandbox(kid) { return nil }
        #endif
        let starter = LivingWorldStarter(kid: kid)
        guard !starter.isLoading, !starter.needsGuide, starter.count == 3 else { return nil }
        let currency = LivingWorldEconomy.currency(for: kid)
        let due = WorldBonusLedger(kid: kid).due(at: now, currency: currency, timeZone: timeZone)
        var inserted: [WorldPlacement] = []
        for record in due {
            let id = record.recordID(childID: kid.id)
            if kid.worldPlacements.contains(where: { $0.id == id }) { continue }
            let row = WorldPlacement(discoveryID: record.rawValue, zone: .village, placedAt: now)
            row.id = id; context.insert(row); row.child = kid; inserted.append(row)
        }
        guard !inserted.isEmpty else { return nil }
        do { try save(context) }
        catch { for row in inserted { row.child = nil; context.delete(row) }; throw error }
        KidStatsCache.invalidateAll()
        let saved = inserted.compactMap { WorldBonusRecord(rawValue: $0.discoveryID) }
        return .init(amount: saved.reduce(0) { $0 + $1.amount }, currency: currency,
                     rules: saved.map(\.rule), streak: WorldBonusLedger(kid: kid).streak(at: now, timeZone: timeZone))
    }
}
