//
//  WorldModels.swift
//  Tuvlo
//
//  Legacy Quest discovery catalog. WorldPlacement preserves those records and
//  carries namespaced living-world project choices; older IDs keep their meaning.
//

import Foundation
import SwiftData
import SwiftUI

enum WorldZone: String, CaseIterable, Identifiable {
    case village
    case forest
    case mountain
    case coast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .village: return "Village"
        case .forest: return "Forest"
        case .mountain: return "Mountain"
        case .coast: return "Coast"
        }
    }

    var icon: String {
        switch self {
        case .village: return "house.fill"
        case .forest: return "tree.fill"
        case .mountain: return "mountain.2.fill"
        case .coast: return "water.waves"
        }
    }

    var tint: Color {
        switch self {
        case .village: return CartoonTheme.kidAccent
        case .forest: return CartoonTheme.kidSuccess
        case .mountain: return Color(hex: "#45B7D1") ?? .blue
        case .coast: return Color(hex: "#4CC9F0") ?? .cyan
        }
    }

    /// Soft hit-area alignment on the quest board (top-left → bottom-right).
    var boardAlignment: Alignment {
        switch self {
        case .village: return .topLeading
        case .forest: return .topTrailing
        case .mountain: return .bottomLeading
        case .coast: return .bottomTrailing
        }
    }

    /// Default normalized drop point in each biome’s clearing.
    var defaultBoardPoint: CGPoint {
        switch self {
        case .village: return CGPoint(x: 0.28, y: 0.30)
        case .forest: return CGPoint(x: 0.72, y: 0.30)
        case .mountain: return CGPoint(x: 0.28, y: 0.70)
        case .coast: return CGPoint(x: 0.72, y: 0.70)
        }
    }

    static func nearest(toNormalized point: CGPoint) -> WorldZone {
        allCases.min { a, b in
            let da = hypot(a.defaultBoardPoint.x - point.x, a.defaultBoardPoint.y - point.y)
            let db = hypot(b.defaultBoardPoint.x - point.x, b.defaultBoardPoint.y - point.y)
            return da < db
        } ?? .village
    }
}

struct WorldDiscovery: Identifiable, Hashable {
    let id: String
    let name: String
    /// SF Symbol fallback / VoiceOver.
    let icon: String
    /// Asset catalog imageset name (e.g. WorldFlower).
    let imageName: String
    /// Crisp 3D badge for toasts / lists when different from the board art.
    let badgeImageName: String?
    /// Approved positive completions required to unlock.
    let unlockWins: Int
    let blurb: String
    let suggestedZone: WorldZone

    var displayImageName: String { badgeImageName ?? imageName }

    /// Asset names for celebration UI (not placed on the board).
    static let treasureChestImage = "UIAnimChest07"
    static let treasureLockedImage = "UIAnimChest00"
    static let rewardBurstImage = "WorldRewardBurst"

