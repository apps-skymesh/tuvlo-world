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
const CREAM := Color("FFF5DC")
const PARCHMENT := Color("F5E4BE")
const WELL := Color("E7D1A3")
const RIM := Color("B98547")
const WALNUT := Color("5C3A1B")
const INK := Color("3B2A17")
const GOLD := Color("F2B632")
const LEAF := Color("6FA850")
const SHORT := Color("C85A3C")
const RING_DIAMETER := 212.0

signal panel_changed(open: bool)

var main  # game_main.gd
var s := 1.0
var root: Control
var coins_label: Label
var level_label: Label
var toast: Label
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
var level_bar: ProgressBar
var coin_pill: Control
var market_button: Button
var fly_layer: Control
var last_level := -1
var last_coins := -1
var audio: Dictionary = {}
var music: AudioStreamPlayer
var sound_on := true
var fly_from := Vector2(-1, -1)
var last_stock := {}

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
		if glow:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
			for i in 6:
				draw_arc(c, r + (4 + i * 4) * ui.s, 0, TAU, 96, Color(WorldUI.GOLD, (0.42 - i * 0.07) * (0.55 + 0.45 * pulse)), 5 * ui.s, true)
		draw_arc(c, r - 5 * ui.s, 0, TAU, 96, Color(1, 0.96, 0.86, 0.95), 10 * ui.s, true)
		draw_arc(c, r - 1 * ui.s, 0, TAU, 96, WorldUI.RIM, 3 * ui.s, true)
		draw_arc(c, r - 10 * ui.s, 0, TAU, 96, Color(WorldUI.RIM, 0.55), 2 * ui.s, true)
		if progress >= 0:
			draw_arc(c, r - 5 * ui.s, -PI / 2, -PI / 2 + TAU * progress, 96, WorldUI.LEAF, 8 * ui.s, true)
		if label != "":
			var font := get_theme_default_font()
			var fs := int(20 * ui.s)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			var pill := Rect2(c.x - w / 2 - 12 * ui.s, size.y - 46 * ui.s, w + 24 * ui.s, 32 * ui.s)
			draw_style_box(ui.pill_box(WorldUI.CREAM), pill)
			draw_string(font, Vector2(c.x - w / 2, pill.position.y + 23 * ui.s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.INK)
	func _gui_input(event: InputEvent) -> void:
		var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
		if press and event.position.distance_to(size / 2) <= size.x / 2: tapped.emit()
	func _can_drop_data(_at: Vector2, data: Variant) -> bool: return data is Dictionary and data.has("good")
	func _drop_data(_at: Vector2, data: Variant) -> void: dropped.emit(str(data.good))

## A gold banner with notched tails, for card and sheet titles.
class Ribbon extends Control:
	var text := ""
	var ui
	func _draw() -> void:
		var h := size.y
		var w := size.x
		var tail := h * 0.55
		var dark := Color("C98A1C")
		for side in [-1, 1]:
			var x0 := 0.0 if side < 0 else w
			var points := PackedVector2Array([Vector2(x0 + side * -tail * 0.2, h * 0.28), Vector2(x0 + side * tail, h * 0.28), Vector2(x0 + side * tail * 0.62, h * 0.72), Vector2(x0 + side * tail, h * 1.12), Vector2(x0 + side * -tail * 0.2, h * 1.12)])
			draw_colored_polygon(points, dark)
		var body := StyleBoxFlat.new()
		body.bg_color = WorldUI.GOLD
		body.set_corner_radius_all(int(h * 0.3))
		body.border_color = Color("A86E12")
		body.set_border_width_all(int(2 * ui.s))
		body.shadow_color = Color(0, 0, 0, 0.25)
		body.shadow_size = int(5 * ui.s)
		body.shadow_offset = Vector2(0, 3 * ui.s)
		draw_style_box(body, Rect2(Vector2.ZERO, Vector2(w, h * 0.9)))
		draw_rect(Rect2(Vector2(h * 0.25, h * 0.12), Vector2(w - h * 0.5, h * 0.12)), Color(1, 1, 1, 0.28))
		var font := get_theme_default_font()
		var fs := int(h * 0.5)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((w - tw) / 2, h * 0.45 + fs * 0.36)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(7 * ui.s), WorldUI.WALNUT)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.CREAM)

