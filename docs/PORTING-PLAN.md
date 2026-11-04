# Porting plan: SwiftUI rules and menus into Godot

Source of truth for behaviour: `reference/tuvlo-swift/` (Tuvlo `b50d5f57`). The game may be redesigned as it's ported, but saved-record compatibility stays (see [Architecture](ARCHITECTURE.md)).

## What moves

| Area | Reference files | Godot target |
| --- | --- | --- |
| **Rules and state** | `HomesteadModel`, `HomesteadState`, `HomesteadActions`, `HomesteadFarm`, `HomesteadConstruction`, `HomesteadMaterials`, `HomesteadSpots`, `HomesteadGoal`, `HomesteadEvent`, `HomesteadConflict`, `LivingWorldExpansion`, `WorldCheckInBonus`, `HomesteadMigration`, `LivingWorld/*`, `WorldModels`, `WorldSpending` | `scripts/game/` as data resources (catalogue, recipes, spots) plus a pure-GDScript state reducer over records |
| **Core menus** | `HomesteadBuilderBar`, `HomesteadToolbelt`, `WorldPlaceCard`, `WorldPlacePage`, `WorldProductionPage`, `WorldWarehousePage`, `HomesteadWorldBalance`, `WorldBuildConfirmation` | `scenes/ui/`: HUD, Build tray, place card, warehouse |
| **Opening and goals** | `HomesteadOpening*`, `TuvloWorldOpening`, `HomesteadGoalCard`, `HomesteadTips`, `*Story*` | `scenes/ui/opening`, goal ticket |
| **Bridge (shell side)** | `HomesteadRuntimeBridge`, `HomesteadNativeRuntimeBridge`, `HomesteadProjection` | Replaced by the `Host` interface; the projection becomes internal game state |

## Order

1. **Host and rules.** Add the `Host` autoload with `EditorHost`, then port the catalogue, recipes, timers, spots and the record reducer. Test it headless against recorded Tuvlo saves.
2. **Core loop UI.** Port the HUD wallet, Build tray, place card (goods → place → product, start and collect) and warehouse. Playable on a Mac.
3. **Solo shell.** Add a minimal Xcode app with SwiftGodotKit: `SoloHost` with local saves and first-run. Playable on iPhone.
4. **Market.** Sell goods for coins and add level progression. This is solo-only.
5. **Later.** Speed-up purchases, iCloud saves and Game Center. Then delete `reference/`.

Building the iOS libgodot and packs currently uses Tuvlo's scripts (`scripts/build-libgodot-ios.sh`, `scripts/prepare-godot-world.py`, `Vendor/SwiftGodotKit`); step 3 brings the parts it needs into this repo.
