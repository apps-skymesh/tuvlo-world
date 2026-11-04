import Foundation

nonisolated struct HomesteadLegacyPlacement: Codable, Equatable, Sendable {
    let id: UUID
    let discoveryID: String
    let zoneRaw: String
    let boardX: Double?
    let boardY: Double?
    let placedAt: Date
    static func == (lhs: Self, rhs: Self) -> Bool {
        func equal(_ a: Double?, _ b: Double?) -> Bool {
            switch (a,b) {
            case (nil,nil): return true
            case (.some(let a), .some(let b)): return a == b || a.isNaN && b.isNaN
            default: return false
            }
        }
        return lhs.id == rhs.id && lhs.discoveryID == rhs.discoveryID && lhs.zoneRaw == rhs.zoneRaw
            && lhs.placedAt == rhs.placedAt && equal(lhs.boardX,rhs.boardX) && equal(lhs.boardY,rhs.boardY)
    }
}

nonisolated struct HomesteadMigrationIssue: Codable, Equatable, Sendable {
    let sourceID: UUID?
    let reason: String
    let original: String
}

nonisolated struct HomesteadBaseline: Codable, Equatable, Sendable {
    let version: Int
    let sourceDigest: String
    let originalCharacterID: String
    let originalPlacements: [HomesteadLegacyPlacement]
    let objects: [HomesteadObject]
    let issues: [HomesteadMigrationIssue]
}

/// Extra cosmetic fields accompany, rather than replace, KidAppearance's existing identity.
nonisolated struct HomesteadAppearanceExtras: Codable, Equatable, Sendable {
    let characterID: String
    var eyeColor: Int = 0
    var height: Int = 1
    var build: Int = 1
    var bottomColor: Int = 0
    var shoeColor: Int = 0
    var accessory: Int = 0
    var accessoryColor: Int = 0
    var isValid: Bool {
        characterID.utf8.count < 160 && (0..<4).contains(eyeColor) && (0..<3).contains(height)
        && (0..<3).contains(build) && (0..<6).contains(bottomColor) && (0..<4).contains(shoeColor)
        && (0..<2).contains(accessory) && (0..<4).contains(accessoryColor)
    }
}

nonisolated enum HomesteadChange: Codable, Equatable, Sendable {
    case migration(HomesteadBaseline)
    case arrange(HomesteadObject)
    case remove(UUID)
    case appearance(HomesteadAppearanceExtras)
    case orchardVariety(Int)
    case windmillLook(Int)
    case expand(HomesteadLand)
    case discovery(String)
}

nonisolated struct HomesteadEvent: Codable, Equatable, Sendable {
    static let prefix = "homestead:v1:"
    static let maximumBytes = 900_000
    let version: Int
    let childID: UUID
    let commandID: UUID
    let change: HomesteadChange

    init(childID: UUID, commandID: UUID, change: HomesteadChange) {
        version = 1; self.childID = childID; self.commandID = commandID; self.change = change
    }
    var recordID: UUID { HomesteadIdentity.stable(childID: childID, key: "command:\(commandID)") }
    func encoded() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let data = try encoder.encode(self)
        let raw = Self.prefix + data.base64EncodedString()
        guard raw.utf8.count <= Self.maximumBytes else { throw Failure.tooLarge }
        return raw
    }
    static func decode(_ raw: String) -> Self? {
        guard raw.hasPrefix(prefix), raw.utf8.count <= maximumBytes,
              let data = Data(base64Encoded: String(raw.dropFirst(prefix.count))),
              data.count <= maximumBytes else { return nil }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        guard let event = try? decoder.decode(Self.self, from: data), event.version == 1, event.isValid else { return nil }
        return event
    }
    var isValid: Bool {
        switch change {
        case .migration(let base):
            return base.version == 1 && base.originalPlacements.count <= 4096 && base.objects.count <= 4096
                && base.objects.allSatisfy { object in
                    (object.landGridVersion == nil || object.landGridVersion == 2) && (0..<4).contains(object.rotation) && (object.cell.map { (-32...32).contains($0.x) && (-32...32).contains($0.z) } ?? true)
                }
                && Set(base.objects.map(\.id)).count == base.objects.count
        case .arrange(let item): return item.cell != nil && (item.landGridVersion == nil || item.landGridVersion == 2) && (0..<4).contains(item.rotation)
                && (-32...32).contains(item.cell!.x) && (-32...32).contains(item.cell!.z) && (0..<(item.kind == .orchard ? 3 : 2)).contains(item.style)
        case .windmillLook(let value): return (0..<2).contains(value)
        case .orchardVariety(let value): return (0..<3).contains(value)
        case .appearance(let look): return look.isValid
        case .discovery(let id): return id == "pip-duck"
        case .remove, .expand: return true
        }
    }
    enum Failure: Error { case tooLarge }
}
