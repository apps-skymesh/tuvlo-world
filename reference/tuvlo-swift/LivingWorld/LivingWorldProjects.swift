import Foundation
import SwiftData
import CryptoKit

/// Approved wins open possibilities; they are never spent or converted. These
/// placements use a new namespace, leaving every legacy discovery untouched.
enum LivingWorldProject: String, CaseIterable, Identifiable {
    case pond, nook, treehouse
    var id: String { rawValue }
    var title: String {
        switch self { case .pond: return "The Quiet Pond"; case .nook: return "The Reading Nook"; case .treehouse: return "The Treetop Hideaway" }
    }
    var invitation: String {
        switch self {
        case .pond: return "A little water. A place for wonders."
        case .nook: return "A favorite story, beneath the leaves."
        case .treehouse: return "Somewhere to dream a little bigger."
        }
    }
    var requiredWins: Int {
        switch self { case .pond: return 4; case .nook: return 9; case .treehouse: return 16 }
    }
    /// Starting purchase prices; mission milestones remain separate unlocks.
    var price: Double { Double(requiredWins) }
    var styles: [String] {
        switch self { case .pond: return ["Water lilies", "Wild reeds"]; case .nook: return ["Rose cushions", "Sage cushions"]; case .treehouse: return ["Honey roof", "Berry roof"] }
    }
    var activity: String {
        switch self { case .pond: return "Watching the pond ripple"; case .nook: return "Enjoying a quiet story"; case .treehouse: return "Ready to fly your paper plane" }
    }
    var visitTitle: String {
        switch self { case .pond: return "Watch the ripples"; case .nook: return "Enjoy a story"; case .treehouse: return "Fly a paper plane" }
    }
    var finishedStory: String {
        switch self {
        case .pond: return "The water settles. A tiny visitor finds its way home."
        case .nook: return "A soft seat, an open book. Your own little corner of calm."
        case .treehouse: return "Up among the leaves, a new place to imagine."
        }
    }
}

struct LivingWorldProjectEvent: Equatable {
    enum Action: String { case focus, built, style, spot }
    static let prefix = "living-world:v1:"
    let project: LivingWorldProject
    let action: Action
    let value: Int
    var rawValue: String { "\(Self.prefix)\(project.rawValue):\(action.rawValue):\(value)" }
    init(project: LivingWorldProject, action: Action, value: Int) {
        self.project = project; self.action = action; self.value = min(1, max(0, value))
    }
    init?(rawValue: String) {
        guard rawValue.hasPrefix(Self.prefix) else { return nil }
        let parts = rawValue.dropFirst(Self.prefix.count).split(separator: ":")
        guard parts.count == 3, let project = LivingWorldProject(rawValue: String(parts[0])),
              let action = Action(rawValue: String(parts[1])), let value = Int(parts[2]), (0...1).contains(value) else { return nil }
        self.project = project; self.action = action; self.value = value
    }
}

