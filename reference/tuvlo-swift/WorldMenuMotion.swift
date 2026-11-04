import SwiftUI
import Observation

struct WorldMenuAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

extension View {
    /// Merges with anchors inside this view: a wallet's anchor must not hide its crate's.
    func worldMenuAnchor(_ key: String) -> some View {
        transformAnchorPreference(key: WorldMenuAnchors.self, value: .bounds) { $0[key] = $1 }
    }
    func worldMenuArrival() -> some View { modifier(WorldMenuArrival()) }
}

struct WorldMenuRoute: Equatable {
    let name: String
    var window = false
}

struct WorldMenuArrivalTicket {
    let id = UUID()
    let origin: CGPoint
}

enum WorldSavedPicture: Equatable {
    case place(HomesteadKind), good(HomesteadFarm.Good), character
}

struct WorldSavedFlight: Identifiable {
    let id = UUID()
    let picture: WorldSavedPicture
    let start: CGPoint
    let end: CGPoint
    /// How many copies fly; collecting two wheat sends two sheaves.
    var count = 1
}

/// Coordinates are transient screen-space presentation, never World placement data.
@MainActor @Observable final class WorldMenuSession {
    var arrival: WorldMenuArrivalTicket?
    var flight: WorldSavedFlight?
    private(set) var entranceCount = 0
    private(set) var savedCount = 0
    /// Bumps when a flight reaches its target, so the target can bounce.
    private(set) var landedCount = 0
    private(set) var landedTarget = ""
    private(set) var landedAmount = 0
    @ObservationIgnored private var flightTarget = ""
    func landed() { landedTarget = flightTarget; landedAmount = flight?.count ?? 1; landedCount += 1 }
    @ObservationIgnored var frames: [String: CGRect] = [:]
    @ObservationIgnored var canvas = CGRect.zero
    @ObservationIgnored private var route: WorldMenuRoute?
    @ObservationIgnored private var source = "dock.build"
    @ObservationIgnored private var mapOrigin: CGPoint?
    @ObservationIgnored private var consumed: Set<UUID> = []
    @ObservationIgnored private var pending: (identity: String, picture: WorldSavedPicture, start: CGPoint)?

    @ObservationIgnored private var pendingControl: (picture: WorldSavedPicture, start: CGPoint, key: String)?
    @ObservationIgnored private var pendingCount = 1
    func updateFrames(_ next: [String: CGRect]) {
        frames = next
        if let pendingControl, let end = frames[pendingControl.key]?.center {
            self.pendingControl = nil
            flightTarget = pendingControl.key
            flight = .init(picture: pendingControl.picture, start: pendingControl.start, end: end, count: pendingCount)
        }
    }
    func control(_ key: String) { source = key; mapOrigin = frames[key]?.center }
    func mapControl(_ point: CGPoint) { mapOrigin = point; source = "map" }
    func present(_ next: WorldMenuRoute?) {
        defer { route = next }
        guard let next else { arrival = nil; return }
        // Tabs and journal subpages keep the mounted shell; only a new surface rises.
        if route == nil || ((next.name.hasPrefix("place.") || next.name == "builder") && route?.name != next.name) || (next.window != route?.window && !source.hasPrefix("dock.")) {
            arrival = .init(origin: mapOrigin ?? frames[source]?.center ?? CGPoint(x: canvas.midX, y: canvas.maxY - 40))
        }
    }
    func consume(_ ticket: WorldMenuArrivalTicket) -> Bool {
        guard consumed.insert(ticket.id).inserted else { return false }
        entranceCount += 1
        if consumed.count > 64 { consumed = [ticket.id] }
        return true
    }
    func sourcePoint(_ key: String? = nil) -> CGPoint {
        frames[key ?? source]?.center ?? mapOrigin ?? CGPoint(x: canvas.midX, y: canvas.midY)
    }
    /// Called only after the canonical save returned successfully.
    @discardableResult func saved(_ identity: String, picture: WorldSavedPicture, from key: String? = nil, count: Int = 1,
                                  destination: String, request: (String, String) -> Void) -> Bool {
        guard WorldMenuFeedback.saved(.wood, identity: identity) else { return false }
        savedCount += 1
        pending = nil; pendingControl = nil; pendingCount = count; flightTarget = destination
        let start = sourcePoint(key)
        if destination.hasPrefix("map:") {
            pending = (identity, picture, start)
            request(String(destination.dropFirst(4)), identity)
        } else if let end = frames[destination]?.center {
            flight = .init(picture: picture, start: start, end: end, count: count)
        } else { pendingControl = (picture, start, destination) }
        return true
    }
    func receiveAnchor(_ payload: [String: Any]) {
        guard let pending, payload["event"] as? String == pending.identity,
              let x = payload["x"] as? Double, let y = payload["y"] as? Double,
              x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else { return }
        self.pending = nil
        flight = .init(picture: pending.picture, start: pending.start,
                       end: CGPoint(x: canvas.minX + x * canvas.width, y: canvas.minY + y * canvas.height))
    }
    func stopVisuals() { pending = nil; pendingControl = nil; flight = nil }
}

