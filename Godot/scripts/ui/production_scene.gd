class_name ProductionScene
extends Control

## The inside of a place, drawn in code and animated: a lamplit workroom with
## a conveyor that carries goods into the machine and products out to a tray,
## or the open field and orchard under the sky. It is also the drop target for
## goods and tools dragged from the card's left column. Display only: every
## state it shows comes from the saved game.

signal tapped
signal dropped(good: String)

var ui  # WorldUI: scale, icons, Reduce Motion
var kind := "mill"        # mill, oven, pantry, barn, grill, field, orchard, build
var inputs: Array = []    # goods the selected product needs
var filled := {}          # goods already dropped in
var output := ""          # the product
var quantity := 1
var working := false
var done := false
var progress := -1.0      # 0..1 while a timer runs
var label := ""           # time left, shown on the clock pill
var glow := false
var stages: Array = []    # field stages (field scene)
var tap_cue := false      # a tap does something now (start, collect, harvest): rings call for it
var hint_good := ""       # a good ready to go in: a faint copy shows the drag until one is held
var t := 0.0
var hover_until := 0.0

const WALL_TOP := Color("4A3426")
const WALL_LOW := Color("6E4C34")
const BEAM := Color("2E2019")
const FLOOR := Color("3A281D")
const RAIL := Color("2C211B")
const BELT := Color("1F1A17")
const BRASS := Color("E3B65A")
const SKY_TOP := Color("8FCBE6")
const SKY_LOW := Color("F7E8C4")
const HILL_FAR := Color("9CC889")
const HILL_NEAR := Color("6FA35E")
const SOIL := Color("7A5235")
const SOIL_DARK := Color("5C3C26")
const LAMP := Color(1.0, 0.82, 0.5)
# Depth (rung 3): one light from the upper left. Surfaces are lit at the top
# and fall into shade below; things sit on the floor through contact shadows;
# the scene reads as a window set into the card.
const LIT_TOP := 0.16       # how much a surface brightens at its top edge
const LIT_LOW := 0.26       # how much it darkens at its foot
const LIT_SIDE := 0.06      # extra light on the left, shade on the right
const RIM_ALPHA := 0.22     # the bright lip along a lit top edge
const CONTACT_ALPHA := 0.38 # soft shadow where a thing meets the ground
const AO_ALPHA := 0.32      # where the wall meets the floor
const LAMP_POOL := 0.16     # the lamp's warm pool on the floor
const HAZE := 0.3           # far hills fade toward the sky
const INSET_DEPTH := 22.0   # inner shadow along the window's top edge (pt)
const INSET_ALPHA := 0.42
const LIP_ALPHA := 0.12     # the window's lit bottom lip
# Life (rung 4): the room breathes while it works. Reduce Motion stills all of it.
const MOTES := 14           # dust motes drifting in the window's shaft (fixed pool)
const MOTE_ALPHA := 0.4
const MOTE_SIZE := 1.6      # pt
const MOOD_TIME := 0.6      # s for the working light to rise or fall
const MOOD_LAMP := 0.45     # how much brighter the lamp's pool gets while working
const FIRE_WASH := 0.08     # firelight flickering over the oven and grill rooms
const LAMP_SWAY := 0.03     # rad, the pendant's slow swing
const SWEEP_TIME := 0.9     # s for the finish light to run round the window
const SWEEP_ALPHA := 0.9
const SWEEP_SPAN := 0.16    # share of the rim lit at once
const BIRDS := 2            # far birds gliding over outdoor scenes

static var _vertical := {}
static var _radial: GradientTexture2D
# Kept per place across rebuilt windows, so light eases instead of jumping.
static var _moods := {}
static var _was_done := {}
static var _opened := {}   # kind -> when its window opened, for the drag hint's first delay
var mood := 0.0
var finish_at := -10.0

var opened_at := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The hint clock carries across rebuilt windows of the same place.
	opened_at = float(_opened.get(kind, _now()))
	_opened[kind] = opened_at

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	# One clock for every scene, so a rebuilt window carries on mid-motion.
	if not ui.reduce_motion: t = Time.get_ticks_msec() / 1000.0
	var target := 1.0 if working else 0.0
	mood = target if ui.reduce_motion else move_toward(float(_moods.get(kind, 0.0)), target, delta / MOOD_TIME)
	_moods[kind] = mood
	# A job that just finished sends one light round the window.
	if done and not bool(_was_done.get(kind, false)): finish_at = _now()
	_was_done[kind] = done
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var up: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if up: tapped.emit()

var hover_at := Vector2(-1, -1)
var hover_good := ""
var hover_valid := false
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("good")
	if not ok: return false
	hover_until = _now() + 0.15
	hover_at = at
	hover_good = str(data.good)
	var valid := wants(hover_good)
	# A light tick the moment a held good finds somewhere it can go.
	if valid and not hover_valid: ui.haptic(0.25); ui.sfx("tap", 1.5)
	hover_valid = valid
	return true
func _drop_data(at: Vector2, data: Variant) -> void:
	hover_until = 0.0
	hover_valid = false
	var good := str(data.good)
	if wants(good): ui.landed[good] = {"at": _now(), "from": get_global_transform() * at}
	else: ui.reject_drop(good, get_global_transform() * at)
	dropped.emit(good)
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END: hover_until = 0.0; hover_valid = false
	if what == NOTIFICATION_READY and not ui.reduce_motion: t = Time.get_ticks_msec() / 1000.0

static func _now() -> float: return Time.get_ticks_msec() / 1000.0
func wants(good: String) -> bool: return good in inputs and not filled.get(good, false) and not working and not done

## Where each input waits to be dropped, per scene.
func slot_point(i: int) -> Vector2:
	var k := _k()
	match kind:
		"field": return Vector2(size.x * (0.27 + 0.32 * i), size.y * 0.42)
		"orchard": return Vector2(size.x * 0.62, size.y * 0.72)
		"fishing": return Vector2(size.x * 0.33 + i * 56 * k, size.y * 0.5)
	return Vector2(size.x * 0.12 + i * 44.0 * k * 1.15, size.y * 0.69 - 44.0 * k * 0.42)

## The tray (or cart, bucket, jar) where products wait: goods fly home from here.
func tray_global() -> Vector2:
	var at := Vector2(size.x * 0.86, size.y * 0.6)
	match kind:
		"field": at = Vector2(size.x * 0.86, size.y * 0.7)
		"orchard": at = Vector2(size.x * 0.8, size.y * 0.72)
	return get_global_transform() * at

# --- shared paint ------------------------------------------------------------

static func _gradient(top: Color, low: Color, across := false) -> GradientTexture2D:
	var key := top.to_html() + low.to_html() + ("h" if across else "")
	if not _vertical.has(key):
		var g := Gradient.new()
		g.set_color(0, top); g.set_color(1, low)
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(1, 0) if across else Vector2(0, 1)
		tex.width = 128 if across else 4; tex.height = 4 if across else 128
		_vertical[key] = tex
	return _vertical[key]

static func _glow_tex() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5); _radial.fill_to = Vector2(1, 0.5)
		_radial.width = 128; _radial.height = 128
	return _radial

func _glow(at: Vector2, radius: Vector2, color: Color) -> void:
	draw_texture_rect(_glow_tex(), Rect2(at - radius, radius * 2), false, color)

func _ellipse(at: Vector2, radius: Vector2, color: Color, points := 40) -> void:
	var p := PackedVector2Array()
	for i in points: p.append(at + Vector2(cos(TAU * i / points) * radius.x, sin(TAU * i / points) * radius.y))
	draw_colored_polygon(p, color)

func _round_rect(rect: Rect2, radius: float, color: Color, border := Color(0, 0, 0, 0), width := 0.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing_size = 0.7
	if width > 0:
		box.border_color = border
		box.set_border_width_all(int(maxf(1, width)))
	draw_style_box(box, rect)

## A lit block: brighter along its top, shaded at its foot, with a bright lip.
func _lit_rect(rect: Rect2, color: Color, radius := 0.0) -> void:
	if radius > 0: _round_rect(rect, radius, color)
	else: draw_rect(rect, color)
	var inner := rect.grow_individual(-radius * 0.5, -radius * 0.25, -radius * 0.5, -radius * 0.25)
	if inner.size.x <= 0 or inner.size.y <= 0: return
	var top := Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45))
	draw_texture_rect(_gradient(Color(1, 1, 1, LIT_TOP), Color(1, 1, 1, 0)), top, false)
	var low := Rect2(inner.position + Vector2(0, inner.size.y * 0.4), Vector2(inner.size.x, inner.size.y * 0.6))
	draw_texture_rect(_gradient(Color(0, 0, 0, 0), Color(0, 0, 0, LIT_LOW)), low, false)
	draw_line(Vector2(inner.position.x, rect.position.y + _k()), Vector2(inner.end.x, rect.position.y + _k()), Color(1, 1, 1, RIM_ALPHA), maxf(1, 1.5 * _k()))

## A lit shape: each corner takes the light by its height and side.
func _lit_poly(points: PackedVector2Array, color: Color) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points: box = box.expand(p)
	var colors := PackedColorArray()
	for p in points:
		var v := (p.y - box.position.y) / maxf(1.0, box.size.y)
		var u := (p.x - box.position.x) / maxf(1.0, box.size.x)
		var c := color.lightened(LIT_TOP * (1.0 - v)) if v < 0.5 else color.darkened(LIT_LOW * (v - 0.5) * 2.0)
		colors.append(c.lightened(LIT_SIDE * (1.0 - u)) if u < 0.5 else c.darkened(LIT_SIDE * (u - 0.5) * 2.0))
	draw_polygon(points, colors)

## The soft dark where something stands on the ground.
func _contact(at: Vector2, half_width: float) -> void:
	_glow(at, Vector2(half_width, half_width * 0.2), Color(0, 0, 0, CONTACT_ALPHA))

func _good(good: String, at: Vector2, side: float, alpha := 1.0) -> void:
	var tex: Texture2D = ui.icons.get(good)
	if tex == null: return
	_ellipse(at + Vector2(0, side * 0.42), Vector2(side * 0.34, side * 0.09), Color(0, 0, 0, 0.28 * alpha))
	draw_texture_rect(tex, Rect2(at - Vector2(side, side) / 2, Vector2(side, side)), false, Color(1, 1, 1, alpha))

func _k() -> float: return ui.s

# --- the scene ---------------------------------------------------------------

