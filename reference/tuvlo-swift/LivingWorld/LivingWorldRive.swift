import SwiftUI
import RiveRuntime

/// A deliberately explicit support boundary: a saved option is never substituted.
enum LivingWorldRiveAppearance {
    static let hairs: [KidAppearance.Hair] = [.swoop, .crop, .curls, .long, .bob, .ponytail, .pigtails, .afro, .braids, .wavy, .bun, .spiky, .sidePart]
    static let outfits: [KidAppearance.Outfit] = [.hoodie, .tee, .dress, .polo, .overalls, .cardigan]
    // Explicit order is the private asset contract, independent of serialized IDs.
    static let shapes: [KidAppearance.FaceShape] = [.soft, .round, .oval, .square]
    static let eyes: [KidAppearance.Eyes] = [.round, .almond, .wide]
    static let faces: [KidAppearance.Face] = [.smile, .grin, .freckles, .dimples]
    static let hats: [KidAppearance.Hat] = [.none, .baseball, .backwards]
    static let patterns: [KidAppearance.Pattern] = [.plain, .stripes, .star, .flower, .dots]
    static let shoeHexes = ["#536C91", "#CB827C", "#76A18E", "#9383B3", "#BC986B", "#609EA7"]
    static func supports(_ appearance: KidAppearance) -> Bool {
        hairs.contains(appearance.hair) && outfits.contains(appearance.outfit)
            && shapes.contains(appearance.faceShape) && eyes.contains(appearance.eyes)
            && faces.contains(appearance.face) && hats.contains(appearance.hat) && patterns.contains(appearance.pattern)
            && KidAppearance.skinHexes.indices.contains(appearance.skin)
            && KidAppearance.hairHexes.indices.contains(appearance.hairColor)
            && KidAppearance.outfitHexes.indices.contains(appearance.outfitColor)
    }
}

@Observable @MainActor
final class LivingWorldRive {
    private(set) var rive: Rive?
    private(set) var error: String?
    private var instance: ViewModelInstance?
    private var lastAppearance: KidAppearance?
    private var numbers: [String: Float] = [:]

    /// One worker and file for every character on screen: loading them per
    /// character delayed each Rive drawing by a second or more, so scenes opened
    /// on the native drawing and swapped mid-animation.
    private static var sharedFile: Task<(Worker, RiveRuntime.File), Error>?

    private static func file() -> Task<(Worker, RiveRuntime.File), Error> {
        if let sharedFile { return sharedFile }
        let task = Task<(Worker, RiveRuntime.File), Error> {
            let worker = try await Worker()
            return (worker, try await RiveRuntime.File(source: .local("TuvloKidPilot", .main), worker: worker))
        }
        sharedFile = task
        return task
    }

    /// Starts loading the file before a scene needs it.
    static func preload() { _ = file() }

