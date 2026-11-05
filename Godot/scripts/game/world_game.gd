class_name WorldGame
extends RefCounted

## Game actions. Each action builds one record, checks it against the rules on a
## replayed copy, then asks the host to save it (with a charge or a sale where
## needed). The shown state only changes after the host confirms the save.

const C = preload("res://scripts/game/catalogue.gd")
var host: WorldHost
var state: WorldState
var clock: Callable = func() -> float: return Time.get_unix_time_from_system()

func _init(world_host: WorldHost) -> void:
	host = world_host
	refresh()

func refresh() -> void:
	state = WorldState.replay(host.load_records())

func now() -> float: return clock.call()

static func new_id() -> String:
	var hex := Crypto.new().generate_random_bytes(16).hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func _record(type: String, fields := {}) -> Dictionary:
	# Order must survive replay: never earlier than the last record, and a
	# sequence number breaks ties between records saved in the same instant.
	var at := now()
	var seq := 0
	for r in host.load_records():
		at = maxf(at, float(r.get("at", 0)))
		seq = maxi(seq, int(r.get("seq", 0)))
	var record := {"v": C.SAVE_VERSION, "id": new_id(), "type": type, "at": at, "seq": seq + 1}
	record.merge(fields)
	return record

## Returns "" on success or a short reason. Nothing changes on failure.
func _commit(record: Dictionary, price := 0, earn := 0) -> String:
	if host.access() != "full": return "read-only"
	var candidate := WorldState.replay(host.load_records())
	var reason := candidate.apply(record)
	if reason != "": return reason
	var saved := true
	if price > 0:
		var result := host.commit_purchase(record.id, price, [record])
		if not result.ok: return result.error
	elif earn > 0:
		var result := host.grant(record.id, earn, [record])
		if not result.ok: return result.error
	else:
		saved = host.append_records([record])
	if not saved: return "save"
	state = candidate
	return ""

func build_price(kind: String) -> int: return int(C.BUILDS[kind].price)

func build(kind: String) -> String:
	var blocker := state.build_blocker(kind, host.progress())
	if blocker != "": return blocker
	var price := build_price(kind)
	if host.wallet() < price: return "short"
	var cell: Vector2i = state.free_spot(kind)
	var record := _record("build", {"kind": kind, "place": "place:%s:%s" % [kind, new_id().substr(0, 8)],
		"x": cell.x, "z": cell.y, "price": price, "seconds": C.duration(C.BUILDS[kind].seconds)})
	return _commit(record, price)

func buy_land(side: String) -> String:
	if not C.LAND.has(side) or side in state.land: return "invalid"
	if host.progress() < C.LAND[side].gate: return "locked"
	var price := int(C.LAND[side].price)
	if host.wallet() < price: return "short"
	return _commit(_record("land", {"side": side, "price": price}), price)

func tend(field: int) -> String:
	var grow := C.FIRST_FIELD_SECONDS if state.harvests == 0 else C.FIELD_SECONDS
	return _commit(_record("tend", {"field": field, "seconds": C.duration(grow)}))
func make(recipe: String) -> String:
	if not C.RECIPES.has(recipe): return "invalid"
	return _commit(_record("make", {"recipe": recipe, "seconds": C.duration(C.RECIPES[recipe].seconds)}))
func collect(station: String) -> String: return _commit(_record("collect", {"station": station}))
func tend_orchard() -> String: return _commit(_record("orchard", {"seconds": C.duration(C.ORCHARD_SECONDS)}))

func sell(good: String, count: int) -> String:
	if not host.features().get("market", false): return "unavailable"
	if not C.SELL_PRICE.has(good) or count < 1 or state.stock.get(good, 0) < count: return "short"
	var record := _record("sell", {"good": good, "count": count, "recover": C.duration(C.DEMAND_RECOVER_SECONDS), "season": C.duration(C.SEASON_SECONDS)})
	# Priced at the record's own time, so replay reaches the same amount.
	record.amount = state.quote(good, count, record.at, record.season)
	return _commit(record, 0, record.amount)

## What selling `count` of `good` would pay right now.
func sell_price(good: String, count := 1) -> int: return state.quote(good, count, now(), C.duration(C.SEASON_SECONDS))
## The market's favourite now and next, and seconds until it changes.
func season() -> Dictionary:
	var length := C.duration(C.SEASON_SECONDS)
	var at := now()
	return {"good": state.season_good(at, length), "next": state.season_good(at, length, 1), "left": state.season_left(at, length),
		"window": state.season_window(at, length)}