func _draw() -> void:
	match kind:
		"field", "orchard", "fishing", "hive": _draw_outdoors()
		"greenhouse": _draw_greenhouse()
		_: _draw_workroom()
	if not working and not done and kind != "build":
		_draw_slots()
		_draw_drag_hint()
	elif working: _draw_last_drop()
	_draw_tap_cue()
	_draw_bursts()
	_draw_inset()
	_draw_clock_pill()
	if hover_until > _now():
		# A held good over the scene: gold when it can go in, a cool rim when not.
		var rim := WorldUI.GOLD if hover_valid else Color(1, 1, 1, 0.5)
		_round_rect(Rect2(Vector2(3, 3) * _k(), size - Vector2(6, 6) * _k()), 22 * _k(), Color(0, 0, 0, 0), Color(rim, 0.9), 3 * _k())
		if hover_valid: _glow(size / 2, size * 0.6, Color(WorldUI.GOLD, 0.1))

## The scene sits behind the card's surface: shadow falls in from the top and
## sides, and the bottom lip catches the light.
func _draw_inset() -> void:
	var k := _k()
	var d := INSET_DEPTH * k
	draw_texture_rect(_gradient(Color(0, 0, 0, INSET_ALPHA), Color(0, 0, 0, 0)), Rect2(0, 0, size.x, d), false)
	draw_texture_rect(_gradient(Color(0, 0, 0, INSET_ALPHA * 0.6), Color(0, 0, 0, 0), true), Rect2(0, 0, d * 0.7, size.y), false)
	draw_texture_rect(_gradient(Color(0, 0, 0, 0), Color(0, 0, 0, INSET_ALPHA * 0.6), true), Rect2(size.x - d * 0.7, 0, d * 0.7, size.y), false)
	draw_line(Vector2(24 * k, size.y - 1.5 * k), Vector2(size.x - 24 * k, size.y - 1.5 * k), Color(1, 1, 1, LIP_ALPHA), maxf(1, 1.5 * k))
	var e := (_now() - finish_at) / SWEEP_TIME
	if e >= 0 and e < 1:
		if ui.reduce_motion:
			# Still: the rim simply warms and fades.
			_round_rect(Rect2(Vector2(2, 2) * k, size - Vector2(4, 4) * k), 22 * k, Color(0, 0, 0, 0), Color(WorldUI.GOLD, SWEEP_ALPHA * (1.0 - e)), 3 * k)
		else:
			var trail := PackedVector2Array()
			var head := ease(e, 0.6)
			for i in 25:
				trail.append(_rim_point(head - SWEEP_SPAN * (1.0 - i / 24.0), 3 * k))
			var fade := minf(1.0, (1.0 - e) * 3.0)
			draw_polyline(trail, Color(WorldUI.GOLD, SWEEP_ALPHA * fade * 0.45), 8 * k, true)
			draw_polyline(trail, Color(1, 0.97, 0.85, SWEEP_ALPHA * fade), 3 * k, true)

## A point a share u of the way round the window's edge, clockwise from the top middle.
func _rim_point(u: float, inset: float) -> Vector2:
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2)
	var perimeter := (r.size.x + r.size.y) * 2
	var d := fposmod(u, 1.0) * perimeter
	var half := r.size.x / 2
	if d < half: return Vector2(r.get_center().x + d, r.position.y)
	d -= half
	if d < r.size.y: return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x: return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	if d < r.size.y: return Vector2(r.position.x, r.end.y - d)
	return Vector2(r.position.x + d, r.position.y)

## A good or a field tool, with an optional squash.
func _item(good: String, at: Vector2, side: float, alpha := 1.0, squash := Vector2.ONE) -> void:
	_ellipse(at + Vector2(0, side * 0.42), Vector2(side * 0.34 * squash.x, side * 0.09), Color(0, 0, 0, 0.28 * alpha))
	draw_set_transform(at + Vector2(0, side * 0.4), 0, squash)
	var local := Vector2(0, -side * 0.4)
	if good in ["seed", "water"]: _tool(good, local, side, alpha)
	else:
		var tex: Texture2D = ui.icons.get(good)
		if tex: draw_texture_rect(tex, Rect2(local - Vector2(side, side) / 2, Vector2(side, side)), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _tool(tool: String, c: Vector2, side: float, alpha: float) -> void:
	var r := side * 0.38
	if tool == "water":
		var points := PackedVector2Array()
		for i in 33:
			var a := float(i) / 32.0 * TAU
			var y := -cos(a)
			var x := sin(a) * (1.0 - 0.55 * maxf(0, y))
			points.append(c + Vector2(x * r * 0.85, y * r * -1.15 + r * 0.25))
		draw_colored_polygon(points, Color("5BA8D8", alpha))
		draw_polyline(points, Color("2F6F9E", alpha), 3.0, true)
		draw_circle(c + Vector2(-r * 0.28, r * 0.1), r * 0.16, Color(1, 1, 1, 0.7 * alpha))
	else:
		draw_circle(c + Vector2(0, r * 0.2), r * 0.85, Color("C08A4E", alpha))
		draw_arc(c + Vector2(0, r * 0.2), r * 0.85, 0, TAU, 48, Color("7A5028", alpha), 3.0, true)
		draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.85), Vector2(r * 0.9, r * 0.35)), Color("9E6B38", alpha))
		for offset in [Vector2(-0.3, 0.2), Vector2(0.25, 0.05), Vector2(0.05, 0.5)]:
			draw_circle(c + offset * r, r * 0.13, Color("F3D98B", alpha))

const LAND_TIME := 0.42
const SETTLE_TIME := 0.38
## Inputs waiting to be dropped (breathing ghosts that reach for a held good),
## and dropped ones flying in, landing with a squash and a puff of dust.
func _draw_slots() -> void:
	var k := _k()
	var side := 44.0 * k if kind not in ["field", "orchard"] else 58.0 * k
	var now := _now()
	for i in inputs.size():
		var good: String = inputs[i]
		var at := slot_point(i)
		if filled.get(good, false):
			var land: Dictionary = ui.landed.get(good, {})
			var e: float = now - float(land.get("at", -10.0))
			if ui.reduce_motion or e > LAND_TIME + SETTLE_TIME + 0.6:
				_item(good, at, side)
				continue
			if e < LAND_TIME:
				# An arc from where the finger let go, easing in and shrinking to size.
				var from: Vector2 = get_global_transform().affine_inverse() * land.get("from", get_global_transform() * Vector2(-40 * k, at.y))
				var u := ease(e / LAND_TIME, 0.6)
				var peak := (from + at) / 2 - Vector2(0, 70 * k + from.distance_to(at) * 0.15)
				var p := from.lerp(peak, u).lerp(peak.lerp(at, u), u)
				_item(good, p, side * lerpf(1.3, 1.0, u), 1.0, Vector2(1, 1).lerp(Vector2(0.92, 1.1), sin(u * PI)))
			else:
				var e2 := e - LAND_TIME
				var wob := 0.0 if e2 > SETTLE_TIME else sin(e2 / SETTLE_TIME * PI * 2.0) * (1.0 - e2 / SETTLE_TIME) * 0.22
				_item(good, at, side, 1.0, Vector2(1.0 + wob, 1.0 - wob))
				_landing_fx(good, at, e2, side)
		else:
			_ghost_slot(good, at, side, i)

const HINT_CYCLE := 2.8   # s between hint glides
const HINT_DELAY := 1.2   # s after opening before the first one
## The way in: a faint copy of a ready good lifts off the left edge and glides
## along an arc into its slot, then the slot ring flashes. It stops the moment
## a good is held, and Reduce Motion leaves the still ghost slots alone.
func _draw_drag_hint() -> void:
	if ui.reduce_motion or hint_good == "" or hover_until > _now() or ui.get_viewport().gui_is_dragging(): return
	var i := inputs.find(hint_good)
	if i < 0 or filled.get(hint_good, false): return
	var k := _k()
	var e := _now() - opened_at - HINT_DELAY
	if e < 0: return
	var u := fposmod(e, HINT_CYCLE) / HINT_CYCLE
	if u > 0.62: return
	var v := ease(u / 0.62, -1.8)
	var to := slot_point(i)
	var from := Vector2(-10 * k, to.y + 30 * k)
	var peak := (from + to) / 2 - Vector2(0, 60 * k)
	var p := from.lerp(peak, v).lerp(peak.lerp(to, v), v)
	var alpha := sin(v * PI) * 0.75 + (0.25 if v > 0.9 else 0.0)
	# A trail of small dots behind it, and a fingertip under it.
	for d in 6:
		var w := clampf(v - 0.05 * (d + 1), 0, 1)
		var q := from.lerp(peak, w).lerp(peak.lerp(to, w), w)
		draw_circle(q, (3.2 - d * 0.4) * k, Color(WorldUI.GOLD, alpha * (0.5 - d * 0.07)))
	draw_circle(p + Vector2(10, 18) * k, 11 * k, Color(1, 1, 1, alpha * 0.22))
	draw_arc(p + Vector2(10, 18) * k, 11 * k, 0, TAU, 24, Color(1, 1, 1, alpha * 0.55), 1.5 * k, true)
	_item(hint_good, p, 44 * k, alpha)
	if v > 0.88: _glow(to, Vector2(60, 60) * k, Color(WorldUI.GOLD, (v - 0.88) * 3.0))

## A tap does something now: two soft rings ripple out from the machine (or
## the beds and tree) and the machine breathes, so a card with no buttons
## still says "tap me".
func _draw_tap_cue() -> void:
	if not tap_cue: return
	var k := _k()
	var at := machine_point()
	if done and kind not in ["field", "orchard"]: at = get_global_transform().affine_inverse() * tray_global()
	if ui.reduce_motion:
		draw_arc(at, 58 * k, 0, TAU, 48, Color(WorldUI.GOLD, 0.7), 3 * k, true)
		return
	for ring in 2:
		var u := fposmod(t / 1.5 + ring * 0.5, 1.0)
		draw_arc(at, (36 + 70 * ease(u, 0.5)) * k, 0, TAU, 56, Color(WorldUI.GOLD, 0.6 * (1.0 - u)), (4 - 3 * u) * k, true)

## The good that completed the set flies on into the machine as it starts.
func _draw_last_drop() -> void:
	if ui.reduce_motion: return
	var k := _k()
	for good in inputs:
		var land: Dictionary = ui.landed.get(good, {})
		var e: float = _now() - float(land.get("at", -10.0))
		if e < 0 or e > 0.55: continue
		var from: Vector2 = get_global_transform().affine_inverse() * land.get("from", get_global_transform() * Vector2(-40 * k, size.y / 2))
		var to := machine_point()
		var u := ease(e / 0.55, 0.5)
		var peak := (from + to) / 2 - Vector2(0, 80 * k)
		var p := from.lerp(peak, u).lerp(peak.lerp(to, u), u)
		_item(good, p, 50 * k * lerpf(1.3, 0.5, u), 1.0 - u * 0.6)