## The card's band, with a round window so the real place shows through the ring.
class Band extends Control:
	var ui
	var hole_radius := 100.0
	func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		var corners := [[rect.position + Vector2(radius, radius), PI], [Vector2(rect.end.x - radius, rect.position.y + radius), -PI / 2], [rect.end - Vector2(radius, radius), 0.0], [Vector2(rect.position.x + radius, rect.end.y - radius), PI / 2]]
		for corner in corners:
			for k in 9: points.append(corner[0] + Vector2.from_angle(corner[1] + k * PI / 16) * radius)
		return points
	func _draw() -> void:
		var circle := PackedVector2Array()
		for k in 64: circle.append(size / 2 + Vector2.from_angle(k * TAU / 64) * hole_radius)
		var outer := _rounded(Rect2(Vector2.ZERO, size), minf(40 * ui.s, size.y / 2))
		var shadow := Transform2D(0, Vector2(0, 4 * ui.s))
		var shapes: Array = Geometry2D.clip_polygons(outer, circle)
		# clip_polygons returns the outer ring and the hole separately; split into halves instead.
		var halves := []
		for side in [0, 1]:
			var clip := PackedVector2Array([Vector2(size.x / 2 * side, -10), Vector2(size.x / 2 * (side + 1), -10), Vector2(size.x / 2 * (side + 1), size.y + 10), Vector2(size.x / 2 * side, size.y + 10)])
			for half in Geometry2D.intersect_polygons(outer, clip):
				for piece in Geometry2D.clip_polygons(half, circle): halves.append(piece)
		for piece in halves: draw_colored_polygon(shadow * piece, Color(0, 0, 0, 0.16))
		for piece in halves: draw_colored_polygon(piece, Color(WorldUI.CREAM, 0.95))
		var edge := outer.duplicate()
		edge.append(outer[0])
		for i in edge.size() - 1:
			var a := edge[i]; var b := edge[i + 1]
			if a.distance_to(size / 2) > hole_radius + 2 and b.distance_to(size / 2) > hole_radius + 2: draw_line(a, b, Color(WorldUI.RIM, 0.85), 3 * ui.s, true)

## A soft chevron between goods, the place and products.
class Arrow extends Control:
	var ui
	func _draw() -> void:
		var c := size / 2
		var d := minf(size.x, size.y) * 0.26
		for i in 2:
			var x := c.x + (i - 0.5) * d * 0.95
			draw_polyline(PackedVector2Array([Vector2(x - d * 0.4, c.y - d), Vector2(x + d * 0.4, c.y), Vector2(x - d * 0.4, c.y + d)]), Color(WorldUI.RIM, 0.55 + 0.35 * i), 6 * ui.s, true)

## A striped market awning with a scalloped edge.
class Awning extends Control:
	var ui
	func _draw() -> void:
		var stripes := 10
		var w := size.x / stripes
		var h := size.y
		for i in stripes:
			var color := Color("D9573E") if i % 2 == 0 else Color("FFF5DC")
			draw_rect(Rect2(Vector2(i * w, 0), Vector2(w, h * 0.7)), color)
			var points := PackedVector2Array()
			for k in 13:
				var t := float(k) / 12.0
				points.append(Vector2(i * w + t * w, h * 0.7 + sin(t * PI) * h * 0.3))
			points.append(Vector2(i * w, h * 0.7))
			draw_colored_polygon(points, color)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, h * 0.12)), Color(0, 0, 0, 0.12))

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
	_build_hud()
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(78 * s))
	toast.add_theme_color_override("font_color", INK)
	toast.add_theme_color_override("font_outline_color", CREAM)
	toast.add_theme_constant_override("outline_size", int(8 * s))
	toast.add_theme_font_size_override("font_size", int(22 * s))
	root.add_child(toast)
	fly_layer = Control.new()
	fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.theme = root.theme
	add_child(fly_layer)
	_setup_audio()
	_show_title()
	refresh()

# --- title -----------------------------------------------------------------

var title_layer: Control

