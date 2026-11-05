class_name WorldUI
extends CanvasLayer

## Step-2 game UI, after Tuvlo's World design (owner decisions 2026-11-02/03):
## - the map keeps only places, ready goods, Build (hammer) and More;
## - one wallet at the top;
## - a place opens a production window over the still map (2026-11-05): its
##   products along the top with time and star price, what the chosen product
##   needs on the left, and the animated inside of the place as the drop target;
## - the Build tray is a single row of places and land.
## Words appear only where a picture can't carry the meaning.

const C = preload("res://scripts/game/catalogue.gd")
const F = preload("res://scripts/ui/feel.gd")
## Design tokens: deep forest glass over the bright world, ivory type, gold
## for money and progress, mint for growth.
const GLASS := Color(0.075, 0.15, 0.14, 0.86)
const GLASS_DEEP := Color(0.04, 0.09, 0.085, 0.92)
const EDGE := Color(1, 1, 1, 0.16)
const TILE := Color(1, 1, 1, 0.075)
const RECESS := Color(0, 0, 0, 0.26)  # a recessed plate inside a card
const RECESS_LIP := 0.1               # its lit bottom edge
const TAB_FILL := Color(1, 1, 1, 0.11)  # an unselected product tab: readable, not muddy
const TAB_EDGE := Color(1, 1, 1, 0.16)
const TAB_BUSY_ALPHA := 0.62            # a tab locked while another job runs
const TAB_BREATH := 2.4                 # s, the selected tab's gold edge breathing in and out
const DISABLED_FILL := Color(1, 1, 1, 0.14)
const DISABLED_INK := Color(1, 0.97, 0.9, 0.8)
const IVORY := Color("FFF8EA")
const MUTED := Color(1, 0.97, 0.9, 0.62)
const GOLD := Color("F7C04A")
const GOLD_DEEP := Color("C98A1C")
const GOLD_INK := Color("3D2805")
const MINT := Color("7EDB9C")
const SHORT := Color("FF8E72")
# Stall and paper, for the Market (the valley's own materials, not glass).
const AWNING_RED := Color("C8553D")
const PAPER := Color("F4E8CF")
const PAPER_EDGE := Color("D9C39A")
const PAPER_INK := Color("5B4636")
const PAPER_READY := Color("3F8F5A")
const PAPER_SHORT := Color("C2502F")
# Older names, kept so the art helpers below read the same.
const CREAM := IVORY
const INK := IVORY
const WALNUT := GOLD_INK
const RIM := EDGE
const LEAF := MINT
const WELL := TILE
const PARCHMENT := GLASS
const DISPLAY := preload("res://assets/fonts/Fredoka-700.ttf")
const DISPLAY_SEMI := preload("res://assets/fonts/Fredoka-600.ttf")
const BODY := preload("res://assets/fonts/Nunito-800.ttf")
const RING_DIAMETER := 212.0

signal panel_changed(open: bool)

var main  # game_main.gd
var s := 1.0
var root: Control
var coins_label: Label
var level_label: Label
var toast: Label
var toast_box: PanelContainer
var toast_left := 0.0
var hud: Array[Control] = []
var sheet_root: Control  # the open card or tray
var mode := ""      # "", "place", "build", "more", "land"
var place_id := ""
var station := ""
var recipe := ""
var filled := {}
var build_pick := ""
var ring: ProductionScene
var signature := ""
var icons := {}
var goal_box: PanelContainer
var goal_icon: TextureRect
var goal_label: Label
var goal_action := Callable()
var level_badge: LevelBadge
var pointer: Pointer
var pointer_id := ""
var coin_pill: Control
var market_button: Button
var dock_node: Control
var wallet_node: Control
var fly_layer: Control
var last_level := -1
var last_coins := -1
var audio: Dictionary = {}
var music: AudioStreamPlayer
var ambience: WorldAmbience
var sound_on := true
var music_on := true
var haptics_on := true
var reduce_motion := false
var atmosphere: Control
const SETTINGS_PATH := "user://settings.cfg"
var fly_from := Vector2(-1, -1)
var last_stock := {}
var gift_offered_day := -1

# --- small drawing helpers -------------------------------------------------

## A card or sheet title: display type on a glass chip with gold diamonds.
## A market stall's striped canvas valance with a scalloped hem: the Market
## sheet reads as a stall in the valley, not a settings box.
class Awning extends Control:
	var ui
	func _draw() -> void:
		var k: float = ui.s
		var stripe := 34.0 * k
		var band := size.y - 12 * k
		var count := ceili(size.x / stripe)
		var width := size.x / count
		for i in count:
			var x := i * width
			var color := WorldUI.AWNING_RED if i % 2 == 0 else WorldUI.PAPER
			draw_rect(Rect2(x, 0, width, band), color)
			# Each stripe ends in a scallop.
			var points := PackedVector2Array()
			for j in 9: points.append(Vector2(x + width * j / 8.0, band + sin(PI * j / 8.0) * 12 * k))
			points.append(Vector2(x + width, band))
			draw_colored_polygon(points, color)
		draw_rect(Rect2(0, 0, size.x, 4 * k), Color(0, 0, 0, 0.18))

## The tack holding a neighbour's note to the stall.
class Pin extends Control:
	func _draw() -> void:
		var r := size.x / 2
		draw_circle(Vector2(r, r + 1.5), r, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(r, r), r, WorldUI.AWNING_RED)
		draw_circle(Vector2(r * 0.7, r * 0.7), r * 0.32, Color(1, 1, 1, 0.55))

class Ribbon extends Control:
	var text := ""
	var ui
	func _draw() -> void:
		var k: float = ui.s
		var h := size.y
		draw_style_box(ui.glass(int(h / 2 / k), WorldUI.GLASS_DEEP), Rect2(Vector2.ZERO, size))
		var font: Font = WorldUI.DISPLAY
		var fs := int(h * 0.5)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - tw) / 2, h * 0.5 + fs * 0.36)
		draw_string(font, at + Vector2(0, 2 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.IVORY)
		for side in [-1, 1]:
			var x: float = size.x / 2 + side * (tw / 2 + 16 * k)
			var d := 4.5 * k
			draw_colored_polygon(PackedVector2Array([Vector2(x, h / 2 - d), Vector2(x + d, h / 2), Vector2(x, h / 2 + d), Vector2(x - d, h / 2)]), WorldUI.GOLD)

## A small on/off switch in the iOS manner.
class Switch extends Control:
	signal toggled(on: bool)
	var on := true
	var knob := 1.0
	var ui
	func _draw() -> void:
		var k: float = ui.s
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.16).lerp(WorldUI.MINT, knob)
		track.set_corner_radius_all(int(size.y / 2))
		track.anti_aliasing_size = 0.8
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var r := size.y / 2 - 3 * k
		var x := lerpf(size.y / 2, size.x - size.y / 2, knob)
		draw_circle(Vector2(x, size.y / 2 + 1.5 * k), r, Color(0, 0, 0, 0.2))
		draw_circle(Vector2(x, size.y / 2), r, WorldUI.IVORY)
	func _gui_input(event: InputEvent) -> void:
		var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
		if not press: return
		on = not on
		create_tween().tween_property(self, "knob", 1.0 if on else 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var redraw := create_tween()
		redraw.tween_method(func(_v): queue_redraw(), 0.0, 1.0, 0.2)
		toggled.emit(on)

## The level as a dark medal with a gold progress ring.
class LevelBadge extends Control:
	var ui
	var level := 0
	var progress := 0.0
	func _draw() -> void:
		var k: float = ui.s
		var c := size / 2
		var r: float = minf(size.x, size.y) / 2 - 1 * k
		draw_circle(c, r, Color(0, 0, 0, 0.25))
		draw_arc(c, r - 3 * k, 0, TAU, 64, Color(1, 1, 1, 0.14), 5 * k, true)
		if progress > 0: draw_arc(c, r - 3 * k, -PI / 2, -PI / 2 + TAU * progress, 64, WorldUI.GOLD, 5 * k, true)
		var font: Font = WorldUI.DISPLAY
		var fs: int = int(r * 0.95)
		var text := str(level)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w / 2, c.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.IVORY)

## A bouncing gold marker that points at the goal's place on the map.
class Pointer extends Control:
	var ui
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var k: float = ui.s
		var t := Time.get_ticks_msec() / 1000.0
		var bob: float = 0.0 if ui.reduce_motion else sin(t * 5.5) * 7 * k
		var c := Vector2(size.x / 2, size.y / 2 + bob)
		# A soft ground halo that breathes under the marker.
		var halo := 0.5 + 0.5 * sin(t * 5.5)
		draw_set_transform(Vector2(size.x / 2, size.y + 26 * k), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, (18 + 6 * halo) * k, Color(WorldUI.GOLD, 0.35 - 0.15 * halo))
		draw_set_transform(Vector2.ZERO)
		var r := 19 * k
		var tip := c + Vector2(0, r * 1.9)
		var body := PackedVector2Array()
		for i in 25: body.append(c + Vector2.from_angle(PI * 0.75 + i * PI * 1.5 / 24) * r)
		body.append(tip)
		var shadow := Transform2D(0, Vector2(0, 4 * k)) * body
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
		draw_colored_polygon(body, WorldUI.GOLD)
		var outline := body.duplicate(); outline.append(body[0])
		draw_polyline(outline, WorldUI.GOLD_DEEP, 2.5 * k, true)
		draw_circle(c, r * 0.42, WorldUI.IVORY)
		draw_circle(c + Vector2(-r * 0.35, -r * 0.45), r * 0.22, Color(1, 1, 1, 0.4))

## The glass dock behind the Build shelf.
class Shelf extends Control:
	var ui
	func _draw() -> void:
		draw_style_box(ui.glass(30), Rect2(Vector2.ZERO, size))

## A small padlock for places that need a higher level.
class Padlock extends Control:
	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		draw_circle(c, r, Color(0.04, 0.09, 0.085, 0.9))
		draw_arc(c + Vector2(0, -r * 0.12), r * 0.3, PI, TAU, 24, WorldUI.IVORY, r * 0.13, true)
		var body := StyleBoxFlat.new()
		body.bg_color = WorldUI.GOLD
		body.set_corner_radius_all(int(r * 0.16))
		draw_style_box(body, Rect2(c + Vector2(-r * 0.42, -r * 0.1), Vector2(r * 0.84, r * 0.62)))
		draw_circle(c + Vector2(0, r * 0.2), r * 0.09, WorldUI.GOLD_INK)

## A soft chevron between goods, the place and products.
class Arrow extends Control:
	var ui
	func _draw() -> void:
		var c := size / 2
		var d := minf(size.x, size.y) * 0.22
		for i in 3:
			var x := c.x + (i - 1) * d * 0.8
			draw_polyline(PackedVector2Array([Vector2(x - d * 0.35, c.y - d * 0.7), Vector2(x + d * 0.35, c.y), Vector2(x - d * 0.35, c.y + d * 0.7)]), Color(1, 1, 1, 0.18 + 0.28 * i), 4 * ui.s, true)

## Drifting motes of light for the title screen.
class Motes extends Control:
	var seeds: Array = []
	func _ready() -> void:
		for i in 46: seeds.append(Vector4(randf(), randf(), randf_range(0.4, 1.0), randf() * TAU))
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for m: Vector4 in seeds:
			var y := fposmod(m.y - t * 0.018 * m.z, 1.0)
			var x := m.x + sin(t * 0.6 * m.z + m.w) * 0.015
			var twinkle := 0.5 + 0.5 * sin(t * 2.0 * m.z + m.w)
			var at := Vector2(x * size.x, y * size.y)
			var r := (1.5 + 2.5 * m.z) * size.y / 720.0
			draw_circle(at, r * 3.0, Color(1, 0.85, 0.5, 0.06 * twinkle))
			draw_circle(at, r, Color(1, 0.93, 0.72, 0.25 + 0.55 * twinkle))

## Living air over the map: a few drifting pollen motes by day and amber,
## blinking fireflies as the hearth-glow comes up. One Control, one _draw,
## redrawn at a capped rate with no nodes, materials or extra passes, so it
## costs a handful of 2D circles. It sits under the HUD and ignores input.
class Atmosphere extends Control:
	const FEEL = preload("res://scripts/ui/feel.gd")
	var seeds: Array = []
	var since := 0.0
	var sampled := -1.0
	var night := 0.0
	var sky := "sunny"
	var rain := 0.0  # eases in and out so a shower never pops
	var drops: Array = []
	func _ready() -> void:
		for i in FEEL.ATMOSPHERE_MOTES: seeds.append(Vector4(randf(), randf(), randf_range(0.4, 1.0), randf() * TAU))
		for i in FEEL.RAIN_DROPS: drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.0)))
	func _process(delta: float) -> void:
		since += delta
		if since < 1.0 / FEEL.ATMOSPHERE_FPS: return
		rain = move_toward(rain, 1.0 if sky == "rain" else 0.0, since / FEEL.RAIN_FADE)
		since = 0.0
		var t := Time.get_ticks_msec() / 1000.0
		if sampled < 0.0 or t - sampled > HomesteadDayCycle.SAMPLE_SECONDS:
			sampled = t
			night = clampf(float(HomesteadDayCycle.at(HomesteadDayCycle.local_hour()).glow), 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var k := size.y / 720.0
		var day := 1.0 - night
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		# Rain: fine slanted streaks, light enough to read the map through.
		if rain > 0.01:
			var fall := Vector2(-0.22, 1.0).normalized()
			for drop in drops:
				var d: Vector3 = drop
				var length := (16.0 + 18.0 * d.z) * k
				var at := Vector2(fposmod(d.x + t * 0.05 * d.z, 1.0) * size.x, fposmod(d.y + t * 1.1 * d.z, 1.0) * size.y)
				var side := Vector2(fall.y, -fall.x) * 0.7 * k
				var base := points.size()
				var c := Color(0.86, 0.92, 1.0, rain * (0.22 + 0.18 * d.z))
				points.append_array([at - side, at + side, at + fall * length + side, at + fall * length - side])
				colors.append_array([Color(c, 0.0), Color(c, 0.0), c, c])
				indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		var drift := 3.0 if sky == "breeze" else 1.0
		for i in seeds.size():
			var m: Vector4 = seeds[i]
			if i < FEEL.ATMOSPHERE_POLLEN and day > 0.05 and rain < 0.6:
				# Pollen: slow sideways drift on the wind with a gentle rise;
				# a breeze carries it faster, rain grounds it.
				var y := fposmod(m.y - t * 0.006 * m.z, 1.0)
				var x := fposmod(m.x + t * 0.012 * m.z * drift + sin(t * 0.4 * m.z + m.w) * 0.02, 1.0)
				var r := (1.2 + 1.6 * m.z) * k
				_glow(points, colors, indices, Vector2(x * size.x, y * size.y), r, r * 2.6, Color(1, 0.98, 0.88, day * (0.2 + 0.25 * m.z)))
			elif i >= FEEL.ATMOSPHERE_POLLEN and night > 0.05:
				# Fireflies keep to the lower, nearer half and wander in loops.
				var x := m.x + sin(t * 0.33 * m.z + m.w) * 0.05
				var y := 0.42 + m.y * 0.5 + sin(t * 0.5 * m.z + m.w * 2.0) * 0.04
				var blink := pow(maxf(0.0, sin(t * (0.9 + m.z) + m.w * 3.0)), 2.0)
				var r := (2.0 + 1.6 * m.z) * k
				if blink > 0.02: _glow(points, colors, indices, Vector2(x * size.x, y * size.y), r, r * 6.0, Color(1, 0.86, 0.45, night * blink))
		# Every mote goes out in one triangle list: a single canvas draw call.
		if not indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)
	## A soft dot: a bright core fading to nothing at the halo edge, done with
	## vertex colours instead of stacked circles or a texture.
	static func _glow(points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, at: Vector2, core: float, halo: float, color: Color) -> void:
		var steps := 10
		var base := points.size()
		points.append(at); colors.append(color)
		var edge := Color(color, color.a * 0.75)
		var clear := Color(color, 0.0)
		for j in steps:
			var dir := Vector2.from_angle(TAU * j / steps)
			points.append(at + dir * core); colors.append(edge)
			points.append(at + dir * halo); colors.append(clear)
		for j in steps:
			var c0 := base + 1 + j * 2
			var c1 := base + 1 + ((j + 1) % steps) * 2
			indices.append_array([base, c0, c1, c0, c0 + 1, c1 + 1, c0, c1 + 1, c1])

## The sky as a small emblem: sun, rain cloud, breeze or warm sun. Drawn in
## code so it stays crisp at every size; `muted` dims a later spell.
class WeatherIcon extends Control:
	var sky := "sunny"
	var muted := false
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var k := minf(w, h) / 48.0
		var a := 0.6 if muted else 1.0
		var sun := Color(1.0, 0.8, 0.3, a)
		match sky:
			"rain":
				var cloud := Color(0.86, 0.9, 0.95, a)
				for drop in 3:
					var x := w * (0.32 + drop * 0.18)
					draw_line(Vector2(x, h * 0.66), Vector2(x - 4 * k, h * 0.86), Color(0.5, 0.75, 0.95, a), 2.6 * k, true)
				draw_circle(Vector2(w * 0.36, h * 0.46), 9 * k, cloud)
				draw_circle(Vector2(w * 0.56, h * 0.38), 12 * k, cloud)
				draw_circle(Vector2(w * 0.72, h * 0.5), 8 * k, cloud)
				draw_rect(Rect2(w * 0.36, h * 0.46, w * 0.36, 8 * k), cloud)
			"breeze":
				var air := Color(0.85, 0.94, 0.92, a)
				for row in 3:
					var y := h * (0.3 + row * 0.2)
					var reach := w * (0.78 - row * 0.12)
					draw_line(Vector2(w * 0.14, y), Vector2(reach, y), air, 3 * k, true)
					draw_arc(Vector2(reach, y - 5 * k), 5 * k, PI * 0.5, PI * 2.1, 12, air, 3 * k, true)
			_:
				var c := Vector2(w / 2, h / 2)
				var warm := sky == "warm"
				if warm: draw_circle(c, 20 * k, Color(1.0, 0.55, 0.25, 0.22 * a))
				for ray in 8:
					var dir := Vector2.from_angle(TAU * ray / 8.0)
					draw_line(c + dir * 13 * k, c + dir * 19 * k, Color(1.0, 0.62, 0.3, a) if warm else sun, 2.6 * k, true)
				draw_circle(c, 10 * k, Color(1.0, 0.68, 0.32, a) if warm else sun)

