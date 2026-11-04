import SwiftUI

/// Guidance reads the real mission configuration; it never promises Stars for a
/// Coins-only mission or treats a waiting claim as spendable earnings.
struct LivingWorldMissionHandoff {
    let message: String
    let examples: [TaskDefinition]
    init(kid: Child, tasks: [TaskDefinition], currency: RewardCurrency, now: Date = Date()) {
        let assigned = tasks.filter { $0.isActive && !$0.isGraduated && $0.taskKind != .badAction && $0.appliesTo(child: kid) }
        let paying = assigned.filter { currency == .stars ? $0.rewardParts.stars > 0 : $0.rewardParts.coins > 0 }
        examples = Array(paying.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.prefix(3))
        let day = MissionDayIndex(allTasks: tasks, kid: kid, today: now, optimisticPending: [])
        if assigned.isEmpty {
            message = "Ask your parent to add a mission. Your World will be here."
        } else if paying.isEmpty {
            message = "Your missions don’t earn \(currency == .stars ? "Stars" : "Coins") yet. Ask your parent about rewards for your World."
        } else if let next = day.nextScheduledDate {
            message = "No missions today. Your next missions are \(next.formatted(date: .abbreviated, time: .omitted)). Your World will be here."
        } else {
            message = "Finish missions your parent sets. When they approve them, you earn the rewards shown."
        }
    }
}

/// One scene-side panel. Leaving never advances a build, and all successful
/// actions are saved by the owner before this view receives its next state.
struct LivingWorldStarterGuide: View {
    let starter: LivingWorldStarter
    let projects: LivingWorldProjects
    let handoff: LivingWorldMissionHandoff
    let allowsChanges: Bool
    var isPlayground = false
    let advance: (LivingWorldStarter.Event) -> Void
    let finish: (Bool) -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    private var step: Int { starter.count }

    private var title: String {
        if step < 3 { return ["A world of your own", "Plant a little possibility", "Make a way home"][step] }
        return "Missions grow your World"
    }
    var body: some View {
        Group {
            if step < 3 {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(step + 1)/3 · Free").font(.caption.weight(.bold))
                        chapterTitle
                        if step == 1 { Text("Approved missions grow your tree.").font(.caption) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    primary(["Place cottage", "Plant tree", "Place path"][step], id: "world.chapter.build") {
                        advance([.cottage, .tree, .path][step])
                    }.frame(maxWidth: 240)
                }
            } else {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your first loaf").font(.headline)
                        Text("Garden → windmill → bread").font(.caption)
                        requirements
                    }.frame(width: 170, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        chapterTitle
                        Text(isPlayground ? "Test missions follow this introduction." : handoff.message).font(.caption).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("world.chapter.explanation")
                        HStack(spacing: 12) {
                            if isPlayground {
                                primary("Start garden", id: "world.chapter.explore") { finish(false) }
                            } else {
                                primary("Missions", id: "world.chapter.missions") { finish(true) }
                                Button("Explore") { finish(false) }.frame(minWidth: 48, minHeight: 48)
                                    .disabled(!allowsChanges).accessibilityIdentifier("world.chapter.explore")
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !allowsChanges {
                Text("Ask your parent to check access.").font(.caption).accessibilityIdentifier("world.chapter.paused")
            }
        }.id(step).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain).accessibilityIdentifier("world.chapter.guide")
    }
    private var chapterTitle: some View {
        Text(title).font(.headline).accessibilityAddTraits(.isHeader).accessibilityIdentifier("world.chapter.title")
    }

    private var requirements: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(min(projects.approvedWins, LivingWorldExpansion.windmill.requiredWins))/\(LivingWorldExpansion.windmill.requiredWins)", systemImage: "checklist").font(.caption)
            HStack { Text("Windmill"); RewardCurrencyAmount(amount: LivingWorldExpansion.windmill.price, currency: projects.currency) }
        }.font(.caption).accessibilityIdentifier("world.chapter.requirements")
    }
    private func primary(_ label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.headline).frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 12).padding(.vertical, 4)
                .foregroundStyle(.white).background(Color(livingWorldHex: "#176E59"), in: Capsule())
        }.buttonStyle(.plain).disabled(!allowsChanges).accessibilityIdentifier(id)
    }
}