## A short title over the living map; any tap starts play.
func _show_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	title_layer.theme = root.theme
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.16, 0.1, 0.02, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(shade)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(6 * s))
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = "Tuvlo World"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", int(96 * s))
	name_label.add_theme_color_override("font_color", CREAM)
	name_label.add_theme_color_override("font_outline_color", WALNUT)
	name_label.add_theme_constant_override("outline_size", int(26 * s))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	name_label.add_theme_constant_override("shadow_offset_y", int(8 * s))
	column.add_child(name_label)
	var sprouts := HBoxContainer.new()
	sprouts.alignment = BoxContainer.ALIGNMENT_CENTER
	sprouts.add_theme_constant_override("separation", int(14 * s))
	for good in ["wheat", "flour", "bread", "tart", "meal"]: sprouts.add_child(_icon(icons.get(good), 58))
	column.add_child(sprouts)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40 * s)
	column.add_child(gap)
	var play := Label.new()
	play.text = "Tap to play"
	play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play.add_theme_font_size_override("font_size", int(30 * s))
	play.add_theme_color_override("font_color", CREAM)
	play.add_theme_color_override("font_outline_color", WALNUT)
	play.add_theme_constant_override("outline_size", int(12 * s))
	column.add_child(play)
	title_layer.add_child(column)
	add_child(title_layer)
	for control in hud: control.modulate.a = 0.0
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	title_layer.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed): dismiss_title())
	main.camera({"mode": "arrival", "resetZoom": true})

func dismiss_title() -> void:
	if not title_layer: return
	var layer := title_layer
	title_layer = null
	sfx("success")
	var tween := create_tween().set_parallel()
	tween.tween_property(layer, "modulate:a", 0.0, 0.45)
	for control in hud: tween.tween_property(control, "modulate:a", 1.0, 0.5).set_delay(0.2)
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
			add_child(player)
			audio[name] = player
	music = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/music_world.ogg") if ResourceLoader.exists("res://assets/audio/music_world.ogg") else null
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		music.stream = stream
		music.volume_db = -16.0
		add_child(music)
		music.play()

func sfx(name: String) -> void:
	if sound_on and audio.has(name): audio[name].play()

func toggle_sound() -> void:
	sound_on = not sound_on
	if music.stream:
		if sound_on: music.play()
		else: music.stop()

# --- motion ----------------------------------------------------------------

func pop_in(control: Control) -> void:
	control.pivot_offset = control.size / 2
	control.scale = Vector2(0.86, 0.86)
	control.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.18)

func bump(control: Control) -> void:
	if not is_instance_valid(control): return
	control.pivot_offset = control.size / 2
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(1.18, 1.18), 0.09).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _juice(button: BaseButton) -> void:
	button.button_down.connect(func():
		button.pivot_offset = button.size / 2
		create_tween().tween_property(button, "scale", Vector2(0.93, 0.93), 0.06))
	button.button_up.connect(func(): create_tween().tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	button.pressed.connect(func(): sfx("tap"))

## Icons fly from a screen point to a HUD target along an arc, then the target bumps.
func fly(texture: Texture2D, from: Vector2, target: Control, count := 3, side := 44.0) -> void:
	if texture == null or not is_instance_valid(target): return
	var to := target.get_global_rect().get_center()
	for i in mini(count, 6):
		var sprite := TextureRect.new()
		sprite.texture = texture
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.size = Vector2(side, side) * s
		sprite.pivot_offset = sprite.size / 2
		sprite.position = from - sprite.size / 2 + Vector2(randf_range(-18, 18), randf_range(-12, 12)) * s
		fly_layer.add_child(sprite)
		var start := sprite.position
		var end := to - sprite.size / 2
		var lift := Vector2(0, -140 * s) + Vector2(randf_range(-60, 60), 0) * s
		var tween := create_tween()
		tween.tween_interval(i * 0.07)
		tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.12)
		tween.tween_method(func(t: float):
			var a := start.lerp(start + lift, t)
			var b := (start + lift).lerp(end, t)
			sprite.position = a.lerp(b, t)
			sprite.scale = Vector2.ONE * lerpf(1.25, 0.6, t), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func():
			sprite.queue_free()
			bump(target))

## A rising "+N" label at a screen point.
func float_text(text: String, at: Vector2, color := INK) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(30 * s))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", CREAM)
	label.add_theme_constant_override("outline_size", int(10 * s))
	fly_layer.add_child(label)
	label.position = at - Vector2(30, 20) * s
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70 * s, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)

