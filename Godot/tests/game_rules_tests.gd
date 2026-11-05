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
	WorldCatalogue.weather_override = "sunny"  # exact timers below; weather is checked at the end
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

	# Valley folk: named neighbours, wishes the farm can make, keepsakes.
	var fresh := WorldState.new()
	var asks_ok := true
	for n in 12: asks_ok = asks_ok and WorldCatalogue.order(0, n, fresh.owned_kinds()).good == "wheat"
	check(asks_ok, "Maeve only asks for wheat before the windmill")
	var rowan_ok := true
	for n in 12: rowan_ok = rowan_ok and not WorldCatalogue.order(1, n, ["garden", "windmill"]).good in ["fruit", "tart"]
	check(rowan_ok, "Rowan never asks for orchard goods without an orchard")
	fresh.stock.wheat = 99
	for n in 3:
		var wish := WorldCatalogue.order(0, n, fresh.owned_kinds())
		fresh.apply({"v": 1, "id": "folk-%d" % n, "type": "order", "at": 10.0 + n, "slot": 0, "nth": n, "folk": wish.folk, "good": wish.good, "count": wish.count, "amount": wish.reward})
	check(fresh.orders_filled[0] == 3 and fresh.stock.bread == 1, "every third delivery brings Maeve's keepsake")
	check(fresh.speech.get("name", "") == "Old Maeve" and fresh.speech.line != "", "the neighbour says thank you")
	var wrong := WorldCatalogue.order(0, 3, fresh.owned_kinds())
	check(fresh.apply({"v": 1, "id": "folk-bad", "type": "order", "at": 20.0, "slot": 0, "nth": 3, "folk": "rowan", "good": wrong.good, "count": wrong.count, "amount": 1}) == "invalid", "an order for the wrong neighbour is refused")
	# Saves from before the folk and the cheese: meat reads as cheese, old orders keep their terms.
	var legacy_state := WorldState.new()
	legacy_state.stock.cheese = 3
	check(legacy_state.apply({"v": 1, "id": "old-sell", "type": "sell", "at": 30.0, "good": "meat", "count": 1, "amount": 3}) == "", "an old meat sale replays as cheese")
	check(legacy_state.apply({"v": 1, "id": "old-order", "type": "order", "at": 31.0, "slot": 2, "nth": 0, "good": "meat", "count": 2, "amount": 11}) == "", "an old meat order replays on its saved terms")
	check(legacy_state.stock.cheese == 0 and legacy_state.orders_filled[2] == 1 and legacy_state.speech.is_empty(), "old orders advance the slot without a keepsake")
	check(WorldCatalogue.RECIPES.livestock.output == "cheese" and not WorldCatalogue.GOODS.has("meat"), "the barn makes cheese")

	# Daily gift: none on the first day, one per later day, streak grows it.
	check(not game.gift_ready(), "no gift on the first day")
	clock.t += 86400.0
	check(game.gift_ready(), "a gift waits the next day")
	check(game.gift_basket() == WorldCatalogue.GIFT_BASKETS[0], "first gift is day 1's basket")
	var wheat_before: int = game.state.stock.wheat
	var coins_before_gift := host.coins
	var claim_result := game.claim_gift()
	check(claim_result == "", "claim the gift (%s)" % claim_result)
	check(game.state.stock.wheat == wheat_before + 2 and host.coins == coins_before_gift, "gift adds goods, never coins")
	check(game.claim_gift() == "claimed" and not game.gift_ready(), "one gift per day")
	var twin := {"v": 1, "id": "twin-gift", "type": "gift", "at": clock.t + 5, "seq": 9999, "day": game.today()}
	check(WorldState.replay(host.records + [twin]).stock.wheat == game.state.stock.wheat, "a second device's gift for the same day is ignored")
	clock.t += 86400.0
	check(game.state.gift_streak_on(game.today()) == 2 and game.gift_basket() == WorldCatalogue.GIFT_BASKETS[1], "next day climbs the streak")
	game.claim_gift()
	clock.t += 86400.0 * 2
	check(game.state.gift_streak_on(game.today()) == 1, "a missed day starts the week again")
	check(WorldState.replay(host.records).gift_streak == 2, "replay keeps the streak")
	check(WorldCatalogue.gift_basket(8) == WorldCatalogue.GIFT_BASKETS[0], "the week loops after day 7")

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

	# Market demand: each sale lowers that good's next price, demand recovers
	# over time, other goods are untouched, and replay holds sellers to the price.
	var dclock := {"t": 50000.0}
	var dhost := MemoryHost.new()
	var dgame := WorldGame.new(dhost)
	dgame.clock = func(): return dclock.t
	check(dgame.sell_price("tart") == 10, "a fresh market pays the base price")
	check(dgame.sell_price("tart", 3) == 10 + 9 + 8, "a batch prices each unit after the last")
	check(dgame.state.quote("tart", 12, dclock.t) == 10 + 9 + 8 + 6 + 5 + 4 + 4 + 4 + 4 + 4 + 4 + 4, "prices stop at the floor")
	var ds := WorldState.new()
	for good in ["tart", "bread"]: ds.stock[good] = 20
	check(ds.apply({"v": 1, "id": "s1", "type": "sell", "at": 100.0, "good": "tart", "count": 3, "amount": 27, "recover": 45}) == "", "a sale at the quoted price saves")
	check(ds.quote("tart", 1, 100.0) == 6, "three sold: the fourth tart is cheaper")
	check(ds.quote("bread", 1, 100.0) == 5, "other goods keep their price")
	check(ds.quote("tart", 1, 100.0 + 45.0 * 3) == 10, "demand fully recovers in time")
	check(ds.quote("tart", 1, 100.0 + 45.0) == 8, "demand recovers one unit at a time")
	check(ds.apply({"v": 1, "id": "s2", "type": "sell", "at": 101.0, "good": "tart", "count": 1, "amount": 10, "recover": 45}) == "price", "replay rejects a sale above the market price")
	check(ds.apply({"v": 1, "id": "s3", "type": "sell", "at": 102.0, "good": "tart", "count": 1, "amount": 10}) == "", "older sales keep their saved amount")
	# Through the game: harvest, sell, and replay reaches the same total.
	var mhost := MemoryHost.new()
	var mgame := WorldGame.new(mhost)
	var mclock := {"t": 9000.0}
	mgame.clock = func(): return mclock.t
	mgame.tend(0); mgame.tend(0); mclock.t += WorldCatalogue.FIRST_FIELD_SECONDS; mgame.tend(0)
	mgame.tend(1); mgame.tend(1); mclock.t += WorldCatalogue.FIELD_SECONDS; mgame.tend(1)
	check(mgame.state.stock.wheat == 4 and mgame.sell("wheat", 4) == "" and mhost.earned == 4, "cheap goods never drop below 1 coin")
	check(WorldState.replay(mhost.records).lifetime_sales == 4, "demand sales replay to the same total")
	# In season: one makeable good sells for more each window, the next one is
	# known ahead, and replay holds the season frozen in the sale.
	var ss := WorldState.new()
	check(ss.season_good(0.0, 600.0) == "", "no season while only wheat can be made")
	ss.items.append({"id": "w", "kind": "windmill", "cell": Vector2i(1, 13), "rotation": 0, "style": ""})
	ss.items.append({"id": "g", "kind": "garden", "cell": Vector2i(2, 10), "rotation": 0, "style": ""})
	check(ss.makeable_goods() == ["wheat", "flour", "bread", "meal"], "makeable goods follow the places owned")
	var seen_goods := {}
	var last_good := ""
	var repeats := 0
	for w in 8:
		var g := ss.season_good(w * 600.0 + 1.0, 600.0)
		seen_goods[g] = true
		if g == last_good: repeats += 1
		last_good = g
	check(seen_goods.size() == 4 and repeats == 0, "every makeable good comes into season and none repeats")
	var hot := ss.season_good(1000.0, 600.0)
	check(ss.season_good(1000.0, 600.0, 1) == ss.season_good(1300.0, 600.0), "the next good is the one after the window turns")
	check(ss.season_left(1000.0, 600.0) == 200, "time left counts to the window's end")
	ss.stock[hot] = 10
	var base_price: int = WorldCatalogue.SELL_PRICE[hot]
	var hot_price := ss.quote(hot, 1, 1000.0, 600.0)
	check(hot_price == maxi(1, roundi(base_price * 1.5)) and ss.quote(hot, 1, 1000.0) == base_price, "the season good sells for half again; older quotes ignore it")
	check(ss.quote(hot, 4, 1000.0, 600.0) < hot_price * 4, "demand still drops a season good per unit")
	check(ss.apply({"v": 1, "id": "h1", "type": "sell", "at": 1000.0, "good": hot, "count": 1, "amount": base_price, "recover": 45}) == "", "a demand-era sale without a season keeps the plain price")
	check(ss.apply({"v": 1, "id": "h2", "type": "sell", "at": 1001.0, "good": hot, "count": 1, "amount": base_price, "recover": 45, "season": 600}) == "price", "replay rejects a season sale at the plain price")
	# The Barge: docks on a schedule, asks for crates of makeable goods, pays the
	# list price per crate plus a bonus for a full hold, then leaves early.
	var bs := WorldState.new()
	check(bs.barge_manifest(0).is_empty(), "no barge before the windmill")
	bs.items.append({"id": "w", "kind": "windmill", "cell": Vector2i(1, 13), "rotation": 0, "style": ""})
	var blen := 7200.0
	var bstay := 2700.0
	var bcyc := 100
	var bstart := bcyc * blen
	var bman := bs.barge_manifest(bcyc)
	check(bman.size() == 2 and bman.all(func(l): return l.good != "wheat" and l.count >= 2), "a windmill farm's barge wants two crates of made goods (%s)" % [bman])
	check(bman[0].good != bman[1].good, "a manifest never repeats a good")
	check(bs.barge_docked(bstart + 10.0, blen, bstay) and not bs.barge_docked(bstart + bstay + 1.0, blen, bstay), "the barge waits its stay, then is away")
	for line in bman: bs.stock[line.good] = 20
	var line_a: Dictionary = bman[0]
	var line_b: Dictionary = bman[1]
	var p1: int = WorldCatalogue.SELL_PRICE[line_a.good]
	var p2: int = WorldCatalogue.SELL_PRICE[line_b.good]
	var bbonus := WorldCatalogue.barge_bonus(bman)
	var bload := func(id: String, at: float, good: String, count: int, amount: int, c := bcyc) -> String:
		return bs.apply({"v": 1, "id": id, "type": "barge", "at": at, "cycle": c, "cycle_len": blen, "stay": bstay, "good": good, "count": count, "amount": amount})
	check(bload.call("b0", bstart + bstay + 5.0, line_a.good, 1, p1) == "departed", "nothing loads once the barge has gone")
	check(bload.call("b1", bstart + 20.0, line_a.good, 1, p1 + 1) == "price", "a crate pays exactly the list price")
	check(bload.call("b2", bstart + 20.0, line_a.good, int(line_a.count), p1 * int(line_a.count)) == "", "a part load pays at once")
	check(bs.barge_loaded(line_a.good, bcyc) == line_a.count and bs.glut_at(line_a.good, bstart + 21.0) == 0.0, "loaded crates count and never dip the market")
	check(bload.call("b3", bstart + 30.0, line_a.good, 1, p1) == "hold-full", "a full crate takes no more")
	check(bload.call("b4", bstart + 40.0, line_b.good, int(line_b.count), p2 * int(line_b.count)) == "price", "the load that fills the hold must include the bonus")
	var sales_before := bs.lifetime_sales
	check(bload.call("b5", bstart + 40.0, line_b.good, int(line_b.count), p2 * int(line_b.count) + bbonus) == "", "filling the hold pays the bonus")
	check(bs.barges_filled == 1 and bs.lifetime_sales == sales_before + p2 * int(line_b.count) + bbonus, "a filled barge is counted and its pay counts as sales")
	check(not bs.barge_docked(bstart + 50.0, blen, bstay), "a filled barge sails early")
	var next_manifest := bs.barge_manifest(bcyc + 1)
	check(not next_manifest.is_empty() and bs.barge_loaded(next_manifest[0].good, bcyc + 1) == 0, "the next barge starts empty")
	# Through the game: the next barge is shown while this one is away, and an
	# empty farm can't load.
	var bhost := MemoryHost.new()
	var bclock := {"t": bstart + 10.0}
	bhost.records.append({"v": 1, "id": "wm", "type": "build", "at": bstart, "seq": 1, "kind": "windmill", "place": "place:windmill:t", "x": 1, "z": 13, "price": 0, "seconds": 0})
	var bgame := WorldGame.new(bhost)
	bgame.clock = func(): return bclock.t
	var binfo := bgame.barge()
	check(binfo.get("docked", false) and binfo.left == int(bstay) - 10 and binfo.lines.size() == 2, "the game shows a docked barge and its time left")
	check(bgame.load_barge(binfo.lines[0].good) == "short", "an empty farm can't load the barge")
	bclock.t = bstart + bstay + 100.0
	binfo = bgame.barge()
	check(not binfo.docked and binfo.cycle == bcyc + 1 and binfo.left == int(blen - bstay) - 100, "while away, the next barge and its manifest are shown")
	check(bgame.snapshot().barge == false, "the renderer is told the barge is away")
	# Weather: a known pattern, never the same spell twice running, and only
	# ever faster. The sped-up time is frozen in the job's record.
	WorldCatalogue.weather_override = ""
	var wpat: Array = WorldCatalogue.WEATHER_PATTERN
	var wrepeat := false
	for i in wpat.size(): wrepeat = wrepeat or wpat[i] == wpat[(i + 1) % wpat.size()]
	check(not wrepeat and wpat.all(func(w): return WorldCatalogue.WEATHER.has(w)), "the weather never repeats a spell back to back, even across the cycle")
	check(WorldCatalogue.WEATHER.values().all(func(w): return w.boost.values().all(func(b): return b >= 1.0)), "weather only ever speeds things up")
	var wlen := float(WorldCatalogue.duration(WorldCatalogue.WEATHER_SECONDS))
	var wrain := wpat.find("rain")
	var wsun := wpat.find("sunny")
	var whost := MemoryHost.new()
	var wclock := {"t": wrain * wlen + 30.0}
	var wgame := WorldGame.new(whost)
	wgame.clock = func(): return wclock.t
	check(wgame.weather() == "rain" and wgame.forecast().left == int(wlen) - 30 and wgame.forecast().next[0] == wpat[(wrain + 1) % wpat.size()], "the forecast names this spell, its time left and the next")
	check(wgame.snapshot().weather == "rain", "the renderer is told the sky")
	check(wgame.tend(0) == "" and wgame.tend(0) == "", "planting and watering in the rain work")
	var wrec: Dictionary = whost.records[-1]
	check(int(wrec.seconds) == WorldCatalogue.duration(WorldCatalogue.FIRST_FIELD_SECONDS / 2.0) and wrec.get("weather") == "rain", "rain halves the field's timer and notes why (%s)" % [wrec])
	var wfrozen := wgame.state.field_total(0)
	wclock.t = (wrain + 1) * wlen + 1.0
	wgame.refresh()
	check(wgame.state.field_total(0) == wfrozen and wfrozen < WorldCatalogue.FIELD_SECONDS, "a running timer keeps its rainy length when the sky changes")
	var whost2 := MemoryHost.new()
	var wclock2 := {"t": wsun * wlen + 30.0}
	var wgame2 := WorldGame.new(whost2)
	wgame2.clock = func(): return wclock2.t
	check(wgame2.tend(0) == "" and wgame2.tend(0) == "" and int(whost2.records[-1].seconds) == WorldCatalogue.duration(WorldCatalogue.FIRST_FIELD_SECONDS) and not whost2.records[-1].has("weather"), "a sunny spell leaves timers as they are")
	print("game rules: %d checks, %d failed" % [checks, failures])
	host.free()
	quit(1 if failures > 0 else 0)
