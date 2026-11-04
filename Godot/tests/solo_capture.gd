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
		2:
			for i in 2: game.tend(i); game.tend(i)
			offset.s += 31; main.push(); wait = 2.0
		3: shot("02-wheat-ready")
		4: main.ui.open("place", "base:garden"); wait = 1.0
		5: shot("03-farm-panel")
		6:
			main.ui.close(); game.tend(0); game.tend(1); main.ui.open("market"); wait = 1.0
		7: shot("04-market")
		8:
			main.ui.close(); main.ui.open("build"); wait = 1.0
		9: shot("05-build")
		10: return true
	step += 1
	return false
