import SwiftUI
import SwiftData

struct HomesteadExtrasEditor: View {
    let kid: Child
    let saved: () -> Void
    let preview: (HomesteadAppearanceExtras) -> Void
    private let allowsChanges: (() -> Bool)?
    @Environment(\.modelContext) private var context
    @ObservedObject private var parentAccess = KidParentAccess.shared
    @State private var draft: HomesteadAppearanceExtras
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var step = 0
    @State private var error: String?
    init(kid: Child, allowsChanges: (() -> Bool)? = nil, preview: @escaping (HomesteadAppearanceExtras) -> Void, saved: @escaping () -> Void) {
        self.kid = kid; self.saved = saved; self.allowsChanges = allowsChanges; self.preview = preview
        _draft = State(initialValue: (try? HomesteadActions.state(for: kid))?.extras ?? .init(characterID: kid.characterID))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                HomesteadMenuSteps(titles: ["Body", "Clothes", "Accessories"], selection: $step,
                                   icons: ["person.crop.circle", "tshirt.fill", "step.sparkles"])
                saveButton
            }
            let choicesLayout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            choicesLayout {
                switch step {
                case 0:
                    choice("Eye color", value: $draft.eyeColor, names: ["Brown", "Green", "Blue", "Amber"], colors: ["423b33", "5c7869", "5b7488", "8a6242"])
                    choice("Height", value: $draft.height, names: ["Short", "Medium", "Tall"])
                    choice("Build", value: $draft.build, names: ["Slim", "Soft", "Broad"])
                case 1:
                    choice("Bottom color", value: $draft.bottomColor, names: ["Sand", "Denim", "Plum", "Fern", "Terracotta", "Peach"], colors: ["b59562", "657e9a", "9c7c9a", "8caa7f", "ba856e", "e2c3a6"])
                    choice("Shoes", value: $draft.shoeColor, names: ["Clay", "Forest", "Blue", "Cream"], colors: ["975f48", "586a66", "798db0", "e6d8bc"])
                default:
                    choice("Accessory", value: $draft.accessory, names: ["None", "Neckerchief"])
                    choice("Accessory color", value: $draft.accessoryColor, names: ["Rust", "Honey", "Teal", "Lavender"], colors: ["c58462", "d9b468", "7c9da6", "b293ab"])
                }
            }
            if let error { Text(error).foregroundStyle(.red) }

        }.onChange(of: draft, initial: true) { _, value in preview(value) }
    }
    private var saveButton: some View {
        HomesteadIconButton(title: "Save your look", icon: "checkmark") {
            do {
                let value = HomesteadAppearanceExtras(characterID: kid.characterID, eyeColor: draft.eyeColor,
                    height: draft.height, build: draft.build, bottomColor: draft.bottomColor, shoeColor: draft.shoeColor,
                    accessory: draft.accessory, accessoryColor: draft.accessoryColor)
                try HomesteadActions.apply(.appearance(value), commandID: UUID(), kid: kid, in: context, allowsChanges: allowsChanges)
                saved()
            } catch { self.error = error.localizedDescription }
        }.disabled(!(allowsChanges?() ?? HomesteadActions.permitsChanges())).accessibilityIdentifier("homestead.appearance.save")
    }
    private func choice(_ title: String, value: Binding<Int>, names: [String], colors: [String]? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title)).font(.caption.bold())
            HomesteadItemStrip(items: Array(names.indices), minimumWidth: colors == nil ? 80 : 48, rowHeight: 48) { index in
                        Button { WorldMenuFeedback.touch(.paper); value.wrappedValue = index } label: {
                            if let colors {
                                Circle().fill(Color(livingWorldHex: colors[index])).frame(width: 30, height: 30)
                                    .overlay { if value.wrappedValue == index { WorldControlIcon(symbol: "checkmark").frame(width: 22, height: 22) } }
                                    .frame(width: 48, height: 48).contentShape(Rectangle())
                            } else {
                                Text(LocalizedStringKey(names[index])).font(.caption).padding(8).frame(minHeight: 48)
                                    .background(HomesteadJournalControlSurface(state: value.wrappedValue == index ? .selected : .available))
                                    .overlay(alignment: .topTrailing) { if value.wrappedValue == index { TuvloCheckMark().frame(width: 12, height: 12) } }
                            }
                        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(Text(LocalizedStringKey(names[index]))).accessibilityAddTraits(value.wrappedValue == index ? .isSelected : [])
            }.accessibilityIdentifier("homestead.details.\(title)")
        }
    }
}