func _ghost_slot(good: String, at: Vector2, side: float, i: int) -> void:
	var k := _k()
	var pulse := 0.5 + 0.5 * sin(t * 3.0 + i)
	var reach := 0.0
	if hover_until > _now() and hover_good == good:
		# The slot leans toward the held good: it swells and lights as it nears.
		reach = clampf(1.0 - hover_at.distance_to(at) / (size.x * 0.6), 0.0, 1.0)
		var dots := 9
		for d in dots:
			var u := fposmod(float(d) / dots + t * 1.2, 1.0)
			var mid := (hover_at + at) / 2 - Vector2(0, 40 * k)
			var p := hover_at.lerp(mid, u).lerp(mid.lerp(at, u), u)
			draw_circle(p, (2.0 + 2.0 * u) * k, Color(WorldUI.GOLD, 0.25 + 0.6 * u))
	var r := side * (0.55 + 0.25 * reach)
	if reach > 0: _glow(at, Vector2(r, r) * 2.0, Color(WorldUI.GOLD, 0.35 * reach + 0.15))
	draw_arc(at + Vector2(0, 2 * k), r, 0, TAU, 40, Color(WorldUI.GOLD, 0.35 + 0.35 * pulse + 0.3 * reach), (2 + 2 * reach) * k, true)
	# Dashes turn slowly around the ring: a place waiting to be filled.
	for d in 12:
		var a := t * 0.6 + TAU * d / 12.0
		draw_arc(at + Vector2(0, 2 * k), r + 6 * k, a, a + 0.22, 6, Color(WorldUI.GOLD, 0.3 + 0.2 * pulse), 1.5 * k, true)
	_item(good, at, side * (0.86 + 0.14 * reach), 0.3 + 0.45 * reach)

func _landing_fx(good: String, at: Vector2, e: float, side: float) -> void:
	var k := _k()
	if e < 0.5:
		var u := e / 0.5
		draw_arc(at, side * (0.4 + 0.9 * u), 0, TAU, 40, Color(WorldUI.GOLD, 0.7 * (1.0 - u)), 3 * k * (1.0 - u) + 0.5, true)
		for d in 7:
			var a := PI + PI * d / 6.0
			var p := at + Vector2(0, side * 0.4) + Vector2(cos(a) * side * (0.3 + 0.6 * u), sin(a) * side * 0.25 * u - 10 * k * u)
			draw_circle(p, (5 - 3 * u) * k, Color(0.95, 0.88, 0.72, 0.6 * (1.0 - u)))
	if kind == "field" and e < 1.1:
		# Seeds scatter into the beds; water falls on them as a bright shower.
		var u := e / 1.1
		for d in 18:
			var bed := Vector2(size.x * (0.18 + 0.035 * d), size.y * (0.66 + 0.04 * (d % 3)))
			var lead := clampf(u * 1.6 - d * 0.03, 0, 1)
			if lead <= 0 or lead >= 1: continue
			var p := at.lerp(bed, lead) - Vector2(0, sin(lead * PI) * 40 * k)
			if good == "seed": draw_circle(p, 3 * k, Color("F3D98B", 1.0 - lead * 0.5))
			else: draw_line(p, p + Vector2(-1, 7) * k, Color(0.6, 0.85, 1.0, 0.85 * (1.0 - lead)), 2.5 * k)
	if kind == "orchard" and good == "water" and e < 1.0:
		var u := e / 1.0
		for d in 8:
			var p := at + Vector2((d - 4) * 10 * k, u * 30 * k + (d % 3) * 6 * k)
			draw_circle(p, 2.5 * k, Color(0.6, 0.85, 1.0, 0.8 * (1.0 - u)))

## Starting, collecting and taps on a working place kick the machine and throw
## sparks: the place answers every touch.
func _draw_bursts() -> void:
	if ui.reduce_motion: return
	var k := _k()
	var centre := machine_point()
	for key in ["burst_at", "poke_at"]:
		var e: float = _now() - float(ui.get(key))
		var length := 0.9 if key == "burst_at" else 0.5
		if e < 0 or e > length: continue
		var u := e / length
		draw_arc(centre, (40 + 200 * u) * k, 0, TAU, 64, Color(WorldUI.GOLD, 0.6 * (1.0 - u)), (5 - 4 * u) * k, true)
		var count := 12 if key == "burst_at" else 7
		for d in count:
			var a := TAU * d / count + (0.3 if key == "poke_at" else 0.0)
			var p := centre + Vector2.from_angle(a) * (30 + 150 * ease(u, 0.4)) * k
			_sparkle(p, (4.0 * (1.0 - u) + 1.0) * k)

func machine_point() -> Vector2:
	match kind:
		"field": return Vector2(size.x * 0.4, size.y * 0.7)
		"orchard": return Vector2(size.x * 0.42, size.y * 0.5)
		"fishing": return Vector2(size.x * 0.55, size.y * 0.68)
		"hive": return Vector2(size.x * 0.5, size.y * 0.55)
		"greenhouse": return Vector2(size.x * 0.48, size.y * 0.55)
	return Vector2(size.x * 0.5, size.y * 0.5)

## How much the machine is kicked right now (a quick scale punch).
func _kick() -> float:
	if ui.reduce_motion: return 1.0
	var best := 1.0
	for key in ["burst_at", "poke_at"]:
		var e: float = _now() - float(ui.get(key))
		if e >= 0 and e < 0.35: best = maxf(best, 1.0 + 0.07 * sin(e / 0.35 * PI))
	return best

func _draw_workroom() -> void:
	var k := _k()
	var w := size.x
	var h := size.y
	var floor_y := h * 0.76
	draw_texture_rect(_gradient(WALL_TOP, WALL_LOW), Rect2(0, 0, w, floor_y), false)
	# Board seams and a ceiling beam.
	var seam := 52.0 * k
	var x := fmod(w / 2, seam)
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, floor_y), Color(0, 0, 0, 0.16), maxf(1, 1.5 * k))
		draw_line(Vector2(x + 1.5 * k, 0), Vector2(x + 1.5 * k, floor_y), Color(1, 1, 1, 0.035), maxf(1, k))
		x += seam
	draw_rect(Rect2(0, h * 0.06, w, 14 * k), BEAM)
	draw_rect(Rect2(0, h * 0.06, w, 2 * k), Color(1, 1, 1, 0.08))
	# A window on the left with a soft shaft of daylight across the room.
	var win := Rect2(w * 0.07, h * 0.16, w * 0.15, h * 0.3)
	var shaft := PackedVector2Array([win.position + Vector2(0, win.size.y * 0.2), win.end - Vector2(0, win.size.y * 0.05),
		Vector2(win.end.x + w * 0.22, floor_y + h * 0.1), Vector2(win.position.x + w * 0.1, floor_y + h * 0.1)])
	draw_colored_polygon(shaft, Color(1, 0.95, 0.8, 0.07))
	if not ui.reduce_motion:
		# Dust turning slowly in the daylight.
		for i in MOTES:
			var u := fposmod(t * 0.025 + i * 0.618, 1.0)
			var across := fposmod(i * 0.381, 1.0)
			var top := win.position.lerp(win.end, across)
			var low := Vector2(win.position.x + w * 0.1, floor_y).lerp(Vector2(win.end.x + w * 0.22, floor_y), across)
			var p := top.lerp(low, u) + Vector2(sin(t * 0.6 + i * 1.7) * 6 * k, 0)
			draw_circle(p, MOTE_SIZE * k * (0.7 + 0.5 * fposmod(i * 0.29, 1.0)), Color(1, 0.96, 0.82, MOTE_ALPHA * sin(PI * u)))
	_round_rect(win.grow(5 * k), 8 * k, Color("2A1D15"))
	draw_texture_rect(_gradient(SKY_TOP, SKY_LOW), win, false)
	var hill := PackedVector2Array([Vector2(win.position.x, win.end.y)])
	for i in 13: hill.append(Vector2(win.position.x + win.size.x * i / 12.0, win.end.y - win.size.y * (0.16 + 0.1 * sin(i * 0.5))))
	hill.append(win.end)
	draw_colored_polygon(hill, HILL_FAR)
	draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), Color("2A1D15"), 4 * k)
	draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), Color("2A1D15"), 4 * k)
	draw_rect(Rect2(win.position.x - 8 * k, win.end.y + 4 * k, win.size.x + 16 * k, 6 * k), Color("5A3E2C"))
	# A pendant lamp over the machine, its pool of warm light on the wall.
	var lamp := Vector2(w * (0.68 if kind == "mill" else 0.5), h * 0.13)
	var swing := 0.0 if ui.reduce_motion else sin(t * 0.8) * LAMP_SWAY
	lamp += Vector2(sin(swing), cos(swing) - 1.0) * (lamp.y - h * 0.06)
	var flicker := 1.0 + (0.04 * sin(t * 7.3) + 0.03 * sin(t * 13.1)) * mood
	_glow(Vector2(w * 0.5 + (lamp.x - w * (0.68 if kind == "mill" else 0.5)) * 2.0, h * 0.42), Vector2(w * 0.42, h * 0.5) * flicker, Color(LAMP, 0.32 * (1.0 + MOOD_LAMP * mood)))
	draw_line(Vector2(lamp.x, h * 0.06), lamp, Color("1C1410"), 2 * k)
	draw_colored_polygon(PackedVector2Array([lamp + Vector2(-16, 12) * k, lamp + Vector2(16, 12) * k, lamp + Vector2(8, 0) * k, lamp + Vector2(-8, 0) * k]), Color("C98A1C"))
	_ellipse(lamp + Vector2(0, 13 * k), Vector2(7, 4) * k, Color(1, 0.93, 0.7))
	# Floor boards in gentle perspective.
	draw_texture_rect(_gradient(FLOOR.lightened(0.1), FLOOR.darkened(0.4)), Rect2(0, floor_y, w, h - floor_y), false)
	_glow(Vector2(lamp.x, floor_y + (h - floor_y) * 0.45), Vector2(w * 0.32, (h - floor_y) * 0.6), Color(LAMP, LAMP_POOL))
	draw_texture_rect(_gradient(Color(0, 0, 0, 0), Color(0, 0, 0, AO_ALPHA)), Rect2(0, floor_y - 18 * k, w, 18 * k), false)
	draw_texture_rect(_gradient(Color(0, 0, 0, AO_ALPHA), Color(0, 0, 0, 0)), Rect2(0, floor_y, w, 12 * k), false)
	draw_rect(Rect2(0, floor_y, w, 1.5 * k), Color(1, 1, 1, 0.06))
	for i in 9:
		var fx := w * (i + 0.5) / 9.0
		draw_line(Vector2(fx, floor_y), Vector2(w / 2 + (fx - w / 2) * 1.6, h), Color(0, 0, 0, 0.22), maxf(1, 1.2 * k))
	# Machine and belt.
	var belt_y := h * 0.69
	var machine := Vector2(w * 0.5, belt_y)
	_contact(Vector2(machine.x, h * 0.9), w * 0.2)
	_draw_belt(belt_y)
	var kick := _kick()
	draw_set_transform(machine * (1.0 - kick), 0, Vector2(kick, kick))
	match kind:
		"workshop": _draw_workshop(machine)
		"mill": _draw_mill(machine)
		"oven": _draw_oven(machine)
		"pantry": _draw_pantry(machine)
		"barn": _draw_barn(machine)
		"grill": _draw_grill(machine)
		"build": _draw_build(machine)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_draw_goods_on_belt(belt_y, machine)
	_draw_tray(Vector2(w * 0.86, belt_y))
	if kind in ["oven", "grill"] and mood > 0:
		# Firelight plays over the whole room while it bakes or grills.
		var dance := 0.75 + 0.15 * sin(t * 6.1) + 0.1 * sin(t * 11.7)
		_glow(machine + Vector2(0, -h * 0.1), Vector2(w * 0.62, h * 0.7), Color(1, 0.55, 0.2, FIRE_WASH * mood * dance))
	# Corners fall into shadow: depth, and the frame reads as a window.
	_glow(Vector2(0, 0), Vector2(w * 0.35, h * 0.45), Color(0, 0, 0, 0.35))
	_glow(Vector2(w, 0), Vector2(w * 0.35, h * 0.45), Color(0, 0, 0, 0.35))
	_glow(Vector2(0, h), Vector2(w * 0.3, h * 0.35), Color(0, 0, 0, 0.3))
	_glow(Vector2(w, h), Vector2(w * 0.3, h * 0.35), Color(0, 0, 0, 0.3))

