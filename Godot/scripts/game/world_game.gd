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
		"x": cell.x, "z": cell.y, "price": price, "seconds": int(C.BUILDS[kind].seconds)})
	return _commit(record, price)

func buy_land(side: String) -> String:
	if not C.LAND.has(side) or side in state.land: return "invalid"
	if host.progress() < C.LAND[side].gate: return "locked"
	var price := int(C.LAND[side].price)
	if host.wallet() < price: return "short"
	return _commit(_record("land", {"side": side, "price": price}), price)

func tend(field: int) -> String: return _commit(_record("tend", {"field": field}))
func make(recipe: String) -> String: return _commit(_record("make", {"recipe": recipe}))
func collect(station: String) -> String: return _commit(_record("collect", {"station": station}))
func tend_orchard() -> String: return _commit(_record("orchard"))

func sell(good: String, count: int) -> String:
	if not host.features().get("market", false): return "unavailable"
	if not C.SELL_PRICE.has(good) or count < 1 or state.stock.get(good, 0) < count: return "short"
	var amount: int = C.SELL_PRICE[good] * count
	return _commit(_record("sell", {"good": good, "count": count, "amount": amount}), 0, amount)

func snapshot() -> Dictionary:
	return state.snapshot(now(), host.progress(), host.player().get("reduced_motion", false))
