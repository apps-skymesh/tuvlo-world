class_name WorldUI
extends CanvasLayer

## Step-2 game UI, after Tuvlo's World design (owner decisions 2026-11-02/03):
## - the map keeps only places, ready goods, Build (hammer) and More;
## - one wallet at the top;
## - each place opens its own centred card: goods → the real place framed inside
##   a clear ring → products, with one primary action below the ring;
## - goods can be dragged onto the ring (or the ring tapped) to start a job;
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
const IVORY := Color("FFF8EA")
const MUTED := Color(1, 0.97, 0.9, 0.62)
const GOLD := Color("F7C04A")
const GOLD_DEEP := Color("C98A1C")
const GOLD_INK := Color("3D2805")
const MINT := Color("7EDB9C")
const SHORT := Color("FF8E72")
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
var ring: WorldRing
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
const SETTINGS_PATH := "user://settings.cfg"
var fly_from := Vector2(-1, -1)
var last_stock := {}
var gift_offered_day := -1

# --- small drawing helpers -------------------------------------------------

class WorldRing extends Control:
	signal tapped
	signal dropped(good: String)
	var progress := -1.0
	var label := ""
	var glow := false
	var ui
	func _process(_delta: float) -> void:
		if glow: queue_redraw()
	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		var k: float = ui.s
		if glow:
			var pulse := 1.0 if ui.reduce_motion else 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
			for i in 7:
				draw_arc(c, r + (3 + i * 4) * k, 0, TAU, 96, Color(WorldUI.GOLD, (0.34 - i * 0.045) * (0.5 + 0.5 * pulse)), 5 * k, true)
		# A thin double rim: dark for contrast on bright turf, ivory on top.
		draw_arc(c, r - 4 * k, 0, TAU, 128, Color(0, 0, 0, 0.28), 9 * k, true)
		draw_arc(c, r - 4 * k, 0, TAU, 128, Color(1, 1, 1, 0.22), 7 * k, true)
		draw_arc(c, r - 0.5 * k, 0, TAU, 128, Color(1, 1, 1, 0.9), 2 * k, true)
		draw_arc(c, r - 8 * k, 0, TAU, 128, Color(1, 1, 1, 0.45), 1.2 * k, true)
		if progress >= 0:
			var tip := -PI / 2 + TAU * progress
			draw_arc(c, r - 4 * k, -PI / 2, tip, 128, WorldUI.MINT, 7 * k, true)
			draw_circle(c + Vector2.from_angle(tip) * (r - 4 * k), 6 * k, WorldUI.IVORY)
		if label != "":
			var font: Font = WorldUI.DISPLAY_SEMI
			var fs := int(19 * k)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var pill := Rect2(c.x - w / 2 - 14 * k, size.y - 44 * k, w + 28 * k, 32 * k)
			draw_style_box(ui.glass(16, WorldUI.GLASS_DEEP, false), pill)
			draw_string(font, Vector2(c.x - w / 2, pill.position.y + 23 * k), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.IVORY)
	func _gui_input(event: InputEvent) -> void:
		var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
		if press and event.position.distance_to(size / 2) <= size.x / 2: tapped.emit()
	func _can_drop_data(_at: Vector2, data: Variant) -> bool: return data is Dictionary and data.has("good")
	func _drop_data(_at: Vector2, data: Variant) -> void: dropped.emit(str(data.good))

## A card or sheet title: display type on a glass chip with gold diamonds.
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

