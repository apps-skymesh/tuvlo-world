import SwiftUI

/// Shared compact production controls for saved World and disposable play.
struct HomesteadFarmPanel: View {
    let farm: HomesteadFarm
    @Binding var station: HomesteadFarm.Station
    let placed: Set<HomesteadKind>
    let nookOwned: Bool
    let inspect: (HomesteadKind) -> Void
    let collectRecipe: (HomesteadFarm.Station) -> Bool
    var celebrate: () -> Void = {}
    var construction: [HomesteadConstruction] = []
    @State private var chosenRecipe = HomesteadFarm.Recipe.bread
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            HStack(spacing: 12) {
                switch station {
                case .field: fields(now: clock.date)
                case .mill: production(.flour, now: clock.date)
                case .oven:
                    production(farm.jobs[.oven]?.recipe ?? chosenRecipe, now: clock.date)
                    if placed.contains(.orchard) {
                        action(chosenRecipe == .bread ? "Tart" : "Bread", icon: "arrow.triangle.2.circlepath", id: "recipe") {
                            chosenRecipe = chosenRecipe == .bread ? .tart : .bread
                        }.disabled(farm.jobs[.oven] != nil)
                    }
                case .barn: production(farm.jobs[.barn]?.recipe ?? .livestock, now: clock.date)
                case .grill: production(.grilledMeal, now: clock.date)
                case .pantry: production(.meal, now: clock.date)
                case .orchard: orchard(now: clock.date)
                case .orders: orders(now: clock.date)
                }
            }.frame(height: 96).lineLimit(1)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("homestead.farm")
    }
    private func fields(now: Date) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Wheat field").font(.subheadline.bold())
                supply(.wheat)
            }.fixedSize()
            ForEach(farm.fields.indices, id: \.self) { index in
                let field = farm.fields[index]
                let stage = field.stage(at: now)
                let time = field.wateredAt.map { HomesteadTimeState.clock(end: $0.addingTimeInterval(HomesteadFarm.fieldSeconds), duration: HomesteadFarm.fieldSeconds, now: now) } ?? .waiting
                Button {
                    if farm.tend(index) { feedback(stage == 1 ? .water : stage == 4 ? .collect : .plant) }
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            HomesteadBreadArt(scene: .patch, amount: stage == 4 ? 3 : stage >= 1 ? 1 : 0).frame(width: 28, height: 32).accessibilityHidden(true)
                            HomesteadSunRing(state: time, size: 40)
                        }
                        Text(stage == 0 ? "Plant" : stage == 1 ? "Water" : stage == 4 ? "Harvest +2" : "Growing")
                            .font(.caption.bold())
                        if stage < 2 { HomesteadDurationLabel(seconds: Int(HomesteadFarm.fieldSeconds)).frame(height: 14) }
                        else { Color.clear.frame(height: 14).accessibilityHidden(true) }
                    }.padding(6).frame(maxWidth: .infinity, minHeight: 80)
                        .background(Color(livingWorldHex: stage == 4 ? "#F4D68A" : "#D9E2C8"), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                }.buttonStyle(HomesteadMenuButtonStyle(showsDisabledMark: false)).disabled(stage == 2 || stage == 3)
                    .accessibilityLabel("Field \(index + 1)")
                    .accessibilityValue(stage == 0 ? "Empty. Plant wheat" : stage == 1 ? "Planted. Water wheat" : stage == 4 ? "Ready. Harvest two wheat" : time.accessibilityValue)
                    .accessibilityIdentifier("homestead.farm.field.\(index)")
            }
            next("Mill", station: .mill, kind: .windmill)
        }
    }
    @ViewBuilder private func production(_ recipe: HomesteadFarm.Recipe, now: Date) -> some View {
        let kind = recipe.station.kind
        if !placed.contains(kind) {
            Image("WorldPlace_" + kind.rawValue).resizable().scaledToFit().frame(width: 60, height: 60)
            Text(recipe == .livestock ? "Wheat → sheep → meat" : recipe == .meatDelivery ? "Bread → delivery" : recipe == .grilledMeal ? "Meat → meals" : recipe.station == .mill ? "Wheat → flour" : "Flour → bread").font(.subheadline.bold())
            Spacer(minLength: 0)
            if let build = construction.first(where: { $0.kind == kind }) {
                constructionAction(build, now: now, id: "build")
            } else { requirement("Build " + kind.title.lowercased(), id: "build") { inspect(kind) } }
        } else {
            HStack(spacing: 8) {
                if recipe == .meatDelivery {
                    Text("Trade").font(.caption.bold())
                        .accessibilityHint("Finishing an earlier bread delivery.")
                }
                ForEach(HomesteadFarm.Good.allCases.filter { recipe.input[$0] != nil }, id: \.self) { good in
                    Button { showSource(good) } label: {
                        VStack(spacing: 2) {
                            HomesteadFarmGoodIcon(good: good).frame(width: 48, height: 44)
                            Text("\(farm[good])/\(recipe.input[good, default: 0])").font(.caption.bold()).monospacedDigit()
                            Text(good.title).font(.caption)
                        }.frame(minWidth: 48, minHeight: 56).contentShape(Rectangle())
                            .foregroundStyle(farm[good] >= recipe.input[good, default: 0] ? Color(livingWorldHex: "#243C32") : Color(livingWorldHex: "#A4563D"))
                    }.buttonStyle(HomesteadMenuButtonStyle())
                        .accessibilityLabel("\(good.title), \(farm[good]) of \(recipe.input[good, default: 0])")
                        .accessibilityHint("Open ingredient source")
                        .accessibilityIdentifier("homestead.farm.source." + good.rawValue)
                }
                if farm.jobs[recipe.station] == nil { HomesteadSunRing(state: .waiting, size: 32) }
                else { Image(systemName: "arrow.right").font(.caption.bold()) }
                if recipe == .livestock {
                    VStack(spacing: 2) {
                        WorldControlIcon(symbol: "sheep").frame(width: 48, height: 44)
                        Text("Sheep").font(.caption)
                        Color.clear.frame(height: 14)
                    }.accessibilityElement(children: .ignore).accessibilityLabel("Raise sheep")
                    Image(systemName: "arrow.right").font(.caption.bold())
                }
                VStack(spacing: 2) {
                    HomesteadFarmGoodIcon(good: recipe.output).frame(width: 48, height: 44)
                    Text("\(recipe.quantity)").font(.caption.bold()).monospacedDigit()
                    Text(recipe.output.title).font(.caption)
                }
            }.frame(maxWidth: .infinity)
            if let job = farm.jobs[recipe.station] {
                VStack(spacing: 4) {
                    if job.remaining(at: now) == 0 {
                        HStack(spacing: 4) {
                            HomesteadSunRing(state: .ready, size: 40)
                            action("Collect", icon: "tray.and.arrow.down.fill", id: "collect") {
                                if collectRecipe(recipe.station) { feedback(.collect) }
                            }.accessibilityValue("Ready")
                        }
                    } else {
                        HomesteadSunRing(state: .clock(end: job.finish, duration: job.recipe.seconds, now: now), size: 52)
                            .accessibilityIdentifier("homestead.farm.job")
                    }
                }.frame(minWidth: 88)
            } else {
                VStack(spacing: 3) {
                    if let missing = HomesteadFarm.Good.allCases.first(where: { farm[$0] < recipe.input[$0, default: 0] }) {
                        requirement("\(recipe.input[missing, default: 0]) " + missing.title, id: "make") { showSource(missing) }
                    } else {
                        action(recipe == .livestock ? "Feed" : recipe == .meatDelivery ? "Trade" : recipe == .grilledMeal ? "Grill" : "Make", icon: recipe == .livestock ? "leaf.fill" : "play.fill", id: "make") { if farm.make(recipe) { feedback(recipe == .flour ? .mill : recipe == .livestock ? .sheep : recipe == .grilledMeal ? .grill : .place) } }
                    }
                    HomesteadDurationLabel(seconds: Int(recipe.seconds))
                }
            }
            VStack(spacing: 3) { supply(recipe.output) }.fixedSize()
        }
        switch recipe {
        case .meatDelivery, .livestock: next("Grill", station: .grill, kind: .grill)
        case .grilledMeal: next("Farm", station: .field, kind: .garden)
        case .flour: next("Oven", station: .oven, kind: .cottage)
        case .bread:
            next("Meals", station: .pantry, kind: .cottage)
            next("Barn", station: .barn, kind: .barn)
        case .meal:
            if !nookOwned {
                if farm[.meal] < 3 {
                    requirement("3 meals", id: "nook") { station = .pantry }
                } else { action("Nook", icon: "hammer.fill", id: "nook") { inspect(.nook) } }
            } else { next("Picnic", station: .orders, kind: .nook) }
        case .tart: next("Orders", station: .orders, kind: .cottage)
        }
    }
    private func orchard(now: Date) -> some View {
        HStack(spacing: 12) {
            Image("WorldPlace_orchard").resizable().scaledToFit().frame(width: 80, height: 70)
            if !placed.contains(.orchard) {
                Text("Fruit → tarts").font(.subheadline.bold())
                if let build = construction.first(where: { $0.kind == .orchard }) {
                    constructionAction(build, now: now, id: "build.orchard")
                } else { requirement("Build orchard", id: "build.orchard") { inspect(.orchard) } }
            } else {
                supply(.fruit)
                Spacer(minLength: 0)
                let growing = farm.orchardWatered != nil && farm.orchardRemaining(at: now) > 0
                if growing {
                    VStack(spacing: 4) {
                        HomesteadSunRing(state: .clock(end: farm.orchardWatered!.addingTimeInterval(HomesteadFarm.orchardSeconds), duration: HomesteadFarm.orchardSeconds, now: now), size: 52)
                    }.frame(width: 88)
                } else {
                    VStack(spacing: 0) {
                        HomesteadSunRing(state: farm.orchardWatered == nil ? .waiting : .ready, size: 40)
                        if farm.orchardWatered == nil { HomesteadDurationLabel(seconds: Int(HomesteadFarm.orchardSeconds)) }
                    }
                    action(farm.orchardWatered == nil ? "Water" : "Pick +3", icon: farm.orchardWatered == nil ? "drop.fill" : "basket.fill", id: "orchard") {
                        let picking = farm.orchardWatered != nil
                        if farm.tendOrchard() { feedback(picking ? .collect : .water) }
                    }
                }
                action("Tart", icon: "arrow.right", id: "tart") { chosenRecipe = .tart; station = .oven }
            }
        }
    }
    private func orders(now: Date) -> some View {
        HStack(spacing: 12) {
            if nookOwned && !farm.picnicServed {
                Image("WorldPlace_nook").resizable().scaledToFit().frame(width: 72, height: 64)
                Text("Reading picnic").font(.subheadline.bold())
                Spacer(minLength: 0)
                if placed.contains(.nook) {
                    if farm.picnicFunded {
                        action("Serve", icon: "basket.fill", id: "serve") { if farm.servePicnic() { feedback(.success); celebrate() } }
                    } else { requirement("Nook", id: "serve") { inspect(.nook) } }
                } else if let build = construction.first(where: { $0.kind == .nook }) {
                    constructionAction(build, now: now, id: "place.nook")
                } else { action("Place", icon: "arrow.down", id: "place.nook") { inspect(.nook) } }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(farm.orders == 0 ? "Share bread" : "Tea for friends").font(.subheadline.bold())
                    Text(farm.orders == 0 ? "The loaf stays" : "1 fruit tart").font(.caption)
                }
                HomesteadFarmGoodIcon(good: farm.orderGood).frame(width: 48, height: 44)
                supply(farm.orderGood)
                Spacer(minLength: 0)
                if farm[farm.orderGood] < 1 {
                    requirement("1 " + farm.orderGood.title, id: "deliver") { showSource(farm.orderGood) }
                } else if farm.orders == 0 {
                    action("Share", icon: "gift.fill", id: "deliver") { if farm.deliver() { feedback(.success); celebrate() } }
                } else {
                    action("Deliver", icon: "gift.fill", id: "deliver") { if farm.deliver() { feedback(.success); celebrate() } }
                }
                action("Farm", icon: "leaf.fill", id: "field") { station = .field }
                action("Fruit", icon: "tree.fill", id: "fruit") { station = .orchard }
            }
        }
    }
    private func supply(_ good: HomesteadFarm.Good) -> some View {
        Button { showSource(good) } label: {
            HStack(spacing: 4) {
                HomesteadFarmGoodIcon(good: good).frame(width: 30, height: 30)
                Text("\(farm[good])").font(.subheadline.bold()).monospacedDigit()
            }.frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityElement(children: .ignore).accessibilityLabel("\(farm[good]) \(good.title)")
            .accessibilityAddTraits(.isButton).accessibilityHint("Open ingredient source")
            .accessibilityIdentifier("homestead.farm.stock." + good.rawValue)
    }
    private func showSource(_ good: HomesteadFarm.Good) {
        switch good {
        case .meat: station = .barn
        case .wheat: station = .field
        case .flour: station = .mill
        case .bread: chosenRecipe = .bread; station = .oven
        case .meal: station = .pantry
        case .fruit: station = .orchard
        case .tart: chosenRecipe = .tart; station = .oven
        }
    }
    private func next(_ title: String, station next: HomesteadFarm.Station, kind: HomesteadKind) -> some View {
        Button { SoundEffects.playTapConfirm(); station = next } label: {
            VStack(spacing: 3) {
                Group {
                    if next == .barn { WorldControlIcon(symbol: "sheep") }
                    else if next == .grill { WorldControlIcon(symbol: "grill") }
                    else {
                        HomesteadFarmGoodIcon(good: next == .field ? .wheat : next == .mill ? .flour : next == .oven ? .bread : next == .orchard ? .fruit : .meal)
                    }
                }.frame(width: 32, height: 32)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1)
            }.frame(minWidth: 62, minHeight: 64).padding(.horizontal, 4)
                .background(HomesteadControlSurface()).contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(title)
            .accessibilityIdentifier("homestead.farm." + next.rawValue)
    }
    private func constructionAction(_ build: HomesteadConstruction, now: Date, id: String) -> some View {
        let state = HomesteadTimeState.clock(end: build.finish, duration: Double(build.seconds), now: now)
        return Button { inspect(build.kind) } label: {
            VStack(spacing: 2) {
                HomesteadSunRing(state: state, size: 40)
                Text(state.phase == .ready ? "Ready" : "Building").font(.caption.bold())
            }.frame(minWidth: 62, minHeight: 64)
        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityLabel(build.kind.title)
            .accessibilityValue(state.accessibilityValue).accessibilityIdentifier("homestead.farm." + id)
    }
    private func requirement(_ title: String, id: String, resolve: @escaping () -> Void) -> some View {
        Button { SoundEffects.playTapConfirm(); resolve() } label: {
            VStack(spacing: 4) {
                Image(systemName: "lock.fill").font(.system(size: 20, weight: .semibold))
                Text(title).font(.caption.bold()).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }.frame(minWidth: 62, minHeight: 64).padding(.horizontal, 4)
                .foregroundStyle(Color(livingWorldHex: "#66705E"))
                .background(HomesteadControlSurface())
                .contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle())
            .accessibilityLabel("Requires " + title).accessibilityHint("Open requirement")
            .accessibilityIdentifier("homestead.farm." + id)
    }
    private func action(_ title: String, icon: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(.caption.bold()).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }.frame(minWidth: 62, minHeight: 64).padding(.horizontal, 4)
                .background(HomesteadControlSurface(prominent: true)).contentShape(Rectangle())
        }.buttonStyle(HomesteadMenuButtonStyle()).accessibilityIdentifier("homestead.farm." + id)
    }
    private enum Feedback { case place, plant, water, collect, mill, sheep, grill, success }
    private func feedback(_ event: Feedback = .place) {
        Haptics.selection()
        switch event {
        case .place: SoundEffects.playPlaceSet()
        case .water: SoundEffects.playPondWater()
        case .plant: SoundEffects.playWorld(.planting)
        case .collect: SoundEffects.playWorld(.harvest)
        case .mill: SoundEffects.playWorld(.milling)
        case .sheep: SoundEffects.playWorld(.sheep)
        case .grill: SoundEffects.playWorld(.grill)
        case .success: SoundEffects.playSuccess()
        }
    }
}
