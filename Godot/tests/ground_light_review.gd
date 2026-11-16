extends SceneTree
# Saves the built farm at four hours on a fixed sunny day, for art review of the
# ground light (squint and grayscale sheets are made outside Godot).
# xvfb-run godot --path Godot --rendering-driver opengl3 -s res://tests/ground_light_review.gd -- <dir> [--reduce-motion]
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

func _process(delta: float) -> bool:
	wait -= delta
	if wait > 0: return false
	match step:
		0:
			# Pin the game clock inside a sunny weather window so every run and
			# every hour compares under the same sky.
			var game: WorldGame = main.game
			var length := maxf(1.0, WorldCatalogue.duration(WorldCatalogue.WEATHER_SECONDS))
			var window := floori(Time.get_unix_time_from_system() / length)
			while WorldCatalogue.weather_in(window) != "sunny": window += 1
			var start := window * length + 5.0 - Time.get_unix_time_from_system()
			game.clock = func(): return Time.get_unix_time_from_system() + start
			main.push(); wait = 4.0
		1: main.ui.dismiss_title(); wait = 1.0
		2:
			var game: WorldGame = main.game
			main.host.grant("review", 400, [])
			for kind in ["windmill", "barn", "pond", "nook", "treehouse", "grill", "doghouse", "bench", "flowers"]: game.build(kind)
			main.push(); wait = 2.0
		3: set_hour(); wait = 1.0
		4:
			root.get_viewport().get_texture().get_image().save_png("%s/hour-%04.1f.png" % [OS.get_cmdline_user_args()[0], HOURS[shot]])
			shot += 1
			if shot >= HOURS.size(): return true
			set_hour(); wait = 1.0
			return false
	step += 1
	return false