## Dims the whole map except a soft circle around the ring: a spotlight on
## the place, so the card reads as a focus mode rather than a pop-up.
const SPOTLIGHT_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 centre = vec2(640.0, 360.0);
uniform float radius = 100.0;
uniform float feather = 60.0;
uniform vec4 tint : source_color = vec4(0.02, 0.06, 0.05, 0.62);
void fragment() {
	vec2 p = UV * rect_size;
	float d = distance(p, centre);
	float hole = smoothstep(radius, radius + feather, d);
	float edge = smoothstep(rect_size.y * 0.35, rect_size.y * 1.1, d) * 0.25;
	COLOR = vec4(tint.rgb, clamp(tint.a * hole + edge, 0.0, 0.9));
}
"""
static var spotlight_shader: Shader

class Spotlight extends ColorRect:
	func aim(viewport: Vector2, at: Vector2, radius: float, feather: float) -> void:
		if WorldUI.spotlight_shader == null:
			WorldUI.spotlight_shader = Shader.new()
			WorldUI.spotlight_shader.code = WorldUI.SPOTLIGHT_SHADER
		var shading := ShaderMaterial.new()
		shading.shader = WorldUI.spotlight_shader
		shading.set_shader_parameter("rect_size", viewport)
		shading.set_shader_parameter("centre", at)
		shading.set_shader_parameter("radius", radius)
		shading.set_shader_parameter("feather", feather)
		material = shading
		size = viewport
		mouse_filter = Control.MOUSE_FILTER_IGNORE

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

class GoodTile extends TextureRect:
	var good := ""
	var draggable := false
	var ui
	func _get_drag_data(_at: Vector2) -> Variant:
		if not draggable: return null
		var preview := TextureRect.new()
		preview.texture = texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = size
		preview.modulate.a = 0.9
		var holder := Control.new()
		holder.add_child(preview)
		preview.position = -size / 2
		set_drag_preview(holder)
		return {"good": good}

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
	var vignette := _gradient_rect([[0.0, Color(0, 0, 0, 0)], [0.62, Color(0, 0, 0, 0)], [1.0, Color(0.02, 0.06, 0.05, 0.34)]], true)
	root.add_child(vignette)
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

func bump(control: Control) -> void:
	if not is_instance_valid(control) or reduce_motion: return
	control.pivot_offset = control.size / 2
	control.scale = Vector2.ONE
	var tween := _solo_tween(control, "bump")
	tween.tween_property(control, "scale", Vector2.ONE * F.BUMP_SCALE, F.BUMP_UP_TIME).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2.ONE, F.BUMP_SETTLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _juice(button: BaseButton) -> void:
	button.button_down.connect(func():
		if reduce_motion or button.disabled: return
		button.pivot_offset = button.size / 2
		_solo_tween(button, "press").tween_property(button, "scale", Vector2.ONE * F.PRESS_SCALE, F.PRESS_TIME))
	button.button_up.connect(func():
		if not is_instance_valid(button): return
		if reduce_motion: button.scale = Vector2.ONE; return
		_solo_tween(button, "press").tween_property(button, "scale", Vector2.ONE, F.RELEASE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	button.pressed.connect(func(): sfx("tap"); haptic())

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
var shown_coins := -1.0
func _count_to(coins: int) -> void:
	if shown_coins < 0 or reduce_motion:
		shown_coins = coins
		coins_label.text = str(coins)
		return
	var gap := absf(coins - shown_coins)
	if gap < 0.5: return
	var time := clampf(gap * F.COUNT_TIME_PER_COIN, F.COUNT_MIN_TIME, F.COUNT_MAX_TIME)
	var tween := _solo_tween(coins_label, "count")
	if coins > shown_coins: tween.tween_interval(F.COUNT_DELAY)
	tween.tween_method(func(value: float):
		shown_coins = value
		coins_label.text = str(roundi(value)), shown_coins, float(coins), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## A rising "+N" label at a screen point.
func float_text(text: String, at: Vector2, color := IVORY) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", DISPLAY)
	label.add_theme_font_size_override("font_size", int(32 * s))
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
		"disabled": _lip_box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0)}
	for state in primary: theme.set_stylebox(state, "Button", primary[state])
	theme.set_font("font", "Button", DISPLAY_SEMI)
	theme.set_color("font_color", "Button", GOLD_INK)
	theme.set_color("font_hover_color", "Button", GOLD_INK)
	theme.set_color("font_pressed_color", "Button", GOLD_INK)
	theme.set_color("font_focus_color", "Button", GOLD_INK)
	theme.set_color("font_disabled_color", "Button", MUTED)
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
	goal_box.gui_input.connect(func(e):
		if ((e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed)) and goal_action.is_valid():
			sfx("tap"); bump(goal_box); goal_action.call())
	root.add_child(goal_box)
	hud.append(goal_box)
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

## The next most useful step, computed from the save. Never a dead end.
func _goal() -> Array:
	var game: WorldGame = main.game
	var st := game.state
	var now := game.now()
	var garden := st.first_of("garden")
	if game.gift_ready():
		return [game.gift_basket().keys()[0], "Daily gift", func(): open("gift"), ""]
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

func _celebrate_level(level: int, before: int) -> void:
	sfx("level_up")
	_confetti()
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
	fly_layer.add_child(banner)
	await get_tree().process_frame
	banner.position = Vector2((root.size.x - banner.size.x) / 2, root.size.y * 0.16)
	pop_in(banner)
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(banner.queue_free)

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
	if ambience and main and main.game:
		ambience.tick(delta, main.game.state.job_remaining("mill", main.game.now()) > 0)
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0: toast.text = ""; toast_box.visible = false

func refresh() -> void:
	var game: WorldGame = main.game
	var coins := game.host.wallet()
	var level := game.host.progress()
	_count_to(coins)
	level_label.text = str(level)
	var bar := game.next_level_progress()
	level_badge.level = level
	level_badge.progress = float(bar.x) / bar.y if bar.y > 0 else 0.0
	level_badge.queue_redraw()
	var from := fly_from if fly_from.x >= 0 else root.get_viewport_rect().size / 2
	if ring and is_instance_valid(ring): from = ring.get_global_rect().get_center()
	if last_coins >= 0 and coins > last_coins:
		sfx("coins", _combo_pitch())
		haptic(F.HAPTIC_REWARD)
		fly(icons["coin"], from, coin_pill, clampi(coins - last_coins, 1, 6))
		float_text("+%d" % (coins - last_coins), from + Vector2(0, -50 * s), GOLD)
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
	fly_from = Vector2(-1, -1)
	if last_level >= 0 and level > last_level: _celebrate_level(level, last_level)
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
	var parts := [mode, place_id, station, recipe, build_pick, game.host.wallet(), game.host.progress(), JSON.stringify(st.stock), JSON.stringify(filled), st.land, st.items.size()]
	if mode == "place":
		parts.append(st.is_building(place_id, now))
		parts.append(st.jobs.has(station) and st.job_remaining(station, now) == 0)
		parts.append(st.jobs.has(station))
		for i in st.fields.size(): parts.append(st.field_stage(i, now))
		parts.append(st.orchard_watered >= 0 and st.orchard_remaining(now) == 0)
		parts.append(st.orchard_watered >= 0)
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
	if next_mode == "place":
		var item: Dictionary = main.game.state.find(place_id)
		var stations := C.stations_for(item.get("kind", ""))
		if station == "" and not stations.is_empty(): station = stations[0]
		if station == "field": station = ""
	_fill()
	was_new = false
	goal_box.visible = false
	dock_node.visible = false
	if next_mode != "build": main.spot_preview({})
	panel_changed.emit(next_mode in ["place", "more", "land", "settings", "gift"])
	if was == "" or was != next_mode: pass

func close() -> void:
	var was_place := mode == "place"
	mode = ""
	place_id = ""
	build_pick = ""
	if sheet_root: sheet_root.queue_free(); sheet_root = null
	ring = null
	main.spot_preview({})
	if was_place: main.camera({"mode": "arrival", "resetZoom": true})
	panel_changed.emit(false)
	goal_box.visible = true
	dock_node.visible = true

func _act(result: String) -> void:
	filled = {}
	main.after_action(result)

var was_new := false

func _fill() -> void:
	signature = _signature()
	if sheet_root: sheet_root.queue_free()
	sheet_root = null
	ring = null
	match mode:
		"place": _fill_place()
		"build": _fill_build()
		"more": _fill_more()
		"land": _fill_land()
		"settings": _fill_settings()
		"gift": _fill_gift()
	if sheet_root and was_new:
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

func _card_shell(title: String) -> Array:
	# A picture sentence under a spotlight: goods › the place in a ring › products.
	# Returns [left well, centre column, right well].
	var viewport := root.get_viewport_rect().size
	var width := minf(760 * s, viewport.x - 24 * s)
	var height := minf(340 * s, viewport.y - 4 * s)
	var card := Control.new()
	card.size = Vector2(width, height)
	card.position = (viewport - card.size) / 2 + Vector2(0, 14 * s)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spotlight := Spotlight.new()
	spotlight.aim(viewport, card.position + Vector2(width / 2, RING_DIAMETER * s / 2), RING_DIAMETER * s / 2 + 6 * s, 70 * s)
	spotlight.position = -card.position
	card.add_child(spotlight)
	var band_top := 22 * s
	var row := HBoxContainer.new()
	row.size = Vector2(width, height)
	row.add_theme_constant_override("separation", int(4 * s))
	card.add_child(row)
	var left := _well()
	var right := _well()
	for well in [left, right]:
		well.custom_minimum_size = Vector2(150, 0) * s
		well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		well.alignment = BoxContainer.ALIGNMENT_CENTER
	var left_holder := _well_holder(left)
	row.add_child(left_holder)
	row.add_child(_arrow())
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.alignment = BoxContainer.ALIGNMENT_BEGIN
	centre.add_theme_constant_override("separation", int(12 * s))
	row.add_child(centre)
	row.add_child(_arrow())
	row.add_child(_well_holder(right))
	var close_button := _close_button()
	close_button.position = Vector2(width - 44 * s, band_top - 26 * s)
	card.add_child(close_button)
	var ribbon := Ribbon.new()
	ribbon.ui = self
	ribbon.text = title
	var ribbon_width := DISPLAY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x + 92 * s
	ribbon.size = Vector2(ribbon_width, 44 * s)
	ribbon.position = Vector2((width - ribbon_width) / 2, band_top - 74 * s)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ribbon)
	root.add_child(card)
	root.move_child(wallet_node, -1)
	sheet_root = card
	ring = WorldRing.new()
	ring.ui = self
	ring.custom_minimum_size = Vector2(RING_DIAMETER, RING_DIAMETER) * s
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centre.add_child(ring)
	return [left, centre, right]

func _well_holder(well: VBoxContainer) -> Control:
	# Keeps a well vertically centred on the ring.
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(150 * s, RING_DIAMETER * s)
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var plate := PanelContainer.new()
	var box := glass(28)
	box.set_content_margin_all(10 * s)
	plate.add_theme_stylebox_override("panel", box)
	plate.custom_minimum_size = Vector2(140, 140) * s
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(well)
	holder.add_child(plate)
	return holder

func _arrow() -> Control:
	var arrow := Arrow.new()
	arrow.ui = self
	arrow.custom_minimum_size = Vector2(40 * s, RING_DIAMETER * s)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return arrow

func _frame_camera(kind_station: String) -> void:
	# The ring's place comes from the card's own geometry: the containers may
	# not have laid out yet, and the pop-in scale would skew a measured rect.
	if not ring or not is_instance_valid(ring) or not sheet_root: return
	var viewport := root.get_viewport_rect().size
	var centre := sheet_root.position + Vector2(sheet_root.size.x / 2, RING_DIAMETER * s / 2)
	var shift := {"x": centre.x / viewport.x - 0.5, "y": centre.y / viewport.y - 0.5}
	main.camera({"mode": "place", "id": place_id, "station": kind_station, "production": true, "focusShift": shift, "ring": RING_DIAMETER * s / viewport.y, "resetZoom": true})

func _fill_place() -> void:
	var game: WorldGame = main.game
	var st := game.state
	var item := st.find(place_id)
	if item.is_empty(): close(); return
	var now := game.now()
	var title := C.title(station) if station != "" and C.stations_for(item.kind).size() > 1 else C.title(item.kind)
	var parts := _card_shell(title)
	var left: VBoxContainer = parts[0]
	var centre: VBoxContainer = parts[1]
	var right: VBoxContainer = parts[2]
	ring.tapped.connect(_ring_tapped)
	ring.dropped.connect(_ring_dropped)
	var action: Button
	if st.is_building(place_id, now):
		left.add_child(_icon(icons["hammer"], 64))
		right.add_child(_icon(icons.get(item.kind), 96))
		action = _button("", func(): pass, false)
	elif item.kind == "garden":
		action = _fill_garden(left, right)
	elif item.kind == "orchard":
		action = _fill_orchard(left, right)
	elif station != "":
		action = _fill_station(left, right)
	else:
		right.add_child(_icon(icons.get(item.kind, icons["star"]), 96))
		left.add_child(_icon(icons["star"], 48))
		action = _button("Close", close)
	action.custom_minimum_size = Vector2(170, 52) * s
	action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centre.add_child(action)
	_update_ring()
	_frame_camera(station if station != "" else ("field" if item.kind == "garden" else ""))
	if C.stations_for(item.kind).size() > 1:
		# The cottage hosts the oven and the kitchen bench: one card each, switched here.
		var other: String = C.stations_for(item.kind)[1] if station == C.stations_for(item.kind)[0] else C.stations_for(item.kind)[0]
		var switch := _button(C.title(other), func(): open("place", place_id, other), true, "", true)
		switch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		centre.add_child(switch)

func _update_ring() -> void:
	if not ring: return
	var game: WorldGame = main.game
	var st := game.state
	var now := game.now()
	var item := st.find(place_id)
	ring.progress = -1.0
	ring.label = ""
	if item.is_empty(): return
	if st.is_building(place_id, now):
		var c: Dictionary = st.construction[place_id]
		ring.progress = clampf((now - c.started) / c.seconds, 0, 1)
		ring.label = _time(ceili(c.started + c.seconds - now))
	elif item.kind == "garden":
		var left := 0
		for i in st.fields.size():
			if st.field_stage(i, now) in [2, 3]: left = maxi(left, st.field_remaining(i, now))
		if left > 0:
			ring.progress = clampf(1.0 - left / st.field_total(0), 0, 1)
			ring.label = _time(left)
	elif item.kind == "orchard" and st.orchard_watered >= 0:
		var left := st.orchard_remaining(now)
		ring.progress = clampf(1.0 - left / st.orchard_grow, 0, 1)
		if left > 0: ring.label = _time(left)
	elif station != "" and st.jobs.has(station):
		var left := st.job_remaining(station, now)
		ring.progress = clampf(1.0 - float(left) / st.job_total(station), 0, 1)
		if left > 0: ring.label = _time(left)
	ring.glow = ring.progress >= 1.0 or (item.kind == "garden" and _any_field(4))
	ring.queue_redraw()

func _any_field(stage: int) -> bool:
	var st: WorldState = main.game.state
	for i in st.fields.size():
		if st.field_stage(i, main.game.now()) == stage: return true
	return false

static func _time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]

func _fill_garden(left: VBoxContainer, right: VBoxContainer) -> Button:
	var st: WorldState = main.game.state
	var now: float = main.game.now()
	var stages := []
	for i in st.fields.size(): stages.append(st.field_stage(i, now))
	var next := "harvest" if 4 in stages else ("plant" if 0 in stages else ("water" if 1 in stages else ""))
	if next == "harvest": left.add_child(_icon(icons["wheat"], 72))
	else:
		var tool_icon := ToolIcon.new()
		tool_icon.tool = "water" if next == "water" else "seed"
		tool_icon.custom_minimum_size = Vector2(72, 72) * s
		tool_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(tool_icon)
	var tool := Label.new()
	tool.text = {"plant": "Plant", "water": "Water", "harvest": "Harvest", "": "Growing"}[next]
	tool.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tool)
	var ready := stages.count(4)
	right.add_child(_good_tile("wheat", "×%d" % (C.FIELD_YIELD * maxi(1, ready if next == "harvest" else st.fields.size())), false, false))
	return _button(tool.text, _tend_all, next != "", "wheat" if next == "harvest" else "")

func _tend_all() -> void:
	var game: WorldGame = main.game
	var now := game.now()
	var stages := []
	for i in game.state.fields.size(): stages.append(game.state.field_stage(i, now))
	var target := 4 if 4 in stages else (0 if 0 in stages else (1 if 1 in stages else -1))
	if target < 0: show_toast("Still growing"); return
	var result := ""
	for i in stages.size():
		if stages[i] == target:
			result = game.tend(i)
			if result != "": break
	_act(result)

func _fill_orchard(left: VBoxContainer, right: VBoxContainer) -> Button:
	var st: WorldState = main.game.state
	var now: float = main.game.now()
	var ready := st.orchard_watered >= 0 and st.orchard_remaining(now) == 0
	left.add_child(_icon(icons["orchard"], 72))
	right.add_child(_good_tile("fruit", "×%d" % C.ORCHARD_YIELD))
	var text := "Water" if st.orchard_watered < 0 else ("Pick" if ready else "")
	return _button(text if text != "" else "Growing", func(): _act(main.game.tend_orchard()), text != "", "fruit" if ready else "")

func _fill_station(left: VBoxContainer, right: VBoxContainer) -> Button:
	var st: WorldState = main.game.state
	var now: float = main.game.now()
	var recipes := C.recipes_for(station)
	if st.jobs.has(station): recipe = st.jobs[station].recipe
	elif recipe == "" or recipe not in recipes:
		recipe = recipes[0]
		for id in recipes:
			if _have_all(id): recipe = id; break
	var spec: Dictionary = C.RECIPES[recipe]
	var working := st.jobs.has(station)
	# Goods on the left: what the selected product needs. A short good shows a
	# red count and opens its source.
	for good in spec.input:
		var need: int = spec.input[good]
		var have: int = st.stock[good]
		var is_filled: bool = filled.get(good, false)
		var text := "✓" if is_filled else "%d/%d" % [mini(have, need), need]
		left.add_child(_good_tile(good, "" if working else text, have < need and not working, not working and have >= need and not is_filled, func(): _open_source(good) if have < need else _ring_dropped(good)))
	# Products on the right: each recipe this place makes; tap to choose.
	for id in recipes:
		var r: Dictionary = C.RECIPES[id]
		var tile := _good_tile(r.output, "×%d" % r.quantity, false, false, func(): if not working: recipe = id; filled = {}; _fill())
		if id == recipe:
			var holder := PanelContainer.new()
			var box := tile_box(18, true)
			box.set_content_margin_all(4 * s)
			holder.add_theme_stylebox_override("panel", box)
			holder.add_child(tile)
			right.add_child(holder)
		else:
			tile.modulate.a = 0.55 if not working else 0.3
			right.add_child(tile)
	if working:
		var ready := st.job_remaining(station, now) == 0
		return _button("Collect" if ready else "Working", func(): _act(main.game.collect(station)), ready, spec.output if ready else "")
	return _button("Make", func(): _act(main.game.make(recipe)), _have_all(recipe), spec.output)

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
	if item.kind == "garden": _tend_all(); return
	if item.kind == "orchard": _act(game.tend_orchard()); return
	if station == "": return
	if st.jobs.has(station): _act(game.collect(station))
	elif _have_all(recipe): _act(game.make(recipe))
	else: show_toast("Not enough yet")

## Dropping (or tapping) a good fills its slot; the last one starts the job.
func _ring_dropped(good: String) -> void:
	if station == "" or recipe == "" or main.game.state.jobs.has(station): return
	var spec: Dictionary = C.RECIPES[recipe]
	if not spec.input.has(good) or main.game.state.stock[good] < spec.input[good]: return
	filled[good] = true
	for g in spec.input:
		if not filled.get(g, false):
			_fill(); return
	_act(main.game.make(recipe))

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

func _fill_more() -> void:
	var game: WorldGame = main.game
	var market: bool = game.host.features().get("market", false)
	var column := _sheet("Market" if market else "Warehouse")
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
			row.add_child(sell)
			if count > 1:
				var all: Button
				all = _button("All · %d" % game.sell_price(good, count), func(): fly_from = all.get_global_rect().get_center(); _act(game.sell(good, count)), true, "", true)
				all.custom_minimum_size = Vector2(0, 46) * s
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
	var ticket := PanelContainer.new()
	var box := tile_box(22, ready)
	box.set_content_margin_all(12 * s)
	ticket.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(8 * s))
	column.custom_minimum_size = Vector2(176, 0) * s
	var who := _eyebrow(order.name)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(who)
	var ask := Label.new()
	ask.text = order.ask
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.custom_minimum_size.x = 176 * s
	ask.add_theme_font_size_override("font_size", int(14 * s))
	ask.add_theme_color_override("font_color", MUTED)
	column.add_child(ask)
	var crate := HBoxContainer.new()
	crate.alignment = BoxContainer.ALIGNMENT_CENTER
	crate.add_theme_constant_override("separation", int(8 * s))
	crate.add_child(_icon(icons.get(order.good), 56))
	var count := _number(24)
	count.text = "%d/%d" % [mini(have, order.count), order.count]
	count.add_theme_color_override("font_color", MINT if ready else SHORT)
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
	column.add_child(deliver)
	ticket.add_child(column)
	if not ready:
		ticket.mouse_filter = Control.MOUSE_FILTER_STOP
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
