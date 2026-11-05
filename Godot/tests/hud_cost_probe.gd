extends SceneTree
# Times the HUD's per-frame upkeep (barge ticket, sky pill, season clock) on
# a built-up farm, so a change to it can be compared before/after.
# godot --headless --path Godot -s res://tests/hud_cost_probe.gd
var main
var frame := 0

func _initialize() -> void:
	var save := "user://tuvlo-world-save.json"
	if FileAccess.file_exists(save): DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	main = load("res://scenes/game.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.ui.dismiss_title()
		main.host.grant("probe", 60, [])
		for kind in ["windmill", "barn", "orchard"]:
			main.game.build(kind)
		main.push()
	if frame == 30:
		var ui: WorldUI = main.ui
		var n := 2000
		var t0 := Time.get_ticks_usec()
		for i in n: ui._process(1.0 / 60.0)  # mostly between HUD ticks, as in play
		var per := float(Time.get_ticks_usec() - t0) / n
		var t1 := Time.get_ticks_usec()
		for i in n: main.game.barge()
		var barge := float(Time.get_ticks_usec() - t1) / n
		print("HUD_COST ui._process %.1f us/frame, game.barge() %.1f us" % [per, barge])
		quit()
	return false
