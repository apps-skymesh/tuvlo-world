import SwiftUI
import RiveRuntime

/// What the Rive rig is told about the onboarding greeting. Gestures are
/// authored animations in the file (chosen, not driven frame by frame); the
/// grown-up proportions are constant per character.
struct RiveCharacterPose: Equatable {
    enum Gesture: Float { case none = 0, wave = 1, cheer = 2, scratch = 3 }
    var gesture: Gesture = .none
    var headScale: Float = 1
    var torsoScale: Float = 1
    /// Part of the observed input value: looking/happiness can change while
    /// the authored gesture stays idle.
    var expression: Float = 0

    /// The strongest gesture in the native greeting pose wins; small drifts,
    /// breathing and blinks are the rig's own idle motion.
    init(_ pose: WelcomeCharacterPose, adult: Bool) {
        let threshold: CGFloat = 0.15
        if pose.scratch > threshold { gesture = .scratch }
        else if pose.raise > threshold { gesture = .cheer }
        else if pose.wave > threshold { gesture = .wave }
        headScale = adult ? 0.8 : 1
        torsoScale = adult ? 56.0 / 48.0 : 1
        expression = Self.expression(pose)
    }

    /// Rig expression: 0 neutral, 50 look up, 100 happy.
    static func expression(_ pose: WelcomeCharacterPose) -> Float {
        if pose.joy > 0.5 || pose.smile > 0.5 { return 100 }
        if pose.curiosity > 0.3 || pose.gazeY < -0.3 { return 50 }
        return 0
    }
}

/// Shared renderer for app characters, profiles and customization: draws with Rive
/// when the file loads and the appearance is one the rig supports, otherwise
/// with the native drawing. Measures size × size with the feet at the bottom.
struct TuvloCharacter: View {
    let appearance: KidAppearance
    var motion: AvatarMotion = .idle
    var facing: WalkDir = .s
    var size: CGFloat = 180
    var outlined = true
    var welcomePose = WelcomeCharacterPose.rest
    var adultProportions = false
    /// Only the native loading/error fallback uses the scene clock; Rive owns its gait.
    var motionTime: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var driver = LivingWorldRive()
    @State private var isVisible = false
    static let nativeScale: CGFloat = 0.95

    // Grown-ups use the native drawing, which has the adult outfits (the rig is child-sized).
    private var usesRive: Bool {
        !adultProportions && !reduceMotion && driver.rive != nil && driver.error == nil && LivingWorldRiveAppearance.supports(appearance)
    }
    private var pose: RiveCharacterPose { RiveCharacterPose(welcomePose, adult: adultProportions) }
    private var running: Bool { !reduceMotion && scenePhase == .active && isVisible }

    var body: some View {
        ZStack {
            if usesRive {
                RiveCharacterSurface(driver: driver, running: running).equatable()
                    .task {
                        // Re-send after the surface has bound its first frame.
                        try? await Task.sleep(for: .milliseconds(120))
                        driver.forgetSentValues(); apply()
                    }
                    // Measured on device screenshots: the rig fills its artboard
                    // about 5% more than the native drawing; keep the feet line.
                    .scaleEffect(Self.nativeScale, anchor: .bottom)
                    .compositingGroup()
                    .shadow(color: outlined ? .white : .clear, radius: 0, x: max(1, size * 0.012), y: 0)
                    .shadow(color: outlined ? .white : .clear, radius: 0, x: -max(1, size * 0.012), y: 0)
                    .shadow(color: outlined ? .white : .clear, radius: 0, x: 0, y: max(1, size * 0.012))
                    .shadow(color: outlined ? .white : .clear, radius: 0, x: 0, y: -max(1, size * 0.012))
                    .transition(.opacity)
            } else {
                CustomKidAvatar(appearance: appearance, motion: motion, facing: facing, size: size,
                                outlined: outlined, welcomePose: reduceMotion ? .rest : welcomePose,
                                adultProportions: adultProportions, motionTime: motionTime)
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: usesRive)
        // A paused Rive surface can be blank on a cold launch. Use the native
        // still drawing for Reduce Motion, matching the World renderer.
        .task(id: !reduceMotion && !adultProportions && LivingWorldRiveAppearance.supports(appearance)) {
            guard !reduceMotion, !adultProportions, LivingWorldRiveAppearance.supports(appearance) else { return }
            if driver.rive == nil { await driver.load() }
            apply()
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: pose) { _, _ in apply() }
        .onChange(of: facing) { _, _ in apply() }
        .onChange(of: motion) { _, _ in apply() }
        .onChange(of: appearance) { _, _ in apply() }
        .accessibilityHidden(true)
    }

    private func apply() {
        driver.update(appearance: appearance, facing: facing, walking: motion != .idle && !reduceMotion,
                      expression: pose.expression)
        driver.update(pose: pose)
    }
}

/// The Rive surface depends only on the driver and playback. Pose, facing and
/// walking reach the rig through the driver; re-rendering the surface on every
/// animation frame reset the rig, so waves and turns showed for a frame at most.
private struct RiveCharacterSurface: View, Equatable {
    let driver: LivingWorldRive
    let running: Bool
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.driver === rhs.driver && lhs.running == rhs.running }
    var body: some View {
        RiveUIViewRepresentable(rive: driver.rive).frameRate(.fps(30)).paused(!running)
    }
}