/// Append-only choice/placement records converge without overwriting another
/// device's completed place. Timestamp + UUID deterministically resolves choices.
struct LivingWorldProjects {
    struct Entry {
        let id: UUID
        let date: Date
        let event: LivingWorldProjectEvent
    }
    let entries: [Entry]
    let approvedWins: Int
    let currency: RewardCurrency
    let balance: Double
    private let purchased: Set<LivingWorldProject>
    private let pendingPurchases: Set<LivingWorldProject>
    init(kid: Child, approvedWins: Int) {
        currency = LivingWorldEconomy.currency(for: kid)
        balance = EconomyLedger.forChild(kid).worldBalance(in: currency)
        purchased = Set(kid.payments.compactMap { $0.storeDetails?.worldProjectRaw.flatMap(LivingWorldProject.init(rawValue:)) })
        pendingPurchases = Set(kid.rewardClaims.filter { $0.status == .pending }.compactMap { $0.storeDetails?.worldProjectRaw.flatMap(LivingWorldProject.init(rawValue:)) })
        self.approvedWins = max(0, approvedWins)
        entries = kid.worldPlacements.compactMap { row in
            guard !row.isDeleted else { return nil }
            return LivingWorldProjectEvent(rawValue: row.discoveryID).map { Entry(id: row.id, date: row.placedAt, event: $0) }
        }.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
    }
    var focus: LivingWorldProject? {
        entries.last { $0.event.action == .focus && !isBuilt($0.event.project) }?.event.project
    }
    var built: [LivingWorldProject] { LivingWorldProject.allCases.filter(isBuilt) }
    func isBuilt(_ project: LivingWorldProject) -> Bool { purchased.contains(project) || entries.contains { $0.event.project == project && $0.event.action == .built } }
    func style(_ project: LivingWorldProject) -> Int {
        entries.last { $0.event.project == project && $0.event.action != .spot }?.event.value ?? 0
    }
    func spot(_ project: LivingWorldProject) -> LivingWorldSpot {
        entries.last { $0.event.project == project && $0.event.action == .spot }
            .flatMap { LivingWorldSpot(rawValue: $0.event.value) } ?? .original
    }
    func hasPendingPurchase(_ project: LivingWorldProject) -> Bool { pendingPurchases.contains(project) }
    func canBuild(_ project: LivingWorldProject) -> Bool { approvedWins >= project.requiredWins && balance >= project.price && !isBuilt(project) }
    func progress(_ project: LivingWorldProject) -> Double { min(1, Double(approvedWins) / Double(project.requiredWins)) }
    func status(_ project: LivingWorldProject) -> String {
        if isBuilt(project) { return "Made by you" }
        if pendingPurchases.contains(project) { return "Waiting to sync" }
        let remaining = max(0, project.requiredWins - approvedWins)
        if remaining == 0 { return balance >= project.price ? "Ready to build" : "Save \(currency.amountLabel(max(0, project.price - balance))) more" }
        return "\(remaining) more approved \(remaining == 1 ? "mission" : "missions")"
    }
    var nextStepText: String {
        if let focus { return "\(focus.title) · \(status(focus).lowercased())" }
        return built.count == LivingWorldProject.allCases.count ? "Your little world, made by you" : "What will you make next?"
    }
}

@MainActor
enum LivingWorldProjectActions {
    enum Failure: LocalizedError {
        case access, notReady, missingChild, notBuilt, insufficientFunds, receipt, priceChanged, onlineRequired
        var errorDescription: String? {
            switch self {
            case .onlineRequired: return "Confirm this purchase online from your World."
            case .priceChanged: return "The World currency changed. Check the price and try again."
            case .insufficientFunds: return "Save a little more before buying this place. Your balance is unchanged."
            case .receipt: return "Your purchase could not be prepared. Please try again."
            case .access: return "Your world is safe. Ask your parent to check access before making changes."
            case .notBuilt: return "Bring this place to life before choosing its spot."
            case .notReady: return "A few more approved missions will bring this place to life."
            case .missingChild: return "This profile is no longer available. Return and choose your profile again."
            }
        }
    }
    @discardableResult
    static func arrange(_ project: LivingWorldProject, spot: LivingWorldSpot, kid: Child, context: ModelContext,
                        now: Date = Date(), allowsChanges: (() -> Bool)? = nil,
                        save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        try apply(.spot, project: project, style: spot.rawValue, kid: kid, context: context,
                  now: now, allowsChanges: allowsChanges, save: save)
    }

