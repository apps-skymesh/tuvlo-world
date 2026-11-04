import Foundation

extension LivingWorldProject {
    var shortTitle: String { switch self { case .pond: return "Pond"; case .nook: return "Nook"; case .treehouse: return "Treehouse" } }
    var symbol: String { switch self { case .pond: return "water.waves"; case .nook: return "book.closed.fill"; case .treehouse: return "tree.fill" } }
}