func _draw_belt(y: float) -> void:
	var k := _k()
	var x0 := size.x * 0.05
	var x1 := size.x * 0.95
	var band := 18.0 * k
	# Trestle legs and the belt's shadow on the floor.
	for lx in [x0 + 24 * k, size.x * 0.5, x1 - 24 * k]:
		_lit_rect(Rect2(lx - 4 * k, y + band * 0.5, 8 * k, size.y * 0.2), Color("2E2116"))
		_contact(Vector2(lx, y + band * 0.5 + size.y * 0.2), 12 * k)
	_ellipse(Vector2(size.x / 2, size.y * 0.93), Vector2(size.x * 0.46, 10 * k), Color(0, 0, 0, 0.25))
	# Rail, belt surface with sliding slats, brass trim and rivets.
	_lit_rect(Rect2(x0, y - band * 0.5, x1 - x0, band * 1.35), RAIL, band * 0.6)
	_round_rect(Rect2(x0 + 6 * k, y - band * 0.5, x1 - x0 - 12 * k, band * 0.8), band * 0.4, BELT)
	var step := 16.0 * k
	var shift := fmod(t * (46.0 * k if working else 0.0), step)
	var sx := x0 + 10 * k + shift
	while sx < x1 - 10 * k:
		draw_line(Vector2(sx, y - band * 0.42), Vector2(sx - 4 * k, y + band * 0.22), Color(1, 1, 1, 0.07), 2 * k)
		sx += step
	draw_line(Vector2(x0 + band * 0.5, y - band * 0.5), Vector2(x1 - band * 0.5, y - band * 0.5), Color(BRASS, 0.85), 2 * k)
	draw_line(Vector2(x0 + band * 0.5, y + band * 0.78), Vector2(x1 - band * 0.5, y + band * 0.78), Color(BRASS, 0.35), 1.5 * k)
	var rx := x0 + 30 * k
	while rx < x1 - 20 * k:
		draw_circle(Vector2(rx, y + band * 0.5), 2 * k, Color(BRASS, 0.7))
		rx += 38 * k
	# End rollers turn with the belt.
	for end in [x0 + band * 0.55, x1 - band * 0.55]:
		var c := Vector2(end, y + band * 0.18)
		draw_circle(c, band * 0.62, Color("3B2C22"))
		draw_arc(c, band * 0.62, 0, TAU, 24, Color(BRASS, 0.8), 1.5 * k, true)
		for i in 3:
			var a := t * (3.0 if working else 0.0) + TAU * i / 3.0
			draw_line(c, c + Vector2.from_angle(a) * band * 0.5, Color(BRASS, 0.6), 1.5 * k)
		draw_circle(c, 2.5 * k, BRASS)

## Goods ride the belt into the machine while it works, and wait at the start
## (or as ghosts asking to be dropped) while it doesn't.
func _draw_goods_on_belt(y: float, machine: Vector2) -> void:
	var k := _k()
	var side := 44.0 * k
	var start := size.x * 0.12
	var entry := machine.x - size.x * 0.14
	var exit := machine.x + size.x * 0.13
	var tray := size.x * 0.8
	var ride := y - side * 0.42
	if working:
		var list := inputs if not inputs.is_empty() else ["wheat"]
		var n := maxi(2, list.size() * 2)
		for i in n:
			var u := fposmod(t / 3.2 + float(i) / n, 1.0)
			var a := clampf(u / 0.12, 0, 1) * clampf((1.0 - u) / 0.18, 0, 1)
			_good(list[i % list.size()], Vector2(lerpf(start, entry, u), ride), side * (1.0 - 0.25 * clampf((u - 0.75) / 0.25, 0, 1)), a)
		if output != "":
			for i in 2:
				var u := fposmod(t / 3.2 + i * 0.5 + 0.25, 1.0)
				var a := clampf(u / 0.15, 0, 1) * clampf((1.0 - u) / 0.15, 0, 1)
				_good(output, Vector2(lerpf(exit, tray, u), ride), side * (0.8 + 0.2 * clampf(u / 0.2, 0, 1)), a)
		return

func _draw_tray(at: Vector2) -> void:
	var k := _k()
	var plate := Rect2(at.x - 38 * k, at.y - 8 * k, 76 * k, 14 * k)
	_round_rect(plate.grow(2 * k), 9 * k, Color("2A1D15"))
	_lit_rect(plate, Color("8A5E3C"), 8 * k)
	if not done or output == "": return
	var lift := 0.0 if ui.reduce_motion else sin(t * 2.4) * 4 * k
	_glow(at - Vector2(0, 34 * k), Vector2(70, 70) * k, Color(WorldUI.GOLD, 0.55))
	var side := 64.0 * k
	_good(output, at - Vector2(0, 34 * k + lift), side)
	for i in 5:
		var a := t * 1.4 + TAU * i / 5.0
		var p := at - Vector2(0, 34 * k) + Vector2(cos(a) * 46 * k, sin(a) * 30 * k)
		_sparkle(p, (3.0 + 2.0 * sin(t * 4 + i)) * k)

func _sparkle(at: Vector2, r: float) -> void:
	var c := Color(1, 0.96, 0.75, 0.9)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r * 2), at + Vector2(r * 0.5, 0), at + Vector2(0, r * 2), at + Vector2(-r * 0.5, 0)]), c)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 2, 0), at + Vector2(0, r * 0.5), at + Vector2(r * 2, 0), at + Vector2(0, -r * 0.5)]), c)

# --- machines ----------------------------------------------------------------

func _draw_mill(base: Vector2) -> void:
	var k := _k()
	# The great gear behind turns with the sails outside.
	var hub := base + Vector2(0, -size.y * 0.36)
	var r := size.y * 0.25
	var spin := t * (0.9 if working else 0.08)
	for i in 16:
		var a := spin + TAU * i / 16.0
		var tooth := PackedVector2Array([hub + Vector2.from_angle(a - 0.08) * r * 0.98, hub + Vector2.from_angle(a - 0.06) * r * 1.12,
			hub + Vector2.from_angle(a + 0.06) * r * 1.12, hub + Vector2.from_angle(a + 0.08) * r * 0.98])
		draw_colored_polygon(tooth, Color("5E3F2A"))
	draw_arc(hub, r * 0.9, 0, TAU, 64, Color("6E4A31"), r * 0.18, true)
	draw_arc(hub, r * 0.99, 0, TAU, 64, Color(1, 1, 1, 0.06), 1.5 * k, true)
	for i in 6:
		var a := spin + TAU * i / 6.0
		draw_line(hub, hub + Vector2.from_angle(a) * r * 0.82, Color("5A3C28"), 7 * k)
	draw_circle(hub, r * 0.16, Color("3F2B1E"))
	draw_circle(hub, r * 0.07, BRASS)
	# Hopper pouring grain into the stones.
	var stone := base + Vector2(0, -size.y * 0.12)
	var hop_top := stone + Vector2(0, -size.y * 0.32)
	_lit_poly(PackedVector2Array([hop_top + Vector2(-34, 0) * k, hop_top + Vector2(34, 0) * k, hop_top + Vector2(9, 34) * k, hop_top + Vector2(-9, 34) * k]), Color("A0703F"))
	draw_line(hop_top + Vector2(-34, 0) * k, hop_top + Vector2(34, 0) * k, Color("C99A5B"), 3 * k)
	if working:
		for i in 7:
			var u := fposmod(t * 1.6 + i / 7.0, 1.0)
			draw_circle(hop_top + Vector2(sin(i * 2.1) * 3 * k, 36 * k + u * (size.y * 0.1)), 2.2 * k, Color(WorldUI.GOLD, 1.0 - u))
	# Two stones on a wooden tub; the upper stone turns.
	_lit_rect(Rect2(stone.x - 62 * k, stone.y + 4 * k, 124 * k, base.y - stone.y - 10 * k), Color("8A5A3B"), 10 * k)
	for i in 3: draw_line(Vector2(stone.x - 62 * k, stone.y + (16 + i * 14) * k), Vector2(stone.x + 62 * k, stone.y + (16 + i * 14) * k), Color(0, 0, 0, 0.18), 2 * k)
	_ellipse(stone + Vector2(0, 4 * k), Vector2(58, 14) * k, Color("8F887D"))
	_ellipse(stone, Vector2(54, 13) * k, Color("BDB5A8"))
	var turn := t * (2.2 if working else 0.0)
	for i in 6:
		var a := turn + TAU * i / 6.0
		draw_line(stone, stone + Vector2(cos(a) * 50 * k, sin(a) * 11 * k), Color(0, 0, 0, 0.16), 1.5 * k)
	_ellipse(stone, Vector2(9, 3) * k, Color("6E675D"))
	if working:
		for i in 4:
			var u := fposmod(t * 0.7 + i / 4.0, 1.0)
			draw_circle(stone + Vector2(-40 * k + i * 26 * k, -u * 40 * k), (3 + u * 5) * k, Color(1, 0.98, 0.92, 0.35 * (1.0 - u)))

