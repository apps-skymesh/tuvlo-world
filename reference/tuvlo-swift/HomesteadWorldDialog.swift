import SwiftUI

/// The app return is a fixed labelled control, separate from map camera navigation.
struct HomesteadReturnButton: View {
    var identifier = "homestead.exit"
    let action: () -> Void
    var body: some View {
        Button { WorldMenuFeedback.touch(.brass); action() } label: {
            VStack(spacing: 1) {
                WorldControlIcon(symbol: "arrow.left").frame(width: 28, height: 28)
                Text("Tuvlo").font(.system(size: 10, weight: .semibold))
            }.frame(width: 48, height: 52).background(HomesteadControlSurface()).contentShape(Rectangle())
        }.buttonStyle(HomesteadControlButtonStyle())
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .accessibilityLabel("Return to Tuvlo").accessibilityIdentifier(identifier)
    }
}

/// Consent and recovery stay explicit. No backdrop-tap or timer dismissal.
struct HomesteadWorldDialog<Content: View>: View {
    let title: String
    let icon: String
    var message: String? = nil
    var systemIcon: String? = nil
    @ViewBuilder let content: Content
    @AccessibilityFocusState private var headingFocused: Bool
    var body: some View {
        ViewThatFits(in: .vertical) { panel(compact: false); panel(compact: true) }
            .frame(maxWidth: 420)
            .background(Color(livingWorldHex: "#F3EBD6"), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(livingWorldHex: "#C8BEA3")))
            .foregroundStyle(Color(livingWorldHex: "#243C32"))
            .environment(\.colorScheme, .light).dynamicTypeSize(.large)
            .accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
            .worldMenuArrival()
            .environment(\.worldMenuMaterial, .paper)
            .onAppear { headingFocused = true }
    }
    private func panel(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            HStack(spacing: 12) {
                Group {
                    if let systemIcon { if WorldControlIcon.appArtwork[systemIcon] != nil { WorldControlIcon(symbol: systemIcon) } else { Image(systemName: systemIcon).resizable().scaledToFit() } }
                    else if message != nil { WorldControlIcon(symbol: "exclamationmark.triangle.fill") }
                    else { WorldControlIcon(symbol: icon) }
                }.frame(width: compact ? 20 : 36, height: compact ? 20 : 36).accessibilityHidden(true)
                Text(LocalizedStringKey(title)).font(.headline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
                Spacer(minLength: 0)
            }
            if let message {
                ScrollView { Text(message).font(compact ? .caption : .subheadline).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true) }
                    .frame(height: compact ? 32 : 44).accessibilityIdentifier("world.dialog.message")
            }
            content
        }.padding(compact ? 8 : 12).fixedSize(horizontal: false, vertical: true)
    }
}

struct HomesteadWorldDialogLayer<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea().contentShape(Rectangle()).onTapGesture {}.accessibilityHidden(true)
            content.padding(.horizontal, 16).padding(.top, 80).padding(.bottom, 12)
        }
    }
}

struct HomesteadWorldExitDialog: ViewModifier {
    @Binding var presented: Bool
    let leave: () -> Void
    func body(content: Content) -> some View {
        content.accessibilityElement(children: .contain).accessibilityHidden(presented).allowsHitTesting(!presented)
            .overlay {
                if presented {
                    HomesteadWorldDialogLayer {
                        HomesteadWorldDialog(title: "Leave Tuvlo World?", icon: "arrow.uturn.backward") {
                            HStack(spacing: 12) {
                                HomesteadActionButton(title: "Stay", icon: "house.fill", state: .selected) { presented = false }
                                    .accessibilityIdentifier("world.exit.stay").keyboardShortcut(.cancelAction)
                                HomesteadActionButton(title: "Leave", icon: "arrow.uturn.backward") { presented = false; leave() }
                                    .accessibilityIdentifier("world.exit.confirm")
                            }
                        }.accessibilityIdentifier("world.dialog.exit").accessibilityAction(.escape) { presented = false }
                    }
                }
            }
    }
}