func _theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["SF Pro Rounded", "Arial Rounded MT Bold", "Nunito", "Helvetica Neue"])
	font.font_weight = 800
	theme.default_font = font
	theme.default_font_size = int(18 * s)
	theme.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := pill_box({"normal": GOLD, "hover": Color("F5C24E"), "pressed": Color("D99C26"), "disabled": Color("E2D6BC"), "focus": GOLD}[state])
		box.border_color = Color(WALNUT, 0.35)
		box.set_border_width_all(int(2 * s))
		box.shadow_color = Color(0, 0, 0, 0.18) if state != "disabled" else Color(0, 0, 0, 0)
		box.shadow_size = int(3 * s)
		box.shadow_offset = Vector2(0, 2 * s)
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", WALNUT)
	theme.set_color("font_hover_color", "Button", WALNUT)
	theme.set_color("font_pressed_color", "Button", WALNUT)
	theme.set_color("font_disabled_color", "Button", Color("9A8D76"))
	theme.set_font_size("font_size", "Button", int(20 * s))
	return theme

func pill_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(22 * s))
	box.content_margin_left = 16 * s; box.content_margin_right = 16 * s
	box.content_margin_top = 6 * s; box.content_margin_bottom = 6 * s
	return box

func frame_box(radius := 26.0, color := PARCHMENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius * s))
	box.border_color = RIM
	box.set_border_width_all(int(3 * s))
	box.shadow_color = Color(0, 0, 0, 0.22)
	box.shadow_size = int(8 * s)
	box.shadow_offset = Vector2(0, 3 * s)
	box.set_content_margin_all(10 * s)
	return box

func _icon(texture: Texture2D, side: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side) * s
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _amount(icon_name: String, label: Label) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", frame_box(24, CREAM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * s))
	row.add_child(_icon(icons[icon_name], 30))
	label.add_theme_font_size_override("font_size", int(24 * s))
	row.add_child(label)
	pill.add_child(row)
	return pill

func _round_button(icon_name: String, action: Callable, label := "") -> Button:
	var button := Button.new()
	button.icon = icons[icon_name]
	button.expand_icon = true
	button.custom_minimum_size = Vector2(68, 68) * s
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = label
	var box := frame_box(34, CREAM)
	box.set_content_margin_all(8 * s)
	for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	_juice(button)
	return button

func _button(text: String, action: Callable, enabled := true, icon_name := "") -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 48 * s)
	if icon_name != "":
		button.icon = icons[icon_name]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", int(28 * s))
		button.custom_minimum_size.x = 92 * s
	button.pressed.connect(action)
	_juice(button)
	return button

func _build_hud() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(10 * s))
	coins_label = Label.new()
	level_label = Label.new()
	coin_pill = _amount("coin", coins_label)
	top.add_child(coin_pill)
	var level := _amount("star", level_label)
	level_bar = ProgressBar.new()
	level_bar.show_percentage = false
	level_bar.custom_minimum_size = Vector2(64, 10) * s
	level_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = WELL
	bar_bg.set_corner_radius_all(int(5 * s))
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	bar_fill.set_corner_radius_all(int(5 * s))
	level_bar.add_theme_stylebox_override("background", bar_bg)
	level_bar.add_theme_stylebox_override("fill", bar_fill)
	level.get_child(0).add_child(level_bar)
	top.add_child(level)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(14 * s))
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(top)
	hud.append(top)
	# Goal ticket: the next step, always one tap away.
	goal_box = PanelContainer.new()
	var ticket := frame_box(22, CREAM)
	ticket.border_color = GOLD
	goal_box.add_theme_stylebox_override("panel", ticket)
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", int(10 * s))
	goal_icon = _icon(icons["star"], 40)
	goal_row.add_child(goal_icon)
	goal_label = Label.new()
	goal_label.add_theme_font_size_override("font_size", int(19 * s))
	goal_row.add_child(goal_label)
	goal_box.add_child(goal_row)
	goal_box.position = Vector2(16, 14) * s
	goal_box.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_box.gui_input.connect(func(e):
		if ((e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed)) and goal_action.is_valid():
			sfx("tap"); goal_action.call())
	root.add_child(goal_box)
	hud.append(goal_box)
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", int(12 * s))
	rail.add_child(_round_button("hammer", func(): open("build"), "Build"))
	market_button = _round_button("meal", func(): open("more"), "Market")
	rail.add_child(market_button)
	rail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(18 * s))
	rail.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rail.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(rail)
	hud.append(rail)
	var sound := Button.new()
	sound.text = "♪"
	sound.focus_mode = Control.FOCUS_NONE
	sound.custom_minimum_size = Vector2(44, 44) * s
	var sound_box := frame_box(22, CREAM)
	sound_box.set_content_margin_all(4 * s)
	for state in ["normal", "hover", "pressed", "focus"]: sound.add_theme_stylebox_override(state, sound_box)
	sound.add_theme_font_size_override("font_size", int(22 * s))
	sound.pressed.connect(func(): toggle_sound(); sound.modulate.a = 1.0 if sound_on else 0.45)
	sound.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, int(16 * s))
	sound.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(sound)
	hud.append(sound)