func _draw_oven(base: Vector2) -> void:
	var k := _k()
	var c := base + Vector2(0, -12 * k)
	var r := size.y * 0.33
	# Chimney and its smoke.
	_lit_rect(Rect2(c.x + r * 0.35, c.y - r * 1.35, r * 0.28, r * 0.6), Color("8C3F2A"))
	draw_rect(Rect2(c.x + r * 0.32, c.y - r * 1.38, r * 0.34, r * 0.08), Color("6E2F1F"))
	if working:
		for i in 4:
			var u := fposmod(t * 0.35 + i / 4.0, 1.0)
			draw_circle(Vector2(c.x + r * 0.49 + sin(u * 5 + i) * 8 * k, c.y - r * 1.4 - u * size.y * 0.2), (6 + u * 12) * k, Color(0.9, 0.88, 0.85, 0.28 * (1.0 - u)))
	# A brick dome on a stone plinth.
	_lit_rect(Rect2(c.x - r * 1.15, c.y - 4 * k, r * 2.3, base.y - c.y + 10 * k), Color("7E756A"))
	var dome := PackedVector2Array()
	for i in 33: dome.append(c + Vector2.from_angle(PI + PI * i / 32.0) * r * Vector2(1.05, 1.0))
	_lit_poly(dome, Color("B5583A"))
	for row in 4:
		var rr := r * (0.36 + row * 0.2)
		draw_arc(c, rr, PI, TAU, 40, Color(0, 0, 0, 0.18), 1.5 * k, true)
		var count := 4 + row * 2
		for j in count:
			var a := PI + PI * (j + (0.5 if row % 2 == 0 else 0.0)) / count
			draw_line(c + Vector2.from_angle(a) * (rr - r * 0.2), c + Vector2.from_angle(a) * rr, Color(0, 0, 0, 0.15), 1.5 * k)
	draw_arc(c, r * 1.02, PI, TAU, 48, Color(1, 1, 1, 0.12), 2 * k, true)
	# The mouth: dark, then a fire that breathes while baking.
	var mouth := PackedVector2Array()
	for i in 21: mouth.append(c + Vector2.from_angle(PI + PI * i / 20.0) * r * 0.42)
	draw_colored_polygon(mouth, Color("2A1410"))
	if working:
		var breathe := 0.75 + 0.15 * sin(t * 6.1) + 0.1 * sin(t * 11.7)
		_glow(c + Vector2(0, -r * 0.12), Vector2(r * 0.9, r * 0.6) * breathe, Color(1, 0.55, 0.15, 0.8))
		for i in 5:
			var fx := c.x + (i - 2) * r * 0.13
			var fh := r * (0.18 + 0.1 * sin(t * 8 + i * 1.7))
			draw_colored_polygon(PackedVector2Array([Vector2(fx - r * 0.07, c.y), Vector2(fx, c.y - fh), Vector2(fx + r * 0.07, c.y)]), Color(1, 0.78 if i % 2 else 0.62, 0.25, 0.95))
	else:
		_glow(c + Vector2(0, -r * 0.08), Vector2(r * 0.4, r * 0.25), Color(1, 0.45, 0.15, 0.25))
	draw_arc(c, r * 0.42, PI, TAU, 24, Color("D9C39A"), 4 * k, true)

func _draw_pantry(base: Vector2) -> void:
	var k := _k()
	# A shelf of jars behind, then a packing table with an open crate.
	var shelf_y := base.y - size.y * 0.46
	draw_rect(Rect2(base.x - size.x * 0.2, shelf_y, size.x * 0.4, 7 * k), Color("5A3E2C"))
	for i in 5:
		var jx := base.x - size.x * 0.16 + i * size.x * 0.08
		var tint: Color = [Color("E8A33D"), Color("C8553D"), Color("7EDB9C"), Color("F4E8CF"), Color("E8A33D")][i]
		_round_rect(Rect2(jx - 11 * k, shelf_y - 30 * k, 22 * k, 30 * k), 6 * k, Color(tint, 0.85))
		draw_rect(Rect2(jx - 9 * k, shelf_y - 35 * k, 18 * k, 6 * k), Color("8A5E3C"))
		draw_line(Vector2(jx - 6 * k, shelf_y - 24 * k), Vector2(jx - 6 * k, shelf_y - 8 * k), Color(1, 1, 1, 0.35), 2 * k)
	var top := base.y - size.y * 0.16
	_lit_rect(Rect2(base.x - 86 * k, top, 172 * k, 12 * k), Color("A0703F"))
	for lx in [-74, 74]: draw_rect(Rect2(base.x + (lx - 5) * k, top + 12 * k, 10 * k, base.y - top - 12 * k), Color("6E4A31"))
	# The crate; its lid lifts each time something drops in.
	var crate := Rect2(base.x - 46 * k, top - 52 * k, 92 * k, 52 * k)
	_lit_rect(crate, Color("C08A4E"), 6 * k)
	for i in 3: draw_line(Vector2(crate.position.x, crate.position.y + (12 + i * 14) * k), Vector2(crate.end.x, crate.position.y + (12 + i * 14) * k), Color(0, 0, 0, 0.2), 2 * k)
	var open := 0.15 + (0.35 + 0.3 * sin(t * 2.6) if working else 0.0)
	var hinge := Vector2(crate.end.x, crate.position.y)
	var lid_tip := hinge + Vector2.from_angle(PI + open) * crate.size.x
	draw_line(hinge, lid_tip, Color("9E6B38"), 8 * k)
	draw_line(hinge, lid_tip, Color(1, 1, 1, 0.15), 2 * k)
	if working:
		var u := fposmod(t * 0.8, 1.0)
		if output != "": _good(output, Vector2(base.x, crate.position.y - 40 * k + u * 40 * k), 36 * k, 1.0 - u)
	# A twine spool for tying the parcels.
	draw_circle(Vector2(crate.end.x + 26 * k, top - 12 * k), 12 * k, Color("D9C39A"))
	draw_arc(Vector2(crate.end.x + 26 * k, top - 12 * k), 8 * k, 0, TAU, 20, Color("B8A07A"), 2 * k, true)

func _draw_barn(base: Vector2) -> void:
	var k := _k()
	# Hay bales stacked at the back.
	for i in 3:
		var bale := Rect2(base.x - size.x * 0.27 + i * 60 * k, base.y - size.y * 0.3 - (24 * k if i == 1 else 0.0), 56 * k, 36 * k)
		_lit_rect(bale, Color("E3C25A"), 8 * k)
		for j in 4: draw_line(bale.position + Vector2(6 * k, (7 + j * 8) * k), bale.position + Vector2(bale.size.x - 6 * k, (7 + j * 8) * k), Color(0.6, 0.45, 0.1, 0.35), 1.2 * k)
		draw_line(bale.position + Vector2(18 * k, 0), bale.position + Vector2(18 * k, bale.size.y), Color("8A5E3C"), 2 * k)
	# The manger the belt feeds, and a milk churn.
	var trough := Rect2(base.x - 64 * k, base.y - 34 * k, 128 * k, 28 * k)
	_lit_rect(trough, Color("8A5A3B"), 6 * k)
	draw_rect(Rect2(trough.position.x + 6 * k, trough.position.y + 3 * k, trough.size.x - 12 * k, 8 * k), Color("E3C25A"))
	var churn := Vector2(base.x + size.x * 0.24, base.y - 8 * k)
	_contact(churn, 22 * k)
	_lit_rect(Rect2(churn.x - 16 * k, churn.y - 54 * k, 32 * k, 54 * k), Color("C9D3D6"), 9 * k)
	draw_rect(Rect2(churn.x - 10 * k, churn.y - 62 * k, 20 * k, 9 * k), Color("A9B5B9"))
	draw_line(Vector2(churn.x - 9 * k, churn.y - 46 * k), Vector2(churn.x - 9 * k, churn.y - 10 * k), Color(1, 1, 1, 0.45), 2.5 * k)
	# Two sheep at the manger; heads dip while they eat.
	for i in 2:
		var sheep := base + Vector2((-44 + i * 70) * k, -56 * k - (6 * k if i == 1 else 0.0))
		var chew := 0.0 if not working else maxf(0.0, sin(t * 2.2 + i * 1.9)) * 7 * k
		var bob := sin(t * 1.3 + i) * 1.5 * k
		for p in [Vector2(-20, 4), Vector2(-6, -6), Vector2(10, -4), Vector2(20, 6), Vector2(4, 10), Vector2(-12, 12)]:
			draw_circle(sheep + p * k + Vector2(0, bob), 15 * k, Color("EDE6D6"))
		for p in [Vector2(-14, -2), Vector2(4, -10), Vector2(16, 0)]:
			draw_circle(sheep + p * k + Vector2(0, bob), 9 * k, Color("FBF8F1"))
		var head := sheep + Vector2(-32 * k if i == 0 else 32 * k, 8 * k + chew)
		_ellipse(head, Vector2(10, 13) * k, Color("3B3029"))
		_ellipse(head + Vector2(-11 * k, -6 * k), Vector2(6, 3) * k, Color("3B3029"))
		_ellipse(head + Vector2(11 * k, -6 * k), Vector2(6, 3) * k, Color("3B3029"))
		draw_circle(head + Vector2(-4 * k, -2 * k), 1.8 * k, Color(1, 1, 1, 0.85))
		draw_circle(head + Vector2(4 * k, -2 * k), 1.8 * k, Color(1, 1, 1, 0.85))