## Rowan's barge as a small emblem: hull, cabin, mast and striped sail over
## two strokes of water. Drawn in code so it stays crisp at every size.
class BoatIcon extends Control:
	var muted := false
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var k := minf(w, h) / 48.0
		var a := 0.55 if muted else 1.0
		var hull := PackedVector2Array([Vector2(w * 0.08, h * 0.62), Vector2(w * 0.92, h * 0.62), Vector2(w * 0.8, h * 0.8), Vector2(w * 0.2, h * 0.8)])
		draw_colored_polygon(hull, Color(0.48, 0.29, 0.17, a))
		draw_line(Vector2(w * 0.08, h * 0.62), Vector2(w * 0.92, h * 0.62), Color(0.33, 0.19, 0.1, a), 2.2 * k, true)
		draw_rect(Rect2(w * 0.16, h * 0.45, w * 0.22, h * 0.17), Color(0.94, 0.89, 0.78, a))
		draw_rect(Rect2(w * 0.13, h * 0.41, w * 0.28, h * 0.06), Color(WorldUI.AWNING_RED, a))
		draw_line(Vector2(w * 0.58, h * 0.62), Vector2(w * 0.58, h * 0.1), Color(0.42, 0.27, 0.15, a), 2.0 * k, true)
		var sail := PackedVector2Array([Vector2(w * 0.61, h * 0.14), Vector2(w * 0.61, h * 0.56), Vector2(w * 0.88, h * 0.56)])
		draw_colored_polygon(sail, Color(0.96, 0.93, 0.85, a))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.61, h * 0.4), Vector2(w * 0.61, h * 0.47), Vector2(w * 0.8, h * 0.47), Vector2(w * 0.74, h * 0.4)]), Color(WorldUI.AWNING_RED, a))
		var water := Color(0.45, 0.78, 0.8, 0.9 * a)
		for row in 2:
			var y := h * (0.87 + row * 0.08)
			var points := PackedVector2Array()
			for i in 13:
				var x := w * (0.1 + row * 0.08 + i * 0.065)
				points.append(Vector2(x, y + sin(i * 1.4) * 1.4 * k))
			draw_polyline(points, water, 1.8 * k, true)

## A slim rounded progress bar on paper or glass.
class FillBar extends Control:
	var share := 0.0
	var goal := -1.0
	var motion: Tween
	## Springs from `from` to the share it was given, with a small overshoot.
	## A new spring mid-flight keeps the same goal, so it always lands there.
	func grow_from(from: float, time: float) -> void:
		var busy := motion != null and motion.is_valid()
		if not busy: goal = share
		if busy: motion.kill()
		share = from
		motion = create_tween()
		motion.tween_method(func(v: float): share = v; queue_redraw(), from, goal, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var track := Color(0, 0, 0, 0.12)
	var fill := Color("3F8F5A")
	func _draw() -> void:
		var r := size.y / 2
		var box := StyleBoxFlat.new()
		box.bg_color = track
		box.set_corner_radius_all(int(r))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		if share > 0.0:
			var inner := StyleBoxFlat.new()
			inner.bg_color = fill
			inner.set_corner_radius_all(int(r))
			draw_style_box(inner, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * clampf(share, 0, 1)), size.y)))

## Field tools drawn in code (no art yet): a seed pouch and a water drop.
class ToolIcon extends Control:
	var tool := "seed"
	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) * 0.38
		if tool == "water":
			var points := PackedVector2Array()
			for i in 33:
				var t := float(i) / 32.0 * TAU
				var y := -cos(t)
				var x := sin(t) * (1.0 - 0.55 * maxf(0, y))
				points.append(c + Vector2(x * r * 0.85, y * r * -1.15 + r * 0.25))
			draw_colored_polygon(points, Color("5BA8D8"))
			draw_polyline(points, Color("2F6F9E"), 3.0, true)
			draw_circle(c + Vector2(-r * 0.28, r * 0.1), r * 0.16, Color(1, 1, 1, 0.7))
		else:
			draw_circle(c + Vector2(0, r * 0.2), r * 0.85, Color("C08A4E"))
			draw_arc(c + Vector2(0, r * 0.2), r * 0.85, 0, TAU, 48, Color("7A5028"), 3.0, true)
			draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.85), Vector2(r * 0.9, r * 0.35)), Color("9E6B38"))
			for offset in [Vector2(-0.3, 0.2), Vector2(0.25, 0.05), Vector2(0.05, 0.5)]:
				draw_circle(c + offset * r, r * 0.13, Color("F3D98B"))

## A watch face drawn in code: gold rim, two hands, and a filled wedge for the
## share of time already gone.
static func draw_clock(canvas: CanvasItem, at: Vector2, r: float, color: Color, share := 1.0) -> void:
	canvas.draw_circle(at, r, Color(0, 0, 0, 0.35))
	if share < 1.0 and share > 0.0:
		var wedge := PackedVector2Array([at])
		for i in 25: wedge.append(at + Vector2.from_angle(-PI / 2 + TAU * share * i / 24.0) * r * 0.82)
		canvas.draw_colored_polygon(wedge, Color(color, 0.35))
	canvas.draw_arc(at, r, 0, TAU, 32, color, maxf(1.5, r * 0.22), true)
	canvas.draw_line(at, at + Vector2(0, -r * 0.62), WorldUI.IVORY, maxf(1.2, r * 0.16), true)
	canvas.draw_line(at, at + Vector2(r * 0.45, 0), WorldUI.IVORY, maxf(1.2, r * 0.16), true)
	canvas.draw_circle(at, maxf(1.2, r * 0.14), color)

class ClockIcon extends Control:
	var share := 1.0
	var color := WorldUI.GOLD
	func _draw() -> void: WorldUI.draw_clock(self, size / 2, minf(size.x, size.y) * 0.46, color, share)

## A field tool that can be dragged into the scene.
## What follows the finger while a good is dragged: the good lifted and a
## little larger, with a soft shadow below, leaning into the direction of travel
## and settling as the finger slows.
class DragGhost extends Control:
	var picture: Control
	var side := 64.0
	var last := Vector2.ZERO
	var lean := 0.0
	var lift := 0.0
	var reduce := false
	func _ready() -> void:
		picture.size = Vector2(side, side)
		picture.pivot_offset = picture.size / 2
		picture.position = -picture.size / 2 - Vector2(0, side * 0.2)
		add_child(picture)
		last = global_position
		if not reduce:
			picture.scale = Vector2.ONE * 0.8
			create_tween().tween_property(picture, "scale", Vector2.ONE * 1.18, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else: picture.scale = Vector2.ONE * 1.1
	func _process(delta: float) -> void:
		var v := (global_position - last) / maxf(delta, 0.001)
		last = global_position
		if reduce: return
		lean = lerpf(lean, clampf(v.x * 0.0009, -0.45, 0.45), 1.0 - exp(-delta * 14.0))
		lift += delta
		picture.rotation = lean + sin(lift * 5.0) * 0.03
		queue_redraw()
	func _draw() -> void:
		var r := side * (0.42 + 0.04 * sin(lift * 5.0))
		var points := PackedVector2Array()
		for i in 24: points.append(Vector2(cos(TAU * i / 24.0) * r, side * 0.42 + sin(TAU * i / 24.0) * r * 0.25))
		draw_colored_polygon(points, Color(0, 0, 0, 0.25))

static func _drag_start(source: Control, ui, picture: Control, good: String) -> Dictionary:
	var ghost := DragGhost.new()
	ghost.picture = picture
	ghost.side = source.size.x
	ghost.reduce = ui.reduce_motion
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.set_drag_preview(ghost)
	source.modulate.a = 0.3
	ui.haptic(0.3)
	ui.sfx("tap", 1.2)
	return {"good": good}

## When a drag ends without landing anywhere, the good drifts back to its socket.
static func _drag_end(source: Control, ui, texture: Texture2D, tool: String) -> void:
	source.modulate.a = 1.0
	ui.press_out(source)
	if source.get_viewport().gui_is_drag_successful(): return
	ui.fly_back(texture, tool, source.get_viewport().get_mouse_position(), source)

## A field tool that can be dragged into the scene.
class DragTool extends ToolIcon:
	var draggable := false
	var ui
	func _get_drag_data(_at: Vector2) -> Variant:
		if not draggable: return null
		var preview := ToolIcon.new()
		preview.tool = tool
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return WorldUI._drag_start(self, ui, preview, tool)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and draggable and modulate.a < 1.0: WorldUI._drag_end(self, ui, null, tool)

class GoodTile extends TextureRect:
	var good := ""
	var draggable := false
	var ui
	func _get_drag_data(_at: Vector2) -> Variant:
		if not draggable: return null
		var preview := TextureRect.new()
		preview.texture = texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return WorldUI._drag_start(self, ui, preview, good)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and draggable and modulate.a < 1.0: WorldUI._drag_end(self, ui, texture, "")

# --- setup -------------------------------------------------------------------

func setup(owner_main) -> void:
	main = owner_main
	s = clampf(main.get_viewport().get_visible_rect().size.y / 720.0, 1.0, 3.0)
	_read_safe_area()
	for good in C.GOODS: icons[good] = load("res://assets/ui/goods/%s.png" % good)
	for kind in C.TITLES:
		var path := "res://assets/ui/places/%s.png" % kind
		if ResourceLoader.exists(path): icons[kind] = load(path)
	icons["west"] = load("res://assets/ui/places/land_west.png")
	for name in ["coin", "star", "hammer", "more", "seedling", "build"]: icons[name] = load("res://assets/ui/nav/%s.png" % name)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	# A soft vignette gives the bright map depth and keeps the HUD legible.
	var vignette := _gradient_rect([[0.0, Color(0, 0, 0, 0)], [0.62, Color(0, 0, 0, 0)], [1.0, Color(0.02, 0.06, 0.05, 0.42)]], true)
	root.add_child(vignette)
	atmosphere = Atmosphere.new()
	atmosphere.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.visible = not reduce_motion
	root.add_child(atmosphere)
	_build_hud()
	toast_box = PanelContainer.new()
	var toast_style := glass(22, GLASS_DEEP)
	toast_style.content_margin_left = 22 * s; toast_style.content_margin_right = 22 * s
	toast_style.content_margin_top = 10 * s; toast_style.content_margin_bottom = 10 * s
	toast_box.add_theme_stylebox_override("panel", toast_style)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font", DISPLAY_SEMI)
	toast.add_theme_font_size_override("font_size", int(20 * s))
	toast_box.add_child(toast)
	toast_box.visible = false
	root.add_child(toast_box)
	fly_layer = Control.new()
	fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.theme = root.theme
	add_child(fly_layer)
	pointer = Pointer.new()
	pointer.ui = self
	pointer.size = Vector2(60, 70) * s
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.visible = false
	root.add_child(pointer)
	root.move_child(pointer, 1)
	_load_settings()
	if atmosphere: atmosphere.visible = not reduce_motion
	if main.host.has_method("set_reduced_motion"): main.host.set_reduced_motion(reduce_motion)
	_setup_audio()
	_show_title()
	refresh()

## Keeps the HUD clear of the iPhone's Dynamic Island and the home indicator.
var safe := Rect2()  # insets: position = left/top, size = right/bottom
func _read_safe_area() -> void:
	if not OS.has_feature("mobile"): return
	var screen := Vector2(DisplayServer.screen_get_size())
	var area := Rect2(DisplayServer.get_display_safe_area())
	var viewport: Vector2 = main.get_viewport().get_visible_rect().size
	if screen.x <= 0 or area.size.x <= 0: return
	var k: float = viewport.x / screen.x
	safe = Rect2(area.position * k, (screen - area.end) * k)

## A full-screen gradient: radial from the centre, or top-to-bottom.
func _gradient_rect(stops: Array, radial: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(stop): return stop[0]))
	gradient.colors = PackedColorArray(stops.map(func(stop): return stop[1]))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	if radial:
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.45)
		texture.fill_to = Vector2(1.08, 1.0)
	else:
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# --- title -----------------------------------------------------------------

var title_layer: Control

## A cinematic title over the living map: a dusk grade, drifting light, a
## wordmark and one Play button. Any tap starts play.
func _show_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	title_layer.theme = root.theme
	var side := _gradient_rect([[0.0, Color(0.02, 0.07, 0.06, 0.88)], [0.42, Color(0.02, 0.07, 0.06, 0.5)], [0.75, Color(0.02, 0.07, 0.06, 0.0)]], false)
	(side.texture as GradientTexture2D).fill_from = Vector2(0, 0.5)
	(side.texture as GradientTexture2D).fill_to = Vector2(1, 0.5)
	title_layer.add_child(side)
	title_layer.add_child(_gradient_rect([[0.0, Color(0.02, 0.07, 0.06, 0.0)], [0.6, Color(0.02, 0.07, 0.06, 0.0)], [1.0, Color(0.02, 0.06, 0.05, 0.6)]], false))
	title_layer.add_child(_gradient_rect([[0.0, Color(0, 0, 0, 0)], [0.55, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.45)]], true))
	var motes := Motes.new()
	motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motes.visible = not reduce_motion
	title_layer.add_child(motes)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(0 * s))
	column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 86 * s + safe.position.x
	column.offset_right = column.offset_left + 520 * s
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eyebrow := Label.new()
	eyebrow.text = "TUVLO"
	eyebrow.add_theme_font_override("font", _spaced(BODY, 12))
	eyebrow.add_theme_font_size_override("font_size", int(22 * s))
	eyebrow.add_theme_color_override("font_color", GOLD)
	column.add_child(eyebrow)
	var name_label := Label.new()
	name_label.text = "World"
	name_label.add_theme_font_override("font", DISPLAY)
	name_label.add_theme_font_size_override("font_size", int(140 * s))
	name_label.add_theme_color_override("font_color", IVORY)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	name_label.add_theme_constant_override("shadow_offset_y", int(6 * s))
	name_label.add_theme_constant_override("shadow_outline_size", int(14 * s))
	name_label.custom_minimum_size = Vector2(0, 150 * s)
	column.add_child(name_label)
	var tagline := Label.new()
	tagline.text = "Grow  ·  Bake  ·  Trade"
	tagline.add_theme_constant_override("line_spacing", 0)
	tagline.add_theme_font_override("font", _spaced(BODY, 3))
	tagline.add_theme_font_size_override("font_size", int(20 * s))
	tagline.add_theme_color_override("font_color", MUTED)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30 * s)
	column.add_child(gap)
	var play := _button("Play", dismiss_title)
	play.custom_minimum_size = Vector2(260, 68) * s
	play.add_theme_font_size_override("font_size", int(30 * s))
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(play)
	title_layer.add_child(column)
	add_child(title_layer)
	for control in hud: control.modulate.a = 0.0
	# Staggered entrance, then Play breathes.
	var parts := [eyebrow, name_label, tagline, play]
	for i in parts.size():
		var part: Control = parts[i]
		part.modulate.a = 0.0
		var tween := part.create_tween()
		tween.tween_interval(0.25 + i * 0.14)
		tween.tween_property(part, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	get_tree().process_frame.connect(func():
		if not is_instance_valid(play): return
		play.pivot_offset = play.size / 2
		if reduce_motion: return
		var pulse := play.create_tween().set_loops()
		pulse.tween_property(play, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE), CONNECT_ONE_SHOT)
	title_layer.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed): dismiss_title())
	main.camera({"mode": "arrival", "resetZoom": true})

func dismiss_title() -> void:
	if not title_layer: return
	var layer := title_layer
	title_layer = null
	sfx("success")
	var tween := create_tween().set_parallel()
	tween.tween_property(layer, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE)
	for control in hud: tween.tween_property(control, "modulate:a", 1.0, 0.5).set_delay(0.25)
	tween.chain().tween_callback(layer.queue_free)

# --- sound -----------------------------------------------------------------

func _setup_audio() -> void:
	for name in ["tap", "coin", "coins", "world_harvest", "world_plant", "world_mill", "world_grill", "world_sheep", "world_build_complete", "place_set", "success", "level_up", "world_paper", "world_wood", "soft_fail", "celebrate"]:
		var path := "res://assets/audio/%s.wav" % name
		if ResourceLoader.exists(path):
			var effect = load(path)
			if effect == null: continue
			var player := AudioStreamPlayer.new()
			player.stream = effect
			player.volume_db = -6.0
			player.max_polyphony = F.SFX_POLYPHONY
			add_child(player)
			audio[name] = player
	ambience = WorldAmbience.new()
	ambience.name = "Ambience"
	ambience.enabled = sound_on
	add_child(ambience)
	music = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/music_world.ogg") if ResourceLoader.exists("res://assets/audio/music_world.ogg") else null
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		music.stream = stream
		music.volume_db = -16.0
		add_child(music)
		if music_on: music.play()

## Every effect varies a little in pitch so repeats never sound mechanical;
## pass a pitch to climb (see _combo_pitch).
func sfx(name: String, pitch := 1.0) -> void:
	if not sound_on or not audio.has(name): return
	var player: AudioStreamPlayer = audio[name]
	player.pitch_scale = pitch * (1.0 + randf_range(-F.PITCH_JITTER, F.PITCH_JITTER))
	player.play()

var combo := 0
var combo_at := -100.0
## Gains in quick succession climb a step each, up to a ceiling; a pause resets.
func _combo_pitch() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	combo = mini(combo + 1, F.COMBO_MAX_STEPS) if now - combo_at <= F.COMBO_WINDOW else 0
	combo_at = now
	return 1.0 + combo * F.COMBO_STEP

## A light tap on phones and iPads; nothing elsewhere.
func haptic(strength := F.HAPTIC_TAP) -> void:
	if haptics_on and OS.has_feature("mobile"): Input.vibrate_handheld(F.HAPTIC_MS, strength)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK: return
	sound_on = config.get_value("audio", "effects", true)
	music_on = config.get_value("audio", "music", true)
	haptics_on = config.get_value("feel", "haptics", true)
	reduce_motion = config.get_value("feel", "reduce_motion", false)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "effects", sound_on)
	config.set_value("audio", "music", music_on)
	config.set_value("feel", "haptics", haptics_on)
	config.set_value("feel", "reduce_motion", reduce_motion)
	config.save(SETTINGS_PATH)

func set_music(on: bool) -> void:
	music_on = on
	if music and music.stream:
		if on and not music.playing: music.play()
		elif not on: music.stop()
	_save_settings()

func toggle_sound() -> void:
	sound_on = not sound_on
	if ambience: ambience.set_enabled(sound_on)
	set_music(sound_on)

# --- motion ----------------------------------------------------------------

func pop_in(control: Control) -> void:
	control.pivot_offset = control.size / 2
	control.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	if not reduce_motion:
		control.scale = Vector2.ONE * F.POP_FROM_SCALE
		tween.tween_property(control, "scale", Vector2.ONE, F.POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, F.FADE_IN_TIME)

## A one-shot tween per control and purpose: a new one replaces the old, so
## rapid taps never stack scales or leave a control stuck mid-animation.
func _solo_tween(control: Node, key: String) -> Tween:
	var meta := "tween_" + key
	if control.has_meta(meta):
		var old: Tween = control.get_meta(meta)
		if old and old.is_valid(): old.kill()
	var tween := control.create_tween()
	control.set_meta(meta, tween)
	return tween

func bump(control: Control, size := F.BUMP_SCALE) -> void:
	if not is_instance_valid(control) or reduce_motion: return
	control.pivot_offset = control.size / 2
	control.scale = Vector2.ONE
	var tween := _solo_tween(control, "bump")
	tween.tween_property(control, "scale", Vector2.ONE * size, F.BUMP_UP_TIME).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2.ONE, F.BUMP_SETTLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _juice(button: BaseButton) -> void:
	button.button_down.connect(func(): if not button.disabled: press_in(button, F.PRESS_SCALE))
	button.button_up.connect(func(): press_out(button))
	button.pressed.connect(func(): last_pressed = button; sfx("tap"); haptic())

## A card, tile or chip that isn't a Button gets the same pressed state: it
## dims and squashes while the finger is down, and springs back on release,
## when the finger slides off, or when any touch ends anywhere (a scroll or a
## drag can swallow the card's own release).
func _press_card(card: Control) -> void:
	card.gui_input.connect(func(e):
		var touch: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch
		if not touch: return
		if e.pressed: press_in(card, F.CARD_PRESS_SCALE)
		else: press_out(card))
	card.mouse_exited.connect(func(): press_out(card))