## The next most useful step, computed from the save. Never a dead end.
func _goal() -> Array:
	var game: WorldGame = main.game
	var st := game.state
	var now := game.now()
	var garden := st.first_of("garden")
	for station in st.jobs:
		if st.job_remaining(station, now) == 0:
			var spec: Dictionary = C.RECIPES[st.jobs[station].recipe]
			return [spec.output, "Collect %s" % C.title(spec.output).to_lower(), func(): place_tapped(st.first_of(C.STATIONS[station]).id, station)]
	var stages := []
	for i in st.fields.size(): stages.append(st.field_stage(i, now))
	if 4 in stages: return ["wheat", "Harvest the wheat", func(): place_tapped(garden.id, "")]
	for order in st.open_orders():
		if st.stock.get(order.good, 0) >= order.count: return ["coin", "Deliver %d %s" % [order.count, C.title(order.good).to_lower()], func(): open("more")]
	if 0 in stages: return ["seed", "Plant wheat", func(): place_tapped(garden.id, "")]
	if 1 in stages: return ["water", "Water the field", func(): place_tapped(garden.id, "")]
	var level := game.host.progress()
	for kind in C.BUILD_ORDER:
		var spec: Dictionary = C.BUILDS[kind]
		if kind in ["flowers", "rocks", "bench"]: continue
		var blocker := st.build_blocker(kind, level)
		if blocker == "" and game.host.wallet() >= spec.price: return [kind, "Build a %s" % C.title(kind).to_lower(), func(): open("build")]
		if blocker == "locked": return [kind, "%s at level %d" % [C.title(kind), spec.gate], func(): open("more")]
	if st.owns("windmill") and not st.jobs.has("mill") and st.stock.wheat >= 2: return ["flour", "Mill some flour", func(): place_tapped(st.first_of("windmill").id, "mill")]
	if not st.jobs.has("oven") and st.stock.flour >= 1: return ["bread", "Bake bread", func(): place_tapped(st.first_of("cottage").id, "oven")]
	return ["wheat", "Wheat is growing", func(): place_tapped(garden.id, "")]

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
				_quick(func():
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
				_quick(func(): return game.tend_orchard())
				return
		else:
			for each in C.stations_for(item.kind):
				if tapped_station != "" and each != tapped_station: continue
				if st.jobs.has(each) and st.job_remaining(each, now) == 0:
					_quick(func(): return game.collect(each))
					return
	open("place", id, tapped_station)

func _quick(action: Callable) -> void:
	var result: String = action.call()
	main.after_action(result)
	if result != "": sfx("soft_fail")

func blocks(point: Vector2) -> bool:
	if title_layer: return true
	if mode in ["place", "more", "land"]: return true
	if sheet_root and sheet_root.get_global_rect().has_point(point): return true
	for control in hud:
		if control.get_global_rect().has_point(point): return true
	return false

func _celebrate_level(level: int, before: int) -> void:
	sfx("level_up")
	var banner := PanelContainer.new()
	var box := frame_box(30, CREAM)
	box.border_color = GOLD
	box.set_border_width_all(int(5 * s))
	banner.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_icon(icons["star"], 64))
	var title := Label.new()
	title.text = "Level %d" % level
	title.add_theme_font_size_override("font_size", int(40 * s))
	head.add_child(title)
	column.add_child(head)
	var unlocked := HBoxContainer.new()
	unlocked.alignment = BoxContainer.ALIGNMENT_CENTER
	unlocked.add_theme_constant_override("separation", int(8 * s))
	for kind in C.BUILD_ORDER:
		var gate: int = C.BUILDS[kind].gate
		if gate > before and gate <= level: unlocked.add_child(_icon(icons.get(kind), 72))
	for side in C.LAND:
		if C.LAND[side].gate > before and C.LAND[side].gate <= level: unlocked.add_child(_icon(icons.get(side), 72))
	if unlocked.get_child_count() > 0: column.add_child(unlocked)
	banner.add_child(column)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_layer.add_child(banner)
	await get_tree().process_frame
	banner.position = Vector2((root.size.x - banner.size.x) / 2, root.size.y * 0.14)
	pop_in(banner)
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(banner.queue_free)

