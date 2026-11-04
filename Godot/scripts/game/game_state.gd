class_name WorldState
extends RefCounted

## Pure game state, rebuilt by replaying append-only records. It never holds
## money: prices and sale amounts are frozen in records, and the host keeps the
## wallet. Replay skips a record that doesn't fit, so two devices' records can
## merge without one charge or one harvest counting twice.

const C = preload("res://scripts/game/catalogue.gd")

var items: Array[Dictionary] = []
var land: Array[String] = []
var stock := {}
var fields: Array[Dictionary] = []
var jobs := {}
var orchard_watered := -1.0
var orchard_grow := C.ORCHARD_SECONDS
var construction := {}
var seen := {}
var rejected := 0
var lifetime_sales := 0
var harvests := 0
var orders_filled := [0, 0, 0]
var start_day := -1  # local day of the first record
var gift_day := -1
var gift_streak := 0
var notice := ""
var glut := {}  # good -> {"units", "at", "recover"}: recent sales not yet recovered
var speech := {}  # the last neighbour to speak: {"name", "line"}

func _init() -> void:
	for spec in C.STARTER:
		items.append({"id": spec.key, "kind": spec.kind, "cell": spec.cell, "rotation": 0, "style": 0})
	for cell in C.starter_paths():
		items.append({"id": "base:path:%d:%d" % [cell.x, cell.y], "kind": "path", "cell": cell, "rotation": 0, "style": 0})
	for i in C.FIELD_COUNT: fields.append({"planted": false, "watered": -1.0})
	for good in C.GOODS: stock[good] = 0

static func replay(records: Array) -> WorldState:
	var state := WorldState.new()
	var sorted := records.duplicate()
	sorted.sort_custom(func(a, b): return [float(a.get("at", 0)), int(a.get("seq", 0)), str(a.get("id", ""))] < [float(b.get("at", 0)), int(b.get("seq", 0)), str(b.get("id", ""))])
	for record in sorted:
		if state.apply(record) != "": state.rejected += 1
	state.notice = ""
	state.speech = {}
	return state

# --- queries ---------------------------------------------------------------

func find(id: String) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}
func first_of(kind: String) -> Dictionary:
	for item in items:
		if item.kind == kind: return item
	return {}
func owns(kind: String) -> bool: return not first_of(kind).is_empty()
func count_of(kind: String) -> int: return items.filter(func(i): return i.kind == kind).size()
func is_building(id: String, now: float) -> bool:
	return construction.has(id) and now < construction[id].started + construction[id].seconds
func ready_place(kind: String, now: float) -> bool:
	var item := first_of(kind)
	return not item.is_empty() and not is_building(item.id, now)

func field_stage(index: int, now: float) -> int:
	var field: Dictionary = fields[index]
	if not field.planted: return 0
	if field.watered < 0: return 1
	var elapsed: float = now - field.watered
	var grow := field_total(index)
	return 4 if elapsed >= grow else (3 if elapsed >= grow / 2 else 2)
## Each timer keeps the length it started with (records freeze it).
func field_total(index: int) -> float: return float(fields[index].get("grow", C.FIELD_SECONDS))
func job_total(station: String) -> float:
	var job: Dictionary = jobs.get(station, {})
	return 1.0 if job.is_empty() else float(job.get("seconds", C.RECIPES[job.recipe].seconds))
func field_remaining(index: int, now: float) -> int:
	if fields[index].watered < 0: return 0
	return maxi(0, ceili(field_total(index) - (now - fields[index].watered)))
func job_remaining(station: String, now: float) -> int:
	if not jobs.has(station): return 0
	return maxi(0, ceili(jobs[station].started + job_total(station) - now))
func orchard_remaining(now: float) -> int:
	if orchard_watered < 0: return 0
	return maxi(0, ceili(orchard_grow - (now - orchard_watered)))

func buildable(cell: Vector2i) -> bool:
	if HomesteadItems.BASE_BOUNDS.has_point(cell): return true
	for side in land:
		if HomesteadItems.LAND_BOUNDS[side].has_point(cell): return true
	return false
func fits(kind: String, cell: Vector2i, excluding := "") -> bool:
	var size := HomesteadItems.footprint(kind, 0)
	for z in size.y:
		for x in size.x:
			var square := cell + Vector2i(x, z)
			if not buildable(square): return false
			if kind in ["greenhouse", "orchard"] and not HomesteadItems.LAND_BOUNDS.west.has_point(square): return false
			for item in items:
				if item.id != excluding and Rect2i(item.cell, HomesteadItems.footprint(item.kind, item.rotation)).has_point(square): return false
	return true
func free_spot(kind: String) -> Variant:
	for cell in C.SPOTS.get(kind, []):
		if fits(kind, cell): return cell
	return null

## Why a build can't happen now, or "" when it can. Money is checked by the host.
func build_blocker(kind: String, progress: int) -> String:
	if not C.BUILDS.has(kind): return "unknown"
	var spec: Dictionary = C.BUILDS[kind]
	if not ["flowers", "bench", "rocks"].has(kind) and owns(kind): return "owned"
	if progress < spec.gate: return "locked"
	if spec.land != "" and spec.land not in land: return "land"
	if free_spot(kind) == null: return "full"
	return ""