var held: Array[Control] = []
func press_in(control: Control, to_scale: float) -> void:
	if not is_instance_valid(control): return
	if control not in held: held.append(control)
	_dim(control, F.PRESS_DIM, F.PRESS_TIME)
	if reduce_motion: return
	control.pivot_offset = control.size / 2
	_solo_tween(control, "press").tween_property(control, "scale", Vector2.ONE * to_scale, F.PRESS_TIME)

func press_out(control: Control) -> void:
	held.erase(control)
	if not is_instance_valid(control): return
	_dim(control, 1.0, F.RELEASE_TIME)
	if reduce_motion: control.scale = Vector2.ONE; return
	# Always replace the press tween: a tap lifted on the same frame it landed
	# would otherwise leave the squash running with nothing to undo it.
	_solo_tween(control, "press").tween_property(control, "scale", Vector2.ONE, F.RELEASE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Brightness only: alpha stays free for drag sockets and locked tabs.
func _dim(control: Control, to: float, time: float) -> void:
	var from := control.modulate.r
	_solo_tween(control, "dim").tween_method(func(v: float):
		if is_instance_valid(control): control.modulate = Color(v, v, v, control.modulate.a), from, to, time)

## Icons fly from a screen point to a HUD target along an arc, then the target bumps.
## With Reduce Motion the target only acknowledges the gain.
func fly(texture: Texture2D, from: Vector2, target: Control, count := 3, side := 44.0) -> void:
	if texture == null or not is_instance_valid(target): return
	if reduce_motion: return
	var to := target.get_global_rect().get_center()
	var room := F.FLY_MAX_ON_SCREEN - fly_layer.get_child_count()
	if room <= 0: return
	for i in mini(mini(count, F.FLY_MAX_PER_GAIN), room):
		var sprite := TextureRect.new()
		sprite.texture = texture
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.size = Vector2(side, side) * s
		sprite.pivot_offset = sprite.size / 2
		sprite.position = from - sprite.size / 2 + Vector2(randf_range(-18, 18), randf_range(-12, 12)) * s
		fly_layer.add_child(sprite)
		var start := sprite.position
		var end := to - sprite.size / 2
		var lift := Vector2(randf_range(-F.FLY_SPREAD, F.FLY_SPREAD), -F.FLY_LIFT) * s
		var tween := sprite.create_tween()
		tween.tween_interval(i * F.FLY_STAGGER)
		tween.tween_property(sprite, "scale", Vector2.ONE * F.FLY_GROW_SCALE, F.FLY_GROW_TIME)
		tween.tween_method(func(t: float):
			var a := start.lerp(start + lift, t)
			var b := (start + lift).lerp(end, t)
			sprite.position = a.lerp(b, t)
			sprite.scale = Vector2.ONE * lerpf(F.FLY_GROW_SCALE, F.FLY_LAND_SCALE, t), 0.0, 1.0, F.FLY_TRAVEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			sprite.queue_free()
			bump(target))

## The wallet rolls to its new total as the coins land; a newer change
## retargets from whatever is showing, so rapid sales never skip or rewind.
func _count_to(coins: int) -> void: roll(coins_label, coins)

## Any number label rolls to its new value instead of jumping. Gains wait for
## the flying icons to land; a newer value retargets from whatever is showing,
## so rapid changes never skip or rewind. Reduce Motion shows it at once.
func roll(label: Label, value: int, wait_for_flight := true) -> void:
	if not is_instance_valid(label): return
	var shown: float = label.get_meta("shown", -1.0)
	if shown < 0 or reduce_motion:
		label.set_meta("shown", float(value))
		_solo_tween(label, "count").kill()
		label.text = str(value)
		return
	var gap := absf(value - shown)
	if gap < 0.5: return
	var time := clampf(gap * F.COUNT_TIME_PER_COIN, F.COUNT_MIN_TIME, F.COUNT_MAX_TIME)
	var tween := _solo_tween(label, "count")
	if value > shown and wait_for_flight: tween.tween_interval(F.COUNT_DELAY)
	tween.tween_method(func(v: float):
		label.set_meta("shown", v)
		label.text = str(roundi(v)), shown, float(value), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 0 for a small gain, 1 for a good one, 2 for a big one (thresholds in feel.gd).
static func reward_tier(gain: int) -> int:
	return 2 if gain >= F.REWARD_BIG else (1 if gain >= F.REWARD_GOOD else 0)

## A rising "+N" label at a screen point.
func float_text(text: String, at: Vector2, color := IVORY, font_px := 32) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", DISPLAY)
	label.add_theme_font_size_override("font_size", int(font_px * s))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.09, 0.085, 0.85))
	label.add_theme_constant_override("outline_size", int(8 * s))
	fly_layer.add_child(label)
	label.position = at - Vector2(30, 20) * s
	label.pivot_offset = Vector2(30, 20) * s
	var tween := create_tween().set_parallel()
	if not reduce_motion:
		label.scale = Vector2(0.6, 0.6)
		tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not reduce_motion: tween.tween_property(label, "position:y", label.position.y - F.FLOAT_RISE * s, F.FLOAT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, F.FLOAT_TIME).set_delay(F.FLOAT_FADE_DELAY)
	tween.chain().tween_callback(label.queue_free)

## Letter-spaced type for small caps eyebrows and taglines.
func _spaced(font: Font, spacing: float) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = int(spacing * s)
	return variation

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY
	theme.default_font_size = int(18 * s)
	theme.set_color("font_color", "Label", IVORY)
	var primary := {
		"normal": _lip_box(GOLD, GOLD_DEEP, 4), "hover": _lip_box(Color("FACB62"), GOLD_DEEP, 4),
		"pressed": _lip_box(Color("EBB23C"), GOLD_DEEP, 1), "focus": _lip_box(GOLD, GOLD_DEEP, 4),
		"disabled": _lip_box(DISABLED_FILL, Color(0, 0, 0, 0), 0)}
	for state in primary: theme.set_stylebox(state, "Button", primary[state])
	theme.set_font("font", "Button", DISPLAY_SEMI)
	theme.set_color("font_color", "Button", GOLD_INK)
	theme.set_color("font_hover_color", "Button", GOLD_INK)
	theme.set_color("font_pressed_color", "Button", GOLD_INK)
	theme.set_color("font_focus_color", "Button", GOLD_INK)
	theme.set_color("font_disabled_color", "Button", DISABLED_INK)
	theme.set_font_size("font_size", "Button", int(21 * s))
	theme.set_stylebox("separator", "HSeparator", _line_box())
	theme.set_constant("separation", "HSeparator", int(14 * s))
	return theme

## A pill with a darker lip under it, like a pressable key.
func _lip_box(color: Color, lip: Color, depth: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(26 * s))
	box.border_color = lip
	box.border_width_bottom = int(depth * s)
	box.content_margin_left = 22 * s; box.content_margin_right = 22 * s
	box.content_margin_top = (8 + (4 - depth)) * s; box.content_margin_bottom = 8 * s
	if depth > 0:
		box.shadow_color = Color(0, 0, 0, 0.22)
		box.shadow_size = int(6 * s)
		box.shadow_offset = Vector2(0, 3 * s)
	box.anti_aliasing_size = 0.8
	return box

func _line_box() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.12)
	line.thickness = int(maxf(1, 1.5 * s))
	return line

## The house surface: dark glass with a hairline edge and a soft long shadow.
func glass(radius := 26.0, color := GLASS, shadow := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius * s))
	box.border_color = EDGE
	box.set_border_width_all(int(maxf(1, 1.5 * s)))
	if shadow:
		box.shadow_color = Color(0, 0, 0, 0.28)
		box.shadow_size = int(16 * s)
		box.shadow_offset = Vector2(0, 6 * s)
	box.set_content_margin_all(12 * s)
	box.anti_aliasing_size = 0.8
	return box

## A lighter well inside glass, for goods, tiles and tickets.
func tile_box(radius := 20.0, highlight := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(GOLD, 0.16) if highlight else TILE
	box.set_corner_radius_all(int(radius * s))
	box.border_color = GOLD if highlight else Color(1, 1, 1, 0.1)
	box.set_border_width_all(int((2.5 if highlight else 1.2) * s))
	box.set_content_margin_all(10 * s)
	box.anti_aliasing_size = 0.8
	return box

func pill_box(color: Color) -> StyleBoxFlat:
	var box := glass(22, color, false)
	box.content_margin_left = 16 * s; box.content_margin_right = 16 * s
	box.content_margin_top = 6 * s; box.content_margin_bottom = 6 * s
	return box

func frame_box(radius := 26.0, _color := GLASS) -> StyleBoxFlat:
	return glass(radius)

func _icon(texture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side) * s
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _number(size_px: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", DISPLAY)
	label.add_theme_font_size_override("font_size", int(size_px * s))
	return label

## A round glass button: an icon, or a glyph when there is no art.
func _round_button(icon_name: String, action: Callable, label := "") -> Button:
	var button := Button.new()
	if icons.has(icon_name): button.icon = icons[icon_name]
	button.expand_icon = true
	button.custom_minimum_size = Vector2(64, 64) * s
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = label
	var box := glass(32)
	box.set_content_margin_all(10 * s)
	var down := glass(32, GLASS_DEEP)
	down.set_content_margin_all(10 * s)
	for state in ["normal", "hover", "focus"]: button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("pressed", down)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_pressed_color", IVORY)
	button.pressed.connect(action)
	_juice(button)
	return button

func _close_button() -> Button:
	var button := _round_button("", close, "Close")
	button.text = "✕"
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", int(18 * s))
	button.custom_minimum_size = Vector2(44, 44) * s
	return button

## Primary actions are gold keys; "quiet" ones are glass.
func _button(text: String, action: Callable, enabled := true, icon_name := "", quiet := false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 50 * s)
	if quiet:
		var box := tile_box(25)
		box.content_margin_left = 20 * s; box.content_margin_right = 20 * s
		box.content_margin_top = 6 * s; box.content_margin_bottom = 6 * s
		var down := box.duplicate()
		down.bg_color = Color(1, 1, 1, 0.16)
		for state in ["normal", "hover", "focus", "disabled"]: button.add_theme_stylebox_override(state, box)
		button.add_theme_stylebox_override("pressed", down)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(key, IVORY)
	if icon_name != "":
		button.icon = icons.get(icon_name)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", int(28 * s))
		button.add_theme_constant_override("h_separation", int(8 * s))
		button.custom_minimum_size.x = 96 * s
	button.pressed.connect(action)
	_juice(button)
	return button

## A dock button: an icon with a small caption under it.
func _dock_button(icon_name: String, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = caption
	button.custom_minimum_size = Vector2(78, 76) * s
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_corner_radius_all(int(22 * s))
	var down := flat.duplicate()
	down.bg_color = Color(1, 1, 1, 0.1)
	for state in ["normal", "hover", "focus"]: button.add_theme_stylebox_override(state, flat)
	button.add_theme_stylebox_override("pressed", down)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(1 * s))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := _icon(icons.get(icon_name), 44)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(picture)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DISPLAY_SEMI)
	label.add_theme_font_size_override("font_size", int(14 * s))
	label.add_theme_color_override("font_color", MUTED)
	column.add_child(label)
	button.add_child(column)
	button.pressed.connect(action)
	_juice(button)
	return button

func _build_hud() -> void:
	# One wallet capsule at the top: level medal, then coins.
	var wallet := PanelContainer.new()
	var wallet_box := glass(30)
	wallet_box.content_margin_left = 6 * s; wallet_box.content_margin_right = 20 * s
	wallet_box.content_margin_top = 5 * s; wallet_box.content_margin_bottom = 5 * s
	wallet.add_theme_stylebox_override("panel", wallet_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(10 * s))
	level_badge = LevelBadge.new()
	level_badge.ui = self
	level_badge.custom_minimum_size = Vector2(48, 48) * s
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(level_badge)
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.14)
	divider.custom_minimum_size = Vector2(maxf(1, 1.5 * s), 28 * s)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(divider)
	var coin := _icon(icons["coin"], 32)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coin)
	coin_pill = coin
	coins_label = _number(26)
	coins_label.custom_minimum_size = Vector2(36, 0) * s
	top.add_child(coins_label)
	# Stars: the purse that finishes timers at once.
	var star_divider := ColorRect.new()
	star_divider.color = Color(1, 1, 1, 0.14)
	star_divider.custom_minimum_size = Vector2(maxf(1, 1.5 * s), 28 * s)
	star_divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(star_divider)
	var star := _icon(icons["star"], 30)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.tooltip_text = "Stars"
	top.add_child(star)
	star_pill = star
	stars_label = _number(26)
	stars_label.custom_minimum_size = Vector2(28, 0) * s
	top.add_child(stars_label)
	level_label = Label.new()
	wallet.add_child(top)
	wallet.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(14 * s))
	wallet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(wallet)
	hud.append(wallet)
	wallet_node = wallet
	# Goal ticket: the next step, always one tap away.
	goal_box = PanelContainer.new()
	var ticket := glass(24)
	ticket.content_margin_left = 8 * s; ticket.content_margin_right = 18 * s
	ticket.content_margin_top = 7 * s; ticket.content_margin_bottom = 7 * s
	goal_box.add_theme_stylebox_override("panel", ticket)
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", int(12 * s))
	var socket := PanelContainer.new()
	var socket_box := tile_box(22, true)
	socket_box.set_content_margin_all(5 * s)
	socket.add_theme_stylebox_override("panel", socket_box)
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_icon = _icon(icons["star"], 36)
	socket.add_child(goal_icon)
	goal_row.add_child(socket)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", int(-3 * s))
	var next := Label.new()
	next.text = "NEXT"
	next.add_theme_font_override("font", _spaced(BODY, 2.5))
	next.add_theme_font_size_override("font_size", int(11 * s))
	next.add_theme_color_override("font_color", GOLD)
	words.add_child(next)
	goal_label = Label.new()
	goal_label.add_theme_font_override("font", DISPLAY_SEMI)
	goal_label.add_theme_font_size_override("font_size", int(20 * s))
	words.add_child(goal_label)
	goal_row.add_child(words)
	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_override("font", DISPLAY)
	chevron.add_theme_font_size_override("font_size", int(30 * s))
	chevron.add_theme_color_override("font_color", MUTED)
	goal_row.add_child(chevron)
	goal_box.add_child(goal_row)
	goal_box.position = Vector2(16 * s + safe.position.x, 14 * s + safe.position.y)
	goal_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_press_card(goal_box)
	goal_box.gui_input.connect(func(e):
		if ((e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed)) and goal_action.is_valid():
			sfx("tap"); bump(goal_box); goal_action.call())
	root.add_child(goal_box)
	hud.append(goal_box)
	_build_barge_chip()
	# The dock: Build and the Market, captioned like a pro app's tab bar.
	var dock := PanelContainer.new()
	var dock_box := glass(30)
	dock_box.set_content_margin_all(5 * s)
	dock.add_theme_stylebox_override("panel", dock_box)
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", int(2 * s))
	rail.add_child(_dock_button("hammer", "Build", func(): open("build")))
	var market: bool = main.game.host.features().get("market", false)
	market_button = _dock_button("meal", "Market" if market else "Goods", func(): open("more"))
	rail.add_child(market_button)
	dock.add_child(rail)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(16 * s))
	dock.offset_left -= safe.size.x; dock.offset_right -= safe.size.x
	dock.offset_top -= safe.size.y; dock.offset_bottom -= safe.size.y
	dock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(dock)
	hud.append(dock)
	dock_node = dock
	var sound := _round_button("", func(): open("settings"), "Settings")
	sound.text = "•••"
	sound.add_theme_font_override("font", DISPLAY)
	sound.add_theme_font_size_override("font_size", int(15 * s))
	sound.custom_minimum_size = Vector2(46, 46) * s
	sound.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(16 * s))
	sound.offset_left -= safe.size.x; sound.offset_right -= safe.size.x
	sound.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(sound)
	hud.append(sound)
	settings_node = sound
	_build_weather_pill()

## The sky pill beside Settings: this spell's emblem and how long it lasts.
## One tap opens the forecast.
var settings_node: Control
var weather_pill: PanelContainer
var weather_pill_icon: WeatherIcon
var weather_pill_label: Label
var weather_shown := -1
var weather_clock: Label
var switching_place := false
var weather_later := {}  # forecast card index -> its "in m:ss" label

func _build_weather_pill() -> void:
	weather_pill = PanelContainer.new()
	var box := glass(22)
	box.content_margin_left = 8 * s; box.content_margin_right = 14 * s
	box.content_margin_top = 4 * s; box.content_margin_bottom = 4 * s
	weather_pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * s))
	weather_pill_icon = WeatherIcon.new()
	weather_pill_icon.custom_minimum_size = Vector2(32, 32) * s
	weather_pill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(weather_pill_icon)
	weather_pill_label = Label.new()
	weather_pill_label.add_theme_font_override("font", DISPLAY_SEMI)
	weather_pill_label.add_theme_font_size_override("font_size", int(16 * s))
	weather_pill_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(weather_pill_label)
	weather_pill.add_child(row)
	weather_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	_press_card(weather_pill)
	weather_pill.gui_input.connect(func(e):
		if (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed):
			sfx("tap"); bump(weather_pill); open("weather"))
	root.add_child(weather_pill)
	hud.append(weather_pill)

func _update_weather() -> void:
	if weather_pill == null or not main or not main.game: return
	var cast: Dictionary = main.game.forecast()
	var sky: String = cast.now
	if atmosphere: atmosphere.sky = sky
	if weather_shown < 0 or reduce_motion:
		weather_pill_icon.sky = sky
		weather_pill_label.text = C.WEATHER[sky].title
	if is_instance_valid(weather_clock): weather_clock.text = "for %s" % _clock(int(cast.left))
	for i in weather_later:
		if is_instance_valid(weather_later[i]): weather_later[i].text = "in %s" % _clock(int(cast.left) + (int(i) - 1) * int(cast.length))
	if int(cast.window) != weather_shown:
		var first := weather_shown < 0
		weather_shown = int(cast.window)
		weather_pill_icon.queue_redraw()
		main.push()  # the map's light and sway follow the new sky
		if not first:
			if mode == "weather": _fill()
			elif mode == "place": _fill()  # its boost badge follows the sky
			_morph_sky(sky)
			if sky != "sunny" and title_layer == null:
				sfx("place_set")
				show_toast("%s · %s" % [C.WEATHER[sky].title, C.WEATHER[sky].line])
	weather_pill.visible = mode == "" and title_layer == null
	if weather_pill.visible and settings_node:
		weather_pill.reset_size()
		weather_pill.position = Vector2(settings_node.position.x - weather_pill.size.x - 10 * s,
			settings_node.position.y + (settings_node.size.y - weather_pill.size.y) / 2)

