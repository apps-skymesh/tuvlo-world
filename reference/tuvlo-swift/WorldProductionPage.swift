import SwiftUI

/// Direct production at the selected place. The saved farm/journal owns all
/// quantities and clocks; a drop calls the same saved action as a tap.
struct WorldProductionPage: View {
    private typealias Held = WorldDragModel.Held
    let farm: HomesteadFarm
    @Binding var station: HomesteadFarm.Station
    @Binding var ovenRecipe: HomesteadFarm.Recipe
    let placed: Set<HomesteadKind>
    let nookOwned: Bool
    let allowsChanges: Bool
    let inspect: (HomesteadKind) -> Void
    let source: (HomesteadFarm.Good) -> Void
    let collectRecipe: (HomesteadFarm.Station) -> Bool
    let committed: (HomesteadFarm.Good, Bool, String) -> Void
    let celebrate: () -> Void
    let ring: (CGRect) -> Void
    let back: (() -> Void)?
    let close: () -> Void
    let move: () -> Void
    @State private var field = 0
    /// Presentation only: nothing is spent until the last slot fills and the job saves.
    @State private var slotted: Set<HomesteadFarm.Good> = []
    /// Finger position lives in its own model so only the carried picture redraws while dragging.
    @State private var drag = WorldDragModel()
    @Environment(\.worldMenuSession) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var space: String { WorldPlaceCard<EmptyView, EmptyView, EmptyView, EmptyView>.space }

