import SwiftUI

/// Tree stages are presentation only: no currency, ledger writes or saved choices.
enum LivingTreeStage: String, CaseIterable, Identifiable {
    case seedling, young, mature
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scale: CGFloat {
        switch self { case .seedling: return 0.30; case .young: return 0.65; case .mature: return 1 }
    }
}

/// A read-only projection of approved wins, never a new balance or saved counter.
/// Prototype milestones align with the first bloom (3) and canopy tree (13).
struct LivingTreeGrowth: Equatable {
    let approvedWins: Int
    init(approvedWins: Int) { self.approvedWins = max(0, approvedWins) }
    static let milestones: [(minimumWins: Int, stage: LivingTreeStage)] = [
        (0, .seedling), (3, .young), (13, .mature)
    ]
    var stage: LivingTreeStage {
        Self.milestones.last { approvedWins >= $0.minimumWins }?.stage ?? .seedling
    }
}

/// Local presentation memory only. First visits establish a baseline; the family
/// ledger remains the sole progression source, and this marker is never synced.
struct LivingTreeVisitMemory {
    var defaults: UserDefaults = .standard
    private func key(_ childID: UUID) -> String { "livingWorld.preview.seenTree." + childID.uuidString }
    func stage(for childID: UUID) -> LivingTreeStage? {
        defaults.string(forKey: key(childID)).flatMap(LivingTreeStage.init(rawValue:))
    }
    func acknowledge(_ stage: LivingTreeStage, for childID: UUID) {
        let old = self.stage(for: childID)
        guard old == nil || LivingTreeReveal.rank(stage) >= LivingTreeReveal.rank(old!) else { return }
        defaults.set(stage.rawValue, forKey: key(childID))
    }
}

/// Device-local memory of how many approved wins have already been watered.
/// The first visit records a baseline and stays quiet. Later approvals water
/// once each. This never changes the ledger or earned growth.
struct HomesteadTreeWaterMemory {
    var defaults: UserDefaults = .standard
    static let keyPrefix = "livingWorld.preview.wateredWins."
    func claim(wins: Int, childID: UUID) -> Int {
        let key = Self.keyPrefix + childID.uuidString
        let earned = max(0, wins)
        guard let stored = defaults.object(forKey: key) as? Int else {
            defaults.set(earned, forKey: key)
            return 0
        }
        if earned <= stored {
            if earned < stored { defaults.set(earned, forKey: key) }
            return 0
        }
        defaults.set(earned, forKey: key)
        return earned - stored
    }
}

/// Device-local memory of World visits for the mission tree. The first visit
/// records today and stays green. A later visit that skipped a family day
/// yellows a few leaves. Watering clears them. Wins and goods do not change.
struct HomesteadTreeThirstMemory {
    var defaults: UserDefaults = .standard
    static let visitPrefix = "livingWorld.preview.treeVisitDay."
    static let yellowPrefix = "livingWorld.preview.treeYellow."
    func noteVisit(day: String, childID: UUID) -> Bool {
        let visitKey = Self.visitPrefix + childID.uuidString
        let yellowKey = Self.yellowPrefix + childID.uuidString
        guard let stored = defaults.string(forKey: visitKey) else {
            defaults.set(day, forKey: visitKey)
            return false
        }
        if stored != day,
           let previous = FamilyDay.noon(forKey: stored),
           let today = FamilyDay.noon(forKey: day),
           let gap = Calendar(identifier: .gregorian).dateComponents([.day], from: previous, to: today).day,
           gap >= 2 {
            defaults.set(true, forKey: yellowKey)
        }
        if stored != day { defaults.set(day, forKey: visitKey) }
        return defaults.bool(forKey: yellowKey)
    }
    func clear(childID: UUID) {
        defaults.set(false, forKey: Self.yellowPrefix + childID.uuidString)
    }
}

/// Device-local memory of the last sunny day the child was shown. The first
/// visit records a baseline and stays quiet. Later approved missions play once.
struct HomesteadSunnyDayMemory {
    var defaults: UserDefaults = .standard
    static let keyPrefix = "livingWorld.preview.seenSunnyDay."
    func claimSunrise(wins: Int, childID: UUID) -> Bool {
        let key = Self.keyPrefix + childID.uuidString
        guard let stored = defaults.object(forKey: key) as? Int else {
            defaults.set(wins, forKey: key)
            return false
        }
        guard wins > stored else {
            if wins < stored { defaults.set(wins, forKey: key) }
            return false
        }
        defaults.set(wins, forKey: key)
        return true
    }
}