## A new spell: the pill winds in, swaps its emblem and name at the bottom of
## the wind-up, then springs out past full size and settles. Reduce Motion
## swaps straight away.
func _morph_sky(sky: String) -> void:
	if reduce_motion:
		weather_pill_icon.sky = sky; weather_pill_label.text = C.WEATHER[sky].title
		weather_pill_icon.queue_redraw()
		return
	weather_pill.pivot_offset = weather_pill.size / 2
	var tween := _solo_tween(weather_pill, "sky")
	tween.tween_property(weather_pill, "scale", Vector2.ONE * F.SKY_WIND_SCALE, F.SKY_WIND_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		weather_pill_icon.sky = sky
		weather_pill_label.text = C.WEATHER[sky].title
		weather_pill_icon.queue_redraw()
		haptic(F.HAPTIC_TAP))
	tween.tween_property(weather_pill, "scale", Vector2.ONE * F.SKY_POP_SCALE, F.SKY_WIND_TIME * 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(weather_pill, "scale", Vector2.ONE, F.SKY_SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## The forecast: this spell and the next two, each with what it speeds up.
func _fill_weather() -> void:
	var cast: Dictionary = main.game.forecast()
	var column := _sheet("Weather")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(12 * s))
	var skies: Array = [cast.now] + cast.next
	for i in skies.size():
		row.add_child(_weather_card(skies[i], i, cast))
	column.add_child(row)

func _weather_card(sky: String, index: int, cast: Dictionary) -> Control:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER if index == 0 else Color(PAPER, 0.82)
	box.set_corner_radius_all(int(12 * s))
	box.border_color = GOLD if index == 0 else PAPER_EDGE
	box.set_border_width_all(int((3.0 if index == 0 else 1.5) * s))
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = int(8 * s)
	box.shadow_offset = Vector2(0, 4 * s)
	box.set_content_margin_all(12 * s)
	box.anti_aliasing_size = 0.8
	card.add_theme_stylebox_override("panel", box)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", int(4 * s))
	stack.custom_minimum_size = Vector2(168, 0) * s
	var when := _eyebrow("Now" if index == 0 else ("Next" if index == 1 else "Later"))
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	when.add_theme_color_override("font_color", AWNING_RED)
	stack.add_child(when)
	var emblem := WeatherIcon.new()
	emblem.sky = sky
	emblem.muted = index > 0
	emblem.custom_minimum_size = Vector2(64, 64) * s
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(emblem)
	var name_label := _number(22)
	name_label.text = C.WEATHER[sky].title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", PAPER_INK)
	stack.add_child(name_label)
	var line := Label.new()
	line.text = C.WEATHER[sky].line
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(150, 0) * s
	line.add_theme_font_size_override("font_size", int(14 * s))
	line.add_theme_color_override("font_color", PAPER_READY if not C.WEATHER[sky].boost.is_empty() else Color(PAPER_INK, 0.7))
	stack.add_child(line)
	# Every card ends on its time, so the three stand level.
	var at := Label.new()
	at.text = "for %s" % _clock(int(cast.left)) if index == 0 else "in %s" % _clock(int(cast.left) + (index - 1) * int(cast.length))
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	at.add_theme_font_size_override("font_size", int(13 * s))
	at.add_theme_color_override("font_color", Color(PAPER_INK, 0.6))
	stack.add_child(at)
	if index == 0: weather_clock = at
	else: weather_later[index] = at
	card.add_child(stack)
	return card

## A small "Rain ×2" tag under a card's action while the sky speeds it up.
func _weather_badge(job: String) -> Control:
	var boost: float = main.game.weather_boost(job)
	if boost <= 1.0: return null
	var sky: String = main.game.weather()
	var tag := PanelContainer.new()
	var box := glass(16, GLASS_DEEP, false)
	box.border_color = Color(GOLD, 0.7)
	box.set_border_width_all(int(1.5 * s))
	box.content_margin_left = 6 * s; box.content_margin_right = 12 * s
	box.content_margin_top = 2 * s; box.content_margin_bottom = 2 * s
	tag.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(4 * s))
	var emblem := WeatherIcon.new()
	emblem.sky = sky
	emblem.custom_minimum_size = Vector2(26, 26) * s
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(emblem)
	var words := Label.new()
	words.text = "%s ×%s" % [C.WEATHER[sky].title, ("%d" % boost) if is_equal_approx(boost, roundf(boost)) else ("%.1f" % boost)]
	words.add_theme_font_override("font", DISPLAY_SEMI)
	words.add_theme_font_size_override("font_size", int(14 * s))
	words.add_theme_color_override("font_color", GOLD)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	tag.add_child(row)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.tooltip_text = C.WEATHER[sky].line
	return tag

## The barge ticket under the goal: when Rowan's barge is in and how long it
## stays, one tap from its screen. Hidden until the windmill brings the barge.
var barge_chip: PanelContainer
var barge_chip_icon: BoatIcon
var barge_chip_status: Label
var barge_chip_eyebrow: Label
var barge_docked_style: StyleBoxFlat
var barge_away_style: StyleBoxFlat
var barge_clock: Label
var barge_shown := {}
var barge_chip_docked := -1  # -1 unseen, 0 away, 1 docked: restyle only on change
var barge_load := {}  # the load just committed, landed once the screen rebuilds

## A load lands: crates arc from the Load button into the hold bar, the bar
## springs to its new share and the tally punches as the first one arrives.
## The load is already saved; none of this holds up the next tap.
func _land_barge_load(load: Dictionary, bar: FillBar, tally: Label) -> void:
	haptic(F.HAPTIC_REWARD)
	if reduce_motion: return
	get_tree().process_frame.connect(func():
		if not is_instance_valid(bar): return
		bar.grow_from(float(load.share), F.BAR_FILL_TIME)
		fly(icons.get(load.good), load.from, bar, mini(int(load.count), F.BARGE_FLY_MAX), 40.0)
		get_tree().create_timer(F.FLY_GROW_TIME + F.FLY_TRAVEL_TIME * 0.6).timeout.connect(func(): if is_instance_valid(tally): bump(tally, 1.25)), CONNECT_ONE_SHOT)
var last_shipped := -1
func _build_barge_chip() -> void:
	barge_chip = PanelContainer.new()
	barge_docked_style = glass(22)
	barge_docked_style.border_color = Color(GOLD, 0.85)
	barge_docked_style.set_border_width_all(int(2 * s))
	barge_away_style = glass(22)
	for style in [barge_docked_style, barge_away_style]:
		style.content_margin_left = 10 * s; style.content_margin_right = 16 * s
		style.content_margin_top = 6 * s; style.content_margin_bottom = 6 * s
	barge_chip.add_theme_stylebox_override("panel", barge_away_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * s))
	barge_chip_icon = BoatIcon.new()
	barge_chip_icon.custom_minimum_size = Vector2(38, 38) * s
	barge_chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(barge_chip_icon)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", int(-3 * s))
	barge_chip_eyebrow = Label.new()
	barge_chip_eyebrow.add_theme_font_override("font", _spaced(BODY, 2.5))
	barge_chip_eyebrow.add_theme_font_size_override("font_size", int(11 * s))
	barge_chip_eyebrow.add_theme_color_override("font_color", GOLD)
	words.add_child(barge_chip_eyebrow)
	barge_chip_status = Label.new()
	barge_chip_status.add_theme_font_override("font", DISPLAY_SEMI)
	barge_chip_status.add_theme_font_size_override("font_size", int(17 * s))
	words.add_child(barge_chip_status)
	row.add_child(words)
	barge_chip.add_child(row)
	barge_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	barge_chip.visible = false
	_press_card(barge_chip)
	barge_chip.gui_input.connect(func(e):
		if (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed):
			sfx("tap"); bump(barge_chip); open("barge"))
	root.add_child(barge_chip)
	hud.append(barge_chip)

func _barge_status(info: Dictionary) -> String:
	if info.docked: return "Leaves in %s" % _clock(int(info.left))
	return "Back in %s" % _clock(int(info.left))

## Hours when they matter, else minutes and seconds.
static func _clock(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds >= 3600: return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return _time(seconds)

func _update_barge_chip() -> void:
	if barge_chip == null or not main or not main.game: return
	var info: Dictionary = main.game.barge()
	var show := not info.is_empty() and mode == "" and title_layer == null
	barge_chip.visible = show
	if is_instance_valid(barge_clock) and not info.is_empty():
		barge_clock.text = _barge_status(info)
	if info.is_empty(): return
	# The screen rebuilds when the barge arrives, leaves or is loaded.
	if mode == "barge" and [info.docked, info.cycle, info.loaded] != [barge_shown.get("docked"), barge_shown.get("cycle"), barge_shown.get("loaded")]:
		_fill()
	# Arrival is a moment: the ticket turns gold with a bump and a short note,
	# once per barge (never for the state found on opening the game).
	var docked: bool = info.docked
	var arrived := docked and barge_chip_docked == 0
	if barge_chip_docked != int(docked):
		barge_chip_docked = int(docked)
		barge_chip.add_theme_stylebox_override("panel", barge_docked_style if docked else barge_away_style)
		barge_chip_icon.muted = not docked
		barge_chip_icon.queue_redraw()
		barge_chip_status.add_theme_color_override("font_color", IVORY if docked else MUTED)
	if arrived and title_layer == null:
		sfx("place_set")
		show_toast("Rowan's barge is in")
	if not show: return
	barge_chip.position = goal_box.position + Vector2(0, goal_box.size.y + 10 * s)
	barge_chip_eyebrow.text = ("BARGE · %d/%d" % [info.loaded, info.wanted]) if docked else "BARGE"
	barge_chip_status.text = _barge_status(info)
	if arrived: bump(barge_chip, 1.15)

## The next most useful step, computed from the save. Never a dead end.
func _goal() -> Array:
	var game: WorldGame = main.game
	var st := game.state
	var now := game.now()
	var garden := st.first_of("garden")
	if game.gift_ready():
		return [game.gift_basket().keys()[0], "Daily gift", func(): open("gift"), ""]
	var barge_info: Dictionary = game.barge()
	if barge_info.get("docked", false):
		for line in barge_info.lines:
			if line.loaded < line.count and st.stock.get(line.good, 0) > 0:
				return [line.good, "Load the barge", func(): open("barge"), ""]
	for station in st.jobs:
		if st.job_remaining(station, now) == 0:
			var spec: Dictionary = C.RECIPES[st.jobs[station].recipe]
			return [spec.output, "Collect %s" % C.title(spec.output).to_lower(), func(): place_tapped(st.first_of(C.STATIONS[station]).id, station), st.first_of(C.STATIONS[station]).id]
	var stages := []
	for i in st.fields.size(): stages.append(st.field_stage(i, now))
	if 4 in stages: return ["wheat", "Harvest the wheat", func(): place_tapped(garden.id, ""), garden.id]
	for order in st.open_orders():
		if st.stock.get(order.good, 0) >= order.count: return ["coin", "Deliver %d %s" % [order.count, C.title(order.good).to_lower()], func(): open("more"), ""]
	if 0 in stages: return ["seed", "Plant wheat", func(): place_tapped(garden.id, ""), garden.id]
	if 1 in stages: return ["water", "Water the field", func(): place_tapped(garden.id, ""), garden.id]
	var level := game.host.progress()
	for kind in C.BUILD_ORDER:
		var spec: Dictionary = C.BUILDS[kind]
		if kind in ["flowers", "rocks", "bench"]: continue
		var blocker := st.build_blocker(kind, level)
		if blocker == "" and game.host.wallet() >= spec.price: return [kind, "Build a %s" % C.title(kind).to_lower(), func(): open("build"), ""]
		if blocker == "locked": return [kind, "%s at level %d" % [C.title(kind), spec.gate], func(): open("more"), ""]
	if st.owns("windmill") and not st.jobs.has("mill") and st.stock.wheat >= 2: return ["flour", "Mill some flour", func(): place_tapped(st.first_of("windmill").id, "mill"), st.first_of("windmill").id]
	if not st.jobs.has("oven") and st.stock.flour >= 1: return ["bread", "Bake bread", func(): place_tapped(st.first_of("cottage").id, "oven"), st.first_of("cottage").id]
	return ["wheat", "Wheat is growing", func(): place_tapped(garden.id, ""), ""]

# --- state -------------------------------------------------------------------

## True when a screen point belongs to the UI, so the world ignores the tap.
## A tap on a place in the map does the obvious thing (collect, plant, water,
## harvest, pick); anything else opens its card.
func place_tapped(id: String, tapped_station := "") -> void:
	var game: WorldGame = main.game
	var st := game.state
	var item := st.find(id)
	if item.is_empty(): return
	var now := game.now()
	fly_from = root.get_viewport_rect().size / 2
	# The cottage itself is neither the oven nor the kitchen bench: a tap on
	# the house never bakes, packs or collects on their behalf.
	if _shared(item) and tapped_station == "":
		open("place", id)
		return
	if mode == "" and not st.is_building(id, now):
		if item.kind == "garden":
			var stages := []
			for i in st.fields.size(): stages.append(st.field_stage(i, now))
			if 4 in stages or 0 in stages or 1 in stages:
				_quick(id, func():
					var target := 4 if 4 in stages else (0 if 0 in stages else 1)
					var result := ""
					for i in stages.size():
						if stages[i] == target:
							result = game.tend(i)
							if result != "": break
					return result)
				return
		elif item.kind == "orchard":
			if st.orchard_watered < 0 or st.orchard_remaining(now) == 0:
				_quick(id, func(): return game.tend_orchard())
				return
		else:
			for each in C.stations_for(item.kind):
				if tapped_station != "" and each != tapped_station: continue
				if st.jobs.has(each) and st.job_remaining(each, now) == 0:
					_quick(id, func(): return game.collect(each))
					return
		# Input buffer: a tap just before a timer finishes waits for it.
		var wait := _ready_in(item, tapped_station, now)
		if wait > 0.0 and wait <= F.TIMER_BUFFER:
			if not buffered.has(id):
				buffered[id] = true
				get_tree().create_timer(wait + 0.05).timeout.connect(func():
					buffered.erase(id)
					if mode == "": place_tapped(id, tapped_station))
			return
	open("place", id, tapped_station)

var buffered := {}  # place ids with a tap waiting for their timer
## Seconds until this place has something to collect, or -1 when nothing is running.
func _ready_in(item: Dictionary, tapped_station: String, now: float) -> float:
	var st: WorldState = main.game.state
	var soonest := -1.0
	match item.kind:
		"garden":
			for i in st.fields.size():
				if st.field_stage(i, now) in [2, 3]: soonest = _min_positive(soonest, st.fields[i].watered + st.field_total(i) - now)
		"orchard":
			if st.orchard_watered >= 0: soonest = _min_positive(soonest, st.orchard_watered + st.orchard_grow - now)
		_:
			for each in C.stations_for(item.kind):
				if tapped_station != "" and each != tapped_station: continue
				if st.jobs.has(each): soonest = _min_positive(soonest, st.jobs[each].started + st.job_total(each) - now)
	return soonest
static func _min_positive(a: float, b: float) -> float:
	if b <= 0: return a
	return b if a < 0 or b < a else a

## A map action: on success the place squashes and throws flecks of what it
## made on the same frame as the sound and haptic; on failure, a soft thud.
func _quick(id: String, action: Callable) -> void:
	var before: Dictionary = main.game.state.stock.duplicate()
	var result: String = action.call()
	main.after_action(result)
	if result != "": sfx("soft_fail"); return
	var good := ""
	for each in main.game.state.stock:
		if main.game.state.stock[each] > before.get(each, 0): good = each; break
	main.send("punch", {"id": id, "good": good if good != "" else "wheat", "strength": 1.0 if good != "" else 0.6})
	if good == "": haptic(F.HAPTIC_TAP)

func blocks(point: Vector2) -> bool:
	if title_layer: return true
	# With a box open the map takes no taps: a tap outside closes the box instead.
	if mode not in ["", "build"]: return true
	if sheet_root and sheet_root.get_global_rect().has_point(point): return true
	for control in hud:
		if control.get_global_rect().has_point(point): return true
	return false

## The renderer reports where the goal's place is on screen (0–1 coordinates).
func point_at(x: float, y: float) -> void:
	if pointer_id == "" or mode != "": pointer.visible = false; return
	var viewport := root.get_viewport_rect().size
	pointer.position = Vector2(x * viewport.x, y * viewport.y) - Vector2(pointer.size.x / 2, pointer.size.y + 30 * s)
	pointer.visible = true

func _confetti() -> void:
	if reduce_motion: return
	var viewport := root.get_viewport_rect().size
	var colors := [GOLD, LEAF, Color("D9573E"), Color("5BA8D8"), CREAM]
	for i in 70:
		var bit := ColorRect.new()
		bit.color = colors[i % colors.size()]
		bit.size = Vector2(randf_range(8, 14), randf_range(12, 20)) * s
		bit.pivot_offset = bit.size / 2
		bit.position = Vector2(randf() * viewport.x, -30 * s - randf() * 120 * s)
		bit.rotation = randf() * TAU
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fly_layer.add_child(bit)
		var tween := bit.create_tween().set_parallel()
		var time := randf_range(1.6, 2.6)
		tween.tween_property(bit, "position", bit.position + Vector2(randf_range(-120, 120) * s, viewport.y + 160 * s), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(bit, "rotation", bit.rotation + randf_range(-8, 8), time)
		tween.chain().tween_callback(bit.queue_free)

func _show_level(level: int, fill: float) -> void:
	level_label.text = str(level)
	level_badge.level = level
	level_badge.progress = fill
	level_badge.queue_redraw()

func _celebrate_level(level: int, before: int, fill := 0.0) -> void:
	var banner := PanelContainer.new()
	var box := glass(32, GLASS_DEEP)
	box.border_color = Color(GOLD, 0.7)
	box.set_border_width_all(int(2 * s))
	box.content_margin_left = 34 * s; box.content_margin_right = 34 * s
	box.content_margin_top = 18 * s; box.content_margin_bottom = 22 * s
	banner.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(4 * s))
	var eyebrow := Label.new()
	eyebrow.text = "LEVEL UP"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", _spaced(BODY, 5))
	eyebrow.add_theme_font_size_override("font_size", int(14 * s))
	eyebrow.add_theme_color_override("font_color", GOLD)
	column.add_child(eyebrow)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", int(10 * s))
	head.add_child(_icon(icons["star"], 56))
	var title := _number(56)
	title.text = str(level)
	title.add_theme_color_override("font_color", IVORY)
	head.add_child(title)
	column.add_child(head)
	var unlocked := HBoxContainer.new()
	unlocked.alignment = BoxContainer.ALIGNMENT_CENTER
	unlocked.add_theme_constant_override("separation", int(10 * s))
	for kind in C.BUILD_ORDER:
		var gate: int = C.BUILDS[kind].gate
		if gate > before and gate <= level: unlocked.add_child(_socket(icons.get(kind), 64))
	for side in C.LAND:
		if C.LAND[side].gate > before and C.LAND[side].gate <= level: unlocked.add_child(_socket(icons.get(side), 64))
	if unlocked.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6 * s)
		column.add_child(gap)
		column.add_child(unlocked)
	# What woke up in the valley, so the world change has a name.
	for tier in HomesteadAwakening.woken(before, level).slice(-2):
		var line := Label.new()
		line.text = tier.line
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_override("font", DISPLAY_SEMI)
		line.add_theme_font_size_override("font_size", int(20 * s))
		line.add_theme_color_override("font_color", MINT)
		column.add_child(line)
	banner.add_child(column)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	fly_layer.add_child(banner)
	await get_tree().process_frame
	if not is_instance_valid(banner): return
	banner.position = Vector2((root.size.x - banner.size.x) / 2, root.size.y * 0.16)
	banner.pivot_offset = banner.size / 2
	sfx("tap", 0.7)  # a soft intake before the hit
	_level_impact(func():
		_show_level(level, fill)
		sfx("level_up")
		_confetti()
		_stamp_in(banner, title))
	var tween := create_tween()
	tween.tween_interval(2.6 + F.LEVEL_WINDUP_TIME)
	tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(banner.queue_free)

