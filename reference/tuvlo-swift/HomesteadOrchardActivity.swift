import SwiftUI

/// Fruit is replayable play, never inventory, currency or mission credit.
/// Only the tree variety is saved, through the existing native mutation owner.
struct HomesteadOrchardActivity: View {
    let variety: Int
    let allowsChanges: Bool
    let chooseVariety: (Int) -> Void
    @State private var basket: [Int?] = [nil, nil, nil]
    @State private var choosingVariety = false
    @State private var selectedSlot: Int?
    @State private var basketFrames: [Int: CGRect] = [:]
    @State private var dragSource: DragSource?
    @State private var dragLocation = CGPoint.zero
    private enum DragSource: Equatable { case fruit(Int), slot(Int) }
    private let treeNames = ["Apple trees", "Pear trees", "Plum trees"]
    private var fruitName: String { ["Apple", "Pear", "Plum"][min(2, max(0, variety))] }
    private var full: Bool { basket.allSatisfy { $0 != nil } }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
            Text(choosingVariety ? "Choose trees" : full ? "Picked by you" : "Pick fruit").font(.subheadline.bold())
                .accessibilityIdentifier("homestead.orchard.status")
            if !choosingVariety { Text(full ? "Tap two fruits to swap" : "Tap fruit to pick").font(.caption) }
            }.frame(width: 124, alignment: .leading)
            if choosingVariety {
                HStack(spacing: 8) {
                    ForEach(0..<3) { value in
                        Button { chooseVariety(value); choosingVariety = false } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "tree.fill").font(.title2)
                                Text(treeNames[value]).font(.caption.weight(.semibold))
                            }.frame(maxWidth: .infinity, minHeight: 64)
                                .background(Color(livingWorldHex: "#9FBD78").opacity(value == variety ? 0.65 : 0.18), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges)
                            .accessibilityAddTraits(value == variety ? .isSelected : [])
                            .accessibilityIdentifier("homestead.orchard.variety.\(value)")
                    }
                }.frame(maxWidth: .infinity)
            } else {
            VStack(spacing: 4) {
            if !full {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Button { pick(index) } label: {
                            fruit(index).frame(height: 36)
                                .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(basket.contains(index))
                            .opacity(dragSource == .fruit(index) ? 0.35 : 1)
                            .highPriorityGesture(fruitDrag(.fruit(index)))
                            .accessibilityLabel("Pick " + fruitName.lowercased() + " \(index + 1)")
                            .accessibilityValue(basket.contains(index) ? "Picked" : "On tree")
                            .accessibilityIdentifier("homestead.orchard.fruit.\(index)")

                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<3) { slot in
                    Button { tapSlot(slot) } label: {
                        VStack(spacing: 2) {
                            if let index = basket[slot] {
                                fruit(index).frame(height: 32)
                                Text("\(index + 1)").font(.caption2)
                            } else {
                                Image(systemName: "plus").font(.caption).frame(height: 32)
                                Text("\(slot + 1)").font(.caption2)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color(livingWorldHex: "#C8AB80").opacity(0.20), in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12).stroke(Color(livingWorldHex: selectedSlot == slot ? "#637E70" : "#B5966B"), style: StrokeStyle(lineWidth: selectedSlot == slot ? 2 : 1, dash: basket[slot] == nil ? [3, 3] : []))
                            }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Basket spot \(slot + 1)")
                        .accessibilityValue(basket[slot].map { fruitName + " \($0 + 1)" } ?? "Empty")
                        .accessibilityHint("Place fruit here, or choose two filled spots to swap")
                        .accessibilityIdentifier("homestead.orchard.basket.\(slot)")
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("orchard-play")) } action: { basketFrames[slot] = $0 }
                        .highPriorityGesture(fruitDrag(.slot(slot)))
                }
            }
            }.frame(maxWidth: .infinity)
            }
            VStack(spacing: 0) {
                Button { choosingVariety.toggle() } label: {
                    Label(treeNames[min(2, max(0, variety))], systemImage: "leaf")
                        .font(.subheadline.bold()).frame(minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(HomesteadMenuButtonStyle()).disabled(!allowsChanges).accessibilityIdentifier("homestead.orchard.variety")
                    .accessibilityValue(treeNames[min(2, max(0, variety))])
                HomesteadIconButton(title: "Pick another basket", icon: "arrow.uturn.backward") { reset() }
                    .accessibilityIdentifier("homestead.orchard.again")
            }
        }.coordinateSpace(name: "orchard-play")
            .overlay(alignment: .topLeading) {
                if let source = dragSource {
                    let index = draggedFruit(source)
                    if let index {
                        fruit(index).frame(width: 48, height: 44).shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                            .position(dragLocation).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            }
            .onChange(of: variety) { _, _ in reset() }
            .accessibilityElement(children: .contain).accessibilityIdentifier("homestead.orchard.activity")
    }
    private func pick(_ index: Int) {
        guard !basket.contains(index), let slot = basket.firstIndex(where: { $0 == nil }) else { return }
        basket[slot] = index
    }
    private func tapSlot(_ slot: Int) {
        if basket[slot] == nil {
            if let index = (0..<3).first(where: { !basket.contains($0) }) { basket[slot] = index }
        } else if let source = selectedSlot, source != slot {
            basket.swapAt(source, slot); selectedSlot = nil
        } else { selectedSlot = slot }
    }
    private func reset() { basket = [nil, nil, nil]; selectedSlot = nil; dragSource = nil }
    private func draggedFruit(_ source: DragSource) -> Int? {
        switch source {
        case .fruit(let index): return basket.contains(index) ? nil : index
        case .slot(let slot): return basket[slot]
        }
    }
    private func fruitDrag(_ source: DragSource) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("orchard-play"))
            .onChanged { value in
                guard draggedFruit(source) != nil else { return }
                dragSource = source; dragLocation = value.location
            }
            .onEnded { value in
                defer { dragSource = nil }
                guard draggedFruit(source) != nil,
                      let slot = (0..<3).first(where: { basketFrames[$0]?.contains(value.location) == true }) else { return }
                switch source {
                case .fruit(let index):
                    guard basket[slot] == nil else { return }
                    basket[slot] = index
                case .slot(let original): basket.swapAt(original, slot)
                }
                selectedSlot = nil
            }
    }
    private func fruit(_ index: Int) -> some View {
        Canvas { context, size in
            let x = size.width / 2
            let color = Color(livingWorldHex: variety == 1 ? "#D5B36B" : variety == 2 ? "#9C8BB2" : "#C98270")
            var shape = Path()
            if variety == 1 {
                shape.move(to: .init(x: x, y: 5))
                shape.addCurve(to: .init(x: x - 12, y: 31), control1: .init(x: x - 7, y: 4), control2: .init(x: x - 19, y: 27))
                shape.addQuadCurve(to: .init(x: x + 12, y: 31), control: .init(x: x, y: 39))
                shape.addCurve(to: .init(x: x, y: 5), control1: .init(x: x + 19, y: 27), control2: .init(x: x + 7, y: 4))
            } else { shape.addEllipse(in: CGRect(x: x - 15, y: 7, width: 30, height: 29)) }
            context.fill(shape, with: .color(color.opacity(0.85 + Double(index) * 0.07)))
            context.stroke(shape, with: .color(Color.white.opacity(0.6)), lineWidth: 1)
            var stem = Path(); stem.move(to: .init(x: x, y: 10)); stem.addQuadCurve(to: .init(x: x + 2, y: 1), control: .init(x: x - 2, y: 3))
            context.stroke(stem, with: .color(Color(livingWorldHex: "#8A7257")), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: x + 1, y: 2, width: 10, height: 5)), with: .color(Color(livingWorldHex: "#729179")))
            context.fill(Path(ellipseIn: CGRect(x: x - 9, y: 13, width: 5, height: 10)), with: .color(.white.opacity(0.23)))
        }.accessibilityHidden(true)
    }
}
