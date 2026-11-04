import Foundation

nonisolated struct HomesteadProjection: Codable, Equatable, Sendable {
    let growthTreeID: UUID
    private(set) var revision: String
    let items: [HomesteadObject]
    let land: [String]
    let discovered: Bool
    let approvedWins: Int
    let appearance: [String: Int]
    let reducedMotion: Bool
    /// Ready materials by scene key: a piece ID, or a fixed edge producer name.
    let harvest: [String: String]
    /// Preserve the mainland scenery independently of retired collection actions.
    let edges: Bool
    let ovenRevealed: Bool?
    let visitor: String
    /// A villager who remains after the lead visitor arrives. Empty when alone.
    let company: String
    let wheatGarden: Bool
    private(set) var farmStages: [Int]?
    private(set) var farmFruitStage: Int?
    private(set) var production: [HomesteadProductionStatus]
    private(set) var construction: [HomesteadConstructionStatus]

    @MainActor
    init(kid: Child, reducedMotion: Bool, look previewLook: KidAppearance? = nil, extras previewExtras: HomesteadAppearanceExtras? = nil, project previewProject: LivingWorldProject? = nil, style previewStyle: Int = 0, starterPreview: LivingWorldStarter.Event? = nil, workshopPreview: HomesteadObject? = nil, farmStages: [Int]? = nil, farmFruitStage: Int? = nil, bakerPresent: Bool? = nil, storytellerPresent: Bool? = nil, production: [HomesteadProductionStatus] = [], ovenRevealed: Bool? = nil, now: Date = Date()) throws {
        growthTreeID = HomesteadIdentity.stable(childID: kid.id, key: "base:tree")
        let state = try HomesteadActions.state(for: kid)
        var renderedItems = state.objects
        if let starterPreview, let count = starterPreview.homesteadBuildCount {
            let baseline = try HomesteadMigration.baseline(for: kid, previewStarterCount: count)
            let owned = Set(renderedItems.map(\.id))
            // Fit newly supplied pieces around the child's saved arrangement.
            // Opening a draft must never relocate a piece they already placed.
            for var item in baseline.objects where !owned.contains(item.id) {
                item.cell = HomesteadGeometry.nearestPlacement(for: item, among: renderedItems, land: state.land)
                renderedItems.append(item)
            }
        }
        if let project = previewProject {
            if let index = renderedItems.firstIndex(where: { $0.kind == project.worldKind }) {
                renderedItems[index].style = previewStyle
                if renderedItems[index].cell == nil {
                    renderedItems[index].cell = HomesteadGeometry.nearestPlacement(for: renderedItems[index], among: renderedItems, land: state.land)
                }
            } else {
                var sample = HomesteadObject(id: HomesteadIdentity.stable(childID: kid.id, key: "preview:\(project.rawValue)"), kind: project.worldKind, cell: nil, rotation: 0, style: previewStyle)
                sample.cell = HomesteadGeometry.nearestPlacement(for: sample, among: renderedItems, land: state.land)
                if sample.cell != nil { renderedItems.append(sample) }
            }
        }
        if let workshopPreview, !renderedItems.contains(where: { $0.id == workshopPreview.id }) { renderedItems.append(workshopPreview) }
        items = renderedItems
        land = state.land.map(\.rawValue).sorted()
        discovered = state.discovered
        // Sandbox completions unlock every purchase in a disposable child. They are
        // not a family's approved missions, so they do not grow the tree, cottage, or path.
        #if DEBUG
        approvedWins = WorldSandboxSession.isSandbox(kid) ? 0 : EconomyLedger.forChild(kid).approvedWins
        #else
        approvedWins = EconomyLedger.forChild(kid).approvedWins
        #endif
        let building = HomesteadConstruction.pending(kid: kid, now: now)
        let buildingKinds = Set(building.map(\.kind))
        construction = building.compactMap { build in
            guard let place = state.objects.first(where: { $0.kind == build.kind && $0.isPlaced }) else { return nil }
            return .init(placeID: place.id.uuidString, remaining: build.remaining(at: now), progress: build.progress(at: now))
        }
        let ledger = HomesteadMaterialLedger(kid: kid, now: now, objects: state.objects, land: state.land)
        var ready: [String: String] = [:]
        for producer in ledger.readyProducers {
            let material = ledger.ready(producer).parts.first?.material.rawValue ?? producer.mainMaterial.rawValue
            if let kind = producer.kind {
                if let item = state.objects.first(where: { $0.kind == kind && $0.isPlaced }) { ready[item.id.uuidString] = material }
            } else { ready[producer.rawValue] = material }
        }
        let showOven = ovenRevealed ?? (!LivingWorldStarter(kid: kid).isEligible
            || HomesteadFarmJournal(kid: kid).farm.hasIntroducedOven)
            || production.contains { $0.state > 0 && ["oven", "pantry"].contains($0.station) }
        self.ovenRevealed = showOven
        let opening = HomesteadOpeningLedger(kid: kid)
        if opening.ready(wins: approvedWins, day: FamilyDay.key(for: Date(), in: .current)) > 0,
           let garden = state.objects.first(where: { $0.kind == .garden && $0.isPlaced }) {
            ready[garden.id.uuidString] = "wheat"
        }
        wheatGarden = opening.started
        self.farmStages = farmStages
        self.farmFruitStage = farmFruitStage
        if farmStages != nil {
            for item in state.objects where [.garden, .windmill, .orchard].contains(item.kind) { ready[item.id.uuidString] = nil }
        }
        self.production = Self.linkProduction(production.filter { showOven || !["oven", "pantry"].contains($0.station) }, items: state.objects, buildingKinds: buildingKinds)
        let baker = bakerPresent ?? opening.hasBaked
        let storyteller = storytellerPresent ?? (opening.picnic && state.objects.contains { $0.kind == .nook && $0.isPlaced })
        if storyteller {
            visitor = "storyteller"
            company = baker ? "baker" : ""
        } else {
            visitor = baker ? "baker" : ""
            company = ""
        }
        harvest = ready
        edges = LivingWorldStarter(kid: kid).count == 3
        self.reducedMotion = reducedMotion
        let look = previewLook ?? KidAppearance.displayed(characterID: kid.characterID)
        let extra = previewExtras ?? state.extras ?? HomesteadAppearanceExtras(characterID: kid.characterID)
        appearance = [
            "skin": look.skin, "hair": KidAppearance.Hair.allCases.firstIndex(of: look.hair) ?? 0,
            "hair_color": look.hairColor, "outfit": KidAppearance.Outfit.allCases.firstIndex(of: look.outfit) ?? 0,
            "top": look.outfitColor, "face": KidAppearance.FaceShape.allCases.firstIndex(of: look.faceShape) ?? 0,
            "eyes": look.eyes == .round ? 0 : look.eyes == .wide ? 1 : 2,
            "eye_color": extra.eyeColor, "glasses": look.glasses ? 1 : 0, "freckles": look.face == .freckles ? 1 : 0,
            "expression": KidAppearance.Face.allCases.firstIndex(of: look.face) ?? 0,
            "hat": KidAppearance.Hat.allCases.firstIndex(of: look.hat) ?? 0,
            "pattern": KidAppearance.Pattern.allCases.firstIndex(of: look.pattern) ?? 0,
            "height": extra.height, "build": extra.build, "bottom": extra.bottomColor,
            "shoes": extra.shoeColor, "accessory": extra.accessory, "scarf": extra.accessoryColor
        ]
        revision = ""
        try updateRevision()
    }

    /// Clock ticks only update presentation values. Saved placements, receipts,
    /// materials and appearance are refreshed by the canonical state-change path.
    @MainActor
    mutating func updateTimers(farmStages: [Int], farmFruitStage: Int,
                               production: [HomesteadProductionStatus],
                               building: [HomesteadConstruction], now: Date) throws {
        self.farmStages = farmStages
        self.farmFruitStage = farmFruitStage
        updateConstruction(building, now: now)
        let showOven = ovenRevealed != false
        self.production = Self.linkProduction(production.filter { showOven || !["oven", "pantry"].contains($0.station) }, items: items, buildingKinds: Set(building.map(\.kind)))
        try updateRevision()
    }

    @MainActor
    mutating func updateConstructionTimers(building: [HomesteadConstruction], now: Date) throws {
        updateConstruction(building, now: now)
        try updateRevision()
    }

    @MainActor
    private mutating func updateConstruction(_ building: [HomesteadConstruction], now: Date) {
        construction = building.compactMap { build in
            guard build.remaining(at: now) > 0,
                  let place = items.first(where: { $0.kind == build.kind && $0.isPlaced }) else { return nil }
            return .init(placeID: place.id.uuidString, remaining: build.remaining(at: now), progress: build.progress(at: now))
        }
    }

    private static func linkProduction(_ production: [HomesteadProductionStatus], items: [HomesteadObject],
                                       buildingKinds: Set<HomesteadKind>) -> [HomesteadProductionStatus] {
        production.compactMap { status in
            let kind: HomesteadKind
            switch status.station {
            case "field": kind = .garden
            case "mill": kind = .windmill
            case "oven", "pantry": kind = .cottage
            case "barn": kind = .barn
            case "grill": kind = .grill
            case "orchard": kind = .orchard
            default: return nil
            }
            guard !buildingKinds.contains(kind), let place = items.first(where: { $0.kind == kind && $0.isPlaced }) else { return nil }
            var result = status; result.placeID = place.id.uuidString
            return result
        }
    }

    private mutating func updateRevision() throws {
        struct Content: Codable { let items: [HomesteadObject]; let appearance: [String:Int]; let wins: Int; let discovered: Bool; let land: [String]; let harvest: [String: String]; let edges: Bool; let ovenRevealed: Bool?; let visitor: String; let company: String; let wheatGarden: Bool; let farmStages: [Int]?; let farmFruitStage: Int?; let production: [HomesteadProductionStatus]; let construction: [HomesteadConstructionStatus] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        revision = HomesteadIdentity.digest(try encoder.encode(Content(items: items, appearance: appearance, wins: approvedWins, discovered: discovered, land: land, harvest: harvest, edges: edges, ovenRevealed: ovenRevealed, visitor: visitor, company: company, wheatGarden: wheatGarden, farmStages: farmStages, farmFruitStage: farmFruitStage, production: self.production, construction: construction)))
    }
}
