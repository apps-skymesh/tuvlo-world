import Foundation

/// Device-local listening memory, separate from the child's earned progression.
struct LivingWorldWelcomeMemory {
    static let keyPrefix = "livingWorld.welcomeDay."
    var defaults: UserDefaults = .standard

    func isDue(for childID: UUID, on date: Date = Date(), in timeZone: TimeZone = .current) -> Bool {
        defaults.string(forKey: Self.keyPrefix + childID.uuidString) != FamilyDay.key(for: date, in: timeZone)
    }

    /// Called only after the player starts, so muted/failed/cancelled attempts can retry.
    func acknowledge(for childID: UUID, on date: Date = Date(), in timeZone: TimeZone = .current) {
        defaults.set(FamilyDay.key(for: date, in: timeZone), forKey: Self.keyPrefix + childID.uuidString)
    }
}