## The level badge winds up, the frame holds for an instant on impact with a
## warm flash and a heavy haptic, then the badge springs back. Display only:
## input keeps flowing through the hold, and Reduce Motion gets the haptic.
var hitstop_until := 0
func _level_impact(on_impact := Callable()) -> void:
	if reduce_motion:
		haptic(F.HAPTIC_BIG)
		if on_impact.is_valid(): on_impact.call()
		return
	var badge := level_badge
	badge.pivot_offset = badge.size / 2
	var tween := _solo_tween(badge, "bump").set_parallel()
	# Anticipation: the badge draws in while its ring charges to full.
	tween.tween_property(badge, "scale", Vector2.ONE * F.LEVEL_WINDUP_SCALE, F.LEVEL_WINDUP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(v: float):
		if is_instance_valid(badge): badge.progress = v; badge.queue_redraw(), badge.progress, 1.0, F.LEVEL_WINDUP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Impact, then a springy settle.
	tween.chain().tween_callback(func():
		haptic(F.HAPTIC_BIG)
		_flash()
		badge.scale = Vector2.ONE * F.LEVEL_PUNCH_SCALE
		if on_impact.is_valid(): on_impact.call()
		_hitstop(F.HITSTOP_TIME))
	tween.chain().tween_property(badge, "scale", Vector2.ONE, F.LEVEL_SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## The level banner lands like a stamp: in from larger, overshooting a touch
## and springing to rest, then its number pops. Reduce Motion fades it in.
func _stamp_in(banner: Control, number: Control) -> void:
	if not is_instance_valid(banner): return
	var tween := banner.create_tween().set_parallel()
	tween.tween_property(banner, "modulate:a", 1.0, F.LEVEL_BANNER_FADE if not reduce_motion else F.FADE_IN_TIME)
	if reduce_motion: return
	banner.scale = Vector2.ONE * F.LEVEL_BANNER_FROM
	tween.tween_property(banner, "scale", Vector2.ONE, F.LEVEL_BANNER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): if is_instance_valid(number): bump(number, F.LEVEL_NUMBER_BUMP))

## Freezes animation (not input) for `seconds` of real time.
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.0
	hitstop_until = Time.get_ticks_msec() + int(seconds * 1000)
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 0.94, 0.78, F.FLASH_ALPHA)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, F.FLASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)

## An icon sitting in a soft round well.
func _socket(texture: Texture2D, side: float, highlight := false) -> PanelContainer:
	var holder := PanelContainer.new()
	var box := tile_box(side / 2, highlight)
	box.set_content_margin_all(6 * s)
	holder.add_theme_stylebox_override("panel", box)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_icon(texture, side))
	return holder

func show_toast(text: String) -> void:
	toast.text = text
	toast_left = 2.2
	toast_box.reset_size()
	var viewport := root.get_viewport_rect().size
	toast_box.position = Vector2((viewport.x - toast_box.size.x) / 2, 84 * s)
	if not toast_box.visible:
		toast_box.visible = true
		pop_in(toast_box)

## A neighbour's words after a delivery: their name over the line, briefly.
var speech_box: Control
func show_speech(who: String, line: String) -> void:
	if is_instance_valid(speech_box): speech_box.queue_free()
	var bubble := PanelContainer.new()
	var box := glass(24, GLASS_DEEP)
	box.border_color = Color(GOLD, 0.55)
	box.set_border_width_all(int(2 * s))
	box.content_margin_left = 26 * s; box.content_margin_right = 26 * s
	box.content_margin_top = 12 * s; box.content_margin_bottom = 14 * s
	bubble.add_theme_stylebox_override("panel", box)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(2 * s))
	column.add_child(_eyebrow(who))
	var words := Label.new()
	words.text = "“%s”" % line
	words.add_theme_font_override("font", DISPLAY_SEMI)
	words.add_theme_font_size_override("font_size", int(20 * s))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = minf(520 * s, root.get_viewport_rect().size.x - 80 * s)
	column.add_child(words)
	bubble.add_child(column)
	fly_layer.add_child(bubble)
	speech_box = bubble
	await get_tree().process_frame
	if not is_instance_valid(bubble): return
	bubble.reset_size()
	# Along the bottom edge, clear of the wallet and the level-up banner.
	bubble.position = Vector2((root.size.x - bubble.size.x) / 2, root.size.y - safe.size.y - bubble.size.y - 18 * s)
	pop_in(bubble)
	var tween := bubble.create_tween()
	tween.tween_interval(F.SPEECH_TIME)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tween.tween_callback(bubble.queue_free)

func _process(delta: float) -> void:
	# A hit-stop can never outlive its moment, whatever happened to its timer.
	if Engine.time_scale != 1.0 and Time.get_ticks_msec() > hitstop_until: Engine.time_scale = 1.0
	# HUD clocks and chips tick a few times a second, not every frame; a mode
	# change (a box opening or closing) updates them at once.
	hud_wait -= delta
	var hud_state := [mode, title_layer == null]
	if hud_wait <= 0.0 or hud_state != hud_seen:
		hud_wait = F.HUD_TICK
		hud_seen = hud_state
		_hud_upkeep()
	if ambience and main and main.game:
		ambience.tick(delta, main.game.state.job_remaining("mill", main.game.now()) > 0)
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0: toast.text = ""; toast_box.visible = false

var hud_wait := 0.0
var hud_seen := []
func _hud_upkeep() -> void:
	_update_barge_chip()
	_update_weather()
	if is_instance_valid(season_clock) and main and main.game:
		var season: Dictionary = main.game.season()
		season_clock.text = _time(int(season.left))
		# A new window reprices everything on the stall.
		if int(season.window) != season_shown: refresh()

func refresh() -> void:
	hud_wait = 0.0  # chips follow a change on the next frame
	var game: WorldGame = main.game
	var coins := game.host.wallet()
	var level := game.host.progress()
	_count_to(coins)
	var bar := game.next_level_progress()
	var fill := float(bar.x) / bar.y if bar.y > 0 else 0.0
	# A new level turns the badge over on the impact beat, not before.
	if not (last_level >= 0 and level > last_level): _show_level(level, fill)
	var from := fly_from if fly_from.x >= 0 else root.get_viewport_rect().size / 2
	if ring and is_instance_valid(ring): from = ring.tray_global()
	if last_coins >= 0 and coins > last_coins:
		# Feedback scales with the gain: a coin or two is crisp and small,
		# a big sale lands heavier, louder and larger.
		var tier := reward_tier(coins - last_coins)
		sfx("coins", _combo_pitch())
		haptic(F.REWARD_HAPTIC[tier])
		fly(icons["coin"], from, coin_pill, F.REWARD_COINS[tier])
		float_text("+%d" % (coins - last_coins), from + Vector2(0, -50 * s), GOLD, F.REWARD_FONT[tier])
		if tier == 2:
			var pill := coin_pill
			get_tree().create_timer(F.FLY_TRAVEL_TIME + F.FLY_GROW_TIME).timeout.connect(func(): bump(pill, F.REWARD_BIG_BUMP))
	elif last_coins >= 0 and coins < last_coins: sfx("world_build_complete")
	if not last_stock.is_empty():
		var gained := false
		for good in game.state.stock:
			var diff: int = game.state.stock[good] - last_stock.get(good, 0)
			if diff > 0:
				gained = true
				fly(icons.get(good), from, market_button, diff)
				float_text("+%d" % diff, from + Vector2(0, -60 * s))
		if gained: sfx("world_harvest", _combo_pitch()); haptic(F.HAPTIC_REWARD)
		elif coins == last_coins and game.state.stock.hash() != last_stock.hash(): sfx("world_plant")
	last_stock = game.state.stock.duplicate()
	var stars := game.state.stars()
	roll(stars_label, stars)
	if last_stars >= 0 and stars > last_stars:
		fly(icons["star"], from, star_pill, mini(stars - last_stars, 5), 36)
		float_text("+%d" % (stars - last_stars), from + Vector2(0, -90 * s), GOLD, 28)
	elif last_stars >= 0 and stars < last_stars:
		bump(star_pill)
	last_stars = stars
	fly_from = Vector2(-1, -1)
	if last_level >= 0 and level > last_level: _celebrate_level(level, last_level, fill)
	var shipped: int = game.state.barges_filled
	if last_shipped >= 0 and shipped > last_shipped:
		_celebrate_barge(C.barge_bonus(game.state.barge.get("manifest", [])))
	last_shipped = shipped
	last_coins = coins
	last_level = level
	# The first look at the farm each day opens the gift once; after that it
	# waits on the goal ticket.
	if mode == "" and title_layer == null and game.gift_ready() and gift_offered_day != game.today():
		gift_offered_day = game.today()
		call_deferred("open", "gift")
	var goal := _goal()
	if goal[0] in ["seed", "water"]:
		goal_icon.texture = null
		for child in goal_icon.get_children(): child.queue_free()
		var tool := ToolIcon.new()
		tool.tool = goal[0]
		tool.set_anchors_preset(Control.PRESET_FULL_RECT)
		tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		goal_icon.add_child(tool)
	else:
		for child in goal_icon.get_children(): child.queue_free()
		goal_icon.texture = icons.get(goal[0], icons["star"])
	goal_label.text = goal[1]
	goal_action = goal[2]
	pointer_id = goal[3] if mode == "" and title_layer == null else ""
	if pointer_id == "": pointer.visible = false
	else: main.send("feedbackAnchor", {"id": pointer_id, "event": "goal"})
	goal_box.visible = mode == ""
	dock_node.visible = mode == ""
	if mode == "": return
	# Rebuild only when something visible changed; timers update in place.
	var next := _signature()
	if next != signature: _fill()
	elif ring: _update_ring()

func _signature() -> String:
	var game: WorldGame = main.game
	var st := game.state
	var now := game.now()
	var parts := [mode, place_id, station, recipe, build_pick, game.host.wallet(), game.host.progress(), JSON.stringify(st.stock), JSON.stringify(filled), st.land, st.items.size(), st.stars()]
	if mode == "place":
		parts.append(st.is_building(place_id, now))
		parts.append(st.jobs.has(station) and st.job_remaining(station, now) == 0)
		parts.append(st.jobs.has(station))
		for i in st.fields.size(): parts.append(st.field_stage(i, now))
		parts.append(st.orchard_watered >= 0 and st.orchard_remaining(now) == 0)
		parts.append(st.orchard_watered >= 0)
	if mode == "more":
		# Prices move with the season and as demand recovers.
		parts.append(game.season().window)
		for good in st.stock: if st.stock[good] > 0: parts.append(game.sell_price(good))
	return JSON.stringify(parts)

func open(next_mode: String, arg := "", arg_station := "") -> void:
	var was := mode
	mode = next_mode
	place_id = arg if next_mode == "place" else ""
	station = arg_station
	recipe = ""
	filled = {}
	build_pick = ""
	was_new = true
	if next_mode == "build" and was != "build": build_scroll = 0
	switching_place = was == "place" and next_mode == "place" and sheet_root != null
	if next_mode == "place":
		var item: Dictionary = main.game.state.find(place_id)
		var stations := C.stations_for(item.get("kind", ""))
		if station == "" and stations.size() == 1: station = stations[0]
		if station == "field": station = ""
	_fill()
	was_new = false
	goal_box.visible = false
	dock_node.visible = false
	if next_mode != "build": main.spot_preview({})
	panel_changed.emit(next_mode in ["place", "more", "land", "settings", "gift", "barge", "weather"])
	if next_mode == "barge": main.send("bargeFocus", {})
	if was == "" or was != next_mode: pass

func close() -> void:
	var was_place := mode == "barge"  # place windows never move the camera
	mode = ""
	place_id = ""
	build_pick = ""
	if sheet_root: _close_out(sheet_root); sheet_root = null
	ring = null
	main.spot_preview({})
	if was_place: main.camera({"mode": "arrival", "resetZoom": true})
	panel_changed.emit(false)
	goal_box.visible = true
	dock_node.visible = true

## The old copy of a rebuilt box lies over the new one and fades away. It
## takes no taps, and its scrim goes at once so the screen never darkens twice.
func _fade_out_old(old: Control) -> void:
	for child in old.get_children():
		if child is ColorRect: child.visible = false
	old.get_parent().move_child(old, -1)
	var tween := old.create_tween()
	tween.tween_property(old, "modulate:a", 0.0, F.REBUILD_FADE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(old.queue_free)

## The closed box shrinks and fades out instead of vanishing. It stops
## taking taps on the same frame, so the map is live at once.
func _close_out(holder: Control) -> void:
	if reduce_motion or not holder.is_inside_tree(): holder.queue_free(); return
	holder.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	var panel: Control = holder.get_meta("panel", holder)
	panel.pivot_offset = panel.size / 2
	var tween := holder.create_tween().set_parallel()
	tween.tween_property(panel, "scale", Vector2.ONE * F.CLOSE_TO_SCALE, F.CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(holder, "modulate:a", 0.0, F.CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(holder.queue_free)

func _act(result: String) -> void:
	filled = {}
	if result == "" and mode == "place": burst_at = Time.get_ticks_msec() / 1000.0
	main.after_action(result)
	if result != "":
		sfx("soft_fail")
		shake(last_pressed)

var last_pressed: Control
## An action that can't happen shakes the control that asked for it: a short
## side-to-side shiver that settles exactly where it started. Reduce Motion
## keeps only the sound and the toast.
func shake(control: Control) -> void:
	if reduce_motion or control == null or not is_instance_valid(control) or not control.is_inside_tree(): return
	var home: Vector2 = control.get_meta("shake_home", control.position)
	control.set_meta("shake_home", home)
	var tween := _solo_tween(control, "shake")
	for i in F.SHAKE_STEPS:
		var side := (1.0 if i % 2 == 0 else -1.0) * F.SHAKE_DISTANCE * s * (1.0 - float(i) / F.SHAKE_STEPS)
		tween.tween_property(control, "position:x", home.x + side, F.SHAKE_TIME / F.SHAKE_STEPS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "position:x", home.x, F.SHAKE_TIME / F.SHAKE_STEPS)
	tween.tween_callback(func(): if is_instance_valid(control): control.remove_meta("shake_home"))

var was_new := false

func _fill() -> void:
	signature = _signature()
	# A rebuilt box (a tab switch, a good dropped in, a job starting) fades
	# from its old look instead of snapping; a newly opened one pops below.
	var old_sheet: Control = null
	if sheet_root and not was_new and not reduce_motion and sheet_root.is_inside_tree():
		old_sheet = sheet_root
		old_sheet.propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	elif sheet_root: sheet_root.queue_free()
	sheet_root = null
	ring = null
	match mode:
		"place": _fill_place()
		"build": _fill_build()
		"more": _fill_more()
		"land": _fill_land()
		"settings": _fill_settings()
		"gift": _fill_gift()
		"barge": _fill_barge()
		"weather": _fill_weather()
	if old_sheet: _fade_out_old(old_sheet)
	# Switching straight from one place's card to another keeps the card
	# steady (no second pop) while the camera glides to the new place.
	if sheet_root and was_new and not switching_place:
		var target := sheet_root
		get_tree().process_frame.connect(func(): if is_instance_valid(target): pop_in(target), CONNECT_ONE_SHOT)

# --- place card --------------------------------------------------------------

func _well() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(8 * s))
	return box

func _framed(content: Control, width: float) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", frame_box(26))
	frame.custom_minimum_size = Vector2(width, 0) * s
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(content)
	return frame

func _good_tile(good: String, count_text: String, short := false, draggable := false, tap := Callable()) -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	var tile := GoodTile.new()
	tile.ui = self
	tile.good = good
	tile.draggable = draggable
	tile.texture = icons.get(good)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.custom_minimum_size = Vector2(64, 64) * s
	tile.mouse_filter = Control.MOUSE_FILTER_STOP if draggable or tap.is_valid() else Control.MOUSE_FILTER_IGNORE
	tile.tooltip_text = C.title(good)
	if tap.is_valid(): _press_card(tile)
	if tap.is_valid(): tile.gui_input.connect(func(e): if (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed): tap.call())
	column.add_child(tile)
	var label := Label.new()
	label.text = count_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DISPLAY_SEMI)
	label.add_theme_font_size_override("font_size", int(20 * s))
	label.add_theme_color_override("font_color", SHORT if short else IVORY)
	column.add_child(label)
	return column

## The production window: the map stays still and a framed window opens on the
## inside of the place. Products run along the top (each with its time and its
## price in stars to finish at once), what the chosen product needs waits on
## the left to be dragged into the scene, and one action sits below.
var tab_refs: Array = []   # {"time": Label, "star": Label, "target", "seconds", "recipe"}
var finish_button: Button
var need_sockets := {}  # good -> its socket on the left, where taps and returns start
var burst_at := -10.0   # a job just started or was collected: the machine kicks
var poke_at := -10.0    # a tap on a working place
var finish_price: Label
var star_pill: Control
var stars_label: Label
var last_stars := -1

func _target() -> String:
	var item: Dictionary = main.game.state.find(place_id)
	if item.get("kind", "") == "garden": return "field"
	if item.get("kind", "") == "orchard": return "orchard"
	return station

func _place_products(item: Dictionary) -> Array:
	var st: WorldState = main.game.state
	match item.kind:
		"garden":
			var grow := C.FIRST_FIELD_SECONDS if st.harvests == 0 else C.FIELD_SECONDS
			return [{"target": "field", "recipe": "", "output": "wheat", "quantity": C.FIELD_YIELD * st.fields.size(), "seconds": grow}]
		"orchard":
			return [{"target": "orchard", "recipe": "", "output": "fruit", "quantity": C.ORCHARD_YIELD, "seconds": C.ORCHARD_SECONDS}]
	var out := []
	for each in C.stations_for(item.kind):
		# A house with several places shows only the one that was opened.
		if _shared(item) and each != station: continue
		for id in C.recipes_for(each):
			var r: Dictionary = C.RECIPES[id]
			out.append({"target": each, "recipe": id, "output": r.output, "quantity": r.quantity, "seconds": float(r.seconds)})
	for p in out: p.twin = out.filter(func(o): return o.output == p.output).size() > 1
	return out

## The goods the field still needs this round: seeds for bare soil, water for
## anything planted and dry.
func _field_needs() -> Array:
	var st: WorldState = main.game.state
	var now: float = main.game.now()
	var stages := []
	for i in st.fields.size(): stages.append(st.field_stage(i, now))
	var needs := []
	if 0 in stages: needs.append("seed")
	if 0 in stages or 1 in stages: needs.append("water")
	return needs

func _needs() -> Array:
	var st: WorldState = main.game.state
	match _target():
		"field": return _field_needs()
		"orchard": return ["water"] if st.orchard_watered < 0 else []
		"": return []
	if st.jobs.has(station): return []
	return C.RECIPES[recipe].input.keys() if recipe != "" else []

static func _short_time(seconds: int) -> String:
	if seconds < 60: return "%ds" % seconds
	return "%dm" % (seconds / 60) if seconds % 60 == 0 else "%dm %ds" % [seconds / 60, seconds % 60]

func _production_window(title: String) -> Dictionary:
	var viewport := root.get_viewport_rect().size
	var top_room := 84 * s + safe.position.y
	var width := minf(920 * s, viewport.x - 32 * s - safe.position.x - safe.size.x)
	var height := minf(560 * s, viewport.y - top_room - 14 * s)
	var holder := Control.new()
	holder.size = viewport
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.05, 0.05, 0.5)
	scrim.position = -viewport * 0.1
	scrim.size = viewport * 1.2
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(scrim)
	var panel := PanelContainer.new()
	var box := glass(30, GLASS_DEEP)
	box.border_color = Color(GOLD, 0.42)
	box.set_content_margin_all(16 * s)
	box.content_margin_top = 26 * s
	box.shadow_size = int(30 * s)
	box.shadow_color = Color(0, 0, 0, 0.45)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(width, height)
	panel.size = panel.custom_minimum_size
	panel.position = Vector2((viewport.x - width) / 2, top_room + maxf(0, (viewport.y - top_room - 14 * s - height) / 2))
	holder.add_child(panel)
	holder.set_meta("panel", panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(12 * s))
	panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", int(10 * s))
	column.add_child(tabs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(14 * s))
	column.add_child(body)
	var needs_plate := PanelContainer.new()
	# A recessed well: darker than the card, lit only along its bottom lip.
	var plate_box := tile_box(24)
	plate_box.bg_color = RECESS
	plate_box.border_color = Color(1, 1, 1, RECESS_LIP)
	plate_box.set_border_width_all(0)
	plate_box.border_width_bottom = int(maxf(1, 1.5 * s))
	plate_box.set_content_margin_all(12 * s)
	needs_plate.add_theme_stylebox_override("panel", plate_box)
	needs_plate.custom_minimum_size = Vector2(138 * s, 0)
	body.add_child(needs_plate)
	var needs := VBoxContainer.new()
	needs.alignment = BoxContainer.ALIGNMENT_CENTER
	needs.add_theme_constant_override("separation", int(12 * s))
	needs_plate.add_child(needs)
	# The scene sits in a rounded window that clips it; a gold hairline rim on top.
	var frame := Panel.new()
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0.1, 0.07, 0.05)
	frame_box.set_corner_radius_all(int(22 * s))
	frame_box.anti_aliasing_size = 0.8
	frame.add_theme_stylebox_override("panel", frame_box)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(320, 210) * s
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(frame)
	var scene := ProductionScene.new()
	scene.ui = self
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(scene)
	var rim := Panel.new()
	var rim_box := StyleBoxFlat.new()
	rim_box.bg_color = Color(0, 0, 0, 0)
	rim_box.set_corner_radius_all(int(22 * s))
	rim_box.border_color = Color(GOLD, 0.55)
	rim_box.set_border_width_all(int(maxf(1, 2 * s)))
	rim_box.shadow_color = Color(0, 0, 0, 0)
	rim_box.anti_aliasing_size = 0.8
	rim.add_theme_stylebox_override("panel", rim_box)
	rim.set_anchors_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rim)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", int(12 * s))
	column.add_child(actions)
	var close_button := _close_button()
	close_button.position = panel.position + Vector2(width - 30 * s, -16 * s)
	holder.add_child(close_button)
	var ribbon := Ribbon.new()
	ribbon.ui = self
	ribbon.text = title
	var ribbon_width := DISPLAY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x + 92 * s
	ribbon.size = Vector2(ribbon_width, 44 * s)
	ribbon.position = panel.position + Vector2((width - ribbon_width) / 2, -24 * s)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ribbon)
	root.add_child(holder)
	root.move_child(wallet_node, -1)
	root.move_child(toast_box, -1)
	sheet_root = holder
	ring = scene
	return {"tabs": tabs, "needs": needs, "scene": scene, "actions": actions}

