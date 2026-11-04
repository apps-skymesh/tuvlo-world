#if DEBUG
import Foundation
import SwiftData

/// Explicit, disposable on-disk fixture for real process-restart checks. This
/// path never aliases tuvlo.sqlite and cannot be selected by a Release build.
@MainActor
enum HomesteadUITestStore {
    static var enabled: Bool {
        UITestLaunchConfiguration.isEnabled && UITestLaunchConfiguration.isStoreAudit
        && ProcessInfo.processInfo.arguments.contains("-ui-testing-homestead-persistence")
    }
    static func make() throws -> ModelContainer {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TuvloHomesteadUITestStore", isDirectory: true)
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset"), FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try TuvloStore.makeContainer(at: directory.appendingPathComponent("fixture.sqlite"))
        if try container.mainContext.fetchCount(FetchDescriptor<Child>()) == 0 {
            UITestLaunchConfiguration.seedStoreIfNeeded(container.mainContext)
        }
        return container
    }
}
#endif