    /// Save before any reveal. Failed saves remove only our insertion, allowing
    /// an open editor and unrelated pending work to survive for retry.
    @discardableResult
    static func apply(_ action: LivingWorldProjectEvent.Action, project: LivingWorldProject, style: Int,
                      kid: Child, context: ModelContext, now: Date = Date(),
                      expectedCurrency: RewardCurrency? = nil, allowsChanges: (() -> Bool)? = nil,
                      save: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard allowsChanges?() ?? (DeviceLinkStorage.role == .kid ? KidParentAccess.shared.allowsRequests : AppAccess.allowsChanges) else { throw Failure.access }
        guard kid.modelContext === context, !kid.isDeleted else { throw Failure.missingChild }
        let state = LivingWorldProjects(kid: kid, approvedWins: EconomyLedger.forChild(kid).approvedWins)
        let style = min(1, max(0, style))
        if action == .built {
            if state.isBuilt(project) { return false }
            #if DEBUG
            if let expectedCurrency, expectedCurrency != state.currency { throw Failure.priceChanged }
            guard state.approvedWins >= project.requiredWins else { throw Failure.notReady }
            guard state.balance >= project.price else { throw Failure.insufficientFunds }
            #else
            throw Failure.onlineRequired
            #endif
        }
        if action == .spot {
            guard state.isBuilt(project) else { throw Failure.notBuilt }
            if state.spot(project).rawValue == style { return false }
        }
        if action == .focus, state.focus == project, state.style(project) == style { return false }
        if action == .style, state.style(project) == style { return false }
        let event = LivingWorldProjectEvent(project: project, action: action, value: style)
        let date = max(now, (state.entries.last?.date ?? .distantPast).addingTimeInterval(0.001))
        let row = WorldPlacement(discoveryID: event.rawValue, zone: .village, placedAt: date)
        context.insert(row)
        row.child = kid
        var payment: Payment?
        if action == .built {
            var details = StoreRewardDetails.payout(kind: .custom, coins: project.price, quantity: 1)
            details.pricedInStars = state.currency == .stars
            details.worldProjectRaw = project.rawValue
            details.deliveredAt = date; details.updatedAt = date
            guard let encoded = details.encoded else { row.child = nil; context.delete(row); throw Failure.receipt }
            let receipt = Payment(amountDollars: 0, category: "World · \(project.shortTitle)", paidAt: date)
            receipt.id = LivingWorldEconomy.receiptID(childID: kid.id, project: project, currency: state.currency)
            receipt.storeDetailsRaw = encoded; receipt.child = kid
            context.insert(receipt); payment = receipt
        }
        do { try save(context) }
        catch {
            if let payment { payment.child = nil; context.delete(payment) }
            row.child = nil; context.delete(row); KidStatsCache.invalidateAll(); throw error
        }
        KidStatsCache.invalidateAll()
        return true
    }
}

@MainActor
enum LivingWorldEconomy {
    static let currencyPrefix = "living-world:v1:currency:"
    static func currency(for kid: Child) -> RewardCurrency {
        kid.worldPlacements.filter { !$0.isDeleted && $0.discoveryID.hasPrefix(currencyPrefix) && RewardCurrency(rawValue: String($0.discoveryID.dropFirst(currencyPrefix.count))) != nil }
            .sorted { $0.placedAt == $1.placedAt ? $0.id.uuidString < $1.id.uuidString : $0.placedAt < $1.placedAt }
            .last.flatMap { RewardCurrency(rawValue: String($0.discoveryID.dropFirst(currencyPrefix.count))) } ?? .stars
    }
    @discardableResult
    static func insertCurrency(_ currency: RewardCurrency, for kid: Child, in context: ModelContext) -> WorldPlacement {
        let row = WorldPlacement(discoveryID: currencyPrefix + currency.rawValue, zone: .village)
        context.insert(row); row.child = kid; return row
    }
    /// A parent's later change appends a newer record; earlier records, receipts
    /// and places already built stay as they are. Returns nil when nothing changes.
    @discardableResult
    static func changeCurrency(to currency: RewardCurrency, for kid: Child, in context: ModelContext, now: Date = Date()) -> WorldPlacement? {
        guard currency != self.currency(for: kid) else { return nil }
        let latest = kid.worldPlacements.filter { !$0.isDeleted && $0.discoveryID.hasPrefix(currencyPrefix) }.map(\.placedAt).max() ?? .distantPast
        let row = WorldPlacement(discoveryID: currencyPrefix + currency.rawValue, zone: .village, placedAt: max(now, latest.addingTimeInterval(0.001)))
        context.insert(row); row.child = kid; return row
    }
    static func inheritedCurrency(in context: ModelContext) throws -> RewardCurrency {
        let rows = try context.fetch(FetchDescriptor<WorldPlacement>())
        return rows.filter { $0.discoveryID.hasPrefix(currencyPrefix) && RewardCurrency(rawValue: String($0.discoveryID.dropFirst(currencyPrefix.count))) != nil }.sorted {
            $0.placedAt == $1.placedAt ? $0.id.uuidString < $1.id.uuidString : $0.placedAt < $1.placedAt
        }.last.flatMap { RewardCurrency(rawValue: String($0.discoveryID.dropFirst(currencyPrefix.count))) } ?? .stars
    }
    /// Concurrent purchases at identical terms converge on one new receipt.
    /// Existing IDs and old receipt values are never changed.
    static func receiptID(childID: UUID, project: LivingWorldProject, currency: RewardCurrency) -> UUID {
        let key = "tuvlo-world-purchase-v1|\(childID)|\(project.rawValue)|\(currency.rawValue)|\(project.price)"
        var bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80; bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