func _draw_grill(base: Vector2) -> void:
	var k := _k()
	# Copper hood, smoke, then the iron grate over a brick firebox.
	var hood_y := base.y - size.y * 0.52
	_lit_poly(PackedVector2Array([Vector2(base.x - 80 * k, hood_y + 40 * k), Vector2(base.x + 80 * k, hood_y + 40 * k),
		Vector2(base.x + 30 * k, hood_y), Vector2(base.x - 30 * k, hood_y)]), Color("B87333"))
	draw_line(Vector2(base.x - 80 * k, hood_y + 40 * k), Vector2(base.x + 80 * k, hood_y + 40 * k), Color("E0A060"), 3 * k)
	_lit_rect(Rect2(base.x - 12 * k, 0, 24 * k, hood_y), Color("8E5A2A"))
	var box := Rect2(base.x - 78 * k, base.y - 58 * k, 156 * k, 52 * k)
	_lit_rect(box, Color("A04A32"), 6 * k)
	for row in 3:
		draw_line(Vector2(box.position.x, box.position.y + (14 + row * 13) * k), Vector2(box.end.x, box.position.y + (14 + row * 13) * k), Color(0, 0, 0, 0.2), 1.5 * k)
	var coals := box.position.y + 6 * k
	var heat := 1.0 if working else 0.35
	_glow(Vector2(base.x, coals), Vector2(90, 34) * k * (0.9 + 0.1 * sin(t * 5)), Color(1, 0.4, 0.1, 0.7 * heat))
	for i in 9:
		var cx := box.position.x + 14 * k + i * 16 * k
		draw_circle(Vector2(cx, coals + 2 * k), 6 * k, Color(1, 0.35 + 0.25 * (0.5 + 0.5 * sin(t * 4 + i * 1.3)), 0.1, heat))
	if working:
		for i in 6:
			var fx := box.position.x + 20 * k + i * 23 * k
			var fh := (14 + 8 * sin(t * 9 + i * 2.1)) * k
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 7 * k, coals), Vector2(fx, coals - fh), Vector2(fx + 7 * k, coals)]), Color(1, 0.72, 0.25, 0.9))
		for i in 4:
			var u := fposmod(t * 0.5 + i / 4.0, 1.0)
			draw_circle(Vector2(base.x + sin(u * 6 + i) * 18 * k, coals - 20 * k - u * (coals - hood_y - 30 * k)), (5 + u * 10) * k, Color(0.9, 0.88, 0.85, 0.25 * (1.0 - u)))
	for i in 10:
		var gx := box.position.x + 8 * k + i * 15.5 * k
		draw_line(Vector2(gx, coals - 6 * k), Vector2(gx, coals + 4 * k), Color("2B2522"), 3 * k)
	draw_line(Vector2(box.position.x, coals - 6 * k), Vector2(box.end.x, coals - 6 * k), Color("3A322E"), 4 * k)

func _draw_build(base: Vector2) -> void:
	var k := _k()
	var top := base.y - size.y * 0.5
	for x in [-80, 0, 80]:
		draw_line(Vector2(base.x + x * k, base.y), Vector2(base.x + x * k, top), Color("A0703F"), 6 * k)
	for y in 3:
		var ly := base.y - (y + 1) * size.y * 0.14
		draw_line(Vector2(base.x - 92 * k, ly), Vector2(base.x + 92 * k, ly), Color("8A5A3B"), 6 * k)
	draw_line(Vector2(base.x - 80 * k, base.y), Vector2(base.x + 80 * k, top), Color("6E4A31"), 4 * k)
	var tex: Texture2D = ui.icons.get("hammer")
	if tex:
		var swing := 0.0 if ui.reduce_motion else sin(t * 6.0) * 0.4
		draw_set_transform(base + Vector2(0, -size.y * 0.3), swing, Vector2.ONE)
		draw_texture_rect(tex, Rect2(Vector2(-30, -30) * k, Vector2(60, 60) * k), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# --- outdoors ------------------------------------------------------------------

func _draw_outdoors() -> void:
	var k := _k()
	var w := size.x
	var h := size.y
	var horizon := h * 0.5
	draw_texture_rect(_gradient(SKY_TOP, SKY_LOW), Rect2(0, 0, w, horizon + 8 * k), false)
	var sun := Vector2(w * 0.84, h * 0.17)
	_glow(sun, Vector2(90, 90) * k, Color(1, 0.95, 0.7, 0.8))
	draw_circle(sun, 20 * k, Color(1, 0.97, 0.82))
	for i in 3:
		var cx := fposmod(w * (0.15 + i * 0.33) + t * 6 * k, w + 160 * k) - 80 * k
		var cy := h * (0.1 + 0.05 * i)
		for p in [Vector2(-22, 4), Vector2(0, -6), Vector2(22, 4)]: _ellipse(Vector2(cx, cy) + p * k, Vector2(22, 12) * k, Color(1, 1, 1, 0.85))
	if not ui.reduce_motion:
		# Two far birds glide across, wings beating now and then.
		for i in BIRDS:
			var u := fposmod(t * 0.02 + i * 0.47, 1.0)
			var bird := Vector2(lerpf(-30 * k, w + 30 * k, u), h * (0.2 + 0.08 * i) + sin(t * 0.7 + i) * 6 * k)
			var beat := 0.35 + 0.65 * maxf(0.0, sin(t * 5.0 + i * 2.0))
			var span := 7.0 * k
			draw_polyline(PackedVector2Array([bird + Vector2(-span, -span * 0.6 * beat), bird, bird + Vector2(span, -span * 0.6 * beat)]), Color(0.2, 0.25, 0.3, 0.55), maxf(1, 1.4 * k), true)
	# Rolling hills, far then near.
	var far := PackedVector2Array([Vector2(0, h)])
	for i in 25: far.append(Vector2(w * i / 24.0, horizon - 18 * k - sin(i * 0.6) * 14 * k))
	far.append(Vector2(w, h))
	_lit_poly(far, HILL_FAR.lerp(SKY_LOW, HAZE))
	var near := PackedVector2Array([Vector2(0, h)])
	for i in 25: near.append(Vector2(w * i / 24.0, horizon + 10 * k - sin(i * 0.4 + 1.5) * 10 * k))
	near.append(Vector2(w, h))
	_lit_poly(near, HILL_NEAR)
	# Sunlit ridge on the near hill, then a meadow that darkens toward us.
	var ridge := near.slice(1, near.size() - 1)
	draw_polyline(ridge, Color(1, 0.97, 0.8, RIM_ALPHA), maxf(1, 2 * k), true)
	draw_texture_rect(_gradient(Color("86B873"), Color("6A9E58")), Rect2(0, h * 0.62, w, h * 0.38), false)
	if kind != "fishing":
		# Tufts of grass and a few wildflowers on the near meadow.
		for i in 16:
			var gx := w * fposmod(i * 0.137 + 0.05, 1.0)
			var gy := h * (0.66 + 0.3 * fposmod(i * 0.311, 1.0))
			var sway := 0.0 if ui.reduce_motion else sin(t * 1.6 + i) * 2 * k
			for b in 3: draw_line(Vector2(gx + (b - 1) * 4 * k, gy), Vector2(gx + (b - 1) * 6 * k + sway, gy - 10 * k), Color("5E9A4E"), 2 * k)
			if i % 4 == 0: draw_circle(Vector2(gx + sway, gy - 12 * k), 3 * k, [Color("F7C04A"), Color("FFF8EA"), Color("E88AA0")][i % 3])
	var kick := _kick()
	var pivot := machine_point()
	draw_set_transform(pivot * (1.0 - kick), 0, Vector2(kick, kick))
	match kind:
		"field": _draw_fields()
		"orchard": _draw_orchard()
		"fishing": _draw_fishing()
		"hive": _draw_hive()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_glow(Vector2(0, h), Vector2(w * 0.3, h * 0.35), Color(0, 0, 0, 0.22))
	_glow(Vector2(w, h), Vector2(w * 0.3, h * 0.35), Color(0, 0, 0, 0.22))

func _draw_fields() -> void:
	var k := _k()
	var count := maxi(1, stages.size())
	var bed_w := size.x * 0.6 / count
	var top := size.y * 0.6
	for f in count:
		var stage: int = stages[f] if f < stages.size() else 0
		var bed := Rect2(size.x * 0.1 + f * (bed_w + 14 * k), top, bed_w, size.y * 0.3)
		_contact(Vector2(bed.get_center().x, bed.end.y + 2 * k), bed.size.x * 0.55)
		_round_rect(bed.grow(3 * k), 12 * k, SOIL_DARK)
		_lit_rect(bed, SOIL, 10 * k)
		var rows := 3
		for r in rows:
			var ry := bed.position.y + bed.size.y * (r + 0.7) / (rows + 0.4)
			draw_line(Vector2(bed.position.x + 8 * k, ry + 4 * k), Vector2(bed.end.x - 8 * k, ry + 4 * k), SOIL_DARK, 3 * k)
			var plants := 6
			for p in plants:
				var px := bed.position.x + bed.size.x * (p + 0.5) / plants
				var sway := 0.0 if ui.reduce_motion else sin(t * 1.8 + p * 0.7 + r) * 2.5 * k
				var base := Vector2(px, ry)
				match stage:
					1: draw_circle(base + Vector2(0, 2 * k), 2.5 * k, Color("F3D98B"))
					2, 3:
						var grow := progress if progress >= 0 else (0.25 if stage == 2 else 0.6)
						var tall := (8 + 26 * grow) * k
						draw_line(base, base + Vector2(sway, -tall), Color("4E9A45"), 2.5 * k)
						draw_line(base + Vector2(0, -tall * 0.4), base + Vector2(-6 * k + sway * 0.5, -tall * 0.65), Color("62B356"), 2 * k)
						draw_line(base + Vector2(0, -tall * 0.55), base + Vector2(6 * k + sway * 0.5, -tall * 0.8), Color("62B356"), 2 * k)
					4:
						var tall := 36 * k
						draw_line(base, base + Vector2(sway, -tall), Color("C9A04A"), 2.5 * k)
						_ellipse(base + Vector2(sway, -tall - 5 * k), Vector2(3.5, 8) * k, Color("F2C75C"), 16)
		if stage in [2, 3] and not ui.reduce_motion:
			# Fresh water glints on the soil while the wheat grows.
			for i in 4:
				var u := fposmod(t * 0.6 + i * 0.25 + f * 0.13, 1.0)
				var at := Vector2(bed.position.x + bed.size.x * (0.15 + 0.23 * i), bed.position.y + bed.size.y * 0.3 + u * bed.size.y * 0.5)
				draw_circle(at, 2 * k, Color(0.7, 0.88, 1.0, 0.6 * (1.0 - u)))
	# The harvest cart at the end of the line.
	var cart := Vector2(size.x * 0.86, size.y * 0.8)
	_contact(cart + Vector2(0, 16 * k), 56 * k)
	_lit_rect(Rect2(cart.x - 44 * k, cart.y - 30 * k, 88 * k, 30 * k), Color("A0703F"), 6 * k)
	for i in 3: draw_line(Vector2(cart.x - 44 * k, cart.y - (22 - i * 8) * k), Vector2(cart.x + 44 * k, cart.y - (22 - i * 8) * k), Color(0, 0, 0, 0.18), 1.5 * k)
	for wx in [-28, 28]:
		draw_circle(cart + Vector2(wx * k, 4 * k), 12 * k, Color("5E3F2A"))
		draw_circle(cart + Vector2(wx * k, 4 * k), 4 * k, BRASS)
	if done:
		var lift := 0.0 if ui.reduce_motion else sin(t * 2.4) * 4 * k
		_glow(cart - Vector2(0, 46 * k), Vector2(72, 72) * k, Color(WorldUI.GOLD, 0.6))
		_good("wheat", cart - Vector2(0, 50 * k + lift), 64 * k)
		for i in 5:
			var a := t * 1.4 + TAU * i / 5.0
			_sparkle(cart - Vector2(0, 50 * k) + Vector2(cos(a) * 46 * k, sin(a) * 28 * k), (3.0 + 2.0 * sin(t * 4 + i)) * k)

func _draw_orchard() -> void:
	var k := _k()
	var base := Vector2(size.x * 0.42, size.y * 0.86)
	_ellipse(base + Vector2(0, 4 * k), Vector2(90, 14) * k, Color(0, 0, 0, 0.18))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-14, 0) * k, base + Vector2(14, 0) * k, base + Vector2(9, -110) * k, base + Vector2(-9, -110) * k]), Color("7A5235"))
	draw_line(base + Vector2(0, -80) * k, base + Vector2(-36, -120) * k, Color("7A5235"), 9 * k)
	draw_line(base + Vector2(0, -90) * k, base + Vector2(40, -128) * k, Color("7A5235"), 9 * k)
	var crown := base + Vector2(0, -150 * k)
	var sway := 0.0 if ui.reduce_motion else sin(t * 0.9) * 3 * k
	for p in [Vector2(-70, 10), Vector2(-40, -30), Vector2(0, -50), Vector2(42, -28), Vector2(72, 10), Vector2(-34, 30), Vector2(30, 32), Vector2(0, 0)]:
		draw_circle(crown + p * k + Vector2(sway, 0), 44 * k, Color("4E9A45"))
	for p in [Vector2(-46, -20), Vector2(-6, -40), Vector2(36, -18), Vector2(0, 8)]:
		draw_circle(crown + p * k + Vector2(sway - 8 * k, -10 * k), 26 * k, Color("6CBF5C"))
	var grow := 1.0 if done else (progress if progress >= 0 else 0.0)
	for i in 9:
		var p := crown + Vector2(cos(i * 2.4) * 64 * k, sin(i * 1.7) * 36 * k + 10 * k) + Vector2(sway, 0)
		var r := (2.5 + 7.0 * grow) * k
		if progress < 0 and not done: r = 3 * k
		draw_circle(p, r, Color("E8573C") if grow > 0.5 else Color("A9C94A"))
		draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.5))
	if working and not ui.reduce_motion:
		for i in 6:
			var u := fposmod(t * 0.5 + i / 6.0, 1.0)
			draw_circle(base + Vector2(-60 * k + i * 24 * k, -u * 40 * k), 2 * k, Color(0.7, 0.88, 1.0, 0.6 * (1.0 - u)))
	var basket := Vector2(size.x * 0.8, size.y * 0.84)
	_contact(basket + Vector2(0, 8 * k), 44 * k)
	_lit_poly(PackedVector2Array([basket + Vector2(-40, -26) * k, basket + Vector2(40, -26) * k, basket + Vector2(30, 6) * k, basket + Vector2(-30, 6) * k]), Color("C08A4E"))
	for i in 3: draw_line(basket + Vector2(-38 + i * 2, -18 + i * 8) * k, basket + Vector2(38 - i * 2, -18 + i * 8) * k, Color(0, 0, 0, 0.2), 1.5 * k)
	draw_arc(basket + Vector2(0, -26 * k), 32 * k, PI, TAU, 24, Color("9E6B38"), 4 * k, true)
	if done:
		var lift := 0.0 if ui.reduce_motion else sin(t * 2.4) * 4 * k
		_glow(basket - Vector2(0, 50 * k), Vector2(72, 72) * k, Color(WorldUI.GOLD, 0.6))
		_good("fruit", basket - Vector2(0, 54 * k + lift), 60 * k)
		for i in 5:
			var a := t * 1.4 + TAU * i / 5.0
			_sparkle(basket - Vector2(0, 54 * k) + Vector2(cos(a) * 44 * k, sin(a) * 28 * k), (3.0 + 2.0 * sin(t * 4 + i)) * k)