    private var recipe: HomesteadFarm.Recipe? {
        switch station {
        case .mill: return .flour
        case .oven: return farm.jobs[.oven]?.recipe ?? ovenRecipe
        case .pantry: return .meal
        case .barn: return farm.jobs[.barn]?.recipe ?? .livestock
        case .grill: return .grilledMeal
        default: return nil
        }
    }
    private var pageKind: HomesteadKind { station == .orders && nookOwned ? .nook : station.kind }
    private var title: String { station == .oven ? "Oven" : station == .pantry ? "Kitchen bench" : pageKind.title }
    private var showsPlace: Bool { placed.contains(station.kind) }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            WorldPlaceCard(title: title, flow: flow(now: clock.date), move: allowsChanges && placed.contains(pageKind) ? move : nil, back: back, close: close, ring: ring) {
                if showsPlace { inputs(now: clock.date) }
            } place: {
                centre(now: clock.date)
            } output: {
                if showsPlace { output(now: clock.date) }
            } action: {
                primary(now: clock.date)
            }.overlay { WorldDragGhost(model: drag).allowsHitTesting(false) }
        }.onChange(of: station) { _, _ in slotted = [] }.onChange(of: ovenRecipe) { _, _ in slotted = [] }
    }

    private func flow(now: Date) -> WorldFlowArrows.Phase? {
        guard showsPlace, station != .field else { return nil }
        let state: HomesteadTimeState = recipe.map { state(of: $0, now: now) } ?? (station == .orchard ? orchardState(now: now) : .waiting)
        return state.phase == .working ? .working : state.phase == .ready ? .ready : .idle
    }

    // MARK: Goods and tools

    @ViewBuilder private func inputs(now: Date) -> some View {
        if let recipe {
            let goods = HomesteadFarm.Good.allCases.filter { recipe.input[$0] != nil }
            VStack(spacing: 12) {
                ForEach(goods, id: \.self) { good in
                    goodTile(good, need: recipe.input[good, default: 0], size: goods.count > 1 ? 84 : 100, enabled: farm.jobs[recipe.station] == nil && !slotted.contains(good)) { place(good, in: recipe) }
                }
            }
        } else if station == .field { fieldTool(now: now) }
        else if station == .orchard { orchardTool(now: now) }
        else { orderInput }
    }
    private func goodTile(_ good: HomesteadFarm.Good, need: Int, size: CGFloat, enabled: Bool, drop: @escaping () -> Void) -> some View {
        let short = farm[good] < need && !slotted.contains(good)
        return Button {
            session?.control("ingredient." + good.rawValue); WorldMenuFeedback.touch(.paper)
            if short { source(good) } else if allowsChanges && enabled { drop() }
        } label: {
            HomesteadFarmGoodIcon(good: good).frame(width: size * 0.74, height: size * 0.74).frame(width: size, height: size)
                .saturation(short ? 0.5 : 1).background(WorldTileSurface())
                .overlay(alignment: .bottomTrailing) { WorldCountBadge(text: HomesteadWalletDisplay.compact(Double(farm[good])), alert: short).offset(x: 6, y: 6) }
                .opacity(drag.held == .good(good) ? 0.45 : 1)
        }.buttonStyle(WorldCardPress()).worldMenuAnchor("ingredient." + good.rawValue)
            .simultaneousGesture(carry(.good(good), enabled: allowsChanges && enabled && !short, drop: drop))
            .accessibilityLabel("\(good.title), \(farm[good]) of \(need)")
            .accessibilityHint(short ? "Open ingredient source" : "Add to this place")
            .accessibilityIdentifier("homestead.farm.source." + good.rawValue)
    }
    private func carry(_ item: Held, enabled: Bool, drop: @escaping () -> Void) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(space)).onChanged { value in
            guard enabled || drag.held == item else { return }
            drag.lift(item, at: value.location)
        }.onEnded { value in
            guard drag.held == item else { return }
            let hit = drag.overWell(value.location)
            drag.release(into: hit, reduceMotion: reduceMotion)
            if hit { drop() }
        }
    }
    private func place(_ good: HomesteadFarm.Good, in recipe: HomesteadFarm.Recipe) {
        guard allowsChanges, farm.jobs[recipe.station] == nil, farm[good] >= recipe.input[good, default: 0] else { return }
        slotted.insert(good)
        if recipe.input.keys.allSatisfy(slotted.contains) { start(recipe) }
    }
    private func start(_ recipe: HomesteadFarm.Recipe) {
        slotted = []
        if let missing = HomesteadFarm.Good.allCases.first(where: { farm[$0] < recipe.input[$0, default: 0] }) { source(missing); return }
        guard farm.make(recipe), let saved = farm.jobs[recipe.station] else { return }
        committed(recipe.input.keys.sorted { $0.rawValue < $1.rawValue }.first ?? recipe.output, false,
                  "make:" + recipe.rawValue + ":" + String(saved.started.timeIntervalSince1970))
    }

    // MARK: The place

    @ViewBuilder private func centre(now: Date) -> some View {
        if !showsPlace { missingPlace }
        else if station == .field { plots(now: now) }
        else if let recipe { recipeLens(recipe, now: now) }
        else if station == .orchard { WorldPlaceLens(state: orchardState(now: now), hot: drag.hot) { EmptyView() }.background(wellReader) }
        else { WorldPlaceLens(state: farm.picnicFunded && !farm.picnicServed ? .ready : .waiting, hot: drag.hot) { EmptyView() }.background(wellReader) }
    }
    private var wellReader: some View {
        Color.clear.onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { drag.wellFrame = $0 }
    }
    private func state(of recipe: HomesteadFarm.Recipe, now: Date) -> HomesteadTimeState {
        farm.jobs[recipe.station].map { .clock(end: $0.finish, duration: $0.recipe.seconds, now: now) } ?? .waiting
    }
    /// Tapping the place itself also starts or collects; the button below says so plainly.
    private func recipeLens(_ recipe: HomesteadFarm.Recipe, now: Date) -> some View {
        let state = state(of: recipe, now: now), job = farm.jobs[recipe.station]
        let units = HomesteadFarm.Good.allCases.flatMap { good in Array(repeating: good, count: recipe.input[good, default: 0]) }
        return WorldPlaceLens(state: state, hot: drag.hot) {
            if job == nil {
                HStack(spacing: 6) {
                    ForEach(units.indices, id: \.self) { WorldGoodSlot(good: units[$0], filled: slotted.contains(units[$0]), size: units.count > 2 ? 40 : 46) }
                }
            }
        }.background(wellReader)
            .contentShape(Circle()).onTapGesture { act(recipe, now: now) }
            .accessibilityHidden(true)
    }
    private func act(_ recipe: HomesteadFarm.Recipe, now: Date) {
        session?.control("farm.action")
        if farm.jobs[recipe.station] != nil { if state(of: recipe, now: now).phase == .ready { collect(recipe) } }
        else if allowsChanges { start(recipe) }
    }
    @ViewBuilder private func primary(now: Date) -> some View {
        if showsPlace, let recipe {
            let state = state(of: recipe, now: now), job = farm.jobs[recipe.station]
            // While it works the ring and the clock beside the product say so; the button returns to collect.
            if job != nil && state.phase != .ready { Color.clear.frame(height: 48) } else {
            WorldPrimaryAction(kind: job == nil ? .start : .collect, state: state, product: recipe.output,
                               enabled: allowsChanges) { act(recipe, now: now) }
                .worldMenuAnchor("farm.action")
                .accessibilityLabel(Text(LocalizedStringKey(job == nil ? (recipe == .livestock ? "Feed" : recipe == .grilledMeal ? "Grill" : "Make") : state.phase == .ready ? "Collect" : "Working")))
                .accessibilityValue(state.accessibilityValue).accessibilityHint(allowsChanges ? "" : "Ask your parent to check access")
                .accessibilityIdentifier("homestead.farm." + (job == nil ? "make" : "collect"))
            }
        } else { Color.clear.frame(height: 48) }
    }
    private func collect(_ recipe: HomesteadFarm.Recipe) {
        guard let job = farm.jobs[recipe.station], collectRecipe(recipe.station) else { return }
        if recipe.station == .oven { ovenRecipe = recipe }
        committed(recipe.output, true, "collect:" + recipe.rawValue + ":" + String(job.started.timeIntervalSince1970))
    }
    private var missingPlace: some View {
        Button { inspect(station.kind) } label: {
            WorldPlaceLens(state: .waiting, locked: true) { EmptyView() }
                .overlay {
                    VStack(spacing: 6) {
                        WorldControlIcon(symbol: "place." + station.kind.rawValue).frame(width: 96, height: 96).saturation(0.35).opacity(0.85)
                        WorldControlIcon(symbol: "lock").frame(width: 34, height: 34)
                    }
                }
        }.buttonStyle(WorldCardPress()).accessibilityLabel("Build " + station.kind.title)
            .accessibilityIdentifier("homestead.farm.build." + station.kind.rawValue)
    }

    // MARK: The product

    @ViewBuilder private func output(now: Date) -> some View {
        if let recipe {
            let state = state(of: recipe, now: now)
            VStack(spacing: 10) {
                if station == .oven && placed.contains(.orchard) {
                    ForEach([HomesteadFarm.Recipe.bread, .tart], id: \.self) { option in
                        Button { WorldMenuFeedback.touch(.paper); ovenRecipe = option } label: {
                            productTile(option.output, quantity: option.quantity, size: 82, lit: recipe == option)
                        }.buttonStyle(WorldCardPress()).disabled(state.phase != .waiting).accessibilityLabel(option.output.title)
                            .accessibilityAddTraits(recipe == option ? .isSelected : []).accessibilityIdentifier("homestead.farm.recipe." + option.rawValue)
                    }
                } else { productTile(recipe.output, quantity: recipe.quantity, size: 100, lit: state.phase == .ready) }
                timeRow(state, planned: farm.jobs[recipe.station] == nil ? Int(recipe.seconds) : nil, good: recipe.output)
            }
        } else if station == .field {
            let selected = farm.fields[field]
            let state = fieldState(selected, now: now)
            VStack(spacing: 10) {
                productTile(.wheat, quantity: 2, size: 100, lit: state.phase == .ready)
                timeRow(state, planned: selected.wateredAt == nil ? Int(HomesteadFarm.fieldSeconds) : nil, good: .wheat)
            }
        } else if station == .orchard {
            let state = orchardState(now: now)
            VStack(spacing: 10) {
                productTile(.fruit, quantity: 3, size: 82, lit: state.phase == .ready)
                timeRow(state, planned: farm.orchardWatered == nil ? Int(HomesteadFarm.orchardSeconds) : nil, good: .fruit)
                Button { ovenRecipe = .tart; station = .oven } label: {
                    HomesteadFarmGoodIcon(good: .tart).frame(width: 40, height: 40).frame(width: 64, height: 52).background(WorldTileSurface(cornerRadius: 14))
                }.buttonStyle(WorldCardPress()).accessibilityLabel("Tart").accessibilityIdentifier("homestead.farm.tart")
            }
        } else { HomesteadFarmGoodIcon(good: nookOwned && !farm.picnicServed ? .meal : farm.orderGood).frame(width: 74, height: 74).frame(width: 100, height: 100).background(WorldTileSurface()).accessibilityHidden(true) }
    }
    private func productTile(_ good: HomesteadFarm.Good, quantity: Int, size: CGFloat, lit: Bool) -> some View {
        HomesteadFarmGoodIcon(good: good).frame(width: size * 0.74, height: size * 0.74).frame(width: size, height: size)
            .background(WorldTileSurface(lit: lit))
            .overlay(alignment: .bottomTrailing) { WorldCountBadge(text: "×\(quantity)").offset(x: 6, y: 6) }
    }
    private func timeRow(_ state: HomesteadTimeState, planned: Int?, good: HomesteadFarm.Good) -> some View {
        HStack(spacing: 5) {
            HomesteadSunRing(state: state, size: 24).accessibilityIdentifier("homestead.farm.job")
            if let planned { Text(HomesteadTimeFormat.remaining(planned)).font(WorldCardFinish.number(13)).foregroundStyle(WorldCardFinish.ink.opacity(0.7)).monospacedDigit().fixedSize().accessibilityLabel("Duration, " + HomesteadTimeFormat.remaining(planned)) }
            else if !allowsChanges { WorldControlIcon(symbol: "lock").frame(width: 24, height: 24).accessibilityHidden(false).accessibilityLabel("Read only") }
            HStack(spacing: 3) {
                WorldControlIcon(symbol: "archivebox").frame(width: 16, height: 16).opacity(0.8)
                Text(HomesteadWalletDisplay.compact(Double(farm[good]))).font(WorldCardFinish.number(13)).foregroundStyle(WorldCardFinish.ink.opacity(0.7)).monospacedDigit().fixedSize()
            }.worldMenuAnchor("stock." + good.rawValue).accessibilityElement(children: .ignore)
                .accessibilityLabel("\(farm[good]) \(good.title) stored").accessibilityIdentifier("homestead.farm.stock." + good.rawValue)
        }.frame(height: 28)
    }

    // MARK: Fields

    private func fieldState(_ value: HomesteadFarm.Field, now: Date) -> HomesteadTimeState {
        value.wateredAt.map { .clock(end: $0.addingTimeInterval(HomesteadFarm.fieldSeconds), duration: HomesteadFarm.fieldSeconds, now: now) } ?? .waiting
    }
    /// The plot the tool acts on: the selected one when it needs work, otherwise the next one that does.
    private func target(now: Date) -> Int {
        let ready = { (index: Int) in [0, 1, 4].contains(farm.fields[index].stage(at: now)) }
        return ready(field) ? field : farm.fields.indices.first(where: ready) ?? field
    }
    private func tool(for stage: Int) -> (icon: String?, label: String) {
        switch stage {
        case 0: return ("tool.seed", "Plant")
        case 1: return ("tool.can", "Water")
        case 4: return ("tool.sickle", "Collect")
        default: return ("tool.sickle", "Growing")
        }
    }
    private func fieldTool(now: Date) -> some View {
        let index = target(now: now), stage = farm.fields[index].stage(at: now), tool = tool(for: stage)
        return toolTile(icon: tool.icon, label: tool.label, id: "tend", ready: stage == 4, waiting: !(stage == 0 || stage == 1 || stage == 4), sweepStage: stage) {
            tend(index, now: Date())
        } sweep: { location in
            // Every plot at the stage this tool started on takes it, once per stroke.
            guard let hit = drag.plotFrames.first(where: { $0.value.contains(location) })?.key, !drag.swept.contains(hit),
                  farm.fields[hit].stage(at: Date()) == drag.sweepStage else { return }
            drag.swept.insert(hit); tend(hit, now: Date())
        }
    }
    private func tend(_ index: Int, now: Date) {
        let stage = farm.fields[index].stage(at: now)
        session?.control("plot.\(index)")
        guard farm.tend(index) else { return }
        committed(.wheat, stage == 4, "field:\(index):\(stage):" + UUID().uuidString)
        // Move on to the next plot that needs the same hand, so taps work down the row.
        if let next = farm.fields.indices.first(where: { $0 != index && farm.fields[$0].stage(at: now) == stage }) { field = next }
        else { field = index }
    }
    /// The live garden fills the ring; each bed gets its own chip, and a dragged tool sweeps across both.
    private func plots(now: Date) -> some View {
        let anyWorking = farm.fields.contains { $0.wateredAt != nil && $0.stage(at: now) < 4 }
        return WorldPlaceLens(state: anyWorking ? fieldState(farm.fields[target(now: now)], now: now) : .waiting, hot: drag.held != nil) {
            HStack(spacing: 22) {
                ForEach(farm.fields.indices, id: \.self) { index in
                    let value = farm.fields[index], stage = value.stage(at: now), state = fieldState(value, now: now)
                    ZStack(alignment: .bottom) {
                        // While a bed grows its clock shows; otherwise the tool below is the whole control.
                        Button { field = index; WorldMenuFeedback.touch(.wood) } label: {
                            Group {
                                if state.phase == .working { HomesteadSunRing(state: state, size: 44) } else { Color.clear }
                            }.frame(width: 62, height: 62).contentShape(Circle())
                                .overlay(Circle().strokeBorder(drag.swept.contains(index) ? WorldCardFinish.gold : .clear, lineWidth: 3))
                                .background(Color.clear.onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { drag.plotFrames[index] = $0 })
                        }.buttonStyle(WorldCardPress()).worldMenuAnchor("plot.\(index)").accessibilityLabel("Field \(index + 1)").accessibilityValue(state.accessibilityValue)
                            .accessibilityAddTraits(field == index ? .isSelected : []).accessibilityIdentifier("homestead.farm.field.\(index)")
                        // Each bed has its own hand: one tap plants, waters or harvests just this plot.
                        if allowsChanges, [0, 1, 4].contains(stage), let icon = tool(for: stage).icon {
                            Button { field = index; tend(index, now: Date()) } label: {
                                WorldToolPicture(icon: icon).frame(width: 34, height: 34).frame(width: 46, height: 46)
                                    .background(Circle().fill(stage == 4 ? Color(livingWorldHex: "#8FCB63") : .white).shadow(color: .black.opacity(0.22), radius: 3, y: 2))
                            }.buttonStyle(WorldCardPress()).offset(y: 8)
                                .accessibilityLabel(Text(LocalizedStringKey(tool(for: stage).label + " field \(index + 1)")))
                                .accessibilityIdentifier("homestead.farm.field.\(index).tend")
                        }
                    }
                }
            }.padding(.bottom, 18)
        }
    }

    // MARK: Orchard and orders

    private func orchardState(now: Date) -> HomesteadTimeState {
        farm.orchardWatered.map { .clock(end: $0.addingTimeInterval(HomesteadFarm.orchardSeconds), duration: HomesteadFarm.orchardSeconds, now: now) } ?? .waiting
    }
    private func orchardTool(now: Date) -> some View {
        let state = orchardState(now: now)
        return toolTile(icon: state.phase == .working ? nil : state.phase == .ready ? "farm.fruit" : "tool.can",
                        label: state.phase == .waiting ? "Water" : state.phase == .ready ? "Pick +3" : "Growing", id: "orchard", ready: state.phase == .ready) {
            if farm.tendOrchard() { committed(.fruit, state.phase == .ready, "orchard:" + UUID().uuidString) }
        }
    }
    @ViewBuilder private var orderInput: some View {
        if nookOwned && !farm.picnicServed {
            let ready = farm.picnicFunded && placed.contains(.nook)
            toolTile(icon: placed.contains(.nook) ? "farm.meal" : "lock", label: placed.contains(.nook) ? "Serve" : "Place nook", id: "serve", ready: ready) {
                guard ready else { inspect(.nook); return }
                if farm.servePicnic() { committed(.meal, false, "picnic:" + UUID().uuidString); celebrate() }
            }
        } else {
            let good = farm.orderGood, have = farm[good] > 0
            toolTile(icon: "farm." + good.rawValue, label: farm.orders == 0 ? "Share" : "Deliver", id: "deliver", ready: have, count: farm[good]) {
                guard have else { source(good); return }
                if farm.deliver() { committed(good, false, "order:" + UUID().uuidString); celebrate() }
            }
        }
    }
    /// One thing to carry or tap. A nil icon means the place is busy.
    private func toolTile(icon: String?, label: String, id: String, ready: Bool, waiting: Bool = false, count: Int? = nil, sweepStage: Int? = nil, act: @escaping () -> Void, sweep: ((CGPoint) -> Void)? = nil) -> some View {
        let acts = allowsChanges && icon != nil && !waiting
        return Button { session?.control("farm.action"); WorldMenuFeedback.touch(.wood); if acts { act() } } label: {
            Group {
                if let icon { toolPicture(icon).saturation(waiting ? 0.3 : 1) } else { WorldControlIcon(symbol: "hourglass") }
            }.frame(width: 72, height: 72).frame(width: 100, height: 100).background(WorldTileSurface(lit: ready))
                .overlay { if ready && !reduceMotion { WorldReadyShimmer().clipShape(RoundedRectangle(cornerRadius: 22)) } }
                .overlay(alignment: .bottomTrailing) { if let count { WorldCountBadge(text: "\(count)", alert: count == 0).offset(x: 6, y: 6) } }
                .opacity(acts ? 1 : 0.55)
        }.buttonStyle(WorldCardPress()).disabled(!acts).worldMenuAnchor("farm.action")
            // Always attached, so a stroke still ends after the tool changes underneath it.
            .simultaneousGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named(space)).onChanged { value in
                if drag.held == nil {
                    guard acts, let icon else { return }
                    drag.sweepStage = sweepStage ?? -1; drag.swept = []
                    drag.lift(.tool(icon), at: value.location)
                } else if case .tool(let carried) = drag.held { drag.lift(.tool(carried), at: value.location) }
                sweep?(value.location)
            }.onEnded { value in
                guard drag.held != nil else { return }
                let hit = sweep == nil && drag.overWell(value.location)
                drag.release(into: hit, reduceMotion: reduceMotion); drag.swept = []
                if hit { act() }
            })
            .accessibilityLabel(Text(LocalizedStringKey(label)))
            .accessibilityValue(Text(LocalizedStringKey(!allowsChanges ? "Disabled" : icon == nil || waiting ? "Working" : ready ? "Ready" : "Available")))
            .accessibilityHint(allowsChanges ? "" : "Ask your parent to check access")
            .accessibilityIdentifier("homestead.farm." + id)
    }
    @ViewBuilder private func toolPicture(_ icon: String) -> some View {
        WorldToolPicture(icon: icon)
    }
}

struct WorldFarmStationMenu: View {
    let farm: HomesteadFarm
    let placed: Set<HomesteadKind>
    let action: (HomesteadFarm.Station) -> Void
    var body: some View {
        HomesteadItemStrip(items: HomesteadFarm.Station.allCases, minimumWidth: 124, rowHeight: 124) { station in
            let owned = placed.contains(station.kind)
            Button { WorldMenuFeedback.touch(.wood); action(station) } label: {
                Image(station.heroArtwork).resizable().scaledToFit().frame(width: 100, height: 86)
                    .saturation(owned ? 1 : 0.2).opacity(owned ? 1 : 0.7)
                    .overlay(alignment: .bottomTrailing) {
                        if !owned { WorldControlIcon(symbol: "lock").frame(width: 26, height: 26).padding(4).background(Circle().fill(WorldCardFinish.cream)) }
                    }
                    .frame(width: 124, height: 124).background(WorldTileSurface())
            }.buttonStyle(WorldCardPress()).accessibilityLabel(station.title)
                .accessibilityValue(owned ? "Available" : "Build " + station.kind.title)
                .accessibilityIdentifier("homestead.station." + station.rawValue)
        }
    }
}
