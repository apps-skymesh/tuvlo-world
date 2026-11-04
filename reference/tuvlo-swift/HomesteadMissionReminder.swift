import SwiftUI
import SwiftData

/// In-map requests use the same saved claim path as Tasks; only parents award rewards.
struct HomesteadMissionReminder: View {
    let kid: Child
    let currency: RewardCurrency
    var project: LivingWorldProject? = nil
    var showsBalance = true
    /// Only the disposable playground supplies an ownership-checked override.
    var allowsRequests: (() -> Bool)? = nil
    /// Beyond this the list scrolls; below it the list hugs its rows.
    var maxListHeight: CGFloat = .infinity
    @Environment(\.modelContext) private var context
    @ObservedObject private var parentAccess = KidParentAccess.shared
    @ObservedObject private var subscriptionStore = PremiumStore.shared
    @State private var submitting: Set<UUID> = []
    @State private var saveError: String?
    /// The card hugs a short list and scrolls a long one.
    @State private var listHeight: CGFloat = 0
    private var canRequest: Bool { allowsRequests?() ?? HomesteadActions.permitsChanges() }
    @Query(sort: \TaskDefinition.name) private var tasks: [TaskDefinition]
    private struct Entry: Identifiable {
        let task: TaskDefinition
        let date: Date?
        let waiting: Bool
        var id: UUID { task.id }
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { time in
            let day = MissionDayIndex(allTasks: tasks, kid: kid, today: time.date, optimisticPending: [], dailyMissionLimit: allowsRequests == nil ? FreePlanMissionAccess.dailyLimit : nil)
            let assigned = tasks.filter { $0.isActive && !$0.isGraduated && $0.taskKind != .badAction && $0.appliesTo(child: kid) }
            let paying = assigned.filter { currency == .stars ? $0.rewardParts.stars > 0 : $0.rewardParts.coins > 0 }
            let entries = entries(for: assigned, day: day, now: time.date)
            let list = VStack(alignment: .leading, spacing: 8) {
                if showsBalance || !canRequest || saveError != nil || project != nil || assigned.isEmpty || paying.isEmpty || entries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                if showsBalance { HomesteadWorldBalance(kid: kid) }
                if !canRequest { Text(parentAccess.message.isEmpty ? "Requests paused. Ask your parent to check access." : parentAccess.message).font(.caption) }
                if let saveError { Text(saveError).font(.subheadline).accessibilityIdentifier("homestead.mission.error") }
                if let project {
                    let progress = LivingWorldProjects(kid: kid, approvedWins: EconomyLedger.forChild(kid).approvedWins)
                    if progress.balance < project.price {
                        Text("Need " + currency.amountLabel(project.price - progress.balance)).font(.subheadline.weight(.semibold))
                    }
                    if progress.approvedWins < project.requiredWins {
                        Text("\(min(progress.approvedWins, project.requiredWins)) / \(project.requiredWins) approved missions").font(.caption)
                    }
                }
                if assigned.isEmpty {
                    Text("Ask your parent to add a mission.").font(.subheadline)
                } else if paying.isEmpty {
                    Text(currency == .stars ? "Ask a parent for missions that earn Stars." : "Ask a parent for missions that earn Coins.").font(.subheadline)
                }
                if !assigned.isEmpty && entries.isEmpty {
                    Text("All done today.").font(.subheadline)
                }
                }.frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(entries) { entry in
                    HStack(alignment: .center, spacing: 12) {
                        MissionGlyph(visual: .forTask(entry.task), size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.task.name).font(.system(.subheadline, design: .rounded).weight(.bold)).lineLimit(1)
                            if entry.waiting {
                                Text("Awaiting approval").font(.caption.weight(.semibold)).foregroundStyle(WorldCardFinish.walnut.opacity(0.75))
                            } else {
                                WorldRewardPills(parts: entry.task.rewardParts)
                                if let date = entry.date { Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day()).font(.caption.weight(.semibold)).foregroundStyle(WorldCardFinish.walnut.opacity(0.75)) }
                                else if let prior = day.needsFixByTask[entry.id] {
                                    Text(prior.parentNote.isEmpty ? "Try again" : prior.parentNote).font(.caption)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        if entry.waiting {
                            WorldControlIcon(symbol: "hourglass").frame(width: 24, height: 24)
                        } else if entry.date == nil, day.locked.contains(where: { $0.id == entry.id }) {
                            AppIconView(name: AppIcon.lockSecure, size: 24)
                                .accessibilityLabel("Locked on the current plan")
                        } else if entry.date == nil {
                            Button {
                                submit(entry.task, prior: day.needsFixByTask[entry.id], now: Date())
                            } label: {
                                Text(day.needsFixByTask[entry.id] == nil ? "Claim" : "Retry")
                                    .font(.system(.subheadline, design: .rounded).weight(.heavy)).lineLimit(1)
                                    .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 0, y: 1)
                                    .frame(minWidth: 84, minHeight: 44).padding(.horizontal, 8)
                                    .background(Capsule().fill(LinearGradient(colors: [Color(livingWorldHex: "#8FCB63"), Color(livingWorldHex: "#5FA63F")], startPoint: .top, endPoint: .bottom)))
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.55), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                                    .contentShape(Capsule())
                            }.buttonStyle(WorldCardPress())
                                .accessibilityLabel((day.needsFixByTask[entry.id] == nil ? "Claim: " : "Retry: ") + entry.task.name)
                                .disabled(!canRequest || submitting.contains(entry.id))
                                .accessibilityIdentifier("homestead.mission.done.\(entry.id.uuidString)")
                        }
                    }.padding(12).frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                        .background(WorldTileSurface(cornerRadius: 18))
                        .opacity(entry.date == nil ? 1 : 0.72)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("homestead.mission.\(entry.id.uuidString)")
                }
                }.padding(.bottom, 4)
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    list.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }.scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    .frame(height: listHeight > 0 ? min(listHeight, maxListHeight) : nil)
                    .accessibilityIdentifier("homestead.missions.pages")
            }.accessibilityElement(children: .contain)
                .accessibilityIdentifier("homestead.missions.list")
        }
    }
    private func submit(_ task: TaskDefinition, prior: MissionClaim?, now: Date) {
        guard canRequest, !submitting.contains(task.id) else { return }
        submitting.insert(task.id)
        defer { submitting.remove(task.id) }
        do {
            if let prior {
                _ = try KidMissionRequest.retry(prior, for: kid, in: context, now: now, allowsRequests: allowsRequests?(), dailyMissionLimit: allowsRequests == nil ? nil : Int.max)
            } else {
                _ = try KidMissionRequest.create(task: task, kid: kid, day: now, in: context, allowsRequests: allowsRequests?(), dailyMissionLimit: allowsRequests == nil ? nil : Int.max)
            }
            saveError = nil
            Haptics.notification(.success)
            SoundEffects.playClaimSent()
        } catch {
            saveError = error.localizedDescription
            Haptics.notification(.error)
        }
    }
    private func entries(for tasks: [TaskDefinition], day: MissionDayIndex, now: Date) -> [Entry] {
        tasks.compactMap { task -> Entry? in
            if day.pending.contains(task.id) { return Entry(task: task, date: nil, waiting: true) }
            if task.isDue(on: now) && !day.completed.contains(task.id) { return Entry(task: task, date: nil, waiting: false) }
            let next = (1...7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: now) }.first { task.isDue(on: $0) }
            return next.map { Entry(task: task, date: $0, waiting: false) }
        }.sorted {
            let a = $0.waiting ? 1 : ($0.date == nil ? 0 : 2)
            let b = $1.waiting ? 1 : ($1.date == nil ? 0 : 2)
            if a != b { return a < b }
            let paysA = currency == .stars ? $0.task.rewardParts.stars > 0 : $0.task.rewardParts.coins > 0
            let paysB = currency == .stars ? $1.task.rewardParts.stars > 0 : $1.task.rewardParts.coins > 0
            if paysA != paysB { return paysA }
            if $0.date != $1.date { return ($0.date ?? now) < ($1.date ?? now) }
            return $0.task.name.localizedStandardCompare($1.task.name) == .orderedAscending
        }
    }
}

