class_name WorldStory
extends RefCounted

## The valley's voice: every narrator line in one place (see docs/design/VOICE.md).
## The story is "wake the sleepy valley". The narrator is the valley itself:
## present tense, short, sensory, warm, never an exclamation mark. Lines name
## what the player can see or what the rules really do, so the words never
## promise something the world doesn't show.

const TAGLINE := "Wake the sleepy valley"

## The first open of a new farm: the hook, pointing at the field.
const ARRIVAL := {"eyebrow": "A sleepy valley", "line": "Cold oven. Quiet field. Seed in your pocket."}

## Every later open: the day count, then the sky. Weather lines say what the
## spell really speeds up (catalogue WEATHER), so the words teach the rule.
const WEATHER_LINES := {
	"rain": "Rain on the roof. The fields drink it in.",
	"breeze": "A good wind. The mill will sing today.",
	"warm": "Warm air. The oven's in a good mood.",
}
const BREEZE_NO_MILL := "A breeze runs through the wheat."
const HOUR_LINES := {
	"dawn": "First light on the fields.",
	"morning": "Morning. Dew on the wheat.",
	"afternoon": "Long light across the meadow.",
	"dusk": "Dusk. The windows start to glow.",
	"evening": "Fireflies over the farm.",
}

## Peak firsts, once per farm (they read the save, so they can't repeat).
const FIRSTS := {
	"harvest": {"eyebrow": "First harvest", "line": "The first wheat. The valley stirs."},
	"sale": {"eyebrow": "First sale", "line": "Coins in hand. Word gets around."},
}

## A place's first breath, when its building timer ends.
const PLACE_LINES := {
	"windmill": "Sails up. Flour, at last.",
	"pond": "Still water. Something's biting.",
	"nook": "A quiet corner for a good book.",
	"treehouse": "Up in the leaves, the bees move in.",
	"workshop": "Sawdust and straw. Busy hands.",
	"barn": "Sheep in the straw. Milk by morning.",
	"doghouse": "A tail that won't stop wagging.",
	"grill": "Coals aglow. Something smells good.",
	"greenhouse": "Warm glass. Herbs reach for the sun.",
	"orchard": "Young trees. Fruit soon enough.",
	"west": "More meadow. More room to grow.",
}

## The level-up banner's eyebrow: a level is the valley waking a little more.
const LEVEL_EYEBROW := "The valley wakes"

## The daily gift is a basket left on the step.
const GIFT_GOAL := "A basket on the step"
const GIFT_TITLE := "On the doorstep"

## The line for opening the game. `new_farm` is a farm with no harvest yet.
static func greeting(new_farm: bool, day: int, weather: String, phase: String, has_mill: bool) -> Dictionary:
	if new_farm: return ARRIVAL
	var line: String = HOUR_LINES.get(phase, HOUR_LINES.morning)
	if weather == "breeze" and not has_mill: line = BREEZE_NO_MILL
	elif WEATHER_LINES.has(weather): line = WEATHER_LINES[weather]
	return {"eyebrow": "Day %d" % maxi(1, day), "line": line}
