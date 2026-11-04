import Foundation
import Observation

/// Display-only station state; no economic authority is delegated to Godot.
nonisolated struct HomesteadProductionStatus: Codable, Equatable, Sendable {
    var placeID = ""
    let station: String
    let good: String
    let state: Int // 0 idle, 1 working, 2 ready
    let remaining: Int
    let progress: Double
}

/// Shared production state. Normal World commits actions through its saved journal;
/// the disposable sandbox keeps the same rules in memory.
@MainActor @Observable
final class HomesteadFarm {
    static let fieldSeconds: TimeInterval = 30
    static let orchardSeconds: TimeInterval = 60
    nonisolated static func timeLabel(_ seconds: Int) -> String {
        HomesteadTimeFormat.remaining(seconds)
    }
    enum Good: String, CaseIterable, Codable {
        case wheat, flour, bread, meal, fruit, tart, meat
        var title: String { switch self { case .meat: return "Meat"; case .wheat: return "Wheat"; case .flour: return "Flour"; case .bread: return "Bread"; case .meal: return "Meals"; case .fruit: return "Fruit"; case .tart: return "Tart" } }
    }
    enum Station: String, CaseIterable, Codable {
        case field, mill, oven, pantry, orchard, orders, barn, grill
        var kind: HomesteadKind {
            switch self {
            case .field: return .garden
            case .mill: return .windmill
            case .oven, .pantry, .orders: return .cottage
            case .orchard: return .orchard
            case .barn: return .barn
            case .grill: return .grill
            }
        }
        var title: String {
            switch self {
            case .field: return "Farm"; case .mill: return "Mill"; case .oven: return "Oven"
            case .pantry: return "Meals"; case .orchard: return "Orchard"; case .orders: return "Orders"
            case .barn: return "Barn"; case .grill: return "Grill"
            }
        }
    }
    enum Recipe: String, CaseIterable, Codable {
        // Retain the draft delivery ID and terms so saved events replay unchanged.
        case flour, bread, meal, tart, meatDelivery, grilledMeal, livestock
        var input: [Good: Int] {
            switch self { case .livestock: return [.wheat: 2]; case .meatDelivery: return [.bread: 2]; case .grilledMeal: return [.meat: 1, .bread: 1]; case .flour: return [.wheat: 2]; case .bread: return [.flour: 1]; case .meal: return [.bread: 1]; case .tart: return [.flour: 1, .fruit: 2] }
        }
        var output: Good { switch self { case .meatDelivery, .livestock: return .meat; case .grilledMeal: return .meal; case .flour: return .flour; case .bread: return .bread; case .meal: return .meal; case .tart: return .tart } }
        nonisolated var station: Station { switch self { case .meatDelivery, .livestock: return .barn; case .grilledMeal: return .grill; case .flour: return .mill; case .bread, .tart: return .oven; case .meal: return .pantry } }
        var seconds: TimeInterval { switch self { case .livestock: return 90; case .meatDelivery: return 60; case .grilledMeal: return 60; case .flour: return 45; case .bread: return 60; case .meal: return 30; case .tart: return 90 } }
        var quantity: Int { self == .meal ? 3 : self == .grilledMeal ? 4 : [Self.meatDelivery, .livestock].contains(self) ? 2 : 1 }
    }
    struct Field {
        var planted = false
        var wateredAt: Date?
        func stage(at now: Date) -> Int {
            guard planted else { return 0 }
            guard let wateredAt else { return 1 }
            let elapsed = now.timeIntervalSince(wateredAt)
            return elapsed >= HomesteadFarm.fieldSeconds ? 4 : elapsed >= HomesteadFarm.fieldSeconds / 2 ? 3 : 2
        }
        func remaining(at now: Date) -> Int { max(0, Int(ceil(HomesteadFarm.fieldSeconds - now.timeIntervalSince(wateredAt ?? now)))) }
    }
    struct Job {
        let recipe: Recipe
        let started: Date
        var finish: Date { started.addingTimeInterval(recipe.seconds) }
        func remaining(at now: Date) -> Int { max(0, Int(ceil(finish.timeIntervalSince(now)))) }
    }
    private(set) var fields = [Field(), Field()]
    private(set) var stock: [Good: Int] = [:]
    private(set) var jobs: [Station: Job] = [:]
    private(set) var wheatHarvested = 0
    private(set) var breadMade = 0
    private(set) var mealsPacked = 0
    private(set) var grilledMade = 0
    private(set) var picnicFunded = false
    private(set) var picnicServed = false
    private(set) var orders = 0
    private(set) var orchardWatered: Date?
    private(set) var notice: String?
    /// Installed only by the normal World host. Replay never calls persistence.
    var commit: ((HomesteadFarmEvent.Action, Date) -> Bool)?
    func restore(_ source: HomesteadFarm) {
        fields = source.fields; stock = source.stock; jobs = source.jobs
        wheatHarvested = source.wheatHarvested; breadMade = source.breadMade
        grilledMade = source.grilledMade
        mealsPacked = source.mealsPacked; picnicFunded = source.picnicFunded
        picnicServed = source.picnicServed; orders = source.orders
        orchardWatered = source.orchardWatered; notice = source.notice
    }
    func importOpening(_ opening: HomesteadOpeningLedger) {
        stock = [.wheat: opening.wheat, .flour: opening.flour, .bread: opening.bread]
        wheatHarvested = opening.wheat; breadMade = opening.hasBaked ? 1 : 0
        picnicServed = opening.picnic
    }
    subscript(_ good: Good) -> Int { stock[good, default: 0] }

