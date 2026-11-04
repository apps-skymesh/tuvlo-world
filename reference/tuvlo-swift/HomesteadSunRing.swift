import SwiftUI
import Observation

nonisolated enum HomesteadTimeFormat {
    static func remaining(_ seconds: Int) -> String {
        let value = max(0, seconds)
        return "\(value / 60):" + String(format: "%02d", value % 60)
    }
}
nonisolated struct HomesteadTimeState: Equatable {
    enum Phase: String { case waiting, working, ready }
    let phase: Phase
    var remaining = 0
    var progress = 0.0
    static let waiting = Self(phase: .waiting)
    static let ready = Self(phase: .ready, progress: 1)
    static func clock(end: Date, duration: TimeInterval, now: Date) -> Self {
        let interval = end.timeIntervalSince(now)
        guard interval.isFinite, duration.isFinite, duration > 0 else { return .waiting }
        guard interval > 0 else { return .ready }
        return .init(phase: .working, remaining: Int(ceil(interval)), progress: duration > 0 ? min(1, max(0, 1 - interval / duration)) : 0)
    }
    var accessibilityValue: String {
        switch phase {
        case .waiting: return String(localized: "Waiting for input")
        case .working: return String(localized: "Working") + ", " + HomesteadTimeFormat.remaining(remaining) + " " + String(localized: "remaining")
        case .ready: return String(localized: "Ready")
        }
    }
}

/// Same plates, radius and stroke as the map shader. No timer or frame callback.
struct HomesteadSunRing: View {
    let state: HomesteadTimeState
    var size: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        ZStack {
            Image("WorldTime" + (state.phase == .ready ? "Bloom" : state.phase == .waiting ? "Waiting" : "Ring"))
                .resizable().scaledToFit()
            if state.phase == .working {
                Circle().trim(from: 0, to: state.progress).stroke(Color(livingWorldHex: "#D2A54B"), style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round))
                    .frame(width: size * 0.72, height: size * 0.72).rotationEffect(.degrees(-90))
                    .animation(reducedMotion ? nil : .linear(duration: 1), value: state.progress)
                Text(HomesteadTimeFormat.remaining(state.remaining))
                    .font(.system(size: max(8, size * 0.23), weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Color(livingWorldHex: "#305540"))
            }
        }.frame(width: size, height: size)
            .accessibilityElement(children: .ignore).accessibilityLabel(state.accessibilityValue)
    }
}
struct HomesteadDurationLabel: View {
    let seconds: Int
    var body: some View {
        Label(HomesteadTimeFormat.remaining(seconds), systemImage: "hourglass")
            .font(.caption.monospacedDigit()).accessibilityLabel("Duration, " + HomesteadTimeFormat.remaining(seconds))
    }
}

/// A retry previews its existing frozen request; nil on a legacy request means
/// immediate construction. Never substitute today's duration for that nil.
enum HomesteadTimePresentation {
    static func plannedBuild(_ target: HomesteadBuildTarget, kid: Child, currency: RewardCurrency) -> Int? {
        if let pending = kid.rewardClaims.first(where: { $0.status == .pending && $0.storeDetails?.worldProjectRaw == target.key && $0.storeDetails?.currency == currency }) {
            return pending.storeDetails?.worldBuildSeconds
        }
        switch target {
        case .project(let project): return HomesteadConstruction.duration(for: project.worldKind)
        case .expansion(let expansion): return expansion.kind.flatMap(HomesteadConstruction.duration)
        }
    }
}

