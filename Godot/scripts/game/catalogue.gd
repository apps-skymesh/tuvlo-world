class_name WorldCatalogue
extends RefCounted

## Game rules as data. Ported from Tuvlo's SwiftUI World (reference/tuvlo-swift,
## Tuvlo b50d5f57): HomesteadFarm, LivingWorldExpansion, LivingWorldProjects,
## HomesteadConstruction, HomesteadSpots, HomesteadMigration.
## Values marked SOLO are new provisional tuning for the standalone game.

const SAVE_VERSION := 1

## Free starting homestead (Tuvlo's saved "first chapter" pieces).
const STARTER := [
	{"key": "base:cottage", "kind": "cottage", "cell": Vector2i(3, 2)},
	{"key": "base:tree", "kind": "tree", "cell": Vector2i(12, 2)},
	{"key": "base:garden", "kind": "garden", "cell": Vector2i(2, 10)},
]
static func starter_paths() -> Array:
	var cells := []
	for z in range(5, 11): cells.append(Vector2i(5, z))
	for x in range(6, 11): cells.append(Vector2i(x, 6))
	return cells

## Buildable places. price is in the host's game currency; gate is the host's
## progress count (Tuvlo: approved missions; solo: market level). seconds is the
## construction time; land names land that must be owned first.
const BUILDS := {
	"pond":       {"price": 4,  "gate": 4,  "seconds": 60, "land": ""},
	"nook":       {"price": 9,  "gate": 9,  "seconds": 120,  "land": ""},
	"treehouse":  {"price": 16, "gate": 16, "seconds": 300, "land": ""},
	"windmill":   {"price": 6,  "gate": 6,  "seconds": 90,  "land": ""},
	"workshop":   {"price": 6,  "gate": 20, "seconds": 180, "land": ""},
	"barn":       {"price": 18, "gate": 12, "seconds": 300, "land": ""},
	"doghouse":   {"price": 8,  "gate": 8,  "seconds": 120, "land": ""},
	"grill":      {"price": 12, "gate": 10, "seconds": 180, "land": ""},
	"greenhouse": {"price": 30, "gate": 25, "seconds": 480, "land": "west"},
	"orchard":    {"price": 35, "gate": 35, "seconds": 600, "land": "west"},
	# SOLO: decorations were free sandbox pieces in Tuvlo; small prices here.
	"flowers":    {"price": 1,  "gate": 0,  "seconds": 0,  "land": ""},
	"bench":      {"price": 3,  "gate": 2,  "seconds": 0,  "land": ""},
	"rocks":      {"price": 1,  "gate": 0,  "seconds": 0,  "land": ""},
}
## Order shown in the Build tray.
const BUILD_ORDER := ["windmill", "pond", "doghouse", "nook", "grill", "barn", "treehouse", "workshop", "greenhouse", "orchard", "flowers", "bench", "rocks"]

## Land expansions. East and north stay future regions (not sold yet).
const LAND := {"west": {"price": 10, "gate": 20}}

## Fixed build spots (HomesteadSpots, A70). One tap builds at the first free spot.
const SPOTS := {
	"grill": [Vector2i(0, 6)],
	"windmill": [Vector2i(1, 13), Vector2i(1, 16)],
	"barn": [Vector2i(13, 13), Vector2i(13, 16)],
	"doghouse": [Vector2i(17, 10), Vector2i(17, 13)],
	"pond": [Vector2i(8, 8), Vector2i(11, 9)],
	"nook": [Vector2i(10, 2), Vector2i(9, 11)],
	"treehouse": [Vector2i(14, 2), Vector2i(16, 6)],
	"workshop": [Vector2i(7, 14), Vector2i(4, 16)],
	"orchard": [Vector2i(-10, 2), Vector2i(-10, 6)],
	"greenhouse": [Vector2i(-6, 2), Vector2i(-6, 6)],
	"bench": [Vector2i(11, 4), Vector2i(12, 6), Vector2i(14, 8)],
	"flowers": [Vector2i(4, 7), Vector2i(6, 7), Vector2i(8, 7), Vector2i(10, 7), Vector2i(4, 9), Vector2i(11, 7), Vector2i(6, 5), Vector2i(9, 5)],
	"rocks": [Vector2i(18, 1), Vector2i(1, 19), Vector2i(18, 18), Vector2i(0, 0)],
}

