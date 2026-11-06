extends SceneTree
# Saves the valley's voice at its peaks: the title hook, the arrival line, the
# first harvest, a level-up that wakes the lanterns, a place's first breath,
# a return greeting and the awake valley at night.
# xvfb-run godot --path Godot --rendering-driver opengl3 -s res://tests/story_capture.gd -- <output-dir>
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
	HomesteadDayCycle.hour_override = 10.0
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
		1: shot("40-title"); main.ui.dismiss_title(); wait = 1.6
		2: shot("41-arrival")
		3: main.ui.goal_action.call(); wait = 0.6
		4: main.ui.place_tapped("base:garden"); wait = 0.6
		5: offset.s += 25; main.push(); wait = 1.0
		6: main.ui.place_tapped("base:garden"); wait = 1.6
		7: shot("42-first-harvest"); wait = 3.5
		8: main.host.grant("story-level", 15, []); main.push(); wait = 1.2
		9: shot("43-level-lanterns"); wait = 4.0
		10: main.host.grant("story-build", 20, []); main.push(); game.build("windmill"); main.push(); wait = 4.0
		11: offset.s += 200; main.push(); wait = 1.4
		12: shot("44-windmill-breath"); wait = 4.0
		13: main.ui._greet(); wait = 1.2
		14: shot("45-return-greeting"); wait = 4.0
		15:
			main.host.grant("story-awake", 40, []); main.push()
			HomesteadDayCycle.hour_override = 21.0
			main.world.apply_day_cycle(); wait = 4.5
		16: shot("46-awake-valley-night"); return true
	step += 1
	return false
