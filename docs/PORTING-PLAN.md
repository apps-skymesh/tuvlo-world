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
2. ✅ **Designed core loop UI** (2026-11-04). What landed:
   - One wallet (coins and level with a progress bar) at the top, a goal ticket at top left that always names the next step and does it on tap, and only Build (hammer) and Market on the rail.
   - Tapping a place on the map does the obvious thing (plant, water, harvest, pick, collect). Otherwise it opens the place card: goods → the real place framed in a ring → products, with drag or tap to fill and one action.
   - A picture-only Build tray in a single row with spot preview, and a Market sheet with orders and selling.
   - Motion and sound: cards spring in, buttons press, goods and coins fly to the Market and wallet, a level-up banner shows what unlocked, and the World music loops (♪ toggles it).
   - Market orders: three order slots that open with the farm, windmill and barn and pay above the market price (record type `order`). 44 headless checks.
3. **iPhone and iPad.** The export presets are in (`Godot/export_presets.cfg`). The first device run happens on the owner's Mac (see [Run](RUN.md)). A Swift shell is only needed later, for StoreKit.
4. **Market.** Selling, levels and orders have landed. Still to do: balancing and a market stall place. This is solo-only.
5. **Later.** Speed-up purchases, iCloud saves and Game Center. Then delete `reference/`.

Building the iOS libgodot and packs currently uses Tuvlo's scripts (`scripts/build-libgodot-ios.sh`, `scripts/prepare-godot-world.py`, `Vendor/SwiftGodotKit`); step 3 brings the parts it needs into this repo.
