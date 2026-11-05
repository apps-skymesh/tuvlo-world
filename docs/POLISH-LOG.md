# Polish log

This log is the memory for repeated improvement passes. Read it before starting a pass so finished work isn't redone, and add one entry per pass. Score each pillar 1–10 and pick the work with Priority = (Delight × Differentiation) / Risk.

## Pass 1 · 2026-11-04

Done before this pass: timers and quick play (#8), the glass interface and fonts (#9), spotlight cards, settings and haptics (#10).

| Pillar | Score | Bottleneck |
|---|---|---|
| Core loop | 5 | Plant → mill → sell works; there's little reason to come back later. |
| Game feel / juice | 6 | Gains flew to the HUD but the wallet jumped; rapid taps could stack tweens. |
| UI / UX | 7 | Glass HUD, dock and cards are consistent. |
| Art / graphics | 6 | Warm grade; the world is still mostly static. (Pass 9: living air, value separation.) |
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

## Pass 5 · 2026-11-04 (owner request)

Saeed asked for a time-of-day cycle, wind, environmental sound, and proof that mobile cost stays lean.

- **Day cycle** (`scripts/day_cycle.gd`). The light follows the local clock: dawn, morning gold (the original look), a crisp afternoon, dusky amber, then hearth-glow with the cottage windows lit.
  - It only retunes the existing sun, ambient light, background and valley haze every 4 s. There are no new lights or passes.
  - The window glow uses emission that is always enabled, so dusk never compiles a new shader.
  - The sun stays above about 38°. A lower sun stretched shadows and cost about 4% more draw calls.
  - A sunny-day lift now rises from the cycle's current light.
- **Wind** (`scripts/wind.gd`, `wind.gdshader`). Trees, orchard leaves, flowers, the treehouse canopy, ripening wheat and the distant treeline sway in the vertex shader.
  - Each matte material gets one cached twin, so the batching and draw calls stay the same. The CPU sway loop is gone.
  - Reduce Motion holds them still. Camera fading still works through the original material.
  - The mission tree keeps its own animation. The windmill has no flags; its sails already turn.
- **Ambience** (`scripts/ui/ambience.gd`, volumes in `feel.gd`). A distant river loop, wooden mill creaks while the mill grinds, and bird calls that are frequent at dawn, thinner in the afternoon and absent at night.
  - Three small mono clips (420 KB in total), synthesized for this pass. They follow the Sound effects switch.

**Performance** (`tests/perf_probe.gd`, 1280×720, Compatibility renderer, built farm):

| | Draw calls | Video MB |
|---|---|---|
| Before | 843 | 97.5 |
| Morning | 847 | 97.5 |
| Afternoon | 842 | 97.5 |
| Dusk / evening | 855 | 97.5 |

Static memory rose by about 0.4 MB (the audio). Not measured on an iPhone; sound balance has not been checked by ear.

Tests: rules 71/0, feel spam 20/0 (7 new checks for the day cycle, wind and ambience), runtime and collect pass.

### Next pass candidates

1. **Adaptive music**: layers that follow the day phase and the valley tiers.
2. **Economy pacing**: orders count toward levels; tune the early level curve.

## Pass 6 · 2026-11-04 (owner request: systems pass)

Saeed asked for a core loop audit and one rule that adds depth without adding complexity. The full audit is in [design/CORE-LOOP-AUDIT.md](design/CORE-LOOP-AUDIT.md).

- **Problem found.** The market had one best move: turn everything into meals and sell them all at once.
- **Chosen fix: market demand** (Delight 6, Differentiation 6, Risk 2).
  - Each sale lowers that good's next price by 12% of base, down to 40%. The price recovers one unit every 45 s.
  - The tuning is in `catalogue.gd`. Prices are deterministic and checked on replay.
  - Older sales keep their saved amounts.
  - The "All" button now shows the batch total.
- **Also in this pass:**
  - Removed the river loop, which played on device as constant hiss (#16).
  - Tapping outside a box now closes it (#16).

Tests: rules 83/0 (12 new demand checks), feel spam 23/0.

## Pass 7 · 2026-11-04 (owner request: juice)

Audit findings:
- Interface tweens already use eased, overshooting curves (pass 1).
- The gaps were on the map:
  - Collecting or harvesting only animated the small bubble; the place itself didn't react.
  - A finished build barely moved.
  - Tapping a timer that showed "0:01" opened a menu instead of collecting.

Changes:
- **Impact on the place** (`presentation.punch`, tuning in `feel.gd`). On the frame an action lands, the place dips for 60 ms, stretches for 80 ms and settles elastically over 420 ms. It also throws flecks coloured like what it made (wheat gold, flour white, and so on).
  - Planting or watering uses a softer punch with a light haptic.
  - Collecting uses the full punch together with the existing sound and reward haptic.
  - A finished build uses double strength with a gold burst.
  - Each place runs one punch at a time; a new one replaces the old. Display only: input is never delayed, and Reduce Motion skips it.
- **Timer input buffer** (`TIMER_BUFFER` 0.6 s). A tap on a place whose timer finishes within 0.6 s waits and collects, instead of opening the card. A tap further off still opens the card.

Tests: feel spam 27/0 (3 new checks for the buffer), rules 83/0, runtime and collect pass. Not checked on a device.

## Pass 8 · 2026-11-04 (owner request: UI/UX)

Audit against the 4-second rule. The player should be able to tell what they're working towards, what they can do, and what their last action did.

- **What they're working towards:** clear. The goal ticket and level badge are always visible.
- **What they can do:** mostly clear.
  - The dock has two large buttons.
  - Places on the map open cards.
  - Before this pass, the Build tray opened on a row of places already built (fixed in #17).
- **What the last action did:** weak in two places.
  - A refused action only showed a toast, so the eye had to leave the button to see what happened.
  - The new market demand was invisible apart from a smaller number.
- **Ergonomics:**
  - The dock, Close and Collect targets are 46–78 pt.
  - No action destroys anything; selling everything is a separate "All" button.
  - Tapping outside a box closes it (#16).
- **Immersion:** the Market was a generic dark glass box, the most app-like screen in the game.

Changes:
- **Market as a stall:**
  - A striped awning with a scalloped hem across the top.
  - Neighbour orders are paper notes, each pinned with a red tack, with the name in terracotta and the request in brown ink.
  - A finished order has a gold border. An unfinished one shows its reward in a pressed paper slot, still readable.
  - Neither the awning nor the notes add any controls.
- **Demand shown on the price:** a fixed-width "-24%" tag sits beside a dipped price. Its slot is reserved even when empty, so the row never moves when the tag appears.
- **Error state:** an action that can't happen now shakes the button that asked for it, as well as playing the soft sound and showing the toast. Spamming the button still settles where it started. Reduce Motion keeps only the sound and the toast. Tuning is in `feel.gd`.

Tests: feel spam 28/0 (a new check that spamming the shake settles at home), rules 83/0, runtime and collect pass. Checked in 1280×720 captures, not on a device or at phone aspect ratios.

## Pass 9 · 2026-11-04 (owner request: art direction)

Audit from blurred and grayscale captures at morning, afternoon, dusk and evening.

- **Squint test:** the red roofs and the cottage read first, which is the right focal point. Fences and plots were lost, because the turf was nearly as light as the cream walls and the paper-coloured plots.
- **Grayscale test:** at noon the ground went close to white, so buildings separated by outline and shadow only, not by value.
- **Color script:** the day cycle (#15) already moves from morning gold to amber hearth-glow. The olive afternoon green leaned neon under the grade's saturation boost.
- **Static world:** wind moves the foliage, but the air was empty. Nothing drifted by day and nothing glowed at night apart from the windows.
- **Frame:** the screen edges were nearly as bright as the centre, so the eye wasn't pulled in.

Chosen upgrade: secondary motion and ambient life, with a small value correction for depth.

Changes:
- **Living air** (`world_ui.Atmosphere`, tuning in `feel.gd`).
  - By day, 14 pollen motes drift sideways on the wind.
  - As the hearth-glow comes up, 12 amber fireflies blink in loops over the near half of the map.
  - Both fade with the day cycle's window glow, which is sampled every 4 s.
  - Each mote is a vertex-coloured soft dot: a bright core fading to clear. All of them go out in one triangle list, so the layer costs one canvas draw call and no textures, nodes or materials. It redraws at 30 fps.
  - It sits under the HUD, ignores input and is hidden under Reduce Motion.
- **Depth and value:**
  - The turf and valley green drop about 15% in value (0.56/0.64/0.45 to 0.47/0.56/0.39). Both shaders change together so the edges still match. Walls, fences and plots now separate from the ground in grayscale, and the green is calmer.
  - The edge vignette deepens from 34% to 42%.
- **Fix:** a quick place tap logged an error, because `punch` read a missing meta with a null default. It now checks `has_meta` first. This was found during the #17 device install.

**Performance** (`tests/perf_probe.gd`, 1280×720, Compatibility renderer, built farm): 859 draw calls before and 860 after, with video memory unchanged at 97.5 MB. The first version drew stacked circles and cost +36 draw calls; it was replaced by the single triangle list.

Tests: rules 83/0, feel spam 28/0, runtime and collect pass. Checked in captures only, not on a device; firefly brightness at night hasn't been judged on a phone screen.

## Pass 10 · 2026-11-04 (owner request: systems design)

Audit and design: see the second section of `docs/design/CORE-LOOP-AUDIT.md`.

- **Gap:** market demand only tells the player what not to sell. The long timers didn't plan anything, holding stock had one answer, and wheat had no allocation choice.
- **Change: in season.** Each 10-minute window (2 min in quick play), one good the homestead can make sells for +50%, and the next window's good is shown.
  - The bonus applies before demand, so only a small timed batch pays.
  - There is no season while wheat is the only good, so the opening is unchanged.
  - It is shown in one gold strip under the Market awning (good, time left, next good), plus a gold "+50%" in the existing price-tag slot.
  - The stall reprices live when the window turns or demand recovers.
- **Saves:** new sale records freeze `season`. Replay checks the amount. Earlier sales replay unchanged.
- **Tuning:** `SEASON_SECONDS`, `SEASON_BONUS` and `SEASON_STEP` are in `catalogue.gd`.

Tests: rules 92/0 (9 new season checks), feel spam 28/0, runtime and collect pass. Checked in a 1280×720 market capture, not on a device.

## Pass 11 · 2026-11-04 (owner request: game feel, second pass)

Audit after pass 7, which added the punch, the flecks and the timer buffer.

- **Input:** already instant everywhere.
  - Buttons press on touch-down and release with an overshoot.
  - Taps on nearly finished timers are buffered (0.6 s).
  - There is no tap-to-action wait anywhere.
  - Coyote time doesn't apply, because there is no movement or jumping.
- **Transitions:**
  - Boxes open with a back-ease pop, but they **closed with a hard cut**, the only unanimated state change left.
- **Proportion:**
  - A 1-coin wheat sale and a 30-coin season batch got identical feedback: the same three coins, label size and haptic.
  - A **level-up** had confetti and a banner but no impact moment, so the biggest milestone felt as light as a sale.

Changes (tuning in `feel.gd`):
- **Box close follow-through** (`_close_out`). The box shrinks to 94% and fades over 120 ms (ease-in). It stops taking taps on the same frame, so the map is live at once. A box opened during the fade sits above it. Reduce Motion closes instantly.
- **Proportional rewards** (`reward_tier`). Coin gains fall into three tiers:

  | Gain | Tier | Coins flying | "+N" label | Haptic |
  |---|---|---|---|---|
  | Under 5 | Small | 2 | 28 pt | 0.35 |
  | 5–14 | Good | 4 | 34 pt | 0.5 |
  | 15 or more | Big | 6 | 44 pt | 0.8 |

  On a big gain, the wallet also punches to 1.32× as the coins land.
- **Level-up choreography** (`_level_impact`):
  - **Anticipation:** the badge winds up to 0.82× (80 ms).
  - **Impact:** on the frame it lands, a heavy haptic, a warm 22% flash, the badge snapped to 1.45× and a 70 ms hit-stop.
  - **Follow-through:** the badge springs back elastically over 0.6 s, followed by the existing confetti and banner.
  - The hit-stop freezes animation only. Input and game clocks keep running, and a guard in `_process` releases it even if its timer were lost.
  - Reduce Motion keeps only the haptic.

Tests: feel spam 32/0 (4 new checks: tiers, hit-stop release, badge settle, closed boxes freed), rules 92/0, runtime and collect pass. Checked in 1280×720 captures; haptic strength hasn't been felt on a device.

## Pass 12 · 2026-11-05 (owner request: The Barge, first challenge)

Saeed picked The Barge from the challenges doc as the first thing to break up the produce-and-build loop.

What it is:
- Once the windmill is built, Rowan's barge docks at the east cove every 2 hours and stays 45 minutes (both shortened 5× in quick play).
- Each visit brings a manifest of 2–3 goods the player can make, with counts sized to about 12 coins a line. The manifest rotates with the market season, so it rarely matches what the market favours.
- Each crate loaded pays the normal sale price at once. Filling the whole hold adds a +50% bonus, and the barge then sails early.
- A missed barge costs nothing. The next manifest is always shown, so the player can plan.

Save rules: one append-only `barge` record per load, carrying the frozen cycle length, stay and pay. `apply` checks departure, the manifest, the line's remaining count, stock and exact pay (including the bonus on the filling load) before changing anything. Replay rebuilds the same hold.

Presentation:
- A low-poly barge (hull, cabin, sail, lantern, crates that fill with the hold) glides in, bobs and sails off. Reduce Motion keeps it still.
- A gold-edged map ticket under the goal ("Barge · n/m · Leaves in …"), plain glass while it's away.
- "Rowan's Barge" screen: status strip with clock and full-load bonus, one paper crate card per line with its own Load button or a "Make" shortcut, and the hold's progress. The camera frames the boat above the screen.
- Filling the hold: celebrate sound, big haptic, confetti and a "Barge filled" banner.

Tests: rules 110/0 (18 new barge checks), feel spam 32/0, runtime and collect pass. Checked in 1280×720 captures 15–16; not yet played on a device.

## Pass 13 · 2026-11-05 (owner request: weather, plus a calmer camera)

**Weather.** Saeed picked weather as the second twist after The Barge.

The sky changes every 15 minutes (3 in quick play) on a fixed 12-step pattern. The pattern never repeats a spell twice in a row, so the forecast is always known.

| Spell | Effect |
|---|---|
| Sunny | A fair day, no change |
| Rain | Fields and the orchard grow 2× faster |
| Breezy | The windmill grinds 2× faster |
| Warm | Oven and grill work 1.5× faster |

Rules:
- Weather only ever helps. Nothing decays or is lost.
- A job started under a spell freezes its shortened length in its own record (`seconds`, plus a display-only `weather` tag). A running timer never changes when the sky does, and replay needs no new record type.
- For fields, the watering step sets the timer, so the sky at watering counts.

Presentation:
- **Map:** rain draws fine slanted streaks, dims and cools the sun, and grounds the pollen. A breeze makes trees and crops sway harder, the windmill's sails turn faster and pollen drifts quicker. A warm spell gilds the sunlight. Changes ease in over a few seconds. No weather sounds, per Saeed's no-noise rule.
- **Sky pill** beside Settings, showing the spell and its name. It opens a three-card forecast (Now / Next / Later), each with its effect and time.
- **Place cards:** a small "Rain ×2" tag sits under the action while the sky favours that place.
- **A new spell:** a short toast such as "Rain · Fields and orchard grow 2× faster" and a pill bump.

**Calmer camera.** Saeed found the jumps when selecting, reselecting and switching places hard on the eyes. Causes found:
1. The card's framing offsets (`h_offset`/`v_offset`) snapped in one frame while focus and zoom eased, so every open and close jolted. They now ease with focus and zoom.
2. Framing eased at rate 12 per second. Place, arrival and pan moves now use rate 6.5, a soft glide. Follow keeps 12 so the camera stays with the walking resident.
3. The barge view and the build-spot preview snapped (`camera_initialized=false`). On a live map they now glide (`pan_glide`) until a finger drag takes over. They still snap only when a native menu holds a paused view.
4. Switching straight from one card to another, such as Oven ↔ Kitchen, no longer re-pops the card. It stays steady while the camera glides.

Tests: rules 118/0 (8 new weather checks, and the existing exact-timer checks hold the sky sunny), feel spam 32/0, runtime and collect pass. Checked in 1280×720 captures 17–19. The camera feel hasn't been tried on a device yet.

## Pass 14 · 2026-11-05 (owner request: game feel, third pass)

Audit:
- **Input:** still instant. Taps act on touch-down release, the 0.6 s timer buffer covers early taps, and nothing waits on an animation. Coyote time doesn't apply because there is no movement.
- **Easing:** no linear snaps were left in the older interactions. The three newest ones had no impact moment:
  - **Loading the barge** rebuilt the screen. The count, the hold bar and the boat just changed.
  - **Dropping a good into a place's slot** silently redrew the card.
  - **A new weather spell** swapped the pill's emblem in one frame.

Changes (tuning in `feel.gd`):
- **Barge load (impact → follow-through):**
  - The load is saved first.
  - On the next frame the goods arc from the Load button into the hold bar (up to 4 sprites).
  - The bar springs from its old share to the new one with a back-ease overshoot (0.45 s), and the tally punches as the first crate lands.
  - On the map, the hull takes a 0.9 m/s kick on a damped spring (stiffness 70, damping 6): it sinks about 10 cm and bobs back over about a second.
  - A reward haptic fires on the commit frame.
  - A hold bar re-sprung mid-flight keeps its goal, so spam always lands on the true share.
- **Goods into a slot (micro-action, crisp):** a 1.07× ring punch, a tick whose pitch climbs 12% per filled slot, and a light haptic on the drop frame. The last slot still starts the job through the existing place punch.
- **Sky change (anticipation → impact → settle):** the pill winds in to 0.8× (80 ms). At the bottom of the wind-up it swaps emblem and name with a light haptic, pops to 1.22× and settles elastically (0.5 s). Spamming it lands on the last spell.
- Reduce Motion keeps the haptics and the instant state changes only. Nothing here delays a tap or covers the map.

Tests: feel spam 36/0 (4 new: sky morph spam, bar re-spring, hull kick and settle), rules 118/0, runtime and collect pass. Captures 00–19 unchanged. The haptic strengths and the boat's bounce haven't been felt on a device.

## Pass 15 · 2026-11-05 (owner request: enhance and optimise the recent changes)

Profiled with a new probe (`tests/hud_cost_probe.gd`) on a farm with a windmill, barn and orchard. Findings:
- **The HUD did its full upkeep every frame.** That covered the barge ticket, the sky pill and the season clock: 78 µs per frame headless on desktop, likely a few hundred µs on a phone, for text that changes once a second.
- Each upkeep recomputed the barge's manifest, which re-walks every place to list the makeable goods.
- The barge ticket re-applied its stylebox and font colour on every update.
- A gust easing in pushed a shader parameter to every swaying surface on almost every frame for several seconds.

Changes:
- **The HUD upkeep runs 5 times a second** (`F.HUD_TICK` 0.2 s). It also runs at once when a box opens or closes, or after any refresh, so chips never lag a change. UI `_process` dropped from 78 µs to 15 µs per frame.
- **The makeable-goods list is cached** by place count. Places are only ever added, and a swap keeps both. The list is copied out, so callers can't change the cache.
- **The barge ticket restyles only when the barge arrives or leaves.**
- **Gust steps are coarser (0.03)**, so a breeze easing in touches the wind materials only a handful of times.
- **Enhancement:** the barge's arrival is now a moment. The ticket turns gold with a bump, a soft chime and a "Rowan's barge is in" note, once per barge and never for the state found when opening the game.

Tests: rules 118/0, feel spam 36/0, runtime and collect pass. Captures 00–19 unchanged. On-device frame cost not measured.
