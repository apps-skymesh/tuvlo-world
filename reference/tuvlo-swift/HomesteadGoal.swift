import Foundation

/// The single next thing to build and the first step toward it. Derived from
/// saved ownership, approved wins, balances and materials; it never writes.
struct HomesteadGoal: Equatable {
    enum Step: Equatable {
        case missions(Int)
        case collect(HomesteadMaterial, HomesteadProducer)
        case grow(HomesteadMaterial)
        case earn(Double)
        case landFirst
        case build
    }
    let target: HomesteadBuildTarget
    let winsLeft: Int
    let missing: HomesteadMaterialAmounts
    let currencyLeft: Double
    let currency: RewardCurrency
    let step: Step

    var isReady: Bool { step == .build }

    @MainActor
    static func next(kid: Child, ledger: HomesteadMaterialLedger, projects: LivingWorldProjects, preferredTarget: HomesteadBuildTarget? = nil) -> HomesteadGoal? {
        func owned(_ target: HomesteadBuildTarget) -> Bool {
            switch target {
            case .project(let p): return projects.isBuilt(p)
            case .expansion(let e): return e.isOwned(by: kid)
            }
        }
        let open = HomesteadBuildTarget.ordered.filter { !owned($0) }
        // A chosen pond/nook/treehouse leads; otherwise the earliest gate.
        let focus = projects.focus.map(HomesteadBuildTarget.project).flatMap { open.contains($0) ? $0 : nil }
        guard let target = focus ?? preferredTarget.flatMap({ open.contains($0) ? $0 : nil }) ?? open.first else { return nil }
        return forTarget(target, kid: kid, ledger: ledger, projects: projects)
    }

    @MainActor
    static func forTarget(_ target: HomesteadBuildTarget, kid: Child, ledger: HomesteadMaterialLedger, projects: LivingWorldProjects) -> Self {
        let winsLeft = max(0, target.requiredWins - projects.approvedWins)
        let missing = ledger.shortfall(for: target)
        let currencyLeft = max(0, target.price - projects.balance)
        let step: Step
        if case .expansion(let e) = target, !e.hasRequiredLand(for: kid) {
            step = .landFirst
        } else if winsLeft > 0 {
            step = .missions(winsLeft)
        } else if let material = missing.parts.first?.material {
            if let source = ledger.source(for: material), ledger.ready(source)[material] > 0 {
                step = .collect(material, source)
            } else { step = .grow(material) }
        } else if currencyLeft > 0 {
            step = .earn(currencyLeft)
        } else { step = .build }
        return .init(target: target, winsLeft: winsLeft, missing: missing, currencyLeft: currencyLeft,
                     currency: projects.currency, step: step)
    }

    /// The name of the one current blocker. `ready` is used once every gate is met.
    func actionTitle(ready: String) -> String {
        switch step {
        case .missions(let n):
            return n == 1 ? String(localized: "1 more mission") : String(localized: "\(n) more missions")
        case .collect(let material, _):
            return String(localized: "Collect \(material.title.lowercased())")
        case .grow(.food):
            let need = missing.food
            return need == 1 ? String(localized: "Pack 1 meal") : String(localized: "Pack \(need) meals")
        case .grow(let material):
            return String(localized: "Gather \(material.title.lowercased())")
        case .earn:
            return String(localized: "Earn \(currency.amountLabel(currencyLeft)) more")
        case .landFirst:
            return String(localized: "Open west meadow")
        case .build:
            return ready
        }
    }

    /// One short line: what to do now.
    var instruction: String {
        switch step {
        case .missions(let n): return n == 1 ? String(localized: "Finish 1 more mission.") : String(localized: "Finish \(n) more missions.")
        case .collect(let m, let p): return String(localized: "Tap the \(p.title.lowercased()) to collect \(m.title.lowercased()).")
        case .grow(.food): return String(localized: "Bake bread and pack provisions.")
        case .grow(let m): return String(localized: "Approved missions make more \(m.title.lowercased()).")
        case .earn(let amount): return String(localized: "Earn \(currency.amountLabel(amount)) more.")
        case .landFirst: return String(localized: "Get the west meadow first.")
        case .build: return String(localized: "Everything is ready. Build it!")
        }
    }
}
