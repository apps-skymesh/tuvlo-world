extends SceneTree
# Plays the solo game for a few steps and saves screenshots.
# xvfb-run godot --path Godot -s res://tests/solo_capture.gd -- <output-dir>
var main
var out := "user://captures"
var offset := {"s": 0.0}
var step := 0
var wait := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var save := "user://tuvlo-world-save.json"
	if FileAccess.file_exists(save): DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	main = load("res://scenes/game.tscn").instantiate()
	root.add_child(main)

func shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("captured ", name)

func _process(delta: float) -> bool:
	wait -= delta
	if wait > 0: return false
	var game: WorldGame = main.game
	if step == 0: game.clock = func(): return Time.get_unix_time_from_system() + offset.s
	match step:
		0: wait = 4.0
		1: shot("00-title"); main.ui.dismiss_title(); wait = 1.0
		2: shot("01-start")
		3: main.ui.goal_action.call(); wait = 0.6
		4: shot("02-planted-quick")
		5: main.ui.place_tapped("base:garden"); wait = 0.6
		6: offset.s += 25; main.push(); wait = 1.0
		7: shot("03-farm-ready")
		8: main.ui.place_tapped("base:garden"); wait = 0.35
		9: shot("04-harvest-fly")
		10: wait = 1.5
		11: main.ui.open("place", "base:garden"); wait = 4.0
		12: shot("05-farm-card")
		13: main.ui.close(); main.ui.open("more"); wait = 1.0
		14: shot("06-market-orders")
		15: main.ui._act(game.deliver(0)); wait = 0.3
		16: shot("07-order-coins")
		17:
			main.ui.close(); main.host.grant("test-level", 40, []); main.push()
			main.ui.open("build"); wait = 1.0
		18: shot("08-build-tray")
		19: main.ui._pick_build("windmill", ""); wait = 1.5
		20: shot("09-build-spot")
		21:
			main.ui._confirm_build(); offset.s += 20; main.push(); wait = 2.0
		22:
			main.ui.open("place", game.state.first_of("windmill").id, "mill"); wait = 4.0
		23: shot("10-mill-card")
		24:
			main.ui._ring_dropped("wheat"); offset.s += 40; main.push(); wait = 1.0
		25: shot("11-mill-working")
		26:
			main.ui.close(); main.ui.open("more"); wait = 1.0
		27: shot("12-market")
		28:
			for good in game.state.stock:
				if game.state.stock[good] > 0: game.sell(good, game.state.stock[good])
			main.ui.close(); main.push(); wait = 0.5
		29: shot("13-level-up")
		30: main.ui.open("settings"); wait = 0.8
		31: shot("14-settings")
		32:
			# Jump to just after the next barge docks; it glides into the cove.
			main.ui.close()
			var length := float(WorldCatalogue.duration(WorldCatalogue.BARGE_CYCLE_SECONDS))
			var at: float = game.now()
			offset.s += (floorf(at / length) + 1.0) * length + 30.0 - at
			main.push(); wait = 4.5
		33: shot("15-barge-docked")
		34:
			# Display only: some goods in stock and part of the hold loaded.
			var info: Dictionary = game.barge()
			for line in info.lines: game.state.stock[line.good] = int(line.count) + 1
			game.state.barge = {"cycle": info.cycle, "manifest": info.lines.map(func(l): return {"good": l.good, "count": l.count}), "loaded": {info.lines[0].good: info.lines[0].count}}
			main.ui.open("barge"); wait = 2.5
		35: shot("16-barge-screen")
		36:
			# A rain spell: streaks over the map, cooler light, the sky pill.
			main.ui.close()
			var wlen := float(WorldCatalogue.duration(WorldCatalogue.WEATHER_SECONDS))
			var wat: float = game.now()
			var wnext := floori(wat / wlen) + 1
			while WorldCatalogue.weather_in(wnext) != "rain": wnext += 1
			offset.s += wnext * wlen + 20.0 - wat
			main.push(); wait = 4.0
		37: shot("17-weather-rain")
		38: main.ui.open("place", "base:garden"); wait = 3.0
		39: shot("18-rain-field-card")
		40: main.ui.close(); main.ui.open("weather"); wait = 1.5
		41: shot("19-forecast")
		42:
			# The cottage window: oven and kitchen products along the top, a
			# loaf in the oven.
			main.ui.close()
			game.state.stock.flour += 2; game.state.stock.fruit += 2; game.state.stock.bread += 1
			main.ui.open("place", "base:cottage", "oven"); wait = 1.2
		43: main.ui.ring.working = true; main.ui.ring.label = "0:42"; main.ui.ring.progress = 0.35; wait = 1.0
		44: shot("20-oven-baking")
		45: main.ui.close(); main.ui.open("place", "base:garden"); wait = 0.6
		46: main.ui._ring_dropped("seed"); wait = 1.0
		47: shot("21-field-seed-dropped")
		48: main.ui._ring_dropped("water"); wait = 2.0
		49: shot("22-field-growing")
		50: main.ui._instant(); wait = 2.0
		51: shot("23-field-finished-with-stars")
		52: return true
	step += 1
	return false