func show_toast(text: String) -> void:
	toast.text = text
	toast_left = 2.2

func _process(delta: float) -> void:
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0: toast.text = ""

func refresh() -> void:
	var game: WorldGame = main.game
	var coins := game.host.wallet()
	var level := game.host.progress()
	coins_label.text = str(coins)
	level_label.text = str(level)
	var bar := game.next_level_progress()
	level_bar.visible = bar.y > 0
	if bar.y > 0: level_bar.value = 100.0 * bar.x / bar.y
	var from := fly_from if fly_from.x >= 0 else root.get_viewport_rect().size / 2
	if ring and is_instance_valid(ring): from = ring.get_global_rect().get_center()
	if last_coins >= 0 and coins > last_coins:
		sfx("coins")
		fly(icons["coin"], from, coin_pill, clampi(coins - last_coins, 1, 6))
		float_text("+%d" % (coins - last_coins), from + Vector2(0, -50 * s), Color(0.62, 0.42, 0.05))
	elif last_coins >= 0 and coins < last_coins: sfx("world_build_complete")
	if not last_stock.is_empty():
		var gained := false
		for good in game.state.stock:
			var diff: int = game.state.stock[good] - last_stock.get(good, 0)
			if diff > 0:
				gained = true
				fly(icons.get(good), from, market_button, diff)
				float_text("+%d" % diff, from + Vector2(0, -60 * s))
		if gained: sfx("world_harvest")
		elif coins == last_coins and game.state.stock.hash() != last_stock.hash(): sfx("world_plant")
	last_stock = game.state.stock.duplicate()
	fly_from = Vector2(-1, -1)
	if last_level >= 0 and level > last_level: _celebrate_level(level, last_level)
	last_coins = coins
	last_level = level
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
	goal_box.visible = mode == ""
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
	if next_mode == "place":
		var item: Dictionary = main.game.state.find(place_id)
		var stations := C.stations_for(item.get("kind", ""))
		if station == "" and not stations.is_empty(): station = stations[0]
		if station == "field": station = ""
	_fill()
	was_new = false
	if next_mode != "build": main.spot_preview({})
	panel_changed.emit(next_mode in ["place", "more", "land"])
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
	label.add_theme_font_size_override("font_size", int(20 * s))
	label.add_theme_color_override("font_color", SHORT if short else INK)
	column.add_child(label)
	return column