## A product along the top: its picture and yield, its time, and its price in
## stars to make at once.
func _product_tab(product: Dictionary, selected: bool, busy: bool) -> Control:
	var tab := PanelContainer.new()
	var box := tile_box(20, selected)
	box.content_margin_left = 14 * s; box.content_margin_right = 14 * s
	box.content_margin_top = 8 * s; box.content_margin_bottom = 8 * s
	if not selected:
		box.bg_color = TAB_FILL
		box.border_color = TAB_EDGE
	elif not reduce_motion:
		# The chosen tab's gold edge breathes, so the eye finds it.
		var breath := tab.create_tween().set_loops()
		breath.tween_property(box, "border_color", Color(GOLD, 0.55), TAB_BREATH / 2).set_trans(Tween.TRANS_SINE)
		breath.tween_property(box, "border_color", GOLD, TAB_BREATH / 2).set_trans(Tween.TRANS_SINE)
	tab.add_theme_stylebox_override("panel", box)
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.tooltip_text = C.title(product.output)
	if busy and not selected: tab.modulate.a = TAB_BUSY_ALPHA
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * s))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(row)
	var picture := Control.new()
	picture.custom_minimum_size = Vector2(52, 52) * s
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := _icon(icons.get(product.output), 52)
	picture.add_child(art)
	var yield_label := Label.new()
	yield_label.text = "×%d" % product.quantity
	yield_label.add_theme_font_override("font", DISPLAY)
	yield_label.add_theme_font_size_override("font_size", int(15 * s))
	yield_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	yield_label.add_theme_constant_override("outline_size", int(5 * s))
	yield_label.position = Vector2(30, 30) * s
	picture.add_child(yield_label)
	if product.recipe != "" and product.get("twin", false):
		# Two products share a picture (bread, meals): a small badge names what
		# makes this one different.
		var inputs: Array = C.RECIPES[product.recipe].input.keys()
		if not inputs.is_empty():
			var badge := _icon(icons.get(inputs[-1]), 24)
			badge.position = Vector2(-6, -4) * s
			picture.add_child(badge)
	row.add_child(picture)
	var facts := VBoxContainer.new()
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	facts.add_theme_constant_override("separation", int(2 * s))
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(facts)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", int(6 * s))
	var clock := ClockIcon.new()
	clock.custom_minimum_size = Vector2(18, 18) * s
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_row.add_child(clock)
	var time_label := Label.new()
	time_label.add_theme_font_override("font", DISPLAY_SEMI)
	time_label.add_theme_font_size_override("font_size", int(17 * s))
	time_row.add_child(time_label)
	facts.add_child(time_row)
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", int(6 * s))
	var star := _icon(icons["star"], 18)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star_row.add_child(star)
	var star_label := Label.new()
	star_label.add_theme_font_override("font", DISPLAY_SEMI)
	star_label.add_theme_font_size_override("font_size", int(17 * s))
	star_label.add_theme_color_override("font_color", GOLD)
	star_row.add_child(star_label)
	facts.add_child(star_row)
	tab_refs.append({"time": time_label, "star": star_label, "clock": clock, "target": product.target, "seconds": product.seconds, "recipe": product.recipe})
	_press_card(tab)
	tab.gui_input.connect(func(e):
		var up: bool = (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed)
		if not up or selected: return
		var st: WorldState = main.game.state
		if st.jobs.has(product.target) and st.jobs[product.target].recipe != product.recipe: show_toast("Already making something"); return
		sfx("tap"); haptic()
		station = product.target if C.STATIONS.has(product.target) else station
		recipe = product.recipe
		filled = {}
		_fill())
	return tab

## One good the chosen product needs, ready to drag into the scene.
func _need_slot(good: String, text: String, state: String) -> Control:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(2 * s))
	var socket := PanelContainer.new()
	var box := tile_box(20, state == "ready")
	box.set_content_margin_all(6 * s)
	if state == "filled": box.border_color = MINT; box.bg_color = Color(MINT, 0.14)
	if state == "short": box.border_color = Color(SHORT, 0.8)
	socket.add_theme_stylebox_override("panel", box)
	socket.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var draggable := state == "ready"
	var tap := func(): if state == "short": _open_source(good) elif state == "ready": _ring_dropped(good)
	if good in ["seed", "water"]:
		var tool := DragTool.new()
		tool.ui = self
		tool.tool = good
		tool.draggable = draggable
		tool.custom_minimum_size = Vector2(60, 60) * s
		tool.tooltip_text = "Seeds" if good == "seed" else "Water"
		tool.mouse_filter = Control.MOUSE_FILTER_STOP
		_press_card(tool)
		tool.gui_input.connect(func(e): if (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed): tap.call())
		socket.add_child(tool)
	else:
		var tile := GoodTile.new()
		tile.ui = self
		tile.good = good
		tile.draggable = draggable
		tile.texture = icons.get(good)
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.custom_minimum_size = Vector2(60, 60) * s
		tile.tooltip_text = C.title(good)
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		_press_card(tile)
		tile.gui_input.connect(func(e): if (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed): tap.call())
		socket.add_child(tile)
	if state == "used": socket.modulate.a = 0.45
	need_sockets[good] = socket
	column.add_child(socket)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", DISPLAY_SEMI)
	label.add_theme_font_size_override("font_size", int(18 * s))
	label.add_theme_color_override("font_color", {"short": SHORT, "filled": MINT, "used": MUTED}.get(state, IVORY))
	column.add_child(label)
	if draggable and not reduce_motion:
		# A ready good leans toward the scene now and then: drag me in.
		var tween := socket.create_tween().set_loops()
		tween.tween_interval(1.6)
		tween.tween_property(socket, "position:x", socket.position.x + 6 * s, 0.22).set_trans(Tween.TRANS_SINE)
		tween.tween_property(socket, "position:x", socket.position.x, 0.3).set_trans(Tween.TRANS_SINE)
	return column

func _fill_place() -> void:
	var game: WorldGame = main.game
	var st := game.state
	var item := st.find(place_id)
	if item.is_empty(): close(); return
	var now := game.now()
	tab_refs = []
	finish_button = null
	need_sockets = {}
	var products := _place_products(item)
	if products.is_empty() and not st.is_building(place_id, now):
		_fill_quiet_place(item)
		return
	# A running job picks its own tab; otherwise the first product that can start.
	if C.STATIONS.has(station) and st.jobs.has(station): recipe = st.jobs[station].recipe
	elif not products.is_empty() and (recipe == "" or products.filter(func(p): return p.recipe == recipe).is_empty()):
		recipe = products[0].recipe
		for p in products:
			if p.recipe != "" and p.target == station and _have_all(p.recipe) and not st.jobs.has(p.target): recipe = p.recipe; break
	var parts := _production_window(C.title(station) if _shared(item) else C.title(item.kind))
	var tabs: HBoxContainer = parts.tabs
	var needs: VBoxContainer = parts.needs
	var scene: ProductionScene = parts.scene
	var actions: HBoxContainer = parts.actions
	scene.tapped.connect(_ring_tapped)
	scene.dropped.connect(_ring_dropped)
	var target := _target()
	if st.is_building(place_id, now):
		scene.kind = "build"
		needs.add_child(_icon(icons["hammer"], 64))
		var wait := _button("Building", func(): pass, false)
		wait.custom_minimum_size = Vector2(190, 52) * s
		actions.add_child(wait)
		_update_ring()
		return
	for p in products:
		tabs.add_child(_product_tab(p, p.recipe == recipe and p.target == target, st.jobs.has(p.target)))
	var spec: Dictionary = C.RECIPES.get(recipe, {})
	scene.kind = target
	scene.output = products.filter(func(p): return p.recipe == recipe)[0].output if not products.filter(func(p): return p.recipe == recipe).is_empty() else ""
	scene.quantity = int(spec.get("quantity", products[0].quantity))
	var need_list := _needs()
	scene.filled = filled.duplicate()
	var primary: Button
	match target:
		"field":
			var ripe := _any_field(4)
			var growing := _any_field(2) or _any_field(3)
			for tool in ["seed", "water"]:
				var state := "filled" if filled.get(tool, false) else ("ready" if tool in need_list else "used")
				needs.add_child(_need_slot(tool, "✓" if state != "ready" else "", state))
			scene.inputs = need_list
			if ripe: primary = _button("Harvest", _tend_all, true, "wheat")
			elif not need_list.is_empty(): primary = _button("Plant", _plant_and_water, true)
			else: primary = _button("Growing", func(): pass, false)
			scene.working = growing and not ripe
			scene.done = ripe
		"orchard":
			var dry := st.orchard_watered < 0
			var ripe := not dry and st.orchard_remaining(now) == 0
			needs.add_child(_need_slot("water", "" if dry and not filled.get("water", false) else "✓", "ready" if dry else "used"))
			scene.inputs = ["water"] if dry else []
			primary = _button("Water" if dry else ("Pick" if ripe else "Growing"), func(): _act(main.game.tend_orchard()), dry or ripe, "fruit" if ripe else "")
			scene.working = not dry and not ripe
			scene.done = ripe
		_:
			var working := st.jobs.has(station)
			for good in spec.input:
				var need: int = spec.input[good]
				var have: int = st.stock[good]
				var state := "used" if working else ("filled" if filled.get(good, false) else ("ready" if have >= need else "short"))
				needs.add_child(_need_slot(good, "✓" if state in ["filled", "used"] else "%d/%d" % [mini(have, need), need], state))
			if spec.input.is_empty():
				# Nothing to bring: the place makes it from sun and time alone.
				var sun := WeatherIcon.new()
				sun.sky = "sunny"
				sun.custom_minimum_size = Vector2(64, 64) * s
				sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sun.tooltip_text = "Needs nothing"
				needs.add_child(sun)
			scene.inputs = spec.input.keys()
			var done := working and st.job_remaining(station, now) == 0
			if working: primary = _button("Collect" if done else "Working", func(): _act(main.game.collect(station)), done, spec.output if done else "")
			else: primary = _button("Make", func(): _act(main.game.make(recipe)), _have_all(recipe), spec.output)
			scene.working = working and not done
			scene.done = done
	primary.custom_minimum_size = Vector2(190, 52) * s
	actions.add_child(primary)
	# Stars finish the job at once: a running timer, or a fresh one start to end.
	if not scene.done:
		finish_button = _button("", _instant, false, "", true)
		var finish_box: StyleBoxFlat = finish_button.get_theme_stylebox("normal").duplicate()
		finish_box.border_color = Color(GOLD, 0.8)
		finish_box.set_border_width_all(int(maxf(1, 2 * s)))
		finish_button.add_theme_stylebox_override("normal", finish_box)
		finish_button.add_theme_stylebox_override("hover", finish_box)
		finish_button.custom_minimum_size = Vector2(190, 52) * s
		# Star, price, words: laid out by hand so the star reads at full size.
		var finish_row := HBoxContainer.new()
		finish_row.set_anchors_preset(Control.PRESET_FULL_RECT)
		finish_row.alignment = BoxContainer.ALIGNMENT_CENTER
		finish_row.add_theme_constant_override("separation", int(8 * s))
		finish_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var finish_star := _icon(icons["star"], 26)
		finish_star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		finish_row.add_child(finish_star)
		finish_price = _number(22)
		finish_price.add_theme_color_override("font_color", GOLD)
		finish_row.add_child(finish_price)
		var finish_words := Label.new()
		finish_words.text = "Finish now"
		finish_words.add_theme_font_override("font", DISPLAY_SEMI)
		finish_words.add_theme_font_size_override("font_size", int(19 * s))
		finish_row.add_child(finish_words)
		finish_button.add_child(finish_row)
		actions.add_child(finish_button)
	var badge := _weather_badge(target)
	if badge: actions.add_child(badge)
	_update_ring()

## Places that make nothing: their picture in the same window, and Close.
func _fill_quiet_place(item: Dictionary) -> void:
	var parts := _production_window(C.title(item.kind))
	var panel: Control = sheet_root.get_meta("panel")
	panel.custom_minimum_size = Vector2(minf(520 * s, panel.custom_minimum_size.x), minf(420 * s, panel.custom_minimum_size.y))
	panel.size = panel.custom_minimum_size
	var viewport := root.get_viewport_rect().size
	panel.position = (viewport - panel.size) / 2 + Vector2(0, 30 * s)
	for child in sheet_root.get_children():
		if child is Ribbon: child.position = panel.position + Vector2((panel.size.x - child.size.x) / 2, -24 * s)
		elif child is Button: child.position = panel.position + Vector2(panel.size.x - 30 * s, -16 * s)
	var body: Control = (parts.needs as Control).get_parent().get_parent()
	for child in body.get_children(): child.queue_free()
	ring = null
	var picture := _icon(icons.get(item.kind, icons["star"]), 240)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(picture)
	if _shared(item):
		# The house's own card points at its places instead of opening one.
		for each in C.stations_for(item.kind):
			var go := _button(C.title(each), func(): open("place", place_id, each))
			go.custom_minimum_size = Vector2(190, 52) * s
			(parts.actions as HBoxContainer).add_child(go)
		return
	var done := _button("Close", close)
	done.custom_minimum_size = Vector2(170, 52) * s
	(parts.actions as HBoxContainer).add_child(done)

## True for a place that holds more than one workplace (the cottage's oven
## and kitchen bench), each with its own card.
static func _shared(item: Dictionary) -> bool:
	return C.stations_for(item.get("kind", "")).size() > 1

func _update_ring() -> void:
	if not ring or not is_instance_valid(ring): return
	var game: WorldGame = main.game
	var st := game.state
	var now := game.now()
	var item := st.find(place_id)
	if item.is_empty(): return
	var scene: ProductionScene = ring
	scene.progress = -1.0
	scene.label = ""
	if st.is_building(place_id, now):
		var c: Dictionary = st.construction[place_id]
		scene.progress = clampf((now - c.started) / c.seconds, 0, 1)
		scene.label = _time(ceili(c.started + c.seconds - now))
		return
	var target := _target()
	var left := st.rush_left(target, now)
	if target == "field":
		scene.stages = []
		for i in st.fields.size(): scene.stages.append(st.field_stage(i, now))
		if left > 0: scene.progress = clampf(1.0 - left / st.field_total(0), 0, 1)
	elif target == "orchard":
		if left > 0: scene.progress = clampf(1.0 - left / st.orchard_grow, 0, 1)
	elif st.jobs.has(station) and left > 0:
		scene.progress = clampf(1.0 - float(left) / st.job_total(station), 0, 1)
	if left > 0: scene.label = _time(left)
	# Tabs: a running product counts down; the rest show their full time.
	for ref in tab_refs:
		var running: bool = st.rush_left(ref.target, now) > 0 and (ref.recipe == "" or st.jobs.get(ref.target, {}).get("recipe", "") == ref.recipe)
		var seconds: int = st.rush_left(ref.target, now) if running else C.duration(ref.seconds / game.weather_boost(ref.target))
		(ref.time as Label).text = _time(seconds) if running else _short_time(seconds)
		(ref.time as Label).add_theme_color_override("font_color", MINT if running else IVORY)
		(ref.clock as ClockIcon).share = clampf(1.0 - float(seconds) / maxf(1.0, C.duration(ref.seconds)), 0, 1) if running else 1.0
		(ref.clock as ClockIcon).queue_redraw()
		(ref.star as Label).text = str(game.rush_price(ref.target, 0.0 if running else ref.seconds))
	if finish_button and is_instance_valid(finish_button):
		var price := _instant_price()
		finish_price.text = str(price)
		finish_button.disabled = price <= 0 or st.stars() < price or not _can_instant()
		finish_button.modulate.a = 0.45 if finish_button.disabled else 1.0
		finish_button.tooltip_text = "Not enough stars" if st.stars() < price else "Make it now with stars"