## Units of `good` sold recently enough to still weigh on its price.
func glut_at(good: String, at: float) -> float:
	if not glut.has(good): return 0.0
	var g: Dictionary = glut[good]
	return maxf(0.0, g.units - maxf(0.0, at - g.at) / maxf(1.0, g.recover))
## Coins for selling `count` of `good` at `at`, each unit priced after the last.
func quote(good: String, count: int, at: float) -> int:
	if not C.SELL_PRICE.has(good): return 0
	var base := glut_at(good, at)
	var total := 0
	for i in count: total += C.unit_price(good, base + i)
	return total

# --- records ---------------------------------------------------------------

## Applies one record. Returns "" on success or a short reason.
func apply(r: Dictionary) -> String:
	var id := str(r.get("id", ""))
	if id == "" or seen.has(id): return "duplicate"
	if int(r.get("v", 0)) != C.SAVE_VERSION: return "version"
	var at := float(r.get("at", 0))
	if start_day < 0: start_day = C.local_day(at)
	var result := _apply(str(r.get("type", "")), r, at)
	if result == "": seen[id] = true
	return result

func _apply(type: String, r: Dictionary, at: float) -> String:
	match type:
		"build":
			var kind := str(r.get("kind", ""))
			var place := str(r.get("place", ""))
			var cell := Vector2i(int(r.get("x", 0)), int(r.get("z", 0)))
			if not C.BUILDS.has(kind) or place == "" or not find(place).is_empty(): return "invalid"
			if not fits(kind, cell): return "occupied"
			items.append({"id": place, "kind": kind, "cell": cell, "rotation": 0, "style": 0})
			var seconds := int(r.get("seconds", 0))
			if seconds > 0: construction[place] = {"started": at, "seconds": seconds}
			notice = C.title(kind) + (" is being built" if seconds > 0 else " built")
		"land":
			var side := str(r.get("side", ""))
			if not C.LAND.has(side) or side in land: return "invalid"
			land.append(side)
			notice = C.title(side) + " is yours"
		"tend":
			var index := int(r.get("field", -1))
			if index < 0 or index >= fields.size() or not ready_place("garden", at): return "invalid"
			match field_stage(index, at):
				0: fields[index].planted = true; notice = "Planted"
				1:
					fields[index].watered = at
					fields[index].grow = float(r.get("seconds", C.FIELD_SECONDS))
					notice = "Watered"
				4:
					fields[index] = {"planted": false, "watered": -1.0}
					stock.wheat += C.FIELD_YIELD
					harvests += 1
					notice = "+%d wheat" % C.FIELD_YIELD
				_: return "growing"
		"make":
			var recipe := str(r.get("recipe", ""))
			if not C.RECIPES.has(recipe): return "invalid"
			var spec: Dictionary = C.RECIPES[recipe]
			if jobs.has(spec.station) or not ready_place(C.STATIONS[spec.station], at): return "busy"
			for good in spec.input:
				if stock[good] < spec.input[good]: return "short"
			for good in spec.input: stock[good] -= spec.input[good]
			jobs[spec.station] = {"recipe": recipe, "started": at, "seconds": float(r.get("seconds", spec.seconds))}
			notice = C.title(recipe) + " started"
		"collect":
			var station := str(r.get("station", ""))
			if not jobs.has(station) or job_remaining(station, at) > 0: return "not-ready"
			var spec: Dictionary = C.RECIPES[jobs[station].recipe]
			jobs.erase(station)
			stock[spec.output] += spec.quantity
			notice = "+%d %s" % [spec.quantity, C.title(spec.output).to_lower()]
		"orchard":
			if not ready_place("orchard", at): return "invalid"
			if orchard_watered < 0:
				orchard_watered = at; orchard_grow = float(r.get("seconds", C.ORCHARD_SECONDS)); notice = "Orchard watered"
			elif at - orchard_watered >= orchard_grow:
				orchard_watered = -1.0; stock.fruit += C.ORCHARD_YIELD; notice = "+%d fruit" % C.ORCHARD_YIELD
			else: return "growing"
		"sell":
			var good := C.good_id(str(r.get("good", "")))
			var count := int(r.get("count", 0))
			var amount := int(r.get("amount", 0))
			if not C.SELL_PRICE.has(good) or count < 1 or stock.get(good, 0) < count or amount < 0: return "short"
			# Sales saved with demand must match the price at that moment; older
			# sales keep their saved amount.
			var current := r.has("recover")
			if current and amount != quote(good, count, at): return "price"
			var recover := float(r.get("recover", C.DEMAND_RECOVER_SECONDS))
			glut[good] = {"units": glut_at(good, at) + count, "at": at, "recover": recover}
			stock[good] -= count
			lifetime_sales += amount
			notice = "Sold %d %s" % [count, C.title(good).to_lower()]
		"order":
			var slot := int(r.get("slot", -1))
			if slot < 0 or slot >= C.FOLK.size() or int(r.get("nth", -1)) != orders_filled[slot]: return "invalid"
			var good := C.good_id(str(r.get("good", "")))
			var count := int(r.get("count", 0))
			var want := C.order(slot, orders_filled[slot], owned_kinds())
			var current := r.has("folk")
			# Orders saved before the valley folk keep their own saved terms.
			if current and (str(r.folk) != want.folk or good != want.good or count != want.count): return "invalid"
			if count < 1 or stock.get(good, -1) < count: return "short"
			stock[good] -= count
			orders_filled[slot] += 1
			lifetime_sales += int(r.get("amount", 0))
			if current:
				for gift in want.keepsake: stock[gift] += want.keepsake[gift]
				speech = {"name": want.name, "line": want.thanks}
			notice = "Order delivered"
		"gift":
			var day := int(r.get("day", -1))
			if harvests == 0 or day <= gift_day: return "claimed"
			if absi(day - floori(at / 86400.0)) > 1: return "invalid"
			gift_streak = gift_streak_on(day)
			gift_day = day
			var basket := C.gift_basket(gift_streak)
			for good in basket: stock[good] += basket[good]
			notice = "Daily gift"
		"swap":
			var a := find(str(r.get("a", "")))
			var b := find(str(r.get("b", "")))
			if a.is_empty() or b.is_empty() or a.kind != b.kind: return "invalid"
			var cell: Vector2i = a.cell
			a.cell = b.cell
			b.cell = cell
		_:
			return "unknown"
	return ""

