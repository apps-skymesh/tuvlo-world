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

---

# Second systems pass: in season (2026-11-04)

## The loops after market demand

| Loop | What the player does | Real choices |
|---|---|---|
| **30 seconds** | Farm taps, start or collect a job, sell one unit. | Sell now or wait (demand). Farm taps are still a rhythm, not a choice. |
| **5 minutes** | Turn wheat into goods and spread sales across goods and time. | Which chain to run. A glut points to another good. |
| **Session** | Levels from sales, builds, valley tiers, daily gift. | Build order. |

## What was still weak

1. **Demand only punishes.** It says what not to sell, never what to aim for. Starting a job is still reactive: look at what's glutted and make something else.
2. **The long timers don't plan anything.** A 10-minute tart or 8-minute cheese is just a wait, because the price at the end is the price now.
3. **Holding stock has one answer.** With demand alone, holding never pays more than the base price, so the right amount to hold is always "whatever is glutted".
4. **Wheat is a fixed bottleneck with no allocation call.** It feeds the mill and the barn, but whichever pays more per wheat always wins.

## The change: in season

There is one new rule, and it adds one strip under the Market awning.

> For each ten-minute window, the market favours one good you can make. It sells for half again as much. The next window's good is shown in advance.

- `WorldCatalogue.season_good(window, makeable)` picks the good. It steps through the makeable goods by a prime, so every good comes round, none runs twice in a row, and every device agrees.
- `WorldState.makeable_goods()` lists the goods the owned places can make. With only one (a new farm with just wheat) there is no season, so the early game is unchanged. The season appears with the windmill.
- `unit_price(good, glut, in_season)` applies the bonus before demand. The premium therefore still drops per unit sold.
- The Market strip shows the good, "+50%", the time left and the next good's icon. A dipped price shows "-N%" in coral; a season price shows "+50%" in gold in the same fixed slot.
- The stall now reprices live: its rebuild signature includes the season window and the current prices.

| Value (`scripts/game/catalogue.gd`) | Setting | Effect |
|---|---|---|
| `SEASON_SECONDS` | 600 | Window length (120 s in quick play). |
| `SEASON_BONUS` | 0.5 | Premium on the season good. |
| `SEASON_STEP` | 7919 | Prime step through the makeable goods. |

### Determinism and saves

- New sale records freeze `season`, the window length at the time of sale, alongside `recover`.
- Replay recalculates the season good from the record's time and the places owned at that point in the replay, and rejects a mismatched amount (`"price"`).
- Sales from the demand pass carry `recover` but no `season`, and replay them at the plain price. Older sales keep their saved amount. Schema `v: 1` is unchanged.

## How the two rules combine

The two rules pull in opposite directions, and the answer is a skill, not a lookup:

- The season raises the ceiling on one good.
- Demand caps how many of it are worth selling: bread in season sells at 8, 7, 6, 5, 4…

So the best play is to hold a small batch (about three or four) of the next season good and sell it when the window opens. A larger hoard gains nothing.

Worked example, five bread:

| Plan | Coins |
|---|---|
| All five, out of season, at once | 5 + 4 + 4 + 3 + 3 = 19 |
| All five, in season, at once | 8 + 7 + 6 + 5 + 4 = 30 |
| Three in season, two more after about 2 min of recovery, same window | 8 + 7 + 6 + 8 + 7 = 36 |

## New decisions per minute

- **What to start now is a forecast.** "Next: tart" with 7 minutes left makes the 10-minute tart a bet on finishing in time, against a 5-minute bread for the current window. The timer ladder becomes positioning in time.
- **Where the wheat goes.** Cheese in season makes the barn worth more per wheat than the mill for that window, and the answer changes every window.
- **Sell, hold or deliver, again.** A neighbour asking for the season good is now a real trade-off: their fixed reward against the boosted market.
- **How many to hold.** Holding pays when a window is coming and demand would cut the batch anyway. That is a push-your-luck amount with an answer that depends on the clock.
- **Dead time has a purpose.** Waiting is now waiting for the window, and coming back at the turn pays.

There is no new currency or button. The only new screen element is a single read-only strip on the existing Market screen.

## Next candidates

- Show the season good as a small badge on the goal ticket or the Market dock button, if playtests show people miss it.
- A neighbour wish could count as "in season" for that one good.
- Farm choice (different crops) is still the open gap in the 30-second loop.
