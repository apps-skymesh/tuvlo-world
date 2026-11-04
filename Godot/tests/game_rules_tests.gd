extends SceneTree
# Headless rules tests: godot --headless --path Godot -s res://tests/game_rules_tests.gd
# Exits 0 when every check passes.

class MemoryHost extends WorldHost:
	var coins := 6
	var earned := 0
	var records: Array = []
	var receipts := {}
	var fail_saves := false
	func wallet() -> int: return coins
	func progress() -> int: return earned / WorldCatalogue.SOLO_SALES_PER_LEVEL
	func earned_total() -> int: return earned
	func features() -> Dictionary: return {"market": true}
	func load_records() -> Array: return records.duplicate(true)
	func append_records(list: Array) -> bool:
		if fail_saves: return false
		records.append_array(list); return true
	func commit_purchase(id: String, price: int, list: Array) -> Dictionary:
		if receipts.has(id): return {"ok": true, "receipt": receipts[id]}
		if fail_saves: return {"ok": false, "error": "save"}
		if coins < price: return {"ok": false, "error": "short"}
		coins -= price; receipts[id] = {"price": price}; records.append_array(list)
		return {"ok": true, "receipt": receipts[id]}
	func grant(id: String, amount: int, list: Array) -> Dictionary:
		if receipts.has(id): return {"ok": true, "receipt": receipts[id]}
		if fail_saves: return {"ok": false, "error": "save"}
		coins += amount; earned += amount; receipts[id] = {"amount": amount}; records.append_array(list)
		return {"ok": true, "receipt": receipts[id]}