    func load() async {
        rive = nil; instance = nil; error = nil; lastAppearance = nil; numbers = [:]
        do {
            let file: RiveRuntime.File
            do { file = try await Self.file().value.1 }
            catch { Self.sharedFile = nil; throw error }   // a later load retries
            let artboard = try await file.createArtboard()
            let instance = try await file.createViewModelInstance(.viewModelDefault(from: .artboardDefault(artboard)))
            // Every control is read once here; a value set on a property that was
            // never read does not reach the rig.
            for name in ["speed", "direction", "expression", "hairChoice", "outfitChoice", "glasses", "shapeChoice", "eyesChoice", "faceChoice", "hatChoice", "patternChoice",
                         "gesture", "headScale", "torsoScale"] {
                _ = try await instance.value(of: NumberProperty(path: name))
            }
            for name in ["skinColor", "hairColor", "shirtColor", "shoeAccent", "shoeTrim"] {
                _ = try await instance.value(of: ColorProperty(path: name))
            }
            let loaded = try await Rive(file: file, artboard: artboard, dataBind: .instance(instance))
            try Task.checkCancellation()
            self.instance = instance; rive = loaded
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }

    func update(appearance: KidAppearance, frame: LivingWorldFrame) {
        update(appearance: appearance, facing: frame.facing, walking: frame.walkingIntent, expression: frame.reaction)
    }

    func update(appearance: KidAppearance, facing: WalkDir, walking: Bool, expression: Float) {
        guard let instance, LivingWorldRiveAppearance.supports(appearance) else { return }
        if lastAppearance != appearance {
            let shoes = LivingWorldRiveAppearance.shoeHexes
            let shoeIndex = (appearance.outfitColor * 2 + appearance.hairColor * 3 + appearance.skin) % shoes.count
            for (path, hex) in [("skinColor", KidAppearance.skinHexes[appearance.skin]),
                                ("hairColor", KidAppearance.hairHexes[appearance.hairColor]),
                                ("shirtColor", KidAppearance.outfitHexes[appearance.outfitColor]),
                                ("shoeAccent", shoes[shoeIndex]), ("shoeTrim", shoes[(shoeIndex + 2) % shoes.count])] {
                let value = UInt32(hex.dropFirst(), radix: 16)!
                instance.setValue(of: ColorProperty(path: path), to: RiveRuntime.Color(0xFF000000 | value))
            }
            set("hairChoice", Float(LivingWorldRiveAppearance.hairs.firstIndex(of: appearance.hair)!))
            set("outfitChoice", Float(LivingWorldRiveAppearance.outfits.firstIndex(of: appearance.outfit)!))
            set("shapeChoice", Float(LivingWorldRiveAppearance.shapes.firstIndex(of: appearance.faceShape)!))
            set("eyesChoice", Float(LivingWorldRiveAppearance.eyes.firstIndex(of: appearance.eyes)!))
            set("faceChoice", Float(LivingWorldRiveAppearance.faces.firstIndex(of: appearance.face)!))
            set("hatChoice", Float(LivingWorldRiveAppearance.hats.firstIndex(of: appearance.hat)!))
            set("patternChoice", Float(LivingWorldRiveAppearance.patterns.firstIndex(of: appearance.pattern)!))
            set("glasses", appearance.glasses ? 1 : 0)
            lastAppearance = appearance
        }
        set("direction", facing == .e ? 100 : facing == .w ? 0 : 50)
        set("speed", walking ? 100 : 0)
        set("expression", expression)
    }

    /// A surface that has just appeared binds the file's default values; the
    /// next update must send everything again.
    func forgetSentValues() { numbers = [:]; lastAppearance = nil }

    /// Onboarding greeting gesture and grown-up proportions.
    func update(pose: RiveCharacterPose) {
        set("gesture", pose.gesture.rawValue)
        set("headScale", pose.headScale)
        set("torsoScale", pose.torsoScale)
    }

    func settle() { rive?.stateMachine.advance(by: 0.4) }

    private func set(_ name: String, _ value: Float) {
        // Remember only values that reached the rig: a value set while the file
        // is still loading must be sent again once it has loaded.
        guard let instance, numbers[name] != value else { return }
        numbers[name] = value
        instance.setValue(of: NumberProperty(path: name), to: value)
    }
}

private struct LivingWorldRiveIntent: Equatable {
    let facing: WalkDir
    let walking: Bool
    let reaction: Float
}

struct LivingWorldRiveCharacter: View, Equatable {
    let driver: LivingWorldRive
    let appearance: KidAppearance
    let frame: LivingWorldFrame
    let running: Bool
    let still: Bool
    private var intent: LivingWorldRiveIntent {
        LivingWorldRiveIntent(facing: frame.facing, walking: frame.walkingIntent, reaction: frame.reaction)
    }
    // Position belongs to the scene. The Rive surface only changes when an
    // intention, appearance or playback setting changes; its own clock animates.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.driver === rhs.driver && lhs.appearance == rhs.appearance
            && lhs.running == rhs.running && lhs.still == rhs.still && lhs.intent == rhs.intent
    }
    var body: some View {
        RiveUIViewRepresentable(rive: driver.rive)
            .frameRate(.fps(30)).paused(!running).equatable()
            // Rive 6.24 skips paused redraws after bootstrap. Recreate only the
            // surface for static edits; the file, rig and animation time persist.
            .id(appearance.characterID + (still ? "-still" : "-live"))
            .onChange(of: intent, initial: true) { _, _ in driver.update(appearance: appearance, frame: frame) }
            .onChange(of: appearance) { _, _ in driver.update(appearance: appearance, frame: frame) }
            .accessibilityHidden(true)
    }
}
