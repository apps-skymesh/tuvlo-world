import SwiftUI

/// Catalogue choices retain their content and native horizontal scrolling.
struct HomesteadAssetDrawer<Content: View>: View {
    let title: String
    let icon: String
    let close: () -> Void
    @ViewBuilder let content: Content
    var body: some View {
        HomesteadJournalPanel(title: title, icon: icon, modal: false, showsIdentity: false, close: close) { content }
    }
}