private extension CGRect { var center: CGPoint { .init(x: midX, y: midY) } }

/// A short paper lift. Input is always live; there is no animation completion gate.
private struct WorldMenuArrival: ViewModifier {
    @Environment(\.worldMenuSession) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 1
    @State private var source = CGPoint.zero
    func body(content: Content) -> some View {
        // visualEffect is Sendable; read actor-owned State before entering it.
        let origin = source
        let appearanceProgress = progress
        return content.visualEffect { view, area in
            let rect = area.frame(in: .global)
            let x = min(1, max(0, (origin.x - rect.minX) / max(1, rect.width)))
            return view.scaleEffect(0.86 + 0.14 * appearanceProgress, anchor: .init(x: x, y: origin.y >= rect.midY ? 1 : 0))
                .offset(x: min(40, max(-40, origin.x - rect.midX)) * (1 - appearanceProgress),
                        y: (origin.y >= rect.midY ? 34 : -24) * (1 - appearanceProgress))
                .opacity(0.3 + 0.7 * appearanceProgress)
        }
        .task(id: session?.arrival?.id) {
            guard let session, let ticket = session.arrival, session.consume(ticket), !reduceMotion else { progress = 1; return }
            source = ticket.origin
            var still = Transaction(); still.disablesAnimations = true
            withTransaction(still) { progress = 0 }
            await Task.yield()
            guard !Task.isCancelled else { return }
            // A short spring with a little overshoot: the page lands rather than fades.
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { progress = 1 }
        }
    }
}

struct WorldSavedFlightLayer: View {
    let session: WorldMenuSession
    var body: some View {
        GeometryReader { area in
            if let flight = session.flight {
                WorldSavedFlightView(flight: flight, origin: area.frame(in: .global).origin) {
                    if session.flight?.id == flight.id { session.flight = nil }
                } landed: { session.landed() }.id(flight.id)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Saved goods pop out where they were made, arc up and drop into their
/// destination one after another. Reduce Motion shows a still check instead.
private struct WorldSavedFlightView: View {
    let flight: WorldSavedFlight
    let origin: CGPoint
    let finished: () -> Void
    let landed: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            if reduceMotion {
                TuvloCheckMark().frame(width: 36, height: 36)
                    .position(x: flight.end.x - origin.x, y: flight.end.y - origin.y)
            } else {
                ForEach(0..<min(4, max(1, flight.count)), id: \.self) { index in
                    WorldFlightPiece(picture: flight.picture, start: CGPoint(x: flight.start.x - origin.x + CGFloat(index) * 22 - 11, y: flight.start.y - origin.y - CGFloat(index % 2) * 12),
                                     end: CGPoint(x: flight.end.x - origin.x, y: flight.end.y - origin.y), delay: Double(index) * 0.09)
                }
            }
        }.task {
            let pieces = min(4, max(1, flight.count))
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 160 : 620))
                landed()
                try await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 80 * (pieces - 1) + 120))
            } catch { return }
            finished()
        }
    }
}

private struct WorldFlightPiece: View {
    let picture: WorldSavedPicture
    let start: CGPoint
    let end: CGPoint
    let delay: Double
    @State private var popped = false
    @State private var travel: CGFloat = 0
    var body: some View {
        Group {
            switch picture {
            case .place(let kind): Image(kind.heroArtwork).resizable().scaledToFit()
            case .good(let good): HomesteadFarmGoodIcon(good: good)
            case .character: WorldControlIcon(symbol: "tshirt.fill")
            }
        }.frame(width: 64, height: 64)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 6)
            .modifier(WorldArcPath(progress: travel, start: start, end: end))
            .scaleEffect(popped ? 1 : 0.2)
            .opacity(travel > 0.985 ? 0 : 1)
            .task {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { popped = true }
                do { try await Task.sleep(for: .milliseconds(140)) } catch { return }
                withAnimation(.timingCurve(0.45, 0, 0.75, 1, duration: 0.46)) { travel = 1 }
            }
    }
}

/// Places a view along a raised quadratic arc and shrinks it toward the end.
private struct WorldArcPath: ViewModifier, Animatable {
    var progress: CGFloat
    let start: CGPoint
    let end: CGPoint
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func body(content: Content) -> some View {
        let t = progress
        let lift = max(90, abs(end.x - start.x) * 0.35)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - lift)
        let x = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x
        let y = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y
        return content.scaleEffect(1.2 - 0.6 * t).rotationEffect(.degrees(Double(t) * 25)).position(x: x, y: y)
    }
}
