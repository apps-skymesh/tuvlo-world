extends SceneTree
# Hammers the interface the way an impatient finger would, then checks that
# nothing is left stuck: scales back at rest, the wallet showing the real
# total, panels closed, flying sprites capped and Reduce Motion honoured.
# godot --headless --path Godot -s res://tests/feel_spam_tests.gd
const F = preload("res://scripts/ui/feel.gd")
var main
var shaken: Button
var bar: WorldUI.FillBar
var boat: HomesteadBarge
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
			# A tap on a timer about to finish waits for it; one further off opens the card.
			var garden: Dictionary = main.game.state.first_of("garden")
			var st: WorldState = main.game.state
			var now: float = main.game.now()
			st.fields[0] = {"planted": true, "watered": now - 100.0, "grow": 100.3}
			st.fields[1] = {"planted": true, "watered": now, "grow": 100.0}
			check(is_equal_approx(snappedf(ui._ready_in(garden, "", now), 0.01), 0.3), "the garden reports when its wheat is ready")
			ui.place_tapped(garden.id)
			check(ui.mode == "" and ui.buffered.has(garden.id), "an early tap is buffered, not a menu")
			ui.buffered.clear()
			st.fields[0] = {"planted": true, "watered": now, "grow": 100.0}
			ui.place_tapped(garden.id)
			check(ui.mode == "place", "a tap well before ready opens the card")
			ui.close()
			main.game.refresh()
			# A tap outside an open box closes it; a tap inside doesn't.
			var tap := func(at: Vector2):
				for pressed in [true, false]:
					var e := InputEventMouseButton.new()
					e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at
					ui._input(e)
			ui.open("settings")
			var panel: Control = ui.sheet_root.get_meta("panel", ui.sheet_root)
			# Headless windows are tiny, so aim just past the box and the HUD.
			var corner := panel.get_global_rect().end + Vector2(300, 300)
			tap.call(panel.get_global_rect().get_center())
			check(ui.mode == "settings", "a tap inside the box keeps it open")
			tap.call(corner)
			check(ui.mode == "" and ui.sheet_root == null, "a tap outside the box closes it")
			ui.open("build")
			tap.call(corner)
			check(ui.mode == "build", "the Build tray stays open for map taps")
			# The tray opens on what can be built now; finished places go last.
			var order: Array = ui._build_entries(main.host.progress()).map(func(e): return e.blocker)
			var first_owned := order.find("owned")
			check(order[0] == "" and (first_owned < 0 or order.slice(first_owned).all(func(b): return b == "owned")), "Build tray leads with what's buildable and ends with what's built (%s)" % [order])
			ui.close()
			# Totals changing faster than the count can finish; the game's next refresh
			# must still land the wallet on the real balance.
			ui._count_to(10); ui._count_to(25); ui._count_to(7); ui._count_to(60)
			for i in 30: ui.fly(ui.icons["coin"], Vector2(400, 300), ui.coin_pill, 6)
			# A refused action shakes its button; spamming it still settles at home.
			shaken = Button.new()
			ui.root.add_child(shaken)
			shaken.position = Vector2(100, 100)
			for i in 12: ui.shake(shaken)
			check(ui.fly_layer.get_child_count() <= F.FLY_MAX_ON_SCREEN, "flying sprites stay capped")
			# Rewards scale with the gain; a level-up holds the frame only briefly.
			check(WorldUI.reward_tier(1) == 0 and WorldUI.reward_tier(F.REWARD_GOOD) == 1 and WorldUI.reward_tier(F.REWARD_BIG) == 2, "reward feedback tiers follow the gain")
			for i in 5: ui._level_impact()
			# Pass 14: a sky change spammed mid-morph, a hold bar sprung over
			# and over, and a barge loaded crate after crate.
			for sky in ["rain", "breeze", "warm", "sunny", "rain"]: ui._morph_sky(sky)
			bar = WorldUI.FillBar.new()
			ui.root.add_child(bar)
			bar.share = 0.75
			for i in 6: bar.grow_from(0.1 * i, F.BAR_FILL_TIME)
			boat = HomesteadBarge.new()
			root.add_child(boat)
			boat.set_docked(true, false)
			for i in 7: boat.set_cargo(i / 6.0)
			check(boat.dip_speed < 0.0, "loading the barge kicks the hull down")
			phase = 2
		3:
			check(ui.coin_pill.scale.is_equal_approx(Vector2.ONE), "wallet coin back at rest after spam")
			check(Engine.time_scale == 1.0, "a level-up hit-stop always releases")
			check(ui.level_badge.scale.is_equal_approx(Vector2.ONE), "the level badge settles after its punch")
			check(ui.root.get_children().filter(func(c): return c.has_meta("panel")).is_empty(), "closed boxes finish fading and are freed")
			check(ui.market_button.scale.is_equal_approx(Vector2.ONE), "dock button back at rest after spam")
			check(shaken.position.is_equal_approx(Vector2(100, 100)), "a spammed shake settles where it started (at %s)" % shaken.position)
			shaken.queue_free()
			check(ui.weather_pill.scale.is_equal_approx(Vector2.ONE) and ui.weather_pill_label.text == "Rain", "a spammed sky change settles on the last spell")
			check(is_equal_approx(bar.share, 0.75), "a re-sprung hold bar lands on its share (%.3f)" % bar.share)
			bar.queue_free()
			check(absf(boat.dip) < 0.03, "the loaded barge settles back to its waterline (%.3f)" % boat.dip)
			boat.queue_free()
			check(ui.coins_label.text == str(main.host.wallet()), "wallet settles on the real total (shows %s)" % ui.coins_label.text)
			var pitch := 0.0
			for i in 20: pitch = ui._combo_pitch()
			check(is_equal_approx(pitch, 1.0 + F.COMBO_MAX_STEPS * F.COMBO_STEP), "combo pitch stops at its ceiling")
			# The valley wakes in tiers as the level rises, and stays awake.
			check(HomesteadAwakening.woken(0, 1).map(func(t): return t.key) == ["flowers"], "level 1 wakes the wildflowers")
			check(HomesteadAwakening.woken(3, 3).is_empty(), "no tier between its gates")
			var awake: HomesteadAwakening = main.world.presentation.awakening
			var level: int = main.host.progress()
			check(awake.parts.keys() == HomesteadAwakening.awake_keys(level), "renderer shows exactly the tiers for level %d" % level)
			main.host.grant("feel-wake", 60, []); main.push()
			check(awake.parts.size() == HomesteadAwakening.TIERS.size(), "a big level jump wakes every tier")
			ui.set_reduce_motion(true)
			check(main.host.player().reduced_motion, "renderer is told about Reduce Motion")
			# Day cycle: morning keeps the original light, evening lights the windows,
			# and midnight joins up with no jump.
			var morning := HomesteadDayCycle.at(8.5)
			check(is_equal_approx(morning.sun_energy, 0.92) and morning.glow == 0.0, "morning gold is the original light")
			check(HomesteadDayCycle.at(21.0).glow > 0.9 and HomesteadDayCycle.at(13.0).sun_energy > HomesteadDayCycle.at(19.0).sun_energy, "afternoon is brightest, evening glows")
			check(HomesteadDayCycle.at(23.999).sun_color.is_equal_approx(HomesteadDayCycle.at(0.0).sun_color), "the cycle joins at midnight")
			check(HomesteadDayCycle.phase(6.0) == "dawn" and HomesteadDayCycle.phase(18.0) == "dusk", "day phases are named for sound")
			# Wind: leaves sway in the shader, and Reduce Motion holds them still.
			var swaying := 0
			for mesh in main.world.presentation.find_children("*", "MeshInstance3D", true, false):
				if mesh.material_override is ShaderMaterial and mesh.material_override.shader == HomesteadWind.SHADER: swaying += 1
			check(swaying > 0, "trees and crops sway in the wind shader (%d surfaces)" % swaying)
			var still := true
			for twin in HomesteadWind.twins.values():
				if is_instance_valid(twin) and float(twin.get_shader_parameter("strength")) != 0.0: still = false
			check(HomesteadWind.still and still, "Reduce Motion holds the wind still")
			check(ui.ambience != null and ui.ambience.mill != null and ui.ambience.birds != null, "ambient mill and birds are loaded")
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