func _card_shell(title: String) -> Array:
	# A picture sentence on one band: goods › the place in a ring › products.
	# Returns [left well, centre column, right well].
	var viewport := root.get_viewport_rect().size
	var width := minf(760 * s, viewport.x - 24 * s)
	var height := minf(340 * s, viewport.y - 4 * s)
	var card := Control.new()
	card.size = Vector2(width, height)
	card.position = (viewport - card.size) / 2 + Vector2(0, 14 * s)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := Band.new()
	band.ui = self
	band.hole_radius = RING_DIAMETER * s / 2 - 4 * s
	band.size = Vector2(width, 168 * s)
	band.position = Vector2(0, (RING_DIAMETER * s - band.size.y) / 2)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
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
	var close_button := _round_button("more", close, "Close")
	close_button.icon = null
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(46, 46) * s
	close_button.position = Vector2(width - 34 * s, band.position.y - 20 * s)
	card.add_child(close_button)
	var ribbon := Ribbon.new()
	ribbon.ui = self
	ribbon.text = title
	var font := root.theme.default_font
	var ribbon_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x + 70 * s
	ribbon.size = Vector2(ribbon_width, 44 * s)
	ribbon.position = Vector2((width - ribbon_width) / 2, -50 * s)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ribbon)
	root.add_child(card)
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
	holder.add_child(well)
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
		var switch := _button(C.title(other), func(): open("place", place_id, other))
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
			ring.progress = clampf(1.0 - left / C.FIELD_SECONDS, 0, 1)
			ring.label = _time(left)
	elif item.kind == "orchard" and st.orchard_watered >= 0:
		var left := st.orchard_remaining(now)
		ring.progress = clampf(1.0 - left / C.ORCHARD_SECONDS, 0, 1)
		if left > 0: ring.label = _time(left)
	elif station != "" and st.jobs.has(station):
		var left := st.job_remaining(station, now)
		ring.progress = clampf(1.0 - float(left) / C.RECIPES[st.jobs[station].recipe].seconds, 0, 1)
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
			var box := frame_box(18, CREAM)
			box.border_color = GOLD
			box.shadow_size = 0
			box.set_content_margin_all(2 * s)
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
	tray.add_theme_stylebox_override("panel", frame_box(28))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(8 * s))
	tray.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(viewport.x - 190 * s, 1100 * s), 128 * s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * s))
	scroll.add_child(row)
	column.add_child(scroll)
	var level := game.host.progress()
	var entries: Array = C.BUILD_ORDER.duplicate()
	for side in C.LAND: entries.append(side)
	for key in entries:
		var is_land: bool = C.LAND.has(key)
		var spec: Dictionary = C.LAND[key] if is_land else C.BUILDS[key]
		var blocker := ""
		if is_land: blocker = "owned" if key in game.state.land else ("locked" if level < spec.gate else "")
		else: blocker = game.state.build_blocker(key, level)
		row.add_child(_build_tile(key, spec, blocker))
	if build_pick != "":
		var spec: Dictionary = C.LAND[build_pick] if C.LAND.has(build_pick) else C.BUILDS[build_pick]
		var confirm := HBoxContainer.new()
		confirm.alignment = BoxContainer.ALIGNMENT_CENTER
		confirm.add_theme_constant_override("separation", int(10 * s))
		var buy := _button("Build  %d" % spec.price, _confirm_build, game.host.wallet() >= int(spec.price), "coin")
		buy.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		buy.custom_minimum_size = Vector2(170, 52) * s
		confirm.add_child(buy)
		confirm.add_child(_button("Cancel", func(): build_pick = ""; main.spot_preview({}); _fill()))
		column.add_child(confirm)
	tray.reset_size()
	root.add_child(tray)
	tray.position = Vector2(12 * s, viewport.y - tray.get_combined_minimum_size().y - 14 * s)
	sheet_root = tray

func _build_tile(key: String, spec: Dictionary, blocker: String) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(112, 124) * s
	button.tooltip_text = C.title(key)
	var box := frame_box(20, CREAM if key != build_pick else Color("FFE7A3"))
	box.shadow_size = int(2 * s)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]: button.add_theme_stylebox_override(state, box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(2 * s))
	var picture := _icon(icons.get(key, icons["build"]), 74)
	if blocker in ["locked", "land", "full", "owned"]: picture.modulate = Color(1, 1, 1, 0.45)
	column.add_child(picture)
	var tag := HBoxContainer.new()
	tag.alignment = BoxContainer.ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.add_theme_font_size_override("font_size", int(18 * s))
	match blocker:
		"owned": label.text = "✓"
		"locked": tag.add_child(_icon(icons["star"], 20)); label.text = str(spec.gate)
		"land": tag.add_child(_icon(icons["west"], 22)); label.text = ""
		"full": label.text = "—"
		_: tag.add_child(_icon(icons["coin"], 20)); label.text = str(spec.price)
	tag.add_child(label)
	column.add_child(tag)
	button.add_child(column)
	button.pressed.connect(func(): _pick_build(key, blocker))
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
	var sheet_box := frame_box(28)
	if title == "Market": sheet_box.content_margin_top = 0
	sheet.add_theme_stylebox_override("panel", sheet_box)
	sheet.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(10 * s))
	sheet.add_child(column)
	if title == "Market":
		var awning := Awning.new()
		awning.ui = self
		awning.custom_minimum_size = Vector2(0, 46 * s)
		awning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(awning)
	var head := HBoxContainer.new()
	var ribbon := Ribbon.new()
	ribbon.ui = self
	ribbon.text = title
	ribbon.custom_minimum_size = Vector2(root.theme.default_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s)).x + 70 * s, 44 * s)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer_left := Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer_left)
	head.add_child(ribbon)
	var right_side := HBoxContainer.new()
	right_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(right_side)
	var close_button := _round_button("more", close, "Close")
	close_button.icon = null
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(46, 46) * s
	right_side.add_child(close_button)
	column.add_child(head)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(sheet)
	root.add_child(centre)
	sheet_root = centre
	sheet.custom_minimum_size = Vector2(minf(640 * s, viewport.x - 40 * s), 0)
	return column