# --- clock pill ----------------------------------------------------------------

func _draw_clock_pill() -> void:
	var k := _k()
	var text := "Ready" if done else label
	if text == "": return
	var font: Font = WorldUI.DISPLAY_SEMI
	var fs: int = ui.fs(WorldUI.TYPE_HEADLINE)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tall := maxf(34 * k, fs * 1.6)
	var pill := Rect2(size.x / 2 - (tw + 56 * k) / 2, 12 * k, tw + 56 * k, tall)
	var box: StyleBoxFlat = ui.glass(17, WorldUI.GLASS_DEEP, false)
	if done: box.border_color = Color(WorldUI.MINT, 0.8)
	draw_style_box(box, pill)
	var clock := pill.position + Vector2(20 * k, pill.size.y / 2)
	WorldUI.draw_clock(self, clock, 9 * k, WorldUI.MINT if done else WorldUI.GOLD, 1.0 if progress < 0 else progress)
	draw_string(font, Vector2(pill.position.x + 36 * k, pill.position.y + tall / 2 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.MINT if done else WorldUI.IVORY)
	if progress >= 0 and not done:
		# A fine progress line along the pill's foot.
		var foot := Rect2(pill.position.x + 14 * k, pill.end.y - 4 * k, (pill.size.x - 28 * k), 2.5 * k)
		draw_rect(foot, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(foot.position, Vector2(foot.size.x * clampf(progress, 0, 1), foot.size.y)), WorldUI.GOLD)

# --- more places -----------------------------------------------------------------

## A finished product glowing where it waits, with sparkles orbiting it.
func _ready_product(at: Vector2, side := 60.0) -> void:
	if not done or output == "": return
	var k := _k()
	var lift := 0.0 if ui.reduce_motion else sin(t * 2.4) * 4 * k
	_glow(at, Vector2(72, 72) * k, Color(WorldUI.GOLD, 0.6))
	_good(output, at - Vector2(0, lift), side * k)
	for i in 5:
		var a := t * 1.4 + TAU * i / 5.0
		_sparkle(at + Vector2(cos(a) * 44 * k, sin(a) * 28 * k), (3.0 + 2.0 * sin(t * 4 + i)) * k)

## The pond: a little jetty, a rod whose float bobs, fish that leap while the
## line is out, and a bucket for the catch.
func _draw_fishing() -> void:
	var k := _k()
	var w := size.x
	var h := size.y
	var shore := h * 0.6
	var water := Rect2(0, shore, w, h - shore)
	draw_texture_rect(_gradient(Color("6DB7D6"), Color("2F7EA6")), water, false)
	for i in 7:
		var y := shore + (14 + i * 18) * k
		var drift := fposmod(t * (10 + i * 3) * k + i * 90 * k, w + 140 * k) - 70 * k
		draw_line(Vector2(drift, y), Vector2(drift + (40 + i * 6) * k, y), Color(1, 1, 1, 0.22), 2 * k)
	# Reeds at the edge and lily pads.
	for i in 7:
		var rx := w * (0.04 + i * 0.022)
		var sway := 0.0 if ui.reduce_motion else sin(t * 1.4 + i) * 3 * k
		draw_line(Vector2(rx, shore + 12 * k), Vector2(rx + sway, shore - (30 + (i % 3) * 10) * k), Color("4E8A3E"), 3 * k)
		if i % 2 == 0: _ellipse(Vector2(rx + sway, shore - (30 + (i % 3) * 10) * k), Vector2(3, 8) * k, Color("8A5A3B"), 12)
	for p in [Vector2(0.72, 0.78), Vector2(0.84, 0.9), Vector2(0.62, 0.92)]:
		_ellipse(Vector2(w * p.x, h * p.y), Vector2(22, 8) * k, Color("5FA352"))
		draw_circle(Vector2(w * p.x + 8 * k, h * p.y - 3 * k), 3.5 * k, Color("F4B6C8"))
	# The jetty and the angler's rod.
	var deck := Rect2(w * 0.16, shore - 6 * k, w * 0.3, 16 * k)
	for leg in [0.2, 0.32, 0.44]: draw_rect(Rect2(w * leg - 4 * k, shore, 8 * k, 46 * k), Color("5E3F2A"))
	_lit_rect(deck, Color("A0703F"), 4 * k)
	for i in 7: draw_line(Vector2(deck.position.x + i * deck.size.x / 7, deck.position.y), Vector2(deck.position.x + i * deck.size.x / 7, deck.end.y), Color(0, 0, 0, 0.2), 1.5 * k)
	var rod_base := Vector2(w * 0.42, shore - 8 * k)
	var tip := Vector2(w * 0.62, shore - 110 * k)
	draw_line(rod_base, tip, Color("6E4A31"), 4 * k)
	var bob := Vector2(w * 0.66, shore + 40 * k) + Vector2(0, (sin(t * 2.2) * 3 + (maxf(0, sin(t * 0.9)) * 6 if working else 0.0)) * k)
	draw_line(tip, bob, Color(1, 1, 1, 0.6), 1.2 * k)
	draw_arc(bob + Vector2(0, 6 * k), 12 * k + fposmod(t, 1.5) * 10 * k, PI * 0.1, PI * 0.9, 12, Color(1, 1, 1, 0.3), 1.5 * k)
	draw_circle(bob, 6 * k, Color("C8553D"))
	draw_circle(bob - Vector2(0, 4 * k), 4 * k, Color(1, 1, 1))
	if working and not ui.reduce_motion:
		# Now and then a fish arcs out of the water and back.
		var u := fposmod(t / 2.6, 1.0)
		if u < 0.4:
			var j := u / 0.4
			var fx := w * (0.75 + 0.1 * j)
			var fy := shore + 30 * k - sin(j * PI) * 70 * k
			draw_set_transform(Vector2(fx, fy), (j - 0.5) * 2.2, Vector2.ONE)
			_ellipse(Vector2.ZERO, Vector2(16, 7) * k, Color("7FC8E0"))
			draw_colored_polygon(PackedVector2Array([Vector2(14, 0) * k, Vector2(24, -8) * k, Vector2(24, 8) * k]), Color("4C9AC4"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			for d in 3: draw_circle(Vector2(fx - 20 * k * d, fy + 10 * k * d), 2 * k, Color(1, 1, 1, 0.5))
	# The catch bucket on the jetty.
	var bucket := Vector2(w * 0.2, shore - 6 * k)
	draw_colored_polygon(PackedVector2Array([bucket + Vector2(-20, -36) * k, bucket + Vector2(20, -36) * k, bucket + Vector2(15, 0), bucket + Vector2(-15, 0)]), Color("9AA9AE"))
	draw_arc(bucket + Vector2(0, -36 * k), 20 * k, PI, TAU, 16, Color("5E6B70"), 2.5 * k, true)
	_ready_product(bucket - Vector2(0, 64 * k), 56)

## The old tree's beehive: bees drift between the hive and the meadow flowers,
## and honey gathers in a jar on the stump.
func _draw_hive() -> void:
	var k := _k()
	var w := size.x
	var h := size.y
	var trunk := Vector2(w * 0.22, h * 0.9)
	draw_colored_polygon(PackedVector2Array([trunk + Vector2(-26, 0) * k, trunk + Vector2(26, 0) * k, trunk + Vector2(16, -200) * k, trunk + Vector2(-16, -200) * k]), Color("7A5235"))
	for p in [Vector2(-60, -230), Vector2(0, -270), Vector2(60, -230), Vector2(-20, -200), Vector2(40, -190)]:
		draw_circle(trunk + p * k, 58 * k, Color("4E9A45"))
	for p in [Vector2(-40, -250), Vector2(20, -280), Vector2(50, -220)]:
		draw_circle(trunk + p * k, 30 * k, Color("6CBF5C"))
	# The hive: stacked white boxes with a little roof.
	var hive := Vector2(w * 0.5, h * 0.82)
	_contact(hive + Vector2(0, 30 * k), 60 * k)
	draw_rect(Rect2(hive.x - 40 * k, hive.y, 80 * k, 30 * k), Color("6E4A31"))
	for i in 3:
		var box := Rect2(hive.x - 46 * k, hive.y - (i + 1) * 34 * k, 92 * k, 32 * k)
		_lit_rect(box, Color("F4E8CF") if i != 1 else Color("EBD9B4"), 4 * k)
		draw_line(box.position + Vector2(4 * k, 2 * k), Vector2(box.end.x - 4 * k, box.position.y + 2 * k), Color(1, 1, 1, 0.5), 1.5 * k)
	var roof := hive.y - 3 * 34 * k
	draw_colored_polygon(PackedVector2Array([Vector2(hive.x - 58 * k, roof), Vector2(hive.x + 58 * k, roof), Vector2(hive.x, roof - 34 * k)]), Color("C8553D"))
	_round_rect(Rect2(hive.x - 14 * k, hive.y - 14 * k, 28 * k, 8 * k), 3 * k, Color("3B2C22"))
	# Flowers the bees visit.
	for i in 6:
		var fx := w * (0.62 + 0.06 * i)
		var fy := h * (0.78 + 0.05 * (i % 2))
		draw_line(Vector2(fx, fy + 20 * k), Vector2(fx, fy), Color("5E9A4E"), 2.5 * k)
		for p in 5: draw_circle(Vector2(fx, fy) + Vector2.from_angle(TAU * p / 5) * 6 * k, 5 * k, [Color("F7C04A"), Color("E88AA0"), Color("FFF8EA")][i % 3])
		draw_circle(Vector2(fx, fy), 3.5 * k, Color("C98A1C"))
	var bees := 7 if working else 3
	for i in bees:
		var u := fposmod(t * (0.12 + i * 0.015) + i * 0.17, 1.0)
		var flower := Vector2(w * (0.62 + 0.06 * (i % 6)), h * 0.76)
		var p := (hive - Vector2(0, 60 * k)).lerp(flower, 0.5 - 0.5 * cos(u * TAU)) + Vector2(sin(t * 7 + i) * 6 * k, sin(u * TAU * 2 + i) * 26 * k)
		_ellipse(p, Vector2(5, 3.5) * k, Color("F7C04A"), 12)
		draw_line(p + Vector2(-1.5 * k, -3 * k), p + Vector2(-1.5 * k, 3 * k), Color("2A1D15"), 1.5 * k)
		var flap := 0.5 + 0.5 * sin(t * 40 + i)
		_ellipse(p + Vector2(0, -5 * k), Vector2(3, 2 + 2 * flap) * k, Color(1, 1, 1, 0.7), 10)
	# The honey jar waits on a stump.
	var stump := Vector2(w * 0.86, h * 0.86)
	_ellipse(stump, Vector2(34, 10) * k, Color("8A5A3B"))
	_contact(stump + Vector2(0, 26 * k), 44 * k)
	_lit_rect(Rect2(stump.x - 34 * k, stump.y, 68 * k, 26 * k), Color("7A5235"))
	_ready_product(stump - Vector2(0, 40 * k), 58)

## The greenhouse: glass walls full of light, shelves of pots whose herbs grow
## with the timer, and a fine mist while it works.
func _draw_greenhouse() -> void:
	var k := _k()
	var w := size.x
	var h := size.y
	draw_texture_rect(_gradient(Color("CFEDE4"), Color("9FD2BF")), Rect2(0, 0, w, h), false)
	var pane := 70.0 * k
	var x := fmod(w / 2, pane)
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h * 0.78), Color(1, 1, 1, 0.75), 3 * k)
		x += pane
	for y in [h * 0.18, h * 0.42]: draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.75), 3 * k)
	for i in 4:
		var sx := w * (0.1 + 0.25 * i) + (0.0 if ui.reduce_motion else fposmod(t * 8 * k, 60 * k))
		draw_colored_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx + 26 * k, 0), Vector2(sx - 40 * k, h * 0.78), Vector2(sx - 66 * k, h * 0.78)]), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(0, h * 0.78, w, h * 0.22), Color("8A6A4E"))
	draw_rect(Rect2(0, h * 0.78, w, 3 * k), Color(1, 1, 1, 0.15))
	var grow := 1.0 if done else (progress if progress >= 0 else 0.15)
	for row in 2:
		var shelf := h * (0.48 + row * 0.24)
		_lit_rect(Rect2(w * 0.1, shelf, w * 0.66, 9 * k), Color("A0703F"))
		for p in 6:
			var px := w * (0.15 + p * 0.11)
			var pot := Rect2(px - 18 * k, shelf - 28 * k, 36 * k, 28 * k)
			_lit_poly(PackedVector2Array([pot.position, Vector2(pot.end.x, pot.position.y), pot.end - Vector2(4 * k, 0), Vector2(pot.position.x + 4 * k, pot.end.y)]), Color("C8693D"))
			draw_rect(Rect2(pot.position.x - 2 * k, pot.position.y, pot.size.x + 4 * k, 6 * k), Color("D9814F"))
			var tall := (6 + 34 * grow) * k
			var sway := 0.0 if ui.reduce_motion else sin(t * 1.8 + p + row) * 2 * k
			for leaf in 5:
				var a := -PI / 2 + (leaf - 2) * 0.45
				var tipp := Vector2(px, pot.position.y) + Vector2(cos(a) * tall * 0.6 + sway, sin(a) * tall)
				draw_line(Vector2(px, pot.position.y), tipp, Color("3F9A45"), 2.5 * k)
				_ellipse(tipp, Vector2(5, 3) * k * (0.6 + grow * 0.6), Color("7EDB9C" if leaf % 2 else "5FBF6A"), 12)
	if working and not ui.reduce_motion:
		for i in 14:
			var u := fposmod(t * 0.4 + i * 0.07, 1.0)
			var p := Vector2(w * (0.12 + 0.05 * i), h * 0.2 + u * h * 0.5)
			draw_circle(p, 2 * k, Color(1, 1, 1, 0.55 * (1.0 - u)))
	var tray := Vector2(w * 0.88, h * 0.7)
	_round_rect(Rect2(tray.x - 40 * k, tray.y, 80 * k, 14 * k), 6 * k, Color("8A5E3C"))
	_ready_product(tray - Vector2(0, 34 * k), 58)

