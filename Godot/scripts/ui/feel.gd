class_name WorldFeel
extends RefCounted

## Every timing, scale and sound-variation knob for the interface's feel, in
## one place. Times are seconds; scales are multipliers of rest size.
## Reduce Motion keeps fades and colour changes but drops movement and scale.

# Panels and toasts appearing.
const POP_FROM_SCALE := 0.86
const POP_TIME := 0.32
const FADE_IN_TIME := 0.18

# A target acknowledging an arrival (wallet, dock button, goal ticket).
const BUMP_SCALE := 1.18
const BUMP_UP_TIME := 0.09
const BUMP_SETTLE_TIME := 0.22

# Buttons: squash on press, spring back on release.
const PRESS_SCALE := 0.93
const PRESS_TIME := 0.06
const RELEASE_TIME := 0.18

# Goods and coins flying to the HUD.
const FLY_MAX_PER_GAIN := 6
const FLY_MAX_ON_SCREEN := 24
const FLY_STAGGER := 0.07
const FLY_LIFT := 140.0
const FLY_SPREAD := 60.0
const FLY_GROW_SCALE := 1.25
const FLY_GROW_TIME := 0.12
const FLY_TRAVEL_TIME := 0.55
const FLY_LAND_SCALE := 0.6

# The wallet counts up to its new total as the coins land, instead of jumping.
const COUNT_DELAY := FLY_GROW_TIME + FLY_TRAVEL_TIME * 0.8
const COUNT_MIN_TIME := 0.25
const COUNT_MAX_TIME := 0.8
const COUNT_TIME_PER_COIN := 0.04

# Rising "+N" labels.
const FLOAT_RISE := 74.0
const FLOAT_TIME := 0.9
const FLOAT_FADE_DELAY := 0.35

# Consecutive gains climb in pitch, so a run of collects sounds like a run.
const COMBO_WINDOW := 1.4
const COMBO_STEP := 0.06
const COMBO_MAX_STEPS := 6
const PITCH_JITTER := 0.04
const SFX_POLYPHONY := 4

# A soft ring where a finger taps the map, so every tap is acknowledged.
const TAP_SLOP := 14.0
const TAP_MAX_TIME := 0.35
const RIPPLE_FROM := 8.0
const RIPPLE_TO := 46.0
const RIPPLE_TIME := 0.42
const RIPPLE_MAX_ON_SCREEN := 6

# How long a neighbour's thank-you stays up.
const SPEECH_TIME := 3.2

# Haptic strengths (0–1) for a light tap and a reward.
const HAPTIC_TAP := 0.35
const HAPTIC_REWARD := 0.5
const HAPTIC_MS := 12

# Ambient sounds (scripts/ui/ambience.gd), quiet under the effects: the mill
# only while it grinds, birds mostly at dawn and morning.
const AMBIENT_MILL_DB := -19.0
const AMBIENT_BIRDS_DB := -21.0
const MILL_CREAK_EVERY := Vector2(2.6, 4.2)
## Seconds between bird calls by day phase; missing phases stay quiet.
const BIRD_CALL_EVERY := {"dawn": Vector2(5.0, 10.0), "morning": Vector2(9.0, 18.0), "afternoon": Vector2(22.0, 40.0)}
const AMBIENT_PITCH_JITTER := 0.08

# Impact on the map (presentation.punch): a place dips, stretches and settles
# on the frame an action lands, with a burst of flecks. Strength 1 for a
# collect or harvest, 2 for a finished build.
const PUNCH_SQUASH := 0.05     # fraction of height per unit of strength
const PUNCH_DIP_TIME := 0.06   # anticipation
const PUNCH_HIT_TIME := 0.08   # impact stretch
const PUNCH_SETTLE_TIME := 0.42 # elastic follow-through
const BURST_FLECKS := 7        # per unit of strength
const BURST_RISE := 0.9
const BURST_SPREAD := 0.8
const BURST_TIME := 0.5

# Taps on a timer about to finish wait for it instead of opening the card,
# so a player tapping on "0:01" gets the harvest, not a menu.
const TIMER_BUFFER := 0.6

# An action that can't happen shakes the button that asked (world_ui.shake).
const SHAKE_DISTANCE := 7.0
const SHAKE_STEPS := 5
const SHAKE_TIME := 0.28
