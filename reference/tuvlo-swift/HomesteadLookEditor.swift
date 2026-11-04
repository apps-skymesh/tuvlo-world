import SwiftUI

/// Choices preview the actual active Godot rig. Drafts never touch the ledger
/// or the saved character until the canonical save succeeds.
struct HomesteadLookEditor: View {
    let allowsChanges: Bool
    let preview: (KidAppearance) -> Void
    let save: (KidAppearance) throws -> Void
    @State private var draft: KidAppearance
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var step = 0
    @State private var error: String?
    init(kid: Child, allowsChanges: Bool, preview: @escaping (KidAppearance) -> Void, save: @escaping (KidAppearance) throws -> Void) {
        self.allowsChanges = allowsChanges; self.preview = preview; self.save = save
        _draft = State(initialValue: KidAppearance.displayed(characterID: kid.characterID))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                HomesteadMenuSteps(titles: ["You", "Hair", "Face", "Outfit", "Finishing touches"], selection: $step,
                                   icons: ["person.crop.circle", "step.hair", "step.face", "tshirt.fill", "step.sparkles"])
                saveButton
            }
            let choicesLayout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            choicesLayout {
                switch step {
                case 0:
                    swatches("Skin tone", value: $draft.skin, colors: KidAppearance.skinHexes, names: KidAppearance.skinNames)
                    choices("Face shape", value: $draft.faceShape, values: KidAppearance.FaceShape.allCases, title: { $0.title })
                case 1:
                    choices("Hair", value: $draft.hair, values: KidAppearance.Hair.allCases, title: { $0.title })
                    swatches("Hair color", value: $draft.hairColor, colors: KidAppearance.hairHexes, names: KidAppearance.hairNames)
                case 2:
                    choices("Eyes", value: $draft.eyes, values: KidAppearance.Eyes.allCases, title: { $0.title })
                    choices("Face", value: $draft.face, values: KidAppearance.Face.allCases, title: { $0.title })
                    HomesteadIconButton(title: draft.glasses ? "Remove glasses" : "Wear glasses", icon: "eyeglasses", selected: draft.glasses) { draft.glasses.toggle() }
                case 3:
                    choices("Outfit", value: $draft.outfit, values: KidAppearance.Outfit.allCases, title: { $0.title })
                    swatches("Outfit color", value: $draft.outfitColor, colors: KidAppearance.outfitHexes, names: KidAppearance.outfitNames)
                default:
                    choices("Pattern", value: $draft.pattern, values: KidAppearance.Pattern.allCases, title: { $0.title })
                    choices("Hat", value: $draft.hat, values: KidAppearance.Hat.allCases, title: { $0.title })
                }
            }
            if let error { Text(error).font(.caption) }

        }.onChange(of: draft, initial: true) { _, value in preview(value) }
    }
    private var saveButton: some View {
        HomesteadIconButton(title: "Save character", icon: "checkmark") {
            do { try save(draft) } catch { self.error = error.localizedDescription }
        }.disabled(!allowsChanges).accessibilityIdentifier("avatar.save")
    }
    private func choices<Value: Hashable>(_ label: String, value: Binding<Value>, values: [Value], title: @escaping (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label)).font(.caption.bold())
            HomesteadItemStrip(items: values, minimumWidth: 80, rowHeight: 48) { item in
                        Button { WorldMenuFeedback.touch(.paper); value.wrappedValue = item } label: {
                            Text(LocalizedStringKey(title(item))).font(.caption).padding(10).frame(minHeight: 48)
                                .background(HomesteadJournalControlSurface(state: value.wrappedValue == item ? .selected : .available))
                                .overlay(alignment: .topTrailing) { if value.wrappedValue == item { TuvloCheckMark().frame(width: 12, height: 12) } }
                        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityAddTraits(value.wrappedValue == item ? .isSelected : [])
            }
        }
    }
    private func swatches(_ label: String, value: Binding<Int>, colors: [String], names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(label)).font(.caption.bold())
            HomesteadItemStrip(items: Array(colors.indices), minimumWidth: 48, rowHeight: 48) { index in
                        Button { WorldMenuFeedback.touch(.paper); value.wrappedValue = index } label: {
                            WorldLookSwatch(color: Color(livingWorldHex: colors[index]), selected: value.wrappedValue == index)
                                .frame(width: 44, height: 44).frame(width: 48, height: 48).contentShape(Rectangle())
                        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(Text(LocalizedStringKey(names[index])))
                            .accessibilityAddTraits(value.wrappedValue == index ? .isSelected : [])
            }
        }
    }
}
