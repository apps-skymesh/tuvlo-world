import Foundation
import SwiftData

/// Versioned paid ownership uses the existing request/payment/placement transport.
/// Only implemented, owner-approved items are exposed to purchasing.
enum LivingWorldExpansion: String, CaseIterable {
    case windmill = "expansion.v1.windmill"
    case meadow = "expansion.v1.westMeadow"
    case workshop = "expansion.v1.makerWorkshop"
    case greenhouse = "expansion.v1.greenhouse"
    case orchard = "expansion.v1.orchard"
    case waterside = "expansion.v1.eastWaterside"
    case barn = "expansion.v1.barn"
    case doghouse = "expansion.v1.doghouse"
    case grill = "expansion.v1.grill"
    static let ownershipPrefix = "living-world:v2:owned:"
    var ownershipRaw: String { Self.ownershipPrefix + rawValue }
    var kind: HomesteadKind? { switch self { case .barn: return .barn; case .doghouse: return .doghouse; case .grill: return .grill; case .windmill: return .windmill; case .meadow, .waterside: return nil; case .workshop: return .workshop; case .orchard: return .orchard; case .greenhouse: return .greenhouse } }
    var title: String { switch self { case .barn: return "Barn"; case .doghouse: return "Dog house"; case .grill: return "Grill"; case .windmill: return "Windmill"; case .waterside: return "East waterside"; case .meadow: return "West meadow"; case .workshop: return "Maker workshop"; case .orchard: return "Orchard"; case .greenhouse: return "Greenhouse" } }
    var price: Double { switch self { case .barn: return 18; case .doghouse: return 8; case .grill: return 12; case .windmill: return 6; case .waterside: return 80; case .meadow: return 10; case .workshop: return 6; case .orchard: return 35; case .greenhouse: return 30 } }
    var requiredWins: Int { switch self { case .barn: return 12; case .doghouse: return 8; case .grill: return 10; case .windmill: return 6; case .waterside: return 40; case .orchard: return 35; case .greenhouse: return 25; case .meadow, .workshop: return 20 } }
    var icon: String { switch self { case .barn: return "barn"; case .doghouse: return "doghouse"; case .grill: return "grill"; case .windmill: return "windmill"; case .waterside: return "water.waves"; case .orchard: return "tree.fill"; case .meadow, .greenhouse: return "garden"; case .workshop: return "hammer" } }
    var invitation: String { switch self {
        case .barn: return "Feed wheat to raise sheep for meat."
        case .doghouse: return "Welcome your own dog."
        case .grill: return "Cook a meal for the family."
        case .windmill: return "Turn wheat into flour."
        case .waterside: return "A stream bank to explore."
        case .meadow: return "More room to build."
        case .workshop: return "Fold paper toys."
        case .orchard: return "Pick apples, pears and plums."
        case .greenhouse: return "Grow potted plants."
    } }
    func hasRequiredLand(for kid: Child) -> Bool { ![Self.greenhouse, .orchard, .waterside].contains(self) || Self.meadow.isOwned(by: kid) }
    var land: HomesteadLand? { switch self { case .meadow: return .west; case .waterside: return .east; default: return nil } }
    static func expansion(for land: HomesteadLand) -> Self? { allCases.first { $0.land == land } }
    static func ownedLand(for kid: Child) -> Set<HomesteadLand> {
        Set(allCases.filter { $0.isOwned(by: kid) }.compactMap(\.land))
    }
    func receiptID(childID: UUID, currency: RewardCurrency) -> UUID {
        HomesteadIdentity.stable(childID: childID, key: "purchase:\(rawValue):\(currency.rawValue):\(price)")
    }
    func isOwned(by kid: Child) -> Bool {
        kid.payments.contains { $0.storeDetails?.worldProjectRaw == rawValue }
            || kid.worldPlacements.contains { !$0.isDeleted && $0.discoveryID == ownershipRaw }
    }
    func draftObject(childID: UUID) -> HomesteadObject {
        .init(id: HomesteadIdentity.stable(childID: childID, key: rawValue), kind: kind ?? .workshop, cell: nil, rotation: 0)
    }
    func ownedObject(for kid: Child) -> HomesteadObject {
        let raw = kid.payments.sorted { $0.id.uuidString < $1.id.uuidString }.first { $0.storeDetails?.worldProjectRaw == rawValue }?.storeDetails?.worldPlacementRaw
        return Self.decodeObject(raw, childID: kid.id, item: self) ?? draftObject(childID: kid.id)
    }
    static func encodeObject(_ object: HomesteadObject) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(object), as: UTF8.self)
    }
    static func decodeObject(_ raw: String?, childID: UUID, item: LivingWorldExpansion = .workshop) -> HomesteadObject? {
        guard let raw, raw.utf8.count < 2048, let object = try? JSONDecoder().decode(HomesteadObject.self, from: Data(raw.utf8)),
              item.kind != nil, object.id == item.draftObject(childID: childID).id, object.kind == item.kind,
              object.sourceID == nil, object.style == 0, (object.landGridVersion == nil || object.landGridVersion == 2), (0..<4).contains(object.rotation),
              let cell = object.cell, (-32...32).contains(cell.x), (-32...32).contains(cell.z) else { return nil }
        return object
    }
}
