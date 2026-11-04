import Foundation

/// Visual growth only. Approved wins remain the sole source; no new currency,
/// unlock records or Quest steps are written, and the original tree stages stay.
struct LivingGardenGrowth: Equatable {
    struct Milestone: Equatable {
        let wins: Int
        let title: String
        let invitation: String
    }
    static let milestones: [Milestone] = LivingTreeGrowth.milestones.map { milestone in
        let title: String
        switch milestone.stage {
        case .seedling: title = "A little seed"
        case .young: title = "Taking root"
        case .mature: title = "A strong tree"
        }
        return Milestone(wins: milestone.minimumWins, title: title, invitation: "your tree grows")
    } + [
        .init(wins: 21, title: "Wildflowers", invitation: "wildflowers bloom"),
        .init(wins: 34, title: "Cottage lanterns", invitation: "your cottage lights up"),
        .init(wins: 55, title: "Stepping stones", invitation: "your garden path appears")
    ]
    let approvedWins: Int
    init(approvedWins: Int) { self.approvedWins = max(0, approvedWins) }
    var current: Milestone { Self.milestones.last { $0.wins <= approvedWins }! }
    var next: Milestone? { Self.milestones.first { $0.wins > approvedWins } }
    var progress: Double {
        guard let next else { return 1 }
        return Double(approvedWins - current.wins) / Double(next.wins - current.wins)
    }
    var hasWildflowers: Bool { approvedWins >= 21 }
    var hasLanterns: Bool { approvedWins >= 34 }
    var hasSteppingStones: Bool { approvedWins >= 55 }
    var nextStepText: String {
        guard let next else { return "Your tree is fully grown. Your garden is in bloom." }
        let left = next.wins - approvedWins
        return "\(left) more approved \(left == 1 ? "mission" : "missions") until \(next.invitation)"
    }
    var unlockedSummary: String {
        [hasWildflowers ? "Wildflowers" : nil, hasLanterns ? "Cottage lanterns" : nil,
         hasSteppingStones ? "Stepping stones" : nil].compactMap { $0 }.joined(separator: ", ")
    }
}
