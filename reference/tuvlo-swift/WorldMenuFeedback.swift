import SwiftUI
import UIKit

/// The menu's tactile materials use the existing Sounds, Silent Mode and haptic policies.
nonisolated enum WorldMenuMaterial: String, CaseIterable, Sendable {
    case wood, paper, brass
    var clip: SoundEffects.Clip {
        switch self { case .wood: return .worldWood; case .paper: return .worldPaper; case .brass: return .worldBrass }
    }
}

/// Session memory only. Never derives a celebration from ownership or view appearance.
nonisolated struct WorldFeedbackGate {
    private var recent: [String] = []
    private var lastTouch = -Double.infinity
    mutating func touch(at time: TimeInterval) -> Bool {
        guard time.isFinite, time - lastTouch >= 0.1 else { return false }
        lastTouch = time; return true
    }
    mutating func saved(_ identity: String) -> Bool {
        guard !identity.isEmpty, !recent.contains(identity) else { return false }
        recent.append(identity)
        if recent.count > 256 { recent.removeFirst(recent.count - 256) }
        return true
    }
}

@MainActor enum WorldMenuFeedback {
    private static var gate = WorldFeedbackGate()
    static func touch(_ material: WorldMenuMaterial) {
        guard gate.touch(at: ProcessInfo.processInfo.systemUptime) else { return }
        pair(material)
    }
    @discardableResult static func saved(_ material: WorldMenuMaterial, identity: String) -> Bool {
        guard gate.saved(identity) else { return false }
        if gate.touch(at: ProcessInfo.processInfo.systemUptime) { pair(material) }; return true
    }
    private static func pair(_ material: WorldMenuMaterial) {
        SoundEffects.playMenu(material)
        switch material {
        case .wood: Haptics.impact(.light)
        case .paper: Haptics.selection()
        case .brass: Haptics.impact(.medium)
        }
    }
}

extension EnvironmentValues {
    @Entry var worldMenuMaterial: WorldMenuMaterial = .paper
    @Entry var worldMenuSession: WorldMenuSession? = nil
}
