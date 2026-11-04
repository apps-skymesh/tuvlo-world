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
	"pond":       {"price": 4,  "gate": 4,  "seconds": 30, "land": ""},
	"nook":       {"price": 9,  "gate": 9,  "seconds": 8,  "land": ""},
	"treehouse":  {"price": 16, "gate": 16, "seconds": 90, "land": ""},
	"windmill":   {"price": 6,  "gate": 6,  "seconds": 8,  "land": ""},
	"workshop":   {"price": 6,  "gate": 20, "seconds": 60, "land": ""},
	"barn":       {"price": 18, "gate": 12, "seconds": 60, "land": ""},
	"doghouse":   {"price": 8,  "gate": 8,  "seconds": 30, "land": ""},
	"grill":      {"price": 12, "gate": 10, "seconds": 45, "land": ""},
	"greenhouse": {"price": 30, "gate": 25, "seconds": 60, "land": "west"},
	"orchard":    {"price": 35, "gate": 35, "seconds": 45, "land": "west"},
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

## Production (HomesteadFarm).
const FIELD_COUNT := 2
const FIELD_SECONDS := 30.0
const FIELD_YIELD := 2
const ORCHARD_SECONDS := 60.0
const ORCHARD_YIELD := 3
const GOODS := ["wheat", "flour", "bread", "fruit", "tart", "meat", "meal"]
## station -> the place kind that hosts it
const STATIONS := {"mill": "windmill", "oven": "cottage", "pantry": "cottage", "barn": "barn", "grill": "grill"}
const RECIPES := {
	"flour":       {"station": "mill",   "input": {"wheat": 2},             "output": "flour", "quantity": 1, "seconds": 45},
	"bread":       {"station": "oven",   "input": {"flour": 1},             "output": "bread", "quantity": 1, "seconds": 60},
	"tart":        {"station": "oven",   "input": {"flour": 1, "fruit": 2}, "output": "tart",  "quantity": 1, "seconds": 90},
	"meal":        {"station": "pantry", "input": {"bread": 1},             "output": "meal",  "quantity": 3, "seconds": 30},
	"livestock":   {"station": "barn",   "input": {"wheat": 2},             "output": "meat",  "quantity": 2, "seconds": 90},
	"grilledMeal": {"station": "grill",  "input": {"meat": 1, "bread": 1},  "output": "meal",  "quantity": 4, "seconds": 60},
}

## SOLO market: coins paid per good sold. Roughly input value plus a little for time.
const SELL_PRICE := {"wheat": 1, "flour": 3, "bread": 5, "fruit": 1, "tart": 10, "meat": 3, "meal": 3}
## SOLO: coins a new player starts with, and lifetime sales per level.
const SOLO_STARTING_COINS := 6
const SOLO_SALES_PER_LEVEL := 5

## SOLO market orders: three slots, each with its own deterministic sequence, so
## two devices always agree on which order comes next. A slot opens once the
## place that makes its goods exists.
const ORDER_SLOTS := [
	{"opens": "garden", "goods": ["wheat", "wheat", "wheat"]},
	{"opens": "windmill", "goods": ["flour", "bread", "bread", "flour"]},
	{"opens": "barn", "goods": ["meat", "meal", "tart", "meal"]},
]
static func order(slot: int, nth: int) -> Dictionary:
	var spec: Dictionary = ORDER_SLOTS[slot]
	var good: String = spec.goods[nth % spec.goods.size()]
	var count := 2 + (nth * 7 + slot * 3) % 3 + mini(nth / 4, 3)
	var reward := int(ceil(SELL_PRICE[good] * count * 1.5)) + 2
	return {"slot": slot, "nth": nth, "good": good, "count": count, "reward": reward}

const TITLES := {
	"cottage": "Cottage", "tree": "Tree", "garden": "Farm", "path": "Path", "pond": "Pond", "nook": "Reading nook",
	"treehouse": "Treehouse", "windmill": "Windmill", "workshop": "Workshop", "barn": "Barn", "doghouse": "Dog house",
	"grill": "Grill", "greenhouse": "Greenhouse", "orchard": "Orchard", "flowers": "Flowers", "bench": "Bench", "rocks": "Rocks",
	"wheat": "Wheat", "flour": "Flour", "bread": "Bread", "fruit": "Fruit", "tart": "Tart", "meat": "Meat", "meal": "Meals",
	"mill": "Mill", "oven": "Oven", "pantry": "Kitchen bench", "west": "West meadow",
	"livestock": "Raise sheep", "grilledMeal": "Grilled meal",
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
