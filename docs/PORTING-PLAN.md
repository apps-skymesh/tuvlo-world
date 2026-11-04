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

1. ✅ **Host and rules** (2026-11-04). What landed:
   - `scripts/game/catalogue.gd`: places, prices, gates, spots, recipes, timers and market prices.
   - `game_state.gd`: the replayable state and the renderer snapshot.
   - `world_game.gd`: the actions.
   - `scripts/host/`: `WorldHost` and `LocalHost`.
   - A plain playable UI (`scripts/ui/world_ui.gd`): wallet and level, goods, Build tray, place panel and market.
   - 37 headless checks.

   Importing Tuvlo's saved records waits for convergence.
2. **Designed core loop UI.** Port the HUD wallet, Build tray, place card (goods → place → product, start and collect) and warehouse. Playable on a Mac.
3. **iPhone and iPad.** The export presets are in (`Godot/export_presets.cfg`). The first device run happens on the owner's Mac (see [Run](RUN.md)). A Swift shell is only needed later, for StoreKit.
4. **Market.** Basic selling and levels landed in step 1. Still to do: market design, balancing and orders. This is solo-only.
5. **Later.** Speed-up purchases, iCloud saves and Game Center. Then delete `reference/`.

Building the iOS libgodot and packs currently uses Tuvlo's scripts (`scripts/build-libgodot-ios.sh`, `scripts/prepare-godot-world.py`, `Vendor/SwiftGodotKit`); step 3 brings the parts it needs into this repo.