var failures := 0
var checks := 0
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	WorldCatalogue.speed_override = 1.0  # rules run at normal speed; quick play is checked below
	var clock := {"t": 1000.0}  # lambdas capture locals by value
	var host := MemoryHost.new()
	var game := WorldGame.new(host)
	game.clock = func(): return clock.t

	# Starting homestead.
	check(game.state.owns("cottage") and game.state.owns("tree") and game.state.owns("garden"), "starter places")
	var snap := game.snapshot()
	var renderer := HomesteadWorldData.new()
	check(renderer.apply_snapshot(snap), "renderer accepts the starting snapshot")

	# Field: plant, water, wait, harvest.
	check(game.tend(0) == "", "plant")
	check(game.tend(0) == "", "water")
	check(game.tend(0) == "growing", "can't harvest while growing")
	check(game.state.field_remaining(0, clock.t) == int(WorldCatalogue.FIRST_FIELD_SECONDS), "the very first wheat grows fast")
	clock.t += WorldCatalogue.FIRST_FIELD_SECONDS
	check(game.tend(0) == "", "harvest")
	check(game.state.stock.wheat == 2, "harvest gives 2 wheat")

	# Gates and money.
	check(game.build("windmill") == "locked", "windmill gated by level")
	check(game.sell("wheat", 2) == "", "sell wheat")
	check(host.coins == 8 and host.earned == 2, "sale pays coins")
	check(game.state.stock.wheat == 0, "sale removes wheat")
	check(game.sell("wheat", 1) == "short", "can't sell what you don't have")
	host.earned = 30
	check(host.progress() == 6, "level from sales")
	check(game.build("windmill") == "", "build windmill")
	check(host.coins == 2, "windmill costs 6")
	var mill := game.state.first_of("windmill")
	check(mill.cell == Vector2i(1, 13), "windmill takes its first fixed spot")
	check(game.state.is_building(mill.id, clock.t), "windmill under construction")
	check(game.build("windmill") == "owned", "only one windmill")
	check(renderer.apply_snapshot(game.snapshot()), "renderer accepts construction snapshot")

	# Production chain: wheat -> flour -> bread.
	for i in 2:
		game.tend(i); game.tend(i)
	check(game.state.field_total(0) == WorldCatalogue.FIELD_SECONDS, "later wheat takes the normal time")
	clock.t += WorldCatalogue.FIELD_SECONDS
	game.tend(0); game.tend(1)
	check(game.state.stock.wheat == 4, "two fields harvested")
	check(game.make("flour") == "", "mill starts after construction")
	check(game.make("flour") == "busy", "one job per station")
	check(game.collect("mill") == "not-ready", "flour not ready yet")
	clock.t += WorldCatalogue.RECIPES.flour.seconds
	check(game.collect("mill") == "", "collect flour")
	check(game.make("bread") == "", "oven bakes")
	clock.t += WorldCatalogue.RECIPES.bread.seconds
	check(game.collect("oven") == "" and game.state.stock.bread == 1, "bread collected")
	check(renderer.apply_snapshot(game.snapshot()), "renderer accepts production snapshot")

	# Failed save changes nothing.
	host.fail_saves = true
	var before: int = game.state.stock.bread
	check(game.sell("bread", 1) == "save", "failed save reported")
	check(game.state.stock.bread == before and host.coins == 2, "failed save leaves state and wallet")
	host.fail_saves = false

	# Replay is deterministic and duplicate records count once.
	var replayed := WorldState.replay(host.records + host.records)
	check(replayed.stock.bread == game.state.stock.bread and replayed.stock.wheat == game.state.stock.wheat, "replay matches and ignores duplicates")
	check(replayed.items.size() == game.state.items.size(), "replay keeps places")

	# Two devices consuming the same bread: only one sale applies on merge.
	var sale_a := {"v": 1, "id": "a", "type": "sell", "at": clock.t + 1, "good": "bread", "count": 1, "amount": 5}
	var sale_b := {"v": 1, "id": "b", "type": "sell", "at": clock.t + 2, "good": "bread", "count": 1, "amount": 5}
	var merged := WorldState.replay(host.records + [sale_a, sale_b])
	check(merged.stock.bread == 0 and merged.rejected == 1, "conflicting offline sales: second one rejected")

	# Land and meadow-only places.
	host.earned = 200; host.coins = 100
	check(game.build("orchard") == "land", "orchard needs the west meadow")
	check(game.buy_land("west") == "", "buy west meadow")
	check(game.build("orchard") == "", "orchard on the meadow")
	check(game.state.first_of("orchard").cell == Vector2i(-10, 2), "orchard spot")
	check(renderer.apply_snapshot(game.snapshot()), "renderer accepts land snapshot")

	# Market orders: deterministic, and each order fills once.
	check(WorldCatalogue.order(1, 3) == WorldCatalogue.order(1, 3), "orders are deterministic")
	var first: Dictionary = game.state.open_orders()[0]
	game.state.stock.wheat = 0
	check(game.deliver(0) == "short", "order needs the goods")
	game.state.stock.wheat = 0
	for i in 3:
		game.tend(0); game.tend(0); clock.t += WorldCatalogue.FIELD_SECONDS; game.tend(0)
	var coins_before := host.coins
	check(game.state.stock.wheat >= first.count, "enough wheat for the order")
	check(game.deliver(0) == "", "deliver order")
	check(host.coins == coins_before + first.reward, "order pays its reward")
	check(game.state.open_orders()[0].nth == 1, "next order in that slot")
	var again := WorldState.replay(host.records)
	check(again.orders_filled[0] == 1, "replay keeps delivered orders")

	# Quick play: new timers run 5× faster; a running timer keeps its frozen length.
	WorldCatalogue.speed_override = WorldCatalogue.QUICK_PLAY_SPEED
	check(WorldCatalogue.duration(WorldCatalogue.FIELD_SECONDS) == 24, "quick play wheat grows in 24 s")
	game.state.stock.wheat = 2
	check(game.make("flour") == "", "quick mill starts")
	WorldCatalogue.speed_override = 1.0
	check(game.state.job_remaining("mill", clock.t) == 36, "running job keeps its quick length after the speed changes")
	check(WorldState.replay(host.records).job_remaining("mill", clock.t) == 36, "replay keeps the frozen length")
	var legacy := WorldState.replay([{"v": 1, "id": "old", "type": "tend", "at": 0.0, "seq": 1, "field": 0}, {"v": 1, "id": "old2", "type": "tend", "at": 1.0, "seq": 2, "field": 0}])
	check(legacy.field_remaining(0, 1.0) == int(WorldCatalogue.FIELD_SECONDS), "records without a length use the catalogue time")

	print("game rules: %d checks, %d failed" % [checks, failures])
	host.free()
	quit(1 if failures > 0 else 0)
