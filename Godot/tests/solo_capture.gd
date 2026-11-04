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
		1: shot("01-start")
		2: main.ui.goal_action.call(); wait = 0.6
		3: shot("02-planted-quick")
		4: main.ui.place_tapped("base:garden"); wait = 0.6
		5: offset.s += 31; main.push(); wait = 1.0
		6: shot("03-farm-ready")
		7: main.ui.place_tapped("base:garden"); wait = 0.35
		8: shot("04-harvest-fly")
		9: wait = 1.5
		10: main.ui.open("place", "base:garden"); wait = 4.0
		11: shot("05-farm-card")
		12: main.ui.close(); main.ui.open("more"); wait = 1.0
		13: shot("06-market-orders")
		14: main.ui._act(game.deliver(0)); wait = 0.3
		15: shot("07-order-coins")
		16:
			main.ui.close(); main.host.grant("test-level", 40, []); main.push()
			main.ui.open("build"); wait = 1.0
		17: shot("08-build-tray")
		18: main.ui._pick_build("windmill", ""); wait = 1.5
		19: shot("09-build-spot")
		20:
			main.ui._confirm_build(); offset.s += 9; main.push(); wait = 2.0
		21:
			main.ui.open("place", game.state.first_of("windmill").id, "mill"); wait = 4.0
		22: shot("10-mill-card")
		23:
			main.ui._ring_dropped("wheat"); offset.s += 20; main.push(); wait = 1.0
		24: shot("11-mill-working")
		25:
			main.ui.close(); main.ui.open("more"); wait = 1.0
		26: shot("12-market")
		27:
			for good in game.state.stock:
				if game.state.stock[good] > 0: game.sell(good, game.state.stock[good])
			main.ui.close(); main.push(); wait = 0.5
		28: shot("13-level-up")
		29: return true
	step += 1
	return false