struct LivingTreeReveal: Equatable {
    let from: LivingTreeStage
    let to: LivingTreeStage
    static let duration = 4.5
    static func rank(_ stage: LivingTreeStage) -> Int {
        LivingTreeGrowth.milestones.firstIndex { $0.stage == stage } ?? 0
    }
    static func pending(seen: LivingTreeStage?, earned: LivingTreeStage) -> Self? {
        guard let seen, rank(earned) > rank(seen) else { return nil }
        return Self(from: seen, to: earned)
    }
    func progress(at time: Double, still: Bool) -> Double {
        if still { return 1 }
        let t = min(1, max(0, (time - 0.5) / 1.8))
        return t * t * (3 - 2 * t)
    }
    func frame(at time: Double, still: Bool) -> LivingWorldFrame {
        var frame = LivingWorldFrame(feet: LivingWorldMotion.doorstep)
        guard !still else { return frame }
        frame.facing = time < 4.2 ? .e : .s
        frame.reaction = time >= 1.8 && time < 4 ? 100 : time < 4 ? 50 : 0
        let attention = CGFloat(min(1, max(0, time / 0.5)) * min(1, max(0, (Self.duration - time) / 0.5)))
        frame.pose.gaze = 2 * attention; frame.pose.headTilt = -4 * attention
        if frame.reaction == 100 {
            let joy = CGFloat(min(1, (time - 1.8) / 0.35) * min(1, (4 - time) / 0.35))
            frame.pose.smile = 0.65 * joy; frame.pose.wave = 0.55 * joy
            frame.pose.waveSwing = CGFloat(sin(time * 3)) * 0.15
        }
        frame.activity = "Watching the tree grow"
        return frame
    }
}

struct LivingWorldFrame {
    var feet: CGPoint
    var facing: WalkDir = .s
    var walking = false
    /// Stop the animation blend while the final ground translation decelerates.
    var walkingIntent = false
    var reaction: Float = 0
    var gaitTime = 0.0
    var gaitWeight: CGFloat = 0
    var pose = WelcomeCharacterPose.rest
    var activity = "Enjoying the clearing"
}

/// Movement and acting share one clock. Gait phase follows distance travelled,
/// rather than an unrelated wall clock, so pausing cannot change the foot pose.
enum LivingWorldMotion {
    static let doorstep = CGPoint(x: 0.215, y: 0.70)
    static let tree = CGPoint(x: 0.64, y: 0.70)
    /// Rive's sideward contact phase covers 14 artboard units in half a second.
    static func cruiseSpeed(characterSize: CGFloat) -> Double { 28 * Double(characterSize) / 200 }
    struct Timing {
        let travel: Double
        var arrival: Double { 3 + travel }
        var returning: Double { arrival + 8 }
        var home: Double { returning + travel }
        var duration: Double { home + 3 }
    }
    static func timing(characterSize: CGFloat = 166) -> Timing {
        Timing(travel: Double(tree.x - doorstep.x) * 600 / cruiseSpeed(characterSize: max(1, characterSize)) + 0.34)
    }
    static var cycleDuration: Double { timing().duration }

    static func frame(at elapsed: Double, still: Bool = false, characterSize: CGFloat = 166) -> LivingWorldFrame {
        if still { return LivingWorldFrame(feet: tree) }
        let elapsed = max(0, elapsed)
        let timing = timing(characterSize: characterSize)
        let t = elapsed.truncatingRemainder(dividingBy: timing.duration)
        var frame = LivingWorldFrame(feet: doorstep)
        frame.pose.breath = CGFloat(sin(elapsed * 1.7)) * 0.65
        frame.pose.armDrift = CGFloat(sin(elapsed * 1.1)) * 0.45
        frame.pose.headTilt = CGFloat(sin(elapsed * 0.55)) * 1.2
        let blink = pulse(t, start: 1.6, duration: 0.20) + pulse(t, start: timing.arrival + 1.2, duration: 0.22)
            + pulse(t, start: timing.returning + 2, duration: 0.20) + pulse(t, start: timing.home + 1, duration: 0.22)
        frame.pose.leftBlink = blink; frame.pose.rightBlink = blink
        if t >= 1.5 && t < timing.returning - 0.7 { frame.facing = .e }
        if t >= timing.returning - 0.7 && t < timing.home + 0.8 { frame.facing = .w }
        if t >= 3 && t < timing.arrival {
            travel(&frame, from: doorstep, to: tree, elapsed: t - 3, characterSize: characterSize)
            frame.activity = "Walking to the tree"
        } else if t >= timing.arrival && t < timing.returning {
            frame.feet = tree
            frame.activity = "Watching a butterfly"
            let local = t - timing.arrival
            let look = envelope(local, start: 0.4, end: 6.8)
            frame.pose.headTilt += look * -6; frame.pose.gaze = look * 2.8; frame.pose.gazeY = look * -2
            frame.pose.smile = look * 0.65
            frame.pose.wave = pulse(local, start: 4.2, duration: 2.6) * 0.55
            frame.pose.waveSwing = CGFloat(sin(t * 3)) * 0.15
            frame.pose.joy = pulse(local, start: 5, duration: 1.5) * 0.75
            frame.reaction = local >= 4.2 && local < 6.8 ? 100 : local >= 0.4 && local < 6.8 ? 50 : 0
        } else if t >= timing.returning && t < timing.home {
            travel(&frame, from: tree, to: doorstep, elapsed: t - timing.returning, characterSize: characterSize)
            frame.activity = "Heading home"
        }
        return frame
    }