## Timers, in seconds at normal speed. One ladder for the whole game:
## - raw goods: wheat 2 min, fruit 6 min;
## - one step from raw: packing meals 2 min, milling 3 min, bread 5 min;
## - longer chains and richer goods: grilled meals 6 min, sheep 8 min, tarts 10 min;
## - building takes about 15–20 s per coin of price, from 1 min (pond) to 10 min
##   (orchard); decorations are instant.
## Quick play (project setting tuvlo_world/quick_play, on while testing)
## runs every new timer 5× faster. Each record freezes the duration it started
## with, so switching speeds never changes a timer already running.
const QUICK_PLAY_SPEED := 5.0
static var speed_override := 0.0

static func speed() -> float:
	if speed_override > 0: return speed_override
	return QUICK_PLAY_SPEED if ProjectSettings.get_setting("tuvlo_world/quick_play", false) else 1.0

## A timer's real length at the current speed (whole seconds, at least 1).
static func duration(seconds: float) -> int:
	return maxi(1, roundi(seconds / speed())) if seconds > 0 else 0

## Production (HomesteadFarm).
const FIELD_COUNT := 2
const FIELD_SECONDS := 120.0
## The very first wheat grows fast, so a new player gets a harvest within
## the first minute (frozen in the watering record like every other time).
const FIRST_FIELD_SECONDS := 20.0
const FIELD_YIELD := 2
const ORCHARD_SECONDS := 360.0
const ORCHARD_YIELD := 3
const GOODS := ["wheat", "flour", "bread", "fruit", "tart", "cheese", "meal"]
## Goods renamed since earlier saves. Replay reads the old name as the new
## good, so a save that made "meat" now holds the same count of cheese.
const LEGACY_GOODS := {"meat": "cheese"}
static func good_id(good: String) -> String: return LEGACY_GOODS.get(good, good)
## station -> the place kind that hosts it
const STATIONS := {"mill": "windmill", "oven": "cottage", "pantry": "cottage", "barn": "barn", "grill": "grill"}
const RECIPES := {
	"flour":       {"station": "mill",   "input": {"wheat": 2},             "output": "flour", "quantity": 1, "seconds": 180},
	"bread":       {"station": "oven",   "input": {"flour": 1},             "output": "bread", "quantity": 1, "seconds": 300},
	"tart":        {"station": "oven",   "input": {"flour": 1, "fruit": 2}, "output": "tart",  "quantity": 1, "seconds": 600},
	"meal":        {"station": "pantry", "input": {"bread": 1},             "output": "meal",  "quantity": 3, "seconds": 120},
	# Recipe ids stay as saved; the flock's milk now makes cheese.
	"livestock":   {"station": "barn",   "input": {"wheat": 2},             "output": "cheese", "quantity": 2, "seconds": 480},
	"grilledMeal": {"station": "grill",  "input": {"cheese": 1, "bread": 1}, "output": "meal",  "quantity": 4, "seconds": 360},
}

## SOLO market: coins paid per good sold. Roughly input value plus a little for time.
const SELL_PRICE := {"wheat": 1, "flour": 3, "bread": 5, "fruit": 1, "tart": 10, "cheese": 3, "meal": 3}
## SOLO market demand. Each unit sold lowers that good's next price by
## DEMAND_DROP of its base, down to DEMAND_FLOOR; demand recovers one unit every
## DEMAND_RECOVER_SECONDS (at normal speed; frozen in each sale record). Other
## goods are unaffected, so spreading sales across goods and time pays, and
## dumping one good all at once doesn't. Neighbour orders never move demand.
const DEMAND_DROP := 0.12
const DEMAND_FLOOR := 0.4
const DEMAND_RECOVER_SECONDS := 45.0
## SOLO in season: the market favours one good at a time. For each window of
## SEASON_SECONDS (normal speed; frozen in each sale record) one good the
## homestead can make sells for SEASON_BONUS more, and the next window's good
## is shown in advance. Demand still drops per unit, so the premium rewards
## timing a batch to the window and holding just a few, not hoarding.
const SEASON_SECONDS := 600.0
const SEASON_BONUS := 0.5
## Prime step through the makeable goods: every good comes round and the same
## good never runs two windows in a row (while two or more can be made).
const SEASON_STEP := 7919
## The good in season during `window` among `makeable` (GOODS order). With
## only one good to make there is no choice to reward, so no season.
static func season_good(window: int, makeable: Array) -> String:
	if makeable.size() < 2: return ""
	return makeable[posmod(window * SEASON_STEP + 3, makeable.size())]
