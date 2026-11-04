# Core loop audit and market demand

This document records the 2026-11-04 systems pass. It looks at the depth-to-complexity ratio: how many real choices each rule gives the player. It covers what the loops are, where they lacked real choices, and the one rule added to fix the largest gap.

## The loops

| Loop | What the player does | Real choices before this pass |
|---|---|---|
| **30 seconds** | Tap the farm to plant, water and harvest (2 fields). Start or collect a job at the mill, oven, kitchen bench, barn or grill. | None. Each tap has one correct next step. |
| **5 minutes** | Turn wheat into goods, then sell them at the market or deliver them to a neighbour. | Which recipe to run, but one answer always won (below). |
| **Session** | Earn coins, level up from sales, unlock places, build them, wake valley tiers. Collect the daily gift. | Build order, a little. Everything is eventually affordable. |

## Problems found

1. **The market had one best move.** Coins per wheat for each chain, at the old fixed prices:
   - Wheat: 1 coin.
   - Flour: 1.5 coins (2 wheat → 3 coins).
   - Bread: 2.5 coins (2 wheat → flour → 5 coins).
   - Meals: 4.5 coins. One bread packs into 3 meals worth 3 each (9 coins).
   - Grilled meals: 4 meals (12 coins) from cheese and bread that were worth 8 coins on their own.

   The best play was always to push everything to meals and sell them all at once. Neighbours paid 1.5× the market price plus 2, so the market was only for leftovers.
2. **Selling had no timing.** Selling now and selling later paid the same, so the market was a "sell all" button.
3. **Farm taps are always the same.** Plant, water, harvest. This is fine as a calm rhythm, but it gives no choices.
4. **Dead time.** While every timer runs, there is nothing to decide. The daily gift and the neighbours only partly fill this.

## The change: market demand

There is one new rule, and it needs no new screen.

> Each unit you sell lowers that good's next price. The price recovers over time.

- `WorldCatalogue.unit_price(good, glut)` gives one unit's price:
  - `glut` is the number of recent sales of that good that the market has not yet absorbed.
  - The price is the base price × max(`DEMAND_FLOOR`, 1 − `DEMAND_DROP` × glut), rounded, and never less than 1 coin.
- `WorldState.glut_at(good, at)` calculates the glut. It drops by one unit every `DEMAND_RECOVER_SECONDS`.
- `WorldState.quote(good, count, at)` prices a batch one unit at a time.
- Each good has its own demand. Neighbour orders never change it.
- All three tuning values live in `scripts/game/catalogue.gd`:

| Value | Setting | Effect |
|---|---|---|
| `DEMAND_DROP` | 0.12 | Each sale takes 12% off that good's base price. |
| `DEMAND_FLOOR` | 0.4 | The price never drops below 40% of base. |
| `DEMAND_RECOVER_SECONDS` | 45 | One unit of demand returns every 45 s (9 s in quick play). |

### Determinism and saves

- New `sell` records carry `recover`, the recovery time frozen at the moment of sale, just as timers freeze their length.
- Replay recalculates demand from earlier sales and rejects a sale whose `amount` differs from the price at that moment (`"price"`). Two devices therefore agree, and a forged amount can't count.
- Sales saved before this change have no `recover`. They keep their saved amount and still count toward demand. Schema `v: 1` is unchanged.

### What it does to the numbers

Dumping one good all at once now pays less than spreading the sales out:

| Sale | Before | All at once | Spread out (one every 45 s) |
|---|---|---|---|
| 9 meals | 27 | 16 | 27 |
| 4 tarts | 40 | 33 | 40 |
| 3 meals + 1 bread + 1 cheese + 1 flour | 20 | 19 | 20 |

So a mix of goods sold now is worth almost as much as one good held back and sold slowly. "Always make meals" no longer wins every time.

## New decisions per minute

- **Which chain to run.** A meal glut makes bread, tarts or cheese the better job to start next. This choice now changes from minute to minute instead of always having the same answer.
- **Sell, hold or deliver.** A depressed price makes a neighbour's order, or simply waiting, worth more. Before, the order always won.
- **How many to sell.** The "All" button now shows the batch total (for example "All · 16"). Comparing it with the one-unit price is a small push-your-luck call: take the coins now or keep stock for later.
- **Timers become useful.** Dead time is now when demand recovers, so coming back after a mill run pays full price again.

None of this adds a screen, button or currency. The sell button already showed a price, and that number now moves.

## Not done here (next candidates)

- **Neighbour wishes as demand.** A good a neighbour wants could also sell at a small premium, so the player chooses between the market and the neighbour. Hold off until playtests show demand is understood.
- **Farm choice.** The two fields could hold different crops with different timings. This needs art and a decision about seeds.
- **Level pacing.** Levels come from coins earned. Demand slightly slows heavy single-good selling, and heavy single-good selling was the fastest way to level, so watch the early level curve in playtests.
