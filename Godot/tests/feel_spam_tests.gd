extends SceneTree
# Hammers the interface the way an impatient finger would, then checks that
# nothing is left stuck: scales back at rest, the wallet showing the real
# total, panels closed, flying sprites capped and Reduce Motion honoured.
# godot --headless --path Godot -s res://tests/feel_spam_tests.gd
const F = preload("res://scripts/ui/feel.gd")
var main
var frame := 0
var elapsed := 0.0
var phase := 0
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	for path in ["user://tuvlo-world-save.json", "user://settings.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main = load("res://scenes/game.tscn").instantiate()
	root.add_child(main)

func _process(delta: float) -> bool:
	frame += 1
	elapsed += delta
	var ui: WorldUI = main.ui
	# Steps wait on real time, so the tweens get to finish however fast frames run.
	if frame == 3: phase = 1
	elif phase == 2 and elapsed > 2.5: phase = 3
	elif phase == 4 and elapsed > 3.0: phase = 5
	else: return false
	match phase:
		1:
			elapsed = 0.0
			ui.dismiss_title()
			# Rapid taps on every kind of panel and target.
			for i in 40:
				ui.bump(ui.coin_pill)
				ui.bump(ui.market_button)
				ui.open("settings"); ui.close()
				ui.open("build"); ui.close()
				ui.open("more"); ui.close()
			check(ui.mode == "" and ui.sheet_root == null, "spammed panels end closed")
			# Totals changing faster than the count can finish; the game's next refresh
			# must still land the wallet on the real balance.
			ui._count_to(10); ui._count_to(25); ui._count_to(7); ui._count_to(60)
			for i in 30: ui.fly(ui.icons["coin"], Vector2(400, 300), ui.coin_pill, 6)
			check(ui.fly_layer.get_child_count() <= F.FLY_MAX_ON_SCREEN, "flying sprites stay capped")
			phase = 2
		3:
			check(ui.coin_pill.scale.is_equal_approx(Vector2.ONE), "wallet coin back at rest after spam")
			check(ui.market_button.scale.is_equal_approx(Vector2.ONE), "dock button back at rest after spam")
			check(ui.coins_label.text == str(main.host.wallet()), "wallet settles on the real total (shows %s)" % ui.coins_label.text)
			var pitch := 0.0
			for i in 20: pitch = ui._combo_pitch()
			check(is_equal_approx(pitch, 1.0 + F.COMBO_MAX_STEPS * F.COMBO_STEP), "combo pitch stops at its ceiling")
			ui.set_reduce_motion(true)
			check(main.host.player().reduced_motion, "renderer is told about Reduce Motion")
			ui.bump(ui.coin_pill)
			ui.fly(ui.icons["coin"], Vector2(400, 300), ui.coin_pill, 6)
			ui._count_to(99)
			check(ui.coins_label.text == "99", "Reduce Motion shows totals at once")
			phase = 4
		5:
			check(ui.coin_pill.scale.is_equal_approx(Vector2.ONE), "Reduce Motion: no bump")
			ui.set_reduce_motion(false)
			print("feel spam: %d checks, %d failed" % [checks, failures])
			quit(1 if failures > 0 else 0)
	return false
