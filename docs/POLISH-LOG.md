# Polish log

This log is the memory for repeated improvement passes. Read it before starting a pass so finished work isn't redone, and add one entry per pass. Score each pillar 1–10 and pick the work with Priority = (Delight × Differentiation) / Risk.

## Pass 1 · 2026-11-04

Done before this pass: timers and quick play (#8), the glass interface and fonts (#9), spotlight cards, settings and haptics (#10).

| Pillar | Score | Bottleneck |
|---|---|---|
| Core loop | 5 | Plant → mill → sell works; there's little reason to come back later. |
| Game feel / juice | 6 | Gains flew to the HUD but the wallet jumped; rapid taps could stack tweens. |
| UI / UX | 7 | Glass HUD, dock and cards are consistent. |
| Art / graphics | 6 | Warm grade; the world is still mostly static. |
| Onboarding / FTUE | 6 | The first wheat took a full grow time before anything paid off. |
| Narrative | 3 | No story beat or reason the valley exists. |
| Audio | 5 | Fixed-pitch effects; no sense of a run of gains. |
| Pacing / economy | 5 | Levels come from sales only. |
| Level / balance | 6 | Orders are deterministic and fair. |
| AI / reactivity | 5 | The world doesn't react to the player beyond timers. |
| Technical performance | 7 | Compatibility renderer on mobile, capped effects. |
| Accessibility | 4 | No Reduce Motion; movement everywhere. |

### What this pass changed

1. **Game feel and audio** (Delight 8, Differentiation 6, Risk 2).
   - All timing, scale and pitch values live in `scripts/ui/feel.gd`.
   - Each control keeps one tween per effect (bump, press, count), so spamming a button ends at rest instead of stacking.
   - The wallet rolls up to its new total as the coins land, and retargets cleanly when totals change mid-roll.
   - Consecutive gains climb in pitch within a short window; every effect gets slight pitch jitter.
   - Taps on the map show a soft ripple, so every tap is acknowledged.
   - Flying icons are capped per gain and on screen.
2. **Accessibility: Reduce Motion** (Delight 5, Differentiation 4, Risk 1).
   - A Settings switch, saved with the other settings and passed to the renderer through the host.
   - It turns off the bump, flight, confetti, pulses, motes and bobbing, and shows totals at once. Fades remain.
3. **FTUE: first harvest in 20 s** (Delight 7, Differentiation 3, Risk 2).
   - Only the very first planting uses `FIRST_FIELD_SECONDS`; later wheat uses the normal time. The length is frozen in the record, so replay is unchanged.

### Edge cases checked

`tests/feel_spam_tests.gd` (now part of `scripts/test.sh`):

- 40 rapid open/close cycles of settings, build and market end with no panel open.
- 80 rapid bumps leave the wallet and dock buttons at rest.
- Totals that change faster than the count can finish still land on the real balance.
- 30 rapid flights stay within the on-screen cap.
- The combo pitch stops at its ceiling.
- Reduce Motion skips the bump and flight and shows totals immediately.

Rules (51), runtime and collect tests pass. The 1280×720 capture still runs end to end. Not checked here: physical-device feel and haptics.

### Next pass candidates

1. **Narrative and reactivity**: a "wake the valley" beat. Each level brightens part of the valley (flowers, birds, a lit window), so progress shows in the world, not just the number.
2. **Return reward and adaptive music**: a small daily find on the first visit, and a music layer that adds instruments as the homestead grows.

## Pass 2 · 2026-11-04

Scores after pass 1: juice 7, accessibility 6, FTUE 7. The weakest pillars are now narrative (3) and reactivity (5): levelling only changes a number.

**Chosen: the valley wakes up** (Delight 8, Differentiation 7, Risk 2).
- New `scripts/valley_awakening.gd` (`HomesteadAwakening`) adds a tier of scenery at levels 1, 2, 4, 6, 8 and 10: wildflowers, butterflies, songbirds, a neighbour's farm with lit windows, a drifting balloon, and a rainbow over the hills.
- Tiers are scenery only. They have no colliders or cells, sit outside the starter clearing's fixed spots, and are never removed.
- When the game opens, tiers already reached appear quietly. A tier reached during play grows in with a pop.
- Reduce Motion keeps every tier visible but holds it still: no reveal, flutter, flight or drift.
- The level-up banner names what woke, for example "A balloon drifts by".
- The tier table lives in one const (`TIERS`), so adding a tier means adding one row and its builder.

Edge cases:
- A jump of several levels at once wakes every tier between them, and the banner lists the last two.
- Reopening the game rebuilds the right set without replaying reveals.
- `feel_spam_tests.gd` checks the gates and that the renderer shows exactly the tiers for the current level.

Known limits:
- The north and east flower beds sit where the future north and east regions will go. Revisit when those regions are built.
- Not checked on a device.

### Next pass candidates

1. **Return reward and adaptive music**: a small daily find on the first visit of the day, and a music layer that adds instruments as tiers wake.
2. **Economy pacing**: levels come only from sales. Orders could count extra, and the level curve could be tuned so tiers arrive roughly every few minutes early on and slower later.

## Pass 3 · 2026-11-04

Scores after pass 2: narrative 5, reactivity 6. The weakest pillar is now the core loop (5): nothing gives a reason to return tomorrow.

**Chosen: a daily gift with a streak** (Delight 7, Differentiation 5, Risk 2).
- On the first look at the farm each later day, the gift card opens once.
  - It shows the week's trail of baskets, with today's lifted, and one Collect button.
  - Closing the card keeps the gift waiting on the goal ticket ("Daily gift").
- Consecutive days climb a seven-basket week, from 2 wheat up to 2 bread and a tart, then loop. A missed day starts again at day 1.
- Gifts give goods only: no coins, no sales and no levels. The economy stays driven by play.
- The gift is saved as an append-only `gift` record carrying its local day.
  - Replay accepts one gift per day, so a retry or a second device can't pay twice.
  - Day one never has a gift, and the farm must have been harvested once.

Edge cases:
- Rules tests cover:
  - No gift on day one.
  - One gift per day.
  - A twin record from another device is ignored.
  - The streak climbs, breaks after a missed day, survives replay and loops after day 7.
- A day boundary passed mid-session offers the gift once.
- Time-zone drift is tolerated by ±1 day between the local and UTC day.

Not checked on a device.

### Next pass candidates

1. **Economy pacing**: orders count toward levels and the early level curve is tuned, so a new tier or unlock arrives every few minutes at first.
2. **Adaptive music**: a music layer that adds instruments as valley tiers wake.

## Pass 4 · 2026-11-04 (owner request)

Saeed asked for named neighbours in place of generic market orders, and cheese in place of meat.

- **Valley folk** (`FOLK` in `catalogue.gd`, still reachable as `ORDER_SLOTS`). Each neighbour has their own wish sequence, request lines, thank-you lines, and a keepsake on every third delivery.
  - **Old Maeve**, weaver and baker: wheat, flour and bread. Keepsake: a warm loaf.
  - **Rowan the Bargeman**, river courier: bread, fruit and tarts for the journey. Keepsake: 2 pears.
  - **Bramble**, forager and herbalist: cheese, fruit, meals and tarts. Keepsake: a tart.
  - A neighbour only asks for goods the homestead can already make (`GOOD_SOURCE`).
  - The ticket shows who is asking and why.
  - After a delivery, their thank-you appears along the bottom.
- **Cheese replaces meat.** The barn's flock now makes sheep's cheese, and the grill makes grilled cheese meals. Recipe ids are unchanged.
- **Saves.** Schema `v: 1` is unchanged.
  - Replay reads the old good "meat" as "cheese" (`LEGACY_GOODS`).
  - Orders saved before the folk carry no `folk` field. They replay on their own saved terms and give no keepsake.
  - New order records add `folk` and are checked against that neighbour's sequence.
- **Renderer.** It accepts barn production as "cheese", or "meat" from older hosts, and shows the new cheese art.

Tests: rules 71/0 (9 new checks for folk, keepsakes and legacy saves), feel spam 13/0, runtime and collect pass.