func _instant_price() -> int:
	var game: WorldGame = main.game
	var target := _target()
	if game.state.rush_left(target, game.now()) > 0: return game.rush_price(target)
	var p := _place_products(game.state.find(place_id)).filter(func(p): return p.target == target and p.recipe == recipe)
	return game.rush_price(target, p[0].seconds) if not p.is_empty() else 0

## Whether stars can finish this product now: a running timer, or one that
## could start with what the farm has.
func _can_instant() -> bool:
	var st: WorldState = main.game.state
	var now: float = main.game.now()
	var target := _target()
	if st.rush_left(target, now) > 0: return true
	match target:
		"field": return not _field_needs().is_empty()
		"orchard": return st.orchard_watered < 0
		"": return false
	return not st.jobs.has(station) and _have_all(recipe)

## Stars make it now: start it if needed, finish the timer, collect. Each step
## is its own saved action and stops at the first that fails.
func _instant() -> void:
	var game: WorldGame = main.game
	var target := _target()
	var price := _instant_price()
	if game.state.stars() < price: show_toast("Not enough stars"); return
	var result := ""
	var now := game.now()
	match target:
		"field":
			if game.state.rush_left("field", now) <= 0: result = _plant_and_water_result()
			if result == "": result = game.rush("field")
			if result == "":
				for i in game.state.fields.size():
					if game.state.field_stage(i, game.now()) == 4:
						result = game.tend(i)
						if result != "": break
		"orchard":
			if game.state.orchard_watered < 0: result = game.tend_orchard()
			if result == "": result = game.rush("orchard")
			if result == "": result = game.tend_orchard()
		_:
			if not game.state.jobs.has(station): result = game.make(recipe)
			if result == "": result = game.rush(station)
			if result == "": result = game.collect(station)
	if result == "" and star_pill and ring:
		# The stars leave the purse for the scene before the goods fly home.
		_spend_fx()
	_act(result)

func _spend_fx() -> void:
	sfx("world_build_complete", 1.2)
	haptic(F.HAPTIC_REWARD)
	if reduce_motion or not is_instance_valid(ring): return
	fly(icons["star"], star_pill.get_global_rect().get_center(), ring, 3, 34)
	var scene: Control = ring
	get_tree().create_timer(F.FLY_TRAVEL_TIME).timeout.connect(func(): if is_instance_valid(scene): bump(scene, F.SLOT_PUNCH))

func _plant_and_water() -> void: _act(_plant_and_water_result())
## Plants every bare field, then waters every planted one.
func _plant_and_water_result() -> String:
	var game: WorldGame = main.game
	for pass_stage in [0, 1]:
		for i in game.state.fields.size():
			if game.state.field_stage(i, game.now()) == pass_stage:
				var result := game.tend(i)
				if result != "": return result
	return ""

func _any_field(stage: int) -> bool:
	var st: WorldState = main.game.state
	for i in st.fields.size():
		if st.field_stage(i, main.game.now()) == stage: return true
	return false

static func _time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

func _tend_all() -> void:
	var game: WorldGame = main.game
	var now := game.now()
	var stages := []
	for i in game.state.fields.size(): stages.append(game.state.field_stage(i, now))
	var target := 4 if 4 in stages else (0 if 0 in stages else (1 if 1 in stages else -1))
	if target < 0: show_toast("Still growing"); return
	if target in [0, 1]: _plant_and_water(); return
	var result := ""
	for i in stages.size():
		if stages[i] == target:
			result = game.tend(i)
			if result != "": break
	_act(result)

func _have_all(id: String) -> bool:
	var spec: Dictionary = C.RECIPES[id]
	for good in spec.input:
		if main.game.state.stock[good] < spec.input[good]: return false
	return true

func _ring_tapped() -> void:
	var game: WorldGame = main.game
	var st := game.state
	var item := st.find(place_id)
	if item.is_empty() or st.is_building(place_id, game.now()): return
	var target := _target()
	if st.rush_left(target, game.now()) > 0:
		# A working place answers a tap: the machine kicks and throws sparks.
		poke_at = Time.get_ticks_msec() / 1000.0
		sfx("place_set", 1.3 + randf() * 0.2)
		haptic(F.HAPTIC_TAP)
		return
	if item.kind == "garden": _tend_all(); return
	if item.kind == "orchard": _act(game.tend_orchard()); return
	if station == "": return
	if st.jobs.has(station): _act(game.collect(station))
	elif _have_all(recipe): _act(game.make(recipe))
	else: show_toast("Not enough yet")

## Dropping (or tapping) a good fills its slot; the last one starts the job.
## The field takes seeds and water the same way.
var landed := {}  # good -> when it landed in the scene (display only)
func _ring_dropped(good: String) -> void:
	var st: WorldState = main.game.state
	var target := _target()
	var wanted: Array = _needs()
	if not good in wanted: return
	if C.STATIONS.has(target):
		if recipe == "" or st.jobs.has(station) or st.stock[good] < C.RECIPES[recipe].input[good]: return
	filled[good] = true
	var now_s := Time.get_ticks_msec() / 1000.0
	if now_s - float(landed.get(good, {}).get("at", -10.0)) > 0.25:
		var socket: Control = need_sockets.get(good)
		landed[good] = {"at": now_s, "from": socket.get_global_rect().get_center() if is_instance_valid(socket) else Vector2(-1, -1)}
	for g in wanted:
		if not filled.get(g, false):
			_fill()
			# The good lands in the scene: a crisp punch and a tick that climbs
			# in pitch as the slots fill. Display only.
			sfx("place_set", 1.0 + F.SLOT_PITCH_STEP * filled.size())
			haptic(F.HAPTIC_TAP)
			_punch_scene()
			return
	match target:
		"field": _plant_and_water()
		"orchard": _act(main.game.tend_orchard())
		_: _act(main.game.make(recipe))

## A good that wasn't taken drifts back to its socket.
func fly_back(texture: Texture2D, tool: String, from: Vector2, socket: Control) -> void:
	sfx("soft_fail")
	if reduce_motion or not is_instance_valid(socket): return
	var sprite: Control
	if texture: sprite = _icon(texture, 64)
	else:
		var t := ToolIcon.new(); t.tool = tool; sprite = t
	sprite.size = socket.size
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.position = from - sprite.size / 2
	sprite.pivot_offset = sprite.size / 2
	fly_layer.add_child(sprite)
	var to := socket.get_global_rect().get_center() - sprite.size / 2
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", to, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.32).from(0.3)
	tween.tween_callback(sprite.queue_free)
	tween.tween_callback(func(): if is_instance_valid(socket): bump(socket))

func reject_drop(good: String, at: Vector2) -> void:
	var socket: Control = need_sockets.get(good)
	fly_back(icons.get(good), good if good in ["seed", "water"] else "", at, socket)
	show_toast("Not needed here" if not filled.get(good, false) else "Already in")

func _punch_scene() -> void:
	if ring and is_instance_valid(ring): bump(ring.get_parent() as Control, F.SLOT_PUNCH)

func _open_source(good: String) -> void:
	var sources := {"wheat": "garden", "fruit": "orchard"}
	var kind: String = sources.get(good, "")
	var target_station := ""
	for id in C.RECIPES:
		if C.RECIPES[id].output == good: target_station = C.RECIPES[id].station; break
	if kind == "" and target_station != "": kind = C.STATIONS[target_station]
	var item: Dictionary = main.game.state.first_of(kind)
	if item.is_empty():
		show_toast("Build a %s first" % C.title(kind).to_lower())
		return
	open("place", item.id, target_station)

# --- build tray ---------------------------------------------------------------

func _fill_build() -> void:
	var game: WorldGame = main.game
	var viewport := root.get_viewport_rect().size
	var tray := PanelContainer.new()
	var dock := glass(30)
	dock.set_content_margin_all(12 * s)
	tray.add_theme_stylebox_override("panel", dock)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(10 * s))
	tray.add_child(column)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Build"
	title.add_theme_font_override("font", DISPLAY)
	title.add_theme_font_size_override("font_size", int(24 * s))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if build_pick != "":
		var spec: Dictionary = C.LAND[build_pick] if C.LAND.has(build_pick) else C.BUILDS[build_pick]
		var picked := Label.new()
		picked.text = C.title(build_pick)
		picked.add_theme_font_override("font", DISPLAY_SEMI)
		picked.add_theme_font_size_override("font_size", int(18 * s))
		picked.add_theme_color_override("font_color", MUTED)
		picked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(picked)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(12, 0) * s
		head.add_child(gap)
		head.add_child(_button("Cancel", func(): build_pick = ""; main.spot_preview({}); main.land_preview(""); _fill(), true, "", true))
		var buy := _button("Build  %d" % spec.price, _confirm_build, game.host.wallet() >= int(spec.price), "coin")
		buy.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		buy.custom_minimum_size = Vector2(160, 50) * s
		head.add_child(buy)
	var close_button := _close_button()
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(10, 0) * s
	head.add_child(gap2)
	head.add_child(close_button)
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(viewport.x - 56 * s - safe.position.x - safe.size.x, 1220 * s), 146 * s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * s))
	scroll.add_child(row)
	column.add_child(scroll)
	var level := game.host.progress()
	for entry in _build_entries(level): row.add_child(_build_tile(entry.key, entry.spec, entry.blocker))
	# Keep the tray where the player left it when picking redraws it.
	scroll.scroll_deadzone = int(10 * s)
	scroll.set_deferred("scroll_horizontal", build_scroll)
	scroll.get_h_scroll_bar().value_changed.connect(func(v: float): build_scroll = int(v))
	tray.reset_size()
	root.add_child(tray)
	tray.position = Vector2(14 * s + safe.position.x, viewport.y - tray.get_combined_minimum_size().y - 16 * s - safe.size.y)
	sheet_root = tray

## The Build tray's order: what can be built now first, then decorations, then
## the next unlocks by level, and finished places last, so the tray opens on
## what's new instead of a row of ticks.
const BUILD_GROUPS := {"": 0, "decor": 1, "locked": 2, "land": 3, "full": 4, "owned": 5}
func _build_entries(level: int) -> Array:
	var game: WorldGame = main.game
	var entries := []
	var keys: Array = C.BUILD_ORDER.duplicate()
	for side in C.LAND: keys.append(side)
	for i in keys.size():
		var key: String = keys[i]
		var is_land: bool = C.LAND.has(key)
		var spec: Dictionary = C.LAND[key] if is_land else C.BUILDS[key]
		var blocker := ""
		if is_land: blocker = "owned" if key in game.state.land else ("locked" if level < spec.gate else "")
		else: blocker = game.state.build_blocker(key, level)
		var group: int = BUILD_GROUPS["decor"] if blocker == "" and key in ["flowers", "bench", "rocks"] else BUILD_GROUPS.get(blocker, 4)
		entries.append({"key": key, "spec": spec, "blocker": blocker, "rank": [group, int(spec.gate) if blocker == "locked" else 0, i]})
	entries.sort_custom(func(a, b): return a.rank < b.rank)
	return entries

func _build_tile(key: String, spec: Dictionary, blocker: String) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	# Pass drags up so a finger can scroll the tray across the tiles.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.custom_minimum_size = Vector2(118, 144) * s
	button.tooltip_text = C.title(key)
	var picked := key == build_pick
	var box := tile_box(22, picked)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]: button.add_theme_stylebox_override(state, box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(0 * s))
	var picture := _icon(icons.get(key, icons["build"]), 76)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var dim := blocker in ["locked", "land", "full", "owned"]
	if dim: picture.modulate = Color(1, 1, 1, 0.4)
	if blocker == "locked":
		var lock := Padlock.new()
		lock.size = Vector2(30, 30) * s
		lock.position = Vector2(50, 46) * s
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.add_child(lock)
	column.add_child(picture)
	var name_label := Label.new()
	name_label.text = C.title(key)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(104, 0) * s
	name_label.add_theme_font_size_override("font_size", int(13 * s))
	name_label.add_theme_color_override("font_color", MUTED if dim else IVORY)
	column.add_child(name_label)
	var tag := HBoxContainer.new()
	tag.alignment = BoxContainer.ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_constant_override("separation", int(4 * s))
	var label := _number(18)
	match blocker:
		"owned": label.text = "✓"; label.add_theme_color_override("font_color", MINT)
		"locked": tag.add_child(_icon(icons["star"], 18)); label.text = "Lv %d" % spec.gate; label.add_theme_color_override("font_color", MUTED)
		"land": tag.add_child(_icon(icons["west"], 20)); label.text = ""
		"full": label.text = "—"
		_: tag.add_child(_icon(icons["coin"], 20)); label.text = str(spec.price); label.add_theme_color_override("font_color", GOLD if main.game.host.wallet() >= int(spec.price) else SHORT)
	tag.add_child(label)
	column.add_child(tag)
	button.add_child(column)
	# A finger that scrolled the tray isn't a pick.
	var down_at := [0]
	button.button_down.connect(func(): down_at[0] = build_scroll)
	button.pressed.connect(func(): if absi(build_scroll - down_at[0]) < int(6 * s): _pick_build(key, blocker))
	_juice(button)
	return button

func _pick_build(key: String, blocker: String) -> void:
	var game: WorldGame = main.game
	match blocker:
		"owned": show_toast("Already built"); return
		"locked": show_toast("Reach level %d" % (C.LAND[key].gate if C.LAND.has(key) else C.BUILDS[key].gate)); return
		"land": show_toast("Needs the %s" % C.title(C.BUILDS[key].land).to_lower()); return
		"full": show_toast("No free spot"); return
	build_pick = key
	if C.LAND.has(key):
		main.land_preview(key)
	else:
		var cell: Vector2i = game.state.free_spot(key)
		var size := HomesteadItems.footprint(key, 0)
		main.spot_preview({"cell": {"x": cell.x, "z": cell.y}, "w": size.x, "d": size.y, "kind": key})
	_fill()

func _confirm_build() -> void:
	var key := build_pick
	var result: String = main.game.buy_land(key) if C.LAND.has(key) else main.game.build(key)
	build_pick = ""
	main.spot_preview({})
	main.land_preview("")
	if result == "": close()
	_act(result)

# --- more: warehouse and market ----------------------------------------------

func _sheet(title: String) -> VBoxContainer:
	var viewport := root.get_viewport_rect().size
	var sheet := PanelContainer.new()
	var sheet_box := glass(30, GLASS_DEEP)
	sheet_box.content_margin_left = 24 * s; sheet_box.content_margin_right = 18 * s
	sheet_box.content_margin_top = 16 * s; sheet_box.content_margin_bottom = 22 * s
	sheet.add_theme_stylebox_override("panel", sheet_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(12 * s))
	sheet.add_child(column)
	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_override("font", DISPLAY)
	name_label.add_theme_font_size_override("font_size", int(32 * s))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(_close_button())
	column.add_child(head)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.05, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	holder.add_child(centre)
	centre.add_child(sheet)
	root.add_child(holder)
	root.move_child(wallet_node, -1)
	holder.set_meta("panel", sheet)  # the visible box; the rest of the holder is outside it
	sheet_root = holder
	sheet.custom_minimum_size = Vector2(minf(660 * s, viewport.x - 40 * s), 0)
	return column

## The daily gift: the week's trail of baskets with today's lifted, and one
## Collect. Closing keeps the gift waiting on the goal ticket.
## Rowan's Barge: when it's in, what it wants and what a full hold pays. A
## status strip, then one paper crate per manifest line with its own Load
## button, then the whole hold's progress. While the barge is away the next
## manifest shows, so the next load can be planned.
func _fill_barge() -> void:
	var game: WorldGame = main.game
	var info: Dictionary = game.barge()
	if info.is_empty():
		close.call_deferred()
		return
	barge_shown = {"docked": info.docked, "cycle": info.cycle, "loaded": info.loaded}
	var column := _sheet("Rowan's Barge")
	# Sit the screen low so the boat stays in view above it.
	var centre: Control = sheet_root.get_child(1)
	centre.offset_top = minf(170 * s, root.get_viewport_rect().size.y * 0.22)
	# Status: in or away, the clock, and the full-load bonus.
	var strip := PanelContainer.new()
	var strip_box := tile_box(20, info.docked)
	strip_box.set_content_margin_all(10 * s)
	strip.add_theme_stylebox_override("panel", strip_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(14 * s))
	var boat := BoatIcon.new()
	boat.muted = not info.docked
	boat.custom_minimum_size = Vector2(58, 58) * s
	boat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(boat)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", int(-2 * s))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_eyebrow("Docked at the cove" if info.docked else ("Shipped · on the river" if info.filled else "On the river")))
	barge_clock = _number(26)
	barge_clock.text = _barge_status(info)
	words.add_child(barge_clock)
	row.add_child(words)
	var reward := VBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_theme_constant_override("separation", int(-2 * s))
	var reward_head := _eyebrow("Full load")
	reward_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(reward_head)
	var bonus := HBoxContainer.new()
	bonus.alignment = BoxContainer.ALIGNMENT_END
	bonus.add_theme_constant_override("separation", int(6 * s))
	bonus.add_child(_icon(icons["coin"], 28))
	var bonus_label := _number(26)
	bonus_label.text = "+%d" % info.bonus
	bonus_label.add_theme_color_override("font_color", GOLD)
	bonus.add_child(bonus_label)
	reward.add_child(bonus)
	row.add_child(reward)
	strip.add_child(row)
	column.add_child(strip)
	column.add_child(_eyebrow("Manifest" if info.docked else "Next manifest"))
	var crates := HBoxContainer.new()
	crates.alignment = BoxContainer.ALIGNMENT_CENTER
	crates.add_theme_constant_override("separation", int(12 * s))
	for line in info.lines: crates.add_child(_barge_crate(line, info.docked))
	column.add_child(crates)
	# The whole hold, with what's been shipped so far.
	var hold := HBoxContainer.new()
	hold.add_theme_constant_override("separation", int(12 * s))
	var bar := FillBar.new()
	bar.share = float(info.loaded) / maxf(1.0, float(info.wanted))
	bar.track = Color(1, 1, 1, 0.1)
	bar.fill = GOLD
	bar.custom_minimum_size = Vector2(0, 10) * s
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hold.add_child(bar)
	var tally := Label.new()
	tally.text = "%d/%d crates" % [info.loaded, info.wanted] + ("  ·  %d shipped" % info.shipped if info.shipped > 0 else "")
	tally.add_theme_font_size_override("font_size", int(14 * s))
	tally.add_theme_color_override("font_color", MUTED)
	hold.add_child(tally)
	if not barge_load.is_empty():
		_land_barge_load(barge_load, bar, tally)
		barge_load = {}
	column.add_child(hold)