## The price of one more unit of `good` when `glut` units are still unrecovered.
static func unit_price(good: String, glut: float, in_season := false) -> int:
	var base: float = SELL_PRICE[good] * (1.0 + SEASON_BONUS if in_season else 1.0)
	return maxi(1, roundi(base * maxf(DEMAND_FLOOR, 1.0 - DEMAND_DROP * glut)))
## SOLO the Barge: Rowan's barge docks at the cove at the start of every
## BARGE_CYCLE_SECONDS and waits BARGE_STAY_SECONDS (normal speed; both frozen
## in each load record). Its manifest asks for a few crates of goods the farm
## can make. Every crate pays the list price straight away, with no market dip,
## and a full manifest pays a bonus and sends the barge off early. A missed
## barge costs nothing; the next one brings a new manifest, shown in advance.
const BARGE_OPENS := "windmill"
const BARGE_CYCLE_SECONDS := 7200.0
const BARGE_STAY_SECONDS := 2700.0
const BARGE_LINE_VALUE := 12.0  # roughly the coins asked for per manifest line
const BARGE_BONUS_RATE := 0.5   # the full-load bonus, as a share of the manifest's value
const BARGE_THANKS := ["Full hold, fair wind. The towns will eat well.", "That's the finest load on the river.", "Every crate stowed. See you next tide!"]
## The barge's manifest for `cycle`: two or three lines of goods the farm can
## make (wheat only when there's nothing else), never the same good twice.
static func barge_manifest(cycle: int, makeable: Array) -> Array:
	var goods: Array = makeable.filter(func(g): return g != "wheat") if makeable.size() >= 3 else makeable.duplicate()
	if goods.size() < 2: return []
	var lines := 3 if goods.size() >= 4 else 2
	var start := posmod(cycle * SEASON_STEP + 5, goods.size())
	var manifest := []
	for i in lines:
		var good: String = goods[(start + i) % goods.size()]
		manifest.append({"good": good, "count": maxi(2, roundi(BARGE_LINE_VALUE / SELL_PRICE[good])) + posmod(cycle + i, 2)})
	return manifest
static func barge_value(manifest: Array) -> int:
	var total := 0
	for line in manifest: total += int(line.count) * int(SELL_PRICE[line.good])
	return total
static func barge_bonus(manifest: Array) -> int: return ceili(barge_value(manifest) * BARGE_BONUS_RATE)

## SOLO: coins a new player starts with, and lifetime sales per level.
const SOLO_STARTING_COINS := 6
const SOLO_SALES_PER_LEVEL := 5

## SOLO daily gift: the first visit of each later day finds a basket on the
## farm. Consecutive days climb the week below and then loop; a missed day
## starts again at day 1. Goods only: gifts never pay coins or count as sales.
const GIFT_BASKETS := [
	{"wheat": 2}, {"wheat": 3}, {"wheat": 2, "flour": 1}, {"wheat": 3, "flour": 1},
	{"flour": 2}, {"flour": 1, "bread": 1}, {"bread": 2, "tart": 1},
]
static func gift_basket(streak: int) -> Dictionary: return GIFT_BASKETS[(maxi(streak, 1) - 1) % GIFT_BASKETS.size()]
## The device's local calendar day for a clock time (days since 1970).
static func local_day(at: float) -> int:
	return floori((at + Time.get_time_zone_from_system().get("bias", 0) * 60.0) / 86400.0)

