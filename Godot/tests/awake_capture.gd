extends SceneTree
# Captures the valley at its fully awake level, near and far.
# xvfb-run godot --path Godot -s res://tests/awake_capture.gd -- <output-dir>
var main
var out := "user://captures"
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
	match step:
		0: wait = 4.0
		1: main.ui.dismiss_title(); main.host.grant("awake", 60, []); main.push(); wait = 0.5
		2: shot("awake-banner"); wait = 3.5
		3: shot("awake-near")
		4: main.world.zoom_camera(2.2); wait = 1.5
		5: shot("awake-far")
		6: return true
	step += 1
	return false
