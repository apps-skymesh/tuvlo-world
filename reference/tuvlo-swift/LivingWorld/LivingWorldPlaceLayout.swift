import SwiftUI

/// Two authored positions per place keep the cottage door, tree and other
/// places clear in every combination. The treehouse stays attached to its tree.
enum LivingWorldSpot: Int, CaseIterable, Identifiable {
    case original = 0, alternate = 1
    var id: Int { rawValue }
    func title(for project: LivingWorldProject) -> String {
        switch project {
        case .pond: return self == .original ? "By the tree" : "By the cottage"
        case .nook: return self == .original ? "Beside the porch" : "At the garden edge"
        case .treehouse: return self == .original ? "Meadow side" : "Cottage side"
        }
    }
}