    static let catalog: [WorldDiscovery] = [
        WorldDiscovery(id: "flower", name: "Sunny Flower", icon: "camera.macro", imageName: "WorldFlower", badgeImageName: nil, unlockWins: 3, blurb: "Your first bloom on Adventure Island.", suggestedZone: .village),
        WorldDiscovery(id: "bench", name: "Wildflower Bench", icon: "sofa.fill", imageName: "WorldBench", badgeImageName: nil, unlockWins: 8, blurb: "A cozy seat for big thoughts.", suggestedZone: .village),
        WorldDiscovery(id: "tree", name: "Canopy Tree", icon: "tree.fill", imageName: "WorldIconTree", badgeImageName: "WorldIconTree", unlockWins: 13, blurb: "Something green grows when you do.", suggestedZone: .forest),
        WorldDiscovery(id: "cottage", name: "Golden Cottage", icon: "house.fill", imageName: "WorldIconCottage", badgeImageName: "WorldIconCottage", unlockWins: 18, blurb: "A home for your adventures.", suggestedZone: .village),
        WorldDiscovery(id: "bridge", name: "Garden Bridge", icon: "arrow.triangle.branch", imageName: "WorldIconBridge", badgeImageName: "WorldIconBridge", unlockWins: 23, blurb: "Connects two sides of your world.", suggestedZone: .forest),
        WorldDiscovery(id: "treehouse", name: "Cozy Treehouse", icon: "leaf.fill", imageName: "WorldIconTreehouse", badgeImageName: "WorldIconTreehouse", unlockWins: 28, blurb: "Hideout among the leaves.", suggestedZone: .forest),
        WorldDiscovery(id: "boat", name: "Sparkle Sailboat", icon: "sailboat.fill", imageName: "WorldIconBoat", badgeImageName: "WorldIconBoat", unlockWins: 33, blurb: "Ready for the next shore.", suggestedZone: .coast),
        WorldDiscovery(id: "egg", name: "Glowstone Egg", icon: "oval.fill", imageName: "WorldIconEgg", badgeImageName: "WorldIconEgg", unlockWins: 38, blurb: "Something magical is hatching.", suggestedZone: .mountain),
        WorldDiscovery(id: "triceratops", name: "Baby Triceratops", icon: "tortoise.fill", imageName: "WorldIconTriceratops", badgeImageName: "WorldIconTriceratops", unlockWins: 43, blurb: "A friendly dino joins the island.", suggestedZone: .forest),
        WorldDiscovery(id: "castle", name: "Blue-Roof Castle", icon: "building.2.fill", imageName: "WorldCastle", badgeImageName: "UIIconCastle", unlockWins: 48, blurb: "Proof of big adventures.", suggestedZone: .village),
        WorldDiscovery(id: "telescope", name: "Snow Observatory", icon: "eyeglasses", imageName: "WorldIconTelescope", badgeImageName: "WorldIconTelescope", unlockWins: 53, blurb: "See how far you've come.", suggestedZone: .mountain),
        WorldDiscovery(id: "rocket", name: "Launch Pad", icon: "airplane.departure", imageName: "WorldIconRocket", badgeImageName: "WorldIconRocket", unlockWins: 58, blurb: "Aim for the stars.", suggestedZone: .coast),
    ]

    static func unlocked(forWins wins: Int) -> [WorldDiscovery] {
        catalog.filter { $0.unlockWins <= wins }
    }

    /// Newly unlocked at this exact win threshold (for cues).
    static func unlockedExactly(atWins wins: Int) -> WorldDiscovery? {
        catalog.first { $0.unlockWins == wins }
    }

    static func nextLocked(afterWins wins: Int) -> WorldDiscovery? {
        catalog
            .filter { $0.unlockWins > wins }
            .sorted { $0.unlockWins < $1.unlockWins }
            .first
    }

    /// Legacy level-based helper — maps level≈wins/2 for older call sites.
    static func unlocked(forLevel level: Int) -> [WorldDiscovery] {
        // Approximate: keep older SignatureLoopCue callers working until migrated.
        unlocked(forWins: max(0, (level - 1) * 3))
    }
}

@Model
final class WorldPlacement {
    var id: UUID
    var discoveryID: String
    var zoneRaw: String
    var placedAt: Date
    /// Normalized board position (0…1). Nil → use zone default until first drag/place.
    var boardX: Double?
    var boardY: Double?

    var child: Child?

    init(
        discoveryID: String,
        zone: WorldZone,
        boardX: Double? = nil,
        boardY: Double? = nil,
        placedAt: Date = Date()
    ) {
        self.id = UUID()
        self.discoveryID = discoveryID
        self.zoneRaw = zone.rawValue
        self.placedAt = placedAt
        let defaults = zone.defaultBoardPoint
        self.boardX = boardX ?? defaults.x
        self.boardY = boardY ?? defaults.y
    }

    var zone: WorldZone {
        get { WorldZone(rawValue: zoneRaw) ?? .village }
        set { zoneRaw = newValue.rawValue }
    }

    var discovery: WorldDiscovery? {
        WorldDiscovery.catalog.first { $0.id == discoveryID }
    }

    /// Resolved normalized point on the island.
    var boardPoint: CGPoint {
        let fallback = zone.defaultBoardPoint
        return CGPoint(x: boardX ?? fallback.x, y: boardY ?? fallback.y)
    }

    func setBoardPoint(_ point: CGPoint, clampedIn bounds: CGSize) {
        let pad: CGFloat = 0.08
        let nx = min(1 - pad, max(pad, point.x / max(bounds.width, 1)))
        let ny = min(1 - pad, max(pad, point.y / max(bounds.height, 1)))
        boardX = Double(nx)
        boardY = Double(ny)
        zone = WorldZone.nearest(toNormalized: CGPoint(x: nx, y: ny))
    }
}
