extends SceneTree
# Prints draw calls, primitives, objects, materials and memory for the starting
# farm and a built-up one, so a visual change can be compared before/after.
# xvfb-run godot --path Godot --rendering-driver opengl3 -s res://tests/perf_probe.gd
var main
var step := 0
var wait := 0.0
var shot := 0
const HOURS := [8.5, 13.0, 18.0, 21.0]

func set_hour() -> void:
	HomesteadDayCycle.hour_override = HOURS[shot]
	main.world.apply_day_cycle()

func _initialize() -> void:
	var save := "user://tuvlo-world-save.json"
	if FileAccess.file_exists(save): DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	main = load("res://scenes/game.tscn").instantiate()
	root.add_child(main)

func report(label: String) -> void:
	var rs := RenderingServer
	print("%s: draw calls %d, primitives %d, objects %d, video MB %.1f, static MB %.1f" % [label,
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		OS.get_static_memory_usage() / 1048576.0])

func _process(delta: float) -> bool:
	wait -= delta
	if wait > 0: return false
	match step:
		0: wait = 4.0
		1: main.ui.dismiss_title(); wait = 2.0
		2: report("start")
		3:
			var game: WorldGame = main.game
			main.host.grant("probe", 400, [])
			for kind in ["windmill", "barn", "pond", "nook", "treehouse", "grill", "doghouse", "bench", "flowers"]: game.build(kind)
			main.push(); wait = 3.0
		4: report("built")
		5:
			# With an output folder, also save the built farm at four hours of the day.
			if OS.get_cmdline_user_args().is_empty(): return true
			shot = 0
			set_hour(); wait = 0.5
		6:
			root.get_viewport().get_texture().get_image().save_png("%s/day-%d.png" % [OS.get_cmdline_user_args()[0], int(HOURS[shot] * 10)])
			shot += 1
			if shot >= HOURS.size(): return true
			set_hour(); wait = 0.5
			return false
	step += 1
	return false