    private static func travel(_ frame: inout LivingWorldFrame, from: CGPoint, to: CGPoint,
                               elapsed: Double, characterSize: CGFloat) {
        let movement = LivingWorldTravelLeg(from: from, to: to, characterSize: characterSize)
            .frame(at: elapsed, activity: "")
        frame.feet = movement.feet; frame.facing = movement.facing
        frame.walking = movement.walking; frame.walkingIntent = movement.walkingIntent
        frame.gaitWeight = movement.gaitWeight; frame.gaitTime = movement.gaitTime
    }

    private static func pulse(_ t: Double, start: Double, duration: Double) -> CGFloat {
        guard t >= start, t <= start + duration else { return 0 }
        return CGFloat(pow(sin((t - start) / duration * .pi), 2))
    }

    private static func envelope(_ t: Double, start: Double, end: Double) -> CGFloat {
        func smooth(_ x: Double) -> Double { let v = min(1, max(0, x)); return v * v * (3 - 2 * v) }
        return CGFloat(smooth((t - start) / 0.8) * smooth((end - t) / 0.8))
    }
}

/// Constant-speed middle with matched start/stop ramps. Very short distances
/// use a lower peak speed so their acceleration and deceleration cannot overlap.
struct LivingWorldTravelLeg {
    let from: CGPoint
    let to: CGPoint
    let characterSize: CGFloat
    private var distance: Double { hypot(Double(to.x - from.x) * 600, Double(to.y - from.y) * 720) }
    var duration: Double {
        distance < 0.00001 ? 0 : max(0.68, distance / LivingWorldMotion.cruiseSpeed(characterSize: characterSize) + 0.34)
    }
    private var speed: Double { duration > 0 ? distance / (duration - 0.34) : 0 }
    func frame(at time: Double, activity: String) -> LivingWorldFrame {
        guard duration > 0, time < duration else { return LivingWorldFrame(feet: to) }
        let t = max(0, time)
        let travelled: Double
        let weight: Double
        if t < 0.32 { travelled = speed * t * t / 0.64; weight = t / 0.32 }
        else if t > duration - 0.36 {
            let remaining = duration - t
            travelled = distance - speed * remaining * remaining / 0.72; weight = remaining / 0.36
        } else { travelled = speed * (t - 0.16); weight = 1 }
        let fraction = min(1, max(0, travelled / distance))
        var result = LivingWorldFrame(feet: CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction))
        result.facing = to.x > from.x ? .e : .w
        result.walking = true; result.walkingIntent = t < duration - 0.36
        result.gaitTime = travelled / LivingWorldMotion.cruiseSpeed(characterSize: characterSize)
        result.gaitWeight = CGFloat(weight); result.activity = activity
        return result
    }
}

extension LivingTreeGrowth {
    /// The next milestone, if the tree has one left.
    var nextMilestone: (minimumWins: Int, stage: LivingTreeStage)? {
        Self.milestones.first { $0.minimumWins > approvedWins }
    }

    var nextStepText: String {
        guard let next = nextMilestone else { return "Your tree is fully grown. Keep up the great work!" }
        let left = next.minimumWins - approvedWins
        return left == 1
            ? "1 more approved mission until your tree grows"
            : "\(left) more approved missions until your tree grows"
    }
}