## SOLO valley folk: three neighbours, each with their own wishes, words and a
## keepsake every third delivery. Each keeps a deterministic sequence, so two
## devices always agree on what comes next. A neighbour visits once the place
## that makes their first wish exists, and only asks for goods the homestead
## can already make (`GOOD_SOURCE`).
const FOLK := [
	{"id": "maeve", "name": "Old Maeve", "role": "Weaver and baker", "opens": "garden",
		"goods": ["wheat", "wheat", "flour", "wheat", "flour", "bread"],
		"ask": ["My loom's quiet and my bread bin's bare.", "A little grain for the morning loaf?", "Flour, dear, if the mill's been kind."],
		"thanks": ["Golden as the summer! My loaves will sing.", "You've your grandmother's knack for grain.", "Warm hands, warm bread. Thank you, love."],
		"keepsake": {"bread": 1}, "keepsake_line": "Take a loaf. Still warm."},
	{"id": "rowan", "name": "Rowan the Bargeman", "role": "River courier", "opens": "windmill",
		"goods": ["bread", "fruit", "bread", "tart", "bread", "fruit"],
		"ask": ["Long river ahead. Pack me something good?", "The barge leaves at the turn of the tide.", "Provisions for the downstream towns!"],
		"thanks": ["That'll see me past the willow bend.", "The towns downriver will hear of this farm.", "Light cargo, full belly. Perfect."],
		"keepsake": {"fruit": 2}, "keepsake_line": "Pears from the far bank, for your trouble."},
	{"id": "bramble", "name": "Bramble", "role": "Forager and herbalist", "opens": "barn",
		"goods": ["cheese", "fruit", "meal", "tart", "cheese", "meal"],
		"ask": ["The hedgerows are turning. I've a basket to fill.", "Something crafted with care, for the woodland market.", "The badgers and I are hosting supper."],
		"thanks": ["Oh, this smells of clover and good work.", "The woods will be glad of it. So am I.", "Just right. I'll trade it for moonflower seeds."],
		"keepsake": {"tart": 1}, "keepsake_line": "A bramble tart. Mind the thorns."},
]
## Kept under the old name: slots are folk, in the same order as before.
const ORDER_SLOTS := FOLK
const KEEPSAKE_EVERY := 3
## The place each good needs, so a neighbour never asks for the impossible.
const GOOD_SOURCE := {"wheat": "garden", "flour": "windmill", "bread": "windmill", "meal": "windmill",
	"fruit": "orchard", "tart": "orchard", "cheese": "barn"}

## The `nth` wish of a neighbour. `owned` lists the homestead's place kinds;
## wishes for goods it can't make yet are skipped.
static func order(slot: int, nth: int, owned: Array = []) -> Dictionary:
	var spec: Dictionary = FOLK[slot]
	var wishes: Array = spec.goods.filter(func(g): return owned.is_empty() or owned.has(GOOD_SOURCE.get(g, "")))
	if wishes.is_empty(): wishes = [spec.goods[0]]
	var good: String = wishes[nth % wishes.size()]
	var count := 2 + (nth * 7 + slot * 3) % 3 + mini(nth / 4, 3)
	var reward := int(ceil(SELL_PRICE[good] * count * 1.5)) + 2
	var keepsake: Dictionary = spec.keepsake if nth % KEEPSAKE_EVERY == KEEPSAKE_EVERY - 1 else {}
	return {"slot": slot, "nth": nth, "folk": spec.id, "name": spec.name, "role": spec.role, "good": good, "count": count,
		"reward": reward, "keepsake": keepsake, "ask": spec.ask[nth % spec.ask.size()],
		"thanks": spec.keepsake_line if not keepsake.is_empty() else spec.thanks[nth % spec.thanks.size()]}

const TITLES := {
	"cottage": "Cottage", "tree": "Tree", "garden": "Farm", "path": "Path", "pond": "Pond", "nook": "Reading nook",
	"treehouse": "Treehouse", "windmill": "Windmill", "workshop": "Workshop", "barn": "Barn", "doghouse": "Dog house",
	"grill": "Grill", "greenhouse": "Greenhouse", "orchard": "Orchard", "flowers": "Flowers", "bench": "Bench", "rocks": "Rocks",
	"wheat": "Wheat", "flour": "Flour", "bread": "Bread", "fruit": "Fruit", "tart": "Tart", "cheese": "Cheese", "meal": "Meals",
	"mill": "Mill", "oven": "Oven", "pantry": "Kitchen bench", "west": "West meadow",
	"livestock": "Sheep's cheese", "grilledMeal": "Grilled cheese",
}
static func title(key: String) -> String: return TITLES.get(key, key.capitalize())

static func recipes_for(station: String) -> Array:
	var result := []
	for id in RECIPES:
		if RECIPES[id].station == station: result.append(id)
	return result

static func stations_for(kind: String) -> Array:
	var result := []
	for station in STATIONS:
		if STATIONS[station] == kind: result.append(station)
	return result