## A gift waits on any day after the first, once the farm has been harvested.
func gift_ready(today: int) -> bool:
	return harvests > 0 and today > gift_day and today > start_day
## The streak a gift claimed on `day` would reach.
func gift_streak_on(day: int) -> int:
	return gift_streak + 1 if gift_day >= 0 and day == gift_day + 1 else 1

func owned_kinds() -> Array:
	var kinds := []
	for item in items: if not kinds.has(item.kind): kinds.append(item.kind)
	return kinds

func open_orders() -> Array:
	var result := []
	for slot in C.ORDER_SLOTS.size():
		if owns(C.ORDER_SLOTS[slot].opens): result.append(C.order(slot, orders_filled[slot], owned_kinds()))
	return result

# --- renderer snapshot -------------------------------------------------------

## Payload for the renderer's `snapshot` message (homestead.gd protocol 1).
func snapshot(now: float, progress: int, reduced_motion := false) -> Dictionary:
	var out_items := []
	for item in items:
		out_items.append({"id": item.id, "kind": item.kind, "cell": {"x": item.cell.x, "z": item.cell.y}, "rotation": item.rotation, "style": item.style})
	var production := []
	var garden := first_of("garden")
	if not garden.is_empty():
		var ripe := false
		var growing := []
		for i in fields.size():
			var stage := field_stage(i, now)
			if stage == 4: ripe = true
			elif stage in [2, 3]: growing.append(field_remaining(i, now))
		var left: int = 0 if ripe or growing.is_empty() else growing.min()
		production.append({"placeID": garden.id, "station": "field", "good": "wheat", "state": 2 if ripe else (1 if not growing.is_empty() else 0),
			"remaining": left, "progress": 1.0 if ripe else (0.0 if growing.is_empty() else clampf(1.0 - left / field_total(0), 0, 1))})
	for station in C.STATIONS:
		var place := first_of(C.STATIONS[station])
		if place.is_empty(): continue
		var job: Dictionary = jobs.get(station, {})
		var remaining := job_remaining(station, now)
		var good: String = C.RECIPES[job.recipe].output if not job.is_empty() else C.RECIPES[C.recipes_for(station)[0]].output
		production.append({"placeID": place.id, "station": station, "good": good, "state": 0 if job.is_empty() else (1 if remaining > 0 else 2),
			"remaining": remaining, "progress": 0.0 if job.is_empty() else clampf(1.0 - float(remaining) / job.get("seconds", C.RECIPES[job.recipe].seconds), 0, 1)})
	var orchard := first_of("orchard")
	var fruit_stage := -1
	if not orchard.is_empty():
		var left := orchard_remaining(now)
		fruit_stage = 0 if orchard_watered < 0 else (1 if left > 0 else 2)
		production.append({"placeID": orchard.id, "station": "orchard", "good": "fruit", "state": fruit_stage, "remaining": left,
			"progress": 0.0 if orchard_watered < 0 else clampf(1.0 - left / orchard_grow, 0, 1)})
	var building := []
	for id in construction:
		var c: Dictionary = construction[id]
		var left := ceili(c.started + c.seconds - now)
		if left >= 1: building.append({"placeID": id, "remaining": left, "progress": clampf((now - c.started) / c.seconds, 0, 0.999)})
	var stages := []
	for i in fields.size(): stages.append(field_stage(i, now))
	return {"growthTreeID": "base:tree", "revision": str(seen.size()), "items": out_items, "land": land.duplicate(), "discovered": true,
		"approvedWins": progress, "appearance": {}, "reducedMotion": reduced_motion, "harvest": {}, "edges": true, "ovenRevealed": true,
		"visitor": "", "company": "", "wheatGarden": true, "farmStages": stages, "farmFruitStage": fruit_stage,
		"production": production, "construction": building}