## The barge as the player sees it: docked now (with time until it leaves) or
## away (with time until the next one and that barge's manifest).
func barge() -> Dictionary:
	if not state.owns(C.BARGE_OPENS) or not host.features().get("market", false): return {}
	var length := float(C.duration(C.BARGE_CYCLE_SECONDS))
	var stay := float(C.duration(C.BARGE_STAY_SECONDS))
	var at := now()
	var cycle := state.barge_cycle(at, length)
	var docked: bool = state.barge_docked(at, length, stay)
	var filled: bool = state.barge.get("cycle", -1) == cycle and state.barge_complete()
	var shown := cycle if docked else cycle + 1
	var manifest := state.barge_manifest(shown)
	if manifest.is_empty(): return {}
	var lines := []
	var wanted := 0
	var loaded := 0
	for line in manifest:
		var have := state.barge_loaded(line.good, shown)
		lines.append({"good": line.good, "count": int(line.count), "loaded": have, "price": int(C.SELL_PRICE[line.good])})
		wanted += int(line.count); loaded += have
	var left := ceili(cycle * length + stay - at) if docked else ceili((cycle + 1) * length - at)
	return {"docked": docked, "filled": filled, "cycle": shown, "left": left, "lines": lines, "wanted": wanted, "loaded": loaded,
		"value": C.barge_value(manifest), "bonus": C.barge_bonus(manifest), "shipped": state.barges_filled}

## Loads as many crates of `good` as the barge still wants and the farm has.
func load_barge(good: String) -> String:
	var info := barge()
	if info.is_empty(): return "unavailable"
	if not info.docked: return "departed"
	var lines: Array = info.lines.filter(func(l): return l.good == good)
	if lines.is_empty(): return "invalid"
	var count := mini(int(state.stock.get(good, 0)), int(lines[0].count) - int(lines[0].loaded))
	if count < 1: return "short" if int(lines[0].loaded) < int(lines[0].count) else "hold-full"
	var record := _record("barge", {"cycle": int(info.cycle), "cycle_len": C.duration(C.BARGE_CYCLE_SECONDS), "stay": C.duration(C.BARGE_STAY_SECONDS), "good": good, "count": count})
	# Each crate pays the list price; the load that fills the hold adds the bonus.
	record.amount = count * int(lines[0].price)
	if int(info.loaded) + count == int(info.wanted): record.amount += int(info.bonus)
	return _commit(record, 0, record.amount)

func deliver(slot: int) -> String:
	if not host.features().get("market", false): return "unavailable"
	if slot < 0 or slot >= C.ORDER_SLOTS.size() or not state.owns(C.ORDER_SLOTS[slot].opens): return "invalid"
	var want := state.open_orders().filter(func(o): return o.slot == slot)
	if want.is_empty(): return "invalid"
	var order: Dictionary = want[0]
	if state.stock.get(order.good, 0) < order.count: return "short"
	return _commit(_record("order", {"slot": slot, "nth": order.nth, "folk": order.folk, "good": order.good, "count": order.count, "amount": order.reward}), 0, order.reward)

func today() -> int: return C.local_day(now())
func gift_ready() -> bool: return state.gift_ready(today())
## The basket waiting today, or empty when there is none.
func gift_basket() -> Dictionary: return C.gift_basket(state.gift_streak_on(today())) if gift_ready() else {}
func claim_gift() -> String:
	if not gift_ready(): return "claimed"
	return _commit(_record("gift", {"day": today()}))

## Sales still needed for the next level (solo hosts; 0 when unknown).
func next_level_progress() -> Vector2:
	if not host.has_method("earned"): return Vector2.ZERO
	var per := C.SOLO_SALES_PER_LEVEL
	return Vector2(host.earned() % per, per)

func snapshot() -> Dictionary:
	var out := state.snapshot(now(), host.progress(), host.player().get("reduced_motion", false))
	var info := barge()
	out["barge"] = info.get("docked", false)
	out["bargeCargo"] = float(info.loaded) / maxf(1.0, float(info.wanted)) if info.get("docked", false) else 0.0
	return out