/// Driven only by the host's existing half-second foreground poll.
@MainActor @Observable final class HomesteadTimeClock {
    private(set) var now = Date()
    private(set) var activities: [HomesteadTimedActivity] = []
    private(set) var completion: HomesteadTimedActivity?
    func advance(to date: Date, activities next: [HomesteadTimedActivity]) {
        let previous = activities.filter { $0.end > now }.sorted(by: HomesteadTimedActivity.earlier).first
        now = date; activities = next
        if let previous, previous.end <= date, date.timeIntervalSince(previous.end) < 1 { completion = previous }
        else if let current = completion, date.timeIntervalSince(current.end) >= 1 { completion = nil }
    }
    var working: [HomesteadTimedActivity] { activities.filter { $0.end > now }.sorted(by: HomesteadTimedActivity.earlier) }
    var next: HomesteadTimedActivity? { completion ?? working.first }
}
struct HomesteadTimedActivity: Identifiable, Equatable {
    enum Destination: Equatable { case farm(HomesteadFarm.Station), construction(HomesteadKind) }
    let id: String
    let title: String
    let end: Date
    let duration: TimeInterval
    let destination: Destination
    static func earlier(_ a: Self, _ b: Self) -> Bool { a.end == b.end ? a.id < b.id : a.end < b.end }
    @MainActor static func all(farm: HomesteadFarm?, construction: [HomesteadConstruction]) -> [Self] {
        var result = construction.map { Self(id: "build:" + $0.kind.rawValue, title: $0.kind.title, end: $0.finish, duration: Double($0.seconds), destination: .construction($0.kind)) }
        guard let farm else { return result }
        for (index, field) in farm.fields.enumerated() where field.planted {
            if let start = field.wateredAt { result.append(.init(id: "field:\(index)", title: "Wheat field", end: start.addingTimeInterval(HomesteadFarm.fieldSeconds), duration: HomesteadFarm.fieldSeconds, destination: .farm(.field))) }
        }
        for (station, job) in farm.jobs { result.append(.init(id: "job:" + station.rawValue, title: station.title, end: job.finish, duration: job.recipe.seconds, destination: .farm(station))) }
        if let start = farm.orchardWatered { result.append(.init(id: "orchard", title: "Orchard", end: start.addingTimeInterval(HomesteadFarm.orchardSeconds), duration: HomesteadFarm.orchardSeconds, destination: .farm(.orchard))) }
        return result
    }
}
struct HomesteadActivityPill: View {
    let clock: HomesteadTimeClock
    let action: (HomesteadTimedActivity.Destination) -> Void
    @Environment(\.worldMenuSession) private var session
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        Group {
            if let next = clock.next {
                let state = HomesteadTimeState.clock(end: next.end, duration: next.duration, now: clock.now)
                Button { session?.control("hud.activity"); WorldMenuFeedback.touch(.wood); action(next.destination) } label: {
                    HStack(spacing: 1) {
                        VStack(spacing: 2) {
                            WorldControlIcon(symbol: icon(next.destination)).frame(width: 12, height: 14)
                            let others = clock.working.filter { $0.id != next.id }.count
                            Text(others == 0 ? "" : others > 9 ? "9+" : "+\(others)").font(.system(size: 8, weight: .bold)).frame(width: 14, height: 12)
                        }
                        HomesteadSunRing(state: state, size: 32)
                    }.frame(width: 48, height: 48)
                        .background(Color(livingWorldHex: state.phase == .ready ? "#E6C56E" : "#F3EEDC"), in: RoundedRectangle(cornerRadius: state.phase == .ready ? 24 : 17))
                        .animation(reducedMotion ? nil : .smooth(duration: 0.35), value: state.phase)
                }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(next.title)
                    .accessibilityValue(state.accessibilityValue + ", \(clock.working.filter { $0.id != next.id }.count) other jobs")
                    .accessibilityIdentifier("homestead.activity")
            } else { Color.clear.accessibilityHidden(true) }
        }.frame(width: 48, height: 52).accessibilityElement(children: .contain).accessibilityIdentifier("homestead.activity.slot")
    }
    private func icon(_ destination: HomesteadTimedActivity.Destination) -> String {
        switch destination { case .construction: return "hammer"; case .farm(let station): return station == .field ? "leaf.fill" : station.kind.controlIcon }
    }
}

/// Native rotor actions describe the otherwise engine-drawn map badges.
struct HomesteadTimeMapActions: ViewModifier {
    let clock: HomesteadTimeClock
    let statuses: [HomesteadProductionStatus]
    let action: (HomesteadTimedActivity.Destination) -> Void
    func body(content: Content) -> some View {
        content.accessibilityActions {
            ForEach(statuses, id: \.station) { status in
                if let station = HomesteadFarm.Station(rawValue: status.station) {
                    let running = clock.activities.filter { $0.destination == .farm(station) }.sorted(by: { HomesteadTimedActivity.earlier($0, $1) }).first
                    let state: HomesteadTimeState = status.state == 0 ? .waiting : status.state == 2 ? .ready
                        : running.map { .clock(end: $0.end, duration: $0.duration, now: clock.now) }
                            ?? .init(phase: .working, remaining: status.remaining, progress: status.progress)
                    Button(station.title + ", " + state.accessibilityValue) { action(.farm(station)) }
                }
            }
            ForEach(clock.activities.filter { if case .construction = $0.destination { return true }; return false }) { activity in
                Button(activity.title + ", " + HomesteadTimeState.clock(end: activity.end, duration: activity.duration, now: clock.now).accessibilityValue) { action(activity.destination) }
            }
        }
    }
}