## The workshop's loom: straw goes in, a shuttle flies across the warp and the
## basket grows row by row.
func _draw_workshop(base: Vector2) -> void:
	var k := _k()
	var frame := Rect2(base.x - 90 * k, base.y - size.y * 0.5, 180 * k, size.y * 0.42)
	for side in [frame.position.x, frame.end.x - 10 * k]:
		_lit_rect(Rect2(side, frame.position.y, 10 * k, frame.size.y + 8 * k), Color("6E4A31"))
	_lit_rect(Rect2(frame.position.x - 6 * k, frame.position.y - 6 * k, frame.size.x + 12 * k, 12 * k), Color("8A5A3B"))
	_lit_rect(Rect2(frame.position.x - 6 * k, frame.end.y - 8 * k, frame.size.x + 12 * k, 12 * k), Color("8A5A3B"))
	for i in 14:
		var wx := frame.position.x + 18 * k + i * (frame.size.x - 36 * k) / 13.0
		draw_line(Vector2(wx, frame.position.y + 6 * k), Vector2(wx, frame.end.y - 8 * k), Color("E8D3A0"), 1.5 * k)
	var woven := (progress if progress >= 0 else 0.0) if working else (1.0 if done else 0.0)
	var rows := int(woven * 10)
	for r in rows:
		var ry := frame.end.y - 14 * k - r * 8 * k
		draw_line(Vector2(frame.position.x + 14 * k, ry), Vector2(frame.end.x - 14 * k, ry), Color("D9A84E") if r % 2 else Color("C08A3E"), 5 * k)
	if working:
		var u := 0.5 - 0.5 * cos(t * 2.4)
		var sy := frame.end.y - 14 * k - rows * 8 * k
		var shuttle := Vector2(lerpf(frame.position.x + 20 * k, frame.end.x - 20 * k, u), sy)
		_ellipse(shuttle, Vector2(16, 5) * k, Color("8A5A3B"))
		draw_line(shuttle - Vector2(14 * k, 0), shuttle + Vector2(14 * k, 0), Color("E3B65A"), 1.5 * k)
	# A sheaf of straw ready by the loom, and a hanging lantern of tools.
	for i in 5: draw_line(Vector2(frame.position.x - 40 * k + i * 4 * k, base.y - 4 * k), Vector2(frame.position.x - 50 * k + i * 6 * k, base.y - 70 * k), Color("E8C06A"), 3 * k)
	for i in 3:
		var tx := frame.end.x + 26 * k + i * 16 * k
		draw_line(Vector2(tx, frame.position.y), Vector2(tx, frame.position.y + (30 + i * 8) * k), Color("6E4A31"), 3 * k)
		draw_circle(Vector2(tx, frame.position.y + (34 + i * 8) * k), 5 * k, Color("9AA9AE"))
