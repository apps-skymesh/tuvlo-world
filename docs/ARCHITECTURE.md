# Architecture

## One game, many hosts

```
┌──────────────────────── Godot game ────────────────────────┐
│ World scene (land, places, character, camera)               │
│ Game rules: catalogue, recipes, timers, spots, unlocks      │
│ Game UI: HUD, Build tray, place cards, warehouse, market    │
│            │  Host interface (autoload `Host`)              │
└────────────┼────────────────────────────────────────────────┘
     ┌───────┴────────┬──────────────────┬───────────────────┐
  EditorHost      SoloHost (Swift)    TuvloHost (Swift)    later: Android/web
  desktop/tests   local saves, market  Tuvlo ledger,
                  coins, IAP later     missions, receipts
```

The game never creates or spends money on its own. It asks the host. That is what lets the same game run solo and inside Tuvlo without forking.

## Host interface (version 1, draft)

| Call | Meaning | Solo | Tuvlo |
| --- | --- | --- | --- |
| `player()` | Stable ID, name, appearance, Reduce Motion, sound and music | Local profile | Child and existing settings |
| `wallet()` | Balance of the game currency | Market coins | The child's World currency (Coins or Stars, including the check-in bonus) |
| `progress()` | Lifetime count that gates unlocks; never decreases | Level from lifetime sales | Approved mission wins |
| `load_records()` / `append_records(list)` | Versioned append-only events (`living-world:v1:*` and newer kinds) | Local file | `WorldPlacement` rows with sync and backup |
| `commit_purchase(request_id, price, items)` | Atomic debit plus records; returns a frozen receipt; retrying the same `request_id` never charges twice | Local transaction | Existing saved purchase and Payment receipt |
| `grant(request_id, amount, reason)` | Adds currency, for example a market sale | Allowed | **Refused** (Tuvlo forbids play-time earnings) |
| `access()` | `full` or `read_only(reason)` | Always `full` | Trial/plan expiry and parent rules |
| `features()` | What the game may show: `market`, `speed_ups`, `missions_link`, … | `market` (`speed_ups` later) | `missions_link`, no market |

**Transport:** in an iOS shell, the calls travel as versioned JSON over the existing Godot message bridge (`homestead.gd`, `emit_message` / `receive_host_json`, `version: 1`). `EditorHost` implements them in GDScript, so the game runs and is tested on a Mac with no iOS build.

## Rules that keep convergence cheap

1. **Reach money only through `Host`.** No hidden balances in game code.
2. **Records are append-only and versioned.** Never change the meaning of an old record kind. Tuvlo children's existing saves must load.
3. **Features are switched on by the host,** never by build flags in game code.
4. **Bump the interface version on any breaking change** and keep the old one readable.