    @discardableResult func tend(_ index: Int, now: Date = Date()) -> Bool {
        if let commit { return commit(.tend(index), now) }
        guard fields.indices.contains(index) else { return false }
        switch fields[index].stage(at: now) {
        case 0: fields[index].planted = true; notice = nil
        case 1: fields[index].wateredAt = now; notice = nil
        case 4:
            fields[index] = Field(); stock[.wheat, default: 0] += 2
            wheatHarvested += 2; notice = "+2 wheat"
        default: return false
        }
        return true
    }
    func canMake(_ recipe: Recipe) -> Bool {
        jobs[recipe.station] == nil && recipe.input.allSatisfy { self[$0.key] >= $0.value }
    }
    @discardableResult func make(_ recipe: Recipe, now: Date = Date()) -> Bool {
        if let commit { return commit(.make(recipe), now) }
        guard canMake(recipe) else { return false }
        for (good, amount) in recipe.input { stock[good, default: 0] -= amount }
        jobs[recipe.station] = Job(recipe: recipe, started: now); notice = nil
        return true
    }
    @discardableResult func collect(_ station: Station, now: Date = Date()) -> Bool {
        if let commit { return commit(.collect(station), now) }
        guard let job = jobs[station], now >= job.finish else { return false }
        jobs[station] = nil; stock[job.recipe.output, default: 0] += job.recipe.quantity
        if job.recipe == .bread { breadMade += 1 }
        if job.recipe == .grilledMeal { grilledMade += 1 }
        if job.recipe.output == .meal { mealsPacked += job.recipe.quantity }
        notice = "+\(job.recipe.quantity) " + job.recipe.output.title.lowercased()
        return true
    }
    func orchardRemaining(at now: Date) -> Int {
        guard let orchardWatered else { return 0 }
        return max(0, Int(ceil(Self.orchardSeconds - now.timeIntervalSince(orchardWatered))))
    }
    @discardableResult func tendOrchard(now: Date = Date()) -> Bool {
        if let commit { return commit(.orchard, now) }
        guard let watered = orchardWatered else { orchardWatered = now; notice = nil; return true }
        guard now.timeIntervalSince(watered) >= Self.orchardSeconds else { return false }
        orchardWatered = nil; stock[.fruit, default: 0] += 3; notice = "+3 fruit"
        return true
    }
    /// Ownership is already saved; serving never charges the project again.
    func fundPicnic() { picnicFunded = true }
    func reconcileMeals(_ amount: Int) { stock[.meal] = max(0, amount) }
    @discardableResult func servePicnic() -> Bool {
        if let commit { return commit(.picnic, Date()) }
        guard picnicFunded, !picnicServed else { return false }
        picnicServed = true; notice = "Picnic ready"; return true
    }
    var orderGood: Good { orders == 0 ? .bread : .tart }
    /// The first welcome admires the loaf and leaves it in inventory.
    /// A saved delivery that already named that loaf still spends it.
    @discardableResult func deliver(consumingLoaf: Bool = false) -> Bool {
        if let commit { return commit(.deliver, Date()) }
        if orders == 0 {
            guard self[.bread] >= 1 else { return false }
            if consumingLoaf { stock[.bread, default: 0] -= 1 }
            orders = 1; notice = "Bread shared"
            return true
        }
        guard self[.tart] >= 1 else { return false }
        stock[.tart, default: 0] -= 1; orders += 1; notice = "Tea is served"
        return true
    }

    func production(at now: Date) -> [HomesteadProductionStatus] {
        let ripe = fields.contains { $0.stage(at: now) == 4 }
        let growing = fields.filter { [2, 3].contains($0.stage(at: now)) }
        let fieldRemaining = growing.map { $0.remaining(at: now) }.min() ?? 0
        var result = [HomesteadProductionStatus(station: "field", good: "wheat", state: ripe ? 2 : growing.isEmpty ? 0 : 1,
            remaining: ripe ? 0 : fieldRemaining, progress: ripe ? 1 : growing.isEmpty ? 0 : max(0, 1 - Double(fieldRemaining) / Self.fieldSeconds))]
        for (station, fallback) in [(Station.mill, Good.flour), (.oven, .bread), (.pantry, .meal), (.barn, .meat), (.grill, .meal)] {
            let job = jobs[station]
            let remaining = job?.remaining(at: now) ?? 0
            result.append(.init(station: station.rawValue, good: (job?.recipe.output ?? fallback).rawValue,
                state: job == nil ? 0 : remaining > 0 ? 1 : 2, remaining: remaining,
                progress: job.map { min(1, max(0, 1 - Double(remaining) / $0.recipe.seconds)) } ?? 0))
        }
        let fruitRemaining = orchardRemaining(at: now)
        result.append(.init(station: "orchard", good: "fruit", state: orchardWatered == nil ? 0 : fruitRemaining > 0 ? 1 : 2,
            remaining: fruitRemaining, progress: orchardWatered == nil ? 0 : max(0, 1 - Double(fruitRemaining) / Self.orchardSeconds)))
        return result
    }
    /// The oven belongs to the cottage, but joins the scene when flour first
    /// gives it a purpose. Descendant results keep it revealed after spending.
    var hasIntroducedOven: Bool {
        self[.flour] > 0 || self[.tart] > 0 || breadMade > 0 || mealsPacked > 0
            || jobs[.oven] != nil || jobs[.pantry] != nil || orders > 0 || grilledMade > 0
    }

    var cottageStation: Station {
        for station in [Station.oven, .pantry] where jobs[station]?.remaining(at: Date()) == 0 { return station }
        return jobs[.oven] != nil ? .oven : jobs[.pantry] != nil ? .pantry : .oven
    }

    func clearNotice() { notice = nil }
}
