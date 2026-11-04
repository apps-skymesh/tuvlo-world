import Foundation
import SwiftData

nonisolated struct HomesteadConstructionStatus: Codable, Equatable, Sendable {
    let placeID: String
    let remaining: Int
    let progress: Double
    var phase: Int { progress < 0.33 ? 0 : progress < 0.72 ? 1 : 2 }
}

/// Construction starts with the frozen receipt, not a view's appearance.
/// Old receipts omit the duration and remain immediately complete.
@MainActor
struct HomesteadConstruction {
    let kind: HomesteadKind
    let started: Date
    let seconds: Int
    var finish: Date { started.addingTimeInterval(Double(seconds)) }
    func remaining(at now: Date) -> Int { max(0, Int(ceil(finish.timeIntervalSince(now)))) }
    func progress(at now: Date) -> Double { min(1, max(0, now.timeIntervalSince(started) / Double(seconds))) }
    static func kind(for raw: String) -> HomesteadKind? {
        LivingWorldProject(rawValue: raw)?.worldKind ?? LivingWorldExpansion(rawValue: raw)?.kind
    }
    static func duration(for kind: HomesteadKind) -> Int? {
        switch kind {
        case .nook, .windmill: return 8
        case .pond, .doghouse: return 30
        case .orchard, .grill: return 45
        case .workshop, .greenhouse, .barn: return 60
        case .treehouse: return 90
        default: return nil // Starter pieces, plants, paths and land stay immediate.
        }
    }
    /// New purchases use `duration`. Receipts already frozen at an earlier
    /// catalogue length keep that clock and stay valid.
    static func acceptedDurations(for kind: HomesteadKind) -> Set<Int> {
        var accepted = Set<Int>()
        if let current = duration(for: kind) { accepted.insert(current) }
        switch kind {
        case .pond, .nook, .doghouse: accepted.insert(30)
        case .windmill, .orchard, .grill: accepted.insert(45)
        case .workshop, .greenhouse, .barn: accepted.insert(60)
        case .treehouse: accepted.insert(90)
        default: break
        }
        return accepted
    }
    static func valid(_ details: StoreRewardDetails) -> Bool {
        guard let seconds = details.worldBuildSeconds else { return true }
        guard let raw = details.worldProjectRaw, let kind = kind(for: raw) else { return false }
        return acceptedDurations(for: kind).contains(seconds)
    }
    static func pending(kid: Child, now: Date = Date()) -> [Self] {
        var seen = Set<HomesteadKind>()
        var result: [Self] = []
        for payment in kid.payments.sorted(by: { $0.paidAt == $1.paidAt ? $0.id.uuidString < $1.id.uuidString : $0.paidAt < $1.paidAt }) {
            guard !payment.isDeleted, let details = payment.storeDetails, !details.isCanceled,
                  let raw = details.worldProjectRaw, let kind = kind(for: raw), seen.insert(kind).inserted else { continue }
            guard let seconds = details.worldBuildSeconds, valid(details),
                  (0...253_402_300_799).contains(payment.paidAt.timeIntervalSince1970) else { continue }
            // An older, grandfathered placement must never become a building site.
            let ownership = LivingWorldProject(rawValue: raw).map { LivingWorldProjectEvent(project: $0, action: .built, value: details.worldStyle ?? 0).rawValue }
                ?? LivingWorldExpansion(rawValue: raw)?.ownershipRaw
            if kid.worldPlacements.contains(where: { !$0.isDeleted && $0.id != payment.id && $0.discoveryID == ownership && $0.placedAt < payment.paidAt }) { continue }
            let construction = Self(kind: kind, started: payment.paidAt, seconds: seconds)
            if construction.finish > now { result.append(construction) }
        }
        return result
    }
    static func current(_ kind: HomesteadKind, kid: Child, now: Date = Date()) -> Self? {
        pending(kid: kid, now: now).first { $0.kind == kind }
    }
    enum Failure: LocalizedError {
        case building(Int)
        var errorDescription: String? {
            switch self { case .building(let seconds): return "Building · " + HomesteadFarm.timeLabel(seconds) }
        }
    }
}