## One manifest line as a paper crate label: the good, how many are aboard,
## the list price per crate and one action.
func _barge_crate(line: Dictionary, docked: bool) -> Control:
	var game: WorldGame = main.game
	var have: int = game.state.stock.get(line.good, 0)
	var full: bool = line.loaded >= line.count
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(int(12 * s))
	box.border_color = PAPER_READY if full else PAPER_EDGE
	box.set_border_width_all(int((3.0 if full else 1.5) * s))
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = int(8 * s)
	box.shadow_offset = Vector2(0, 4 * s)
	box.set_content_margin_all(12 * s)
	box.anti_aliasing_size = 0.8
	card.add_theme_stylebox_override("panel", box)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", int(6 * s))
	stack.custom_minimum_size = Vector2(170, 0) * s
	var name_label := _eyebrow(C.title(line.good))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", AWNING_RED)
	stack.add_child(name_label)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", int(8 * s))
	top.add_child(_icon(icons.get(line.good), 58))
	var count := _number(26)
	count.text = "%d/%d" % [line.loaded, line.count]
	count.add_theme_color_override("font_color", PAPER_READY if full else PAPER_INK)
	top.add_child(count)
	stack.add_child(top)
	var bar := FillBar.new()
	bar.share = float(line.loaded) / maxf(1.0, float(line.count))
	bar.custom_minimum_size = Vector2(130, 8) * s
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(bar)
	var each := HBoxContainer.new()
	each.alignment = BoxContainer.ALIGNMENT_CENTER
	each.add_theme_constant_override("separation", int(4 * s))
	each.add_child(_icon(icons["coin"], 18))
	var price := Label.new()
	price.text = "%d each" % line.price
	price.add_theme_font_size_override("font_size", int(13 * s))
	price.add_theme_color_override("font_color", PAPER_INK)
	each.add_child(price)
	stack.add_child(each)
	var want: int = mini(have, line.count - line.loaded)
	if full:
		var stowed := Label.new()
		stowed.text = "Stowed"
		stowed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stowed.add_theme_font_override("font", DISPLAY_SEMI)
		stowed.add_theme_font_size_override("font_size", int(17 * s))
		stowed.add_theme_color_override("font_color", PAPER_READY)
		stowed.custom_minimum_size = Vector2(0, 46) * s
		stowed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stack.add_child(stowed)
	elif docked and want > 0:
		var load_button: Button
		load_button = _button("Load %d" % want, func():
			fly_from = load_button.get_global_rect().get_center()
			var before := float(game.barge().get("loaded", 0)) / maxf(1.0, float(game.barge().get("wanted", 1)))
			var result := game.load_barge(line.good)
			if result == "": barge_load = {"good": line.good, "from": fly_from, "count": want, "share": before}
			_act(result), true)
		load_button.custom_minimum_size = Vector2(130, 46) * s
		load_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(load_button)
	else:
		var make := _button("Have %d · Make" % have, func(): _open_source(line.good), true, "", true)
		make.custom_minimum_size = Vector2(130, 46) * s
		make.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(make)
	card.add_child(stack)
	return card

## A filled hold: confetti, a heavy haptic and a banner; the barge sails off.
func _celebrate_barge(bonus: int) -> void:
	sfx("celebrate")
	haptic(F.HAPTIC_BIG)
	_confetti()
	var banner := PanelContainer.new()
	var box := glass(32, GLASS_DEEP)
	box.border_color = Color(GOLD, 0.7)
	box.set_border_width_all(int(2 * s))
	box.content_margin_left = 30 * s; box.content_margin_right = 30 * s
	box.content_margin_top = 14 * s; box.content_margin_bottom = 16 * s
	banner.add_theme_stylebox_override("panel", box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", int(14 * s))
	var boat := BoatIcon.new()
	boat.custom_minimum_size = Vector2(64, 64) * s
	line.add_child(boat)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", int(-2 * s))
	words.add_child(_eyebrow("Barge filled"))
	var title := _number(40)
	title.text = "+%d bonus" % bonus
	words.add_child(title)
	line.add_child(words)
	banner.add_child(line)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.add_child(banner)
	await get_tree().process_frame
	banner.position = Vector2((root.size.x - banner.size.x) / 2, root.size.y * 0.16)
	pop_in(banner)
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(banner.queue_free)

func _fill_gift() -> void:
	var game: WorldGame = main.game
	if not game.gift_ready():
		close.call_deferred()
		return
	var streak := game.state.gift_streak_on(game.today())
	var today := (streak - 1) % C.GIFT_BASKETS.size()
	var column := _sheet("Daily gift")
	var trail := HBoxContainer.new()
	trail.alignment = BoxContainer.ALIGNMENT_CENTER
	trail.add_theme_constant_override("separation", int(8 * s))
	for i in C.GIFT_BASKETS.size():
		var basket: Dictionary = C.GIFT_BASKETS[i]
		var last: String = basket.keys()[-1]
		var day := PanelContainer.new()
		var box := tile_box(16, i == today)
		box.set_content_margin_all(6 * s)
		if i == today:
			box.border_color = GOLD
			box.set_border_width_all(int(2 * s))
		day.add_theme_stylebox_override("panel", box)
		day.modulate.a = 1.0 if i <= today else 0.5
		var stack := VBoxContainer.new()
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 0)
		var number := Label.new()
		number.text = "✓" if i < today else str(i + 1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_font_override("font", DISPLAY_SEMI)
		number.add_theme_font_size_override("font_size", int(15 * s))
		number.add_theme_color_override("font_color", MINT if i < today else (GOLD if i == today else MUTED))
		stack.add_child(number)
		stack.add_child(_icon(icons.get(last), 40 if i == C.GIFT_BASKETS.size() - 1 else 34))
		day.add_child(stack)
		day.tooltip_text = "Day %d" % (i + 1)
		trail.add_child(day)
	column.add_child(trail)
	var basket_row := HBoxContainer.new()
	basket_row.alignment = BoxContainer.ALIGNMENT_CENTER
	basket_row.add_theme_constant_override("separation", int(18 * s))
	var basket := game.gift_basket()
	for good in basket: basket_row.add_child(_good_tile(good, "×%d" % basket[good]))
	column.add_child(basket_row)
	var collect := _button("Collect", func():
		fly_from = basket_row.get_global_rect().get_center()
		var result := game.claim_gift()
		close()
		_act(result))
	collect.custom_minimum_size.y = 56 * s
	column.add_child(collect)
	if was_new: sfx("success")

func _eyebrow(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_override("font", _spaced(BODY, 3))
	label.add_theme_font_size_override("font_size", int(12 * s))
	label.add_theme_color_override("font_color", GOLD)
	return label

var season_clock: Label
var season_shown := -1

## The market's favourite under the awning: what sells high now, for how
## long, and what comes next, so a batch can be timed to the window.
func _season_strip(season: Dictionary) -> Control:
	season_shown = int(season.get("window", -1))
	if str(season.good) == "": return null
	var strip := PanelContainer.new()
	var box := tile_box(18, true)
	box.set_content_margin_all(8 * s)
	strip.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * s))
	row.add_child(_icon(icons[season.good], 40))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", int(-4 * s))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Label.new()
	head.text = "In season"
	head.add_theme_font_size_override("font_size", int(13 * s))
	head.add_theme_color_override("font_color", MUTED)
	words.add_child(head)
	var name_line := Label.new()
	name_line.text = "%s  +%d%%" % [C.title(season.good), roundi(C.SEASON_BONUS * 100)]
	name_line.add_theme_font_override("font", DISPLAY_SEMI)
	name_line.add_theme_font_size_override("font_size", int(19 * s))
	name_line.add_theme_color_override("font_color", GOLD)
	words.add_child(name_line)
	row.add_child(words)
	season_clock = _number(20)
	season_clock.text = _time(int(season.left))
	season_clock.custom_minimum_size = Vector2(64, 0) * s
	season_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	season_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(season_clock)
	if str(season.next) != "" and season.next != season.good:
		var next := Label.new()
		next.text = "Next"
		next.add_theme_font_size_override("font_size", int(13 * s))
		next.add_theme_color_override("font_color", MUTED)
		next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(next)
		var next_icon := _icon(icons[season.next], 32)
		next_icon.tooltip_text = "Next in season: %s" % C.title(season.next)
		next_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(next_icon)
	strip.add_child(row)
	return strip

func _fill_more() -> void:
	var game: WorldGame = main.game
	var market: bool = game.host.features().get("market", false)
	var column := _sheet("Market" if market else "Warehouse")
	if market:
		var awning := Awning.new()
		awning.ui = self
		awning.custom_minimum_size = Vector2(0, 40 * s)
		awning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(awning)
		column.move_child(awning, 0)
		var strip := _season_strip(game.season())
		if strip: column.add_child(strip)
	var orders := game.state.open_orders()
	if market and not orders.is_empty():
		column.add_child(_eyebrow("Orders"))
		var board := HBoxContainer.new()
		board.add_theme_constant_override("separation", int(12 * s))
		for order in orders: board.add_child(_order_ticket(order))
		column.add_child(board)
	column.add_child(_eyebrow("Your goods" if market else "Stored"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(12 * s))
	grid.add_theme_constant_override("v_separation", int(10 * s))
	column.add_child(grid)
	var any := false
	for good in C.GOODS:
		var count: int = game.state.stock.get(good, 0)
		if count <= 0: continue
		any = true
		var cell := PanelContainer.new()
		var box := tile_box(20)
		box.set_content_margin_all(8 * s)
		cell.add_theme_stylebox_override("panel", box)
		cell.custom_minimum_size = Vector2(296, 0) * s
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(10 * s))
		row.add_child(_icon(icons[good], 50))
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", int(-4 * s))
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var good_name := Label.new()
		good_name.text = C.title(good)
		good_name.add_theme_font_size_override("font_size", int(13 * s))
		good_name.add_theme_color_override("font_color", MUTED)
		words.add_child(good_name)
		var amount := _number(24)
		amount.text = "×%d" % count
		words.add_child(amount)
		row.add_child(words)
		if market:
			var sell: Button
			var price := game.sell_price(good)
			sell = _button("%d" % price, func(): fly_from = sell.get_global_rect().get_center(); _act(game.sell(good, 1)), true, "coin")
			sell.tooltip_text = "Sell one" if price >= C.SELL_PRICE[good] else "Sell one (demand is recovering)"
			sell.custom_minimum_size = Vector2(88, 46) * s
			# How far demand has dipped, in a fixed-width slot so nothing shifts.
			var dip := Label.new()
			var drop := roundi(100.0 * (1.0 - float(price) / C.SELL_PRICE[good]))
			dip.text = "-%d%%" % drop if drop > 0 else ("+%d%%" % -drop if drop < 0 else "")
			dip.custom_minimum_size = Vector2(44, 0) * s
			dip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			dip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dip.add_theme_font_override("font", DISPLAY_SEMI)
			dip.add_theme_font_size_override("font_size", int(15 * s))
			dip.add_theme_color_override("font_color", SHORT if drop > 0 else GOLD)
			dip.tooltip_text = "Demand is recovering" if drop > 0 else "In season"
			row.add_child(dip)
			row.add_child(sell)
			if count > 1:
				var all: Button
				all = _button("All · %d" % game.sell_price(good, count), func(): fly_from = all.get_global_rect().get_center(); _act(game.sell(good, count)), true, "", true)
				all.custom_minimum_size = Vector2(104, 46) * s
				row.add_child(all)
		cell.add_child(row)
		grid.add_child(cell)
	if not any:
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", tile_box(20))
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", int(12 * s))
		line.add_child(_icon(icons["wheat"], 48))
		var hint := Label.new()
		hint.text = "Grow wheat at the farm"
		hint.add_theme_font_override("font", DISPLAY_SEMI)
		hint.add_theme_font_size_override("font_size", int(19 * s))
		line.add_child(hint)
		empty.add_child(line)
		column.add_child(empty)

## One order: a crate of goods for a bonus over the market price.
func _order_ticket(order: Dictionary) -> Control:
	var game: WorldGame = main.game
	var have: int = game.state.stock.get(order.good, 0)
	var ready: bool = have >= order.count
	# A paper note pinned to the stall, written in the neighbour's hand.
	var ticket := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(int(10 * s))
	box.border_color = GOLD if ready else PAPER_EDGE
	box.set_border_width_all(int((3.0 if ready else 1.5) * s))
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = int(8 * s)
	box.shadow_offset = Vector2(0, 4 * s)
	box.set_content_margin_all(12 * s)
	box.content_margin_top = 6 * s
	box.anti_aliasing_size = 0.8
	ticket.add_theme_stylebox_override("panel", box)
	ticket.rotation_degrees = [-1.6, 1.2, -0.8][int(order.slot) % 3] if not reduce_motion else 0.0
	ticket.resized.connect(func(): ticket.pivot_offset = ticket.size / 2)
	var pin := Pin.new()
	pin.custom_minimum_size = Vector2(14, 14) * s
	pin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(8 * s))
	column.custom_minimum_size = Vector2(176, 0) * s
	column.add_child(pin)
	var who := _eyebrow(order.name)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_color_override("font_color", AWNING_RED)
	column.add_child(who)
	var ask := Label.new()
	ask.text = order.ask
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.custom_minimum_size.x = 176 * s
	ask.add_theme_font_size_override("font_size", int(14 * s))
	ask.add_theme_color_override("font_color", PAPER_INK)
	column.add_child(ask)
	var crate := HBoxContainer.new()
	crate.alignment = BoxContainer.ALIGNMENT_CENTER
	crate.add_theme_constant_override("separation", int(8 * s))
	crate.add_child(_icon(icons.get(order.good), 56))
	var count := _number(24)
	count.text = "%d/%d" % [mini(have, order.count), order.count]
	count.add_theme_color_override("font_color", PAPER_READY if ready else PAPER_SHORT)
	crate.add_child(count)
	column.add_child(crate)
	if not order.keepsake.is_empty():
		var gift := HBoxContainer.new()
		gift.alignment = BoxContainer.ALIGNMENT_CENTER
		gift.add_theme_constant_override("separation", int(4 * s))
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_override("font", DISPLAY)
		plus.add_theme_font_size_override("font_size", int(18 * s))
		plus.add_theme_color_override("font_color", GOLD)
		gift.add_child(plus)
		for good in order.keepsake: gift.add_child(_icon(icons.get(good), 30))
		gift.tooltip_text = "Keepsake"
		column.add_child(gift)
	var deliver := _button("%d" % order.reward, func():
		var at := ticket.get_global_rect().get_center()
		fly_from = at
		_act(game.deliver(order.slot))
		if game.state.stock.get(order.good, 0) < have: sfx("celebrate"), ready, "coin")
	deliver.custom_minimum_size = Vector2(0, 46) * s
	if not ready:
		# Not yet: a pressed-in paper slot with the reward in faded ink.
		var slot := StyleBoxFlat.new()
		slot.bg_color = Color("E6D6B4")
		slot.set_corner_radius_all(int(23 * s))
		slot.set_content_margin_all(8 * s)
		deliver.add_theme_stylebox_override("disabled", slot)
		deliver.add_theme_color_override("font_disabled_color", Color(PAPER_INK, 0.7))
	column.add_child(deliver)
	ticket.add_child(column)
	if not ready:
		ticket.mouse_filter = Control.MOUSE_FILTER_STOP
		_press_card(ticket)
		ticket.gui_input.connect(func(e):
			if (e is InputEventMouseButton and not e.pressed) or (e is InputEventScreenTouch and not e.pressed): _open_source(order.good))
	return ticket

func _fill_land() -> void:
	open("build")

# --- settings -----------------------------------------------------------------

func _fill_settings() -> void:
	var column := _sheet("Settings")
	var rows := [["Sound effects", sound_on, func(on): sound_on = on; ambience.set_enabled(on); _save_settings()],
		["Music", music_on, func(on): set_music(on)],
		["Haptics", haptics_on, func(on): haptics_on = on; _save_settings(); haptic(0.6)],
		["Reduce motion", reduce_motion, func(on): set_reduce_motion(on)]]
	var list := PanelContainer.new()
	var box := tile_box(20)
	box.set_content_margin_all(6 * s)
	list.add_theme_stylebox_override("panel", box)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	for i in rows.size():
		var entry: Array = rows[i]
		var line := HBoxContainer.new()
		line.custom_minimum_size = Vector2(0, 54) * s
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(12, 0) * s
		line.add_child(gap)
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_font_override("font", DISPLAY_SEMI)
		label.add_theme_font_size_override("font_size", int(20 * s))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(label)
		var toggle := Switch.new()
		toggle.ui = self
		_press_card(toggle)
		toggle.on = entry[1]
		toggle.knob = 1.0 if entry[1] else 0.0
		toggle.custom_minimum_size = Vector2(58, 34) * s
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.toggled.connect(func(on): sfx("tap"); entry[2].call(on))
		line.add_child(toggle)
		var tail := Control.new()
		tail.custom_minimum_size = Vector2(10, 0) * s
		line.add_child(tail)
		stack.add_child(line)
		if i < rows.size() - 1: stack.add_child(HSeparator.new())
	list.add_child(stack)
	column.add_child(list)
	if C.speed() > 1.0:
		var note := Label.new()
		note.text = "Quick play  ×%d" % roundi(C.speed())
		note.add_theme_font_size_override("font_size", int(14 * s))
		note.add_theme_color_override("font_color", MUTED)
		column.add_child(note)

## Reduce Motion: interface movement stops (fades stay) and the renderer
## gets the same flag for its camera and scenery.
func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	if atmosphere: atmosphere.visible = not on
	_save_settings()
	if main.host.has_method("set_reduced_motion"): main.host.set_reduced_motion(on)
	main.push()

# --- tap acknowledgement ---------------------------------------------------------

## A soft expanding ring where a finger lifts on the open map.
class Ripple extends Control:
	var t := 0.0
	var ui
	func _draw() -> void:
		var k: float = ui.s
		var r: float = lerpf(WorldFeel.RIPPLE_FROM, WorldFeel.RIPPLE_TO, t if not ui.reduce_motion else 0.6) * k
		var a := 1.0 - t
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 1, 1, 0.75 * a), 3 * k, true)
		draw_circle(Vector2.ZERO, r * 0.55, Color(1, 1, 1, 0.16 * a))

var press_at := Vector2(-1, -1)
var press_time := 0.0
var press_panel: Control  # the panel open when the finger went down
var build_scroll := 0  # the Build tray's scroll, kept while it stays open
func _input(event: InputEvent) -> void:
	var down := false
	var up := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		down = event.pressed; up = not event.pressed; at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed; up = not event.pressed; at = event.position
	else:
		return
	if up:
		for control in held.duplicate(): press_out(control)
	if down:
		press_at = at
		press_time = Time.get_ticks_msec() / 1000.0
		press_panel = sheet_root
	elif up and press_at.x >= 0:
		var quick := Time.get_ticks_msec() / 1000.0 - press_time <= F.TAP_MAX_TIME
		var still := at.distance_to(press_at) <= F.TAP_SLOP * s
		press_at = Vector2(-1, -1)
		if quick and still and mode == "" and not blocks(at): _ripple(at)
		# A tap outside an open box closes it, like its close button. The Build
		# tray stays: taps on the map pick where to build. A tap that opened the
		# panel (it wasn't open at press) never closes it.
		elif quick and still and mode not in ["", "build"] and sheet_root != null and press_panel == sheet_root and _outside_panel(at):
			close()

func _outside_panel(at: Vector2) -> bool:
	var panel: Control = sheet_root.get_meta("panel", sheet_root)
	if not is_instance_valid(panel) or panel.get_global_rect().has_point(at): return false
	for control in hud:
		if control.visible and control.get_global_rect().has_point(at): return false
	return true

func _ripple(at: Vector2) -> void:
	if fly_layer.get_child_count() > F.FLY_MAX_ON_SCREEN: return
	var live := 0
	for child in fly_layer.get_children(): if child is Ripple: live += 1
	if live >= F.RIPPLE_MAX_ON_SCREEN: return
	var ring_mark := Ripple.new()
	ring_mark.ui = self
	ring_mark.position = at
	ring_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.add_child(ring_mark)
	var tween := ring_mark.create_tween()
	tween.tween_method(func(v: float): ring_mark.t = v; ring_mark.queue_redraw(), 0.0, 1.0, F.RIPPLE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring_mark.queue_free)