func _fill_more() -> void:
	var game: WorldGame = main.game
	var market: bool = game.host.features().get("market", false)
	var column := _sheet("Market" if market else "Warehouse")
	var orders := game.state.open_orders()
	if market and not orders.is_empty():
		var board := HBoxContainer.new()
		board.add_theme_constant_override("separation", int(12 * s))
		board.alignment = BoxContainer.ALIGNMENT_CENTER
		for order in orders: board.add_child(_order_ticket(order))
		column.add_child(board)
		var rule := HSeparator.new()
		column.add_child(rule)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(14 * s))
	grid.add_theme_constant_override("v_separation", int(10 * s))
	column.add_child(grid)
	var any := false
	for good in C.GOODS:
		var count: int = game.state.stock.get(good, 0)
		if count <= 0: continue
		any = true
		var cell := PanelContainer.new()
		var box := frame_box(20, CREAM)
		box.shadow_size = int(2 * s)
		cell.add_theme_stylebox_override("panel", box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(10 * s))
		row.add_child(_icon(icons[good], 52))
		var amount := Label.new()
		amount.text = "×%d" % count
		amount.custom_minimum_size = Vector2(56, 0) * s
		amount.add_theme_font_size_override("font_size", int(22 * s))
		row.add_child(amount)
		if market:
			var sell: Button
			sell = _button("%d" % C.SELL_PRICE[good], func(): fly_from = sell.get_global_rect().get_center(); _act(game.sell(good, 1)), true, "coin")
			sell.tooltip_text = "Sell one"
			row.add_child(sell)
			if count > 1:
				var all: Button
				all = _button("All", func(): fly_from = all.get_global_rect().get_center(); _act(game.sell(good, count)))
				row.add_child(all)
		cell.add_child(row)
		grid.add_child(cell)
	if not any:
		var empty := HBoxContainer.new()
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.add_child(_icon(icons["wheat"], 56))
		var hint := Label.new()
		hint.text = "Grow wheat at the farm"
		empty.add_child(hint)
		column.add_child(empty)

## One order: a crate of goods for a bonus over the market price.
func _order_ticket(order: Dictionary) -> Control:
	var game: WorldGame = main.game
	var have: int = game.state.stock.get(order.good, 0)
	var ready: bool = have >= order.count
	var ticket := PanelContainer.new()
	var box := frame_box(22, CREAM)
	box.border_color = GOLD if ready else Color(0.78, 0.66, 0.45)
	box.set_border_width_all(int((4 if ready else 2) * s))
	ticket.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", int(4 * s))
	column.custom_minimum_size = Vector2(150, 0) * s
	var crate := HBoxContainer.new()
	crate.alignment = BoxContainer.ALIGNMENT_CENTER
	crate.add_child(_icon(icons.get(order.good), 60))
	var count := Label.new()
	count.text = "%d/%d" % [mini(have, order.count), order.count]
	count.add_theme_font_size_override("font_size", int(22 * s))
	if not ready: count.add_theme_color_override("font_color", Color(0.78, 0.2, 0.15))
	crate.add_child(count)
	column.add_child(crate)
	var deliver := _button("%d" % order.reward, func():
		var at := ticket.get_global_rect().get_center()
		fly_from = at
		_act(game.deliver(order.slot))
		if game.state.stock.get(order.good, 0) < have: sfx("celebrate"), ready, "coin")
	column.add_child(deliver)
	ticket.add_child(column)
	if not ready:
		ticket.mouse_filter = Control.MOUSE_FILTER_STOP
		ticket.gui_input.connect(func(e):
			if (e is InputEventMouseButton and not e.pressed) or (e is InputEventScreenTouch and not e.pressed): _open_source(order.good))
	return ticket

func _fill_land() -> void:
	open("build")