/// Mission rewards on World tiles: dark numbers on a gold-cream pill, so
/// amounts read clearly against the parchment.
private struct WorldRewardPills: View {
    let parts: RewardParts
    var body: some View {
        HStack(spacing: 6) {
            if parts.isEmpty { Text(parts.label).font(.caption.weight(.semibold)) }
            if parts.coins != 0 { pill(RewardPartArt.coins, RewardAmount.text(parts.coins)) }
            if parts.stars > 0 { pill(RewardPartArt.stars, RewardAmount.text(parts.stars)) }
            if parts.screenMinutes > 0 { pill(RewardPartArt.screenTime, RewardAmount.text(parts.screenMinutes) + "m") }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(parts.label)
    }
    private func pill(_ art: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            AppIconView(name: art, size: 20)
            Text(text).font(WorldCardFinish.number(15)).monospacedDigit().foregroundStyle(WorldCardFinish.ink)
        }
        .padding(.leading, 4).padding(.trailing, 9).frame(minHeight: 26)
        .background(Capsule().fill(LinearGradient(colors: [Color(livingWorldHex: "#FFF1C4"), Color(livingWorldHex: "#F7D97E")], startPoint: .top, endPoint: .bottom)))
        .overlay(Capsule().strokeBorder(WorldCardFinish.rim.opacity(0.55), lineWidth: 1))
    }
}
