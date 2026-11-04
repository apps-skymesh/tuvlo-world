extends SceneTree
# Plays to the next day and captures the daily gift card and its collection.
# xvfb-run godot --path Godot -s res://tests/gift_capture.gd -- <output-dir>
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
	match step:
		0:
			game.clock = func(): return Time.get_unix_time_from_system() + offset.s
			wait = 4.0
		1:
			main.ui.dismiss_title()
			game.tend(0); game.tend(0); offset.s += 30; game.tend(0); main.push()
			print("gift ready on day one: ", game.gift_ready())
			wait = 1.5
		2: offset.s += 86400; main.push(); wait = 1.2
		3: shot("gift-card"); print("mode: ", main.ui.mode)
		4:
			for child in main.ui.sheet_root.find_children("*", "Button", true, false):
				if child.text == "Collect": child.pressed.emit()
			wait = 0.35
		5: shot("gift-collect"); wait = 1.5
		6: shot("gift-after"); print("gift ready after: ", game.gift_ready(), " streak ", game.state.gift_streak)
		7: return true
	step += 1
	return false
