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

static var _vertical := {}
static var _radial: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	# One clock for every scene, so a rebuilt window carries on mid-motion.
	if not ui.reduce_motion: t = Time.get_ticks_msec() / 1000.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var up: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	if up: tapped.emit()
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("good")
	if ok: hover_until = t + 0.15 if not ui.reduce_motion else 1e9
	return ok
func _drop_data(_at: Vector2, data: Variant) -> void:
	hover_until = 0.0
	dropped.emit(str(data.good))
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END: hover_until = 0.0
	if what == NOTIFICATION_READY and not ui.reduce_motion: t = Time.get_ticks_msec() / 1000.0

# --- shared paint ------------------------------------------------------------

static func _gradient(top: Color, low: Color) -> GradientTexture2D:
	var key := top.to_html() + low.to_html()
	if not _vertical.has(key):
		var g := Gradient.new()
		g.set_color(0, top); g.set_color(1, low)
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(0, 1)
		tex.width = 4; tex.height = 128
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

func _good(good: String, at: Vector2, side: float, alpha := 1.0) -> void:
	var tex: Texture2D = ui.icons.get(good)
	if tex == null: return
	_ellipse(at + Vector2(0, side * 0.42), Vector2(side * 0.34, side * 0.09), Color(0, 0, 0, 0.28 * alpha))
	draw_texture_rect(tex, Rect2(at - Vector2(side, side) / 2, Vector2(side, side)), false, Color(1, 1, 1, alpha))

func _k() -> float: return ui.s

# --- the scene ---------------------------------------------------------------

func _draw() -> void:
	if kind in ["field", "orchard"]: _draw_outdoors()
	else: _draw_workroom()
	_draw_clock_pill()
	if hover_until > t:
		# A dragged good is over the scene: the whole window lights up to take it.
		_round_rect(Rect2(Vector2(3, 3) * _k(), size - Vector2(6, 6) * _k()), 22 * _k(), Color(0, 0, 0, 0), Color(WorldUI.GOLD, 0.9), 3 * _k())
		_glow(size / 2, size * 0.6, Color(WorldUI.GOLD, 0.12))

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
	var flicker := 1.0 + (0.04 * sin(t * 7.3) + 0.03 * sin(t * 13.1) if working else 0.0)
	_glow(Vector2(w * 0.5, h * 0.42), Vector2(w * 0.42, h * 0.5) * flicker, Color(LAMP, 0.32))
	draw_line(Vector2(lamp.x, h * 0.06), lamp, Color("1C1410"), 2 * k)
	draw_colored_polygon(PackedVector2Array([lamp + Vector2(-16, 12) * k, lamp + Vector2(16, 12) * k, lamp + Vector2(8, 0) * k, lamp + Vector2(-8, 0) * k]), Color("C98A1C"))
	_ellipse(lamp + Vector2(0, 13 * k), Vector2(7, 4) * k, Color(1, 0.93, 0.7))
	# Floor boards in gentle perspective.
	draw_rect(Rect2(0, floor_y, w, h - floor_y), FLOOR)
	draw_rect(Rect2(0, floor_y, w, 3 * k), Color(1, 1, 1, 0.07))
	for i in 9:
		var fx := w * (i + 0.5) / 9.0
		draw_line(Vector2(fx, floor_y), Vector2(w / 2 + (fx - w / 2) * 1.6, h), Color(0, 0, 0, 0.22), maxf(1, 1.2 * k))
	# Machine and belt.
	var belt_y := h * 0.69
	var machine := Vector2(w * 0.5, belt_y)
	_draw_belt(belt_y)
	match kind:
		"mill": _draw_mill(machine)
		"oven": _draw_oven(machine)
		"pantry": _draw_pantry(machine)
		"barn": _draw_barn(machine)
		"grill": _draw_grill(machine)
		"build": _draw_build(machine)
	_draw_goods_on_belt(belt_y, machine)
	_draw_tray(Vector2(w * 0.86, belt_y))
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
		draw_rect(Rect2(lx - 4 * k, y + band * 0.5, 8 * k, size.y * 0.2), Color("24190F"))
	_ellipse(Vector2(size.x / 2, size.y * 0.93), Vector2(size.x * 0.46, 10 * k), Color(0, 0, 0, 0.25))
	# Rail, belt surface with sliding slats, brass trim and rivets.
	_round_rect(Rect2(x0, y - band * 0.5, x1 - x0, band * 1.35), band * 0.6, RAIL)
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
	if done or kind == "build": return
	var gap := side * 1.15
	for i in inputs.size():
		var good: String = inputs[i]
		var at := Vector2(start + i * gap, ride)
		if filled.get(good, false):
			var since: float = t - float(ui.landed.get(good, -10.0))
			var hop := 0.0 if since > 0.45 or ui.reduce_motion else sin(since / 0.45 * PI) * 14 * k * (1.0 - since / 0.45)
			_good(good, at - Vector2(0, hop), side)
		else:
			# A ghost of the good, breathing softly: drop it here.
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + i)
			draw_arc(at + Vector2(0, 2 * k), side * 0.52, 0, TAU, 36, Color(WorldUI.GOLD, 0.35 + 0.35 * pulse), 2 * k, true)
			_good(good, at, side * 0.86, 0.28)

func _draw_tray(at: Vector2) -> void:
	var k := _k()
	var plate := Rect2(at.x - 38 * k, at.y - 8 * k, 76 * k, 14 * k)
	_round_rect(plate.grow(2 * k), 9 * k, Color("2A1D15"))
	_round_rect(plate, 8 * k, Color("8A5E3C"))
	draw_line(plate.position + Vector2(6 * k, 2 * k), Vector2(plate.end.x - 6 * k, plate.position.y + 2 * k), Color(1, 1, 1, 0.18), 1.5 * k)
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
	draw_colored_polygon(PackedVector2Array([hop_top + Vector2(-34, 0) * k, hop_top + Vector2(34, 0) * k, hop_top + Vector2(9, 34) * k, hop_top + Vector2(-9, 34) * k]), Color("A0703F"))
	draw_line(hop_top + Vector2(-34, 0) * k, hop_top + Vector2(34, 0) * k, Color("C99A5B"), 3 * k)
	if working:
		for i in 7:
			var u := fposmod(t * 1.6 + i / 7.0, 1.0)
			draw_circle(hop_top + Vector2(sin(i * 2.1) * 3 * k, 36 * k + u * (size.y * 0.1)), 2.2 * k, Color(WorldUI.GOLD, 1.0 - u))
	# Two stones on a wooden tub; the upper stone turns.
	_round_rect(Rect2(stone.x - 62 * k, stone.y + 4 * k, 124 * k, base.y - stone.y - 10 * k), 10 * k, Color("8A5A3B"))
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
	draw_rect(Rect2(c.x + r * 0.35, c.y - r * 1.35, r * 0.28, r * 0.6), Color("8C3F2A"))
	draw_rect(Rect2(c.x + r * 0.32, c.y - r * 1.38, r * 0.34, r * 0.08), Color("6E2F1F"))
	if working:
		for i in 4:
			var u := fposmod(t * 0.35 + i / 4.0, 1.0)
			draw_circle(Vector2(c.x + r * 0.49 + sin(u * 5 + i) * 8 * k, c.y - r * 1.4 - u * size.y * 0.2), (6 + u * 12) * k, Color(0.9, 0.88, 0.85, 0.28 * (1.0 - u)))
	# A brick dome on a stone plinth.
	draw_rect(Rect2(c.x - r * 1.15, c.y - 4 * k, r * 2.3, base.y - c.y + 10 * k), Color("7E756A"))
	draw_rect(Rect2(c.x - r * 1.15, c.y - 4 * k, r * 2.3, 4 * k), Color(1, 1, 1, 0.12))
	var dome := PackedVector2Array()
	for i in 33: dome.append(c + Vector2.from_angle(PI + PI * i / 32.0) * r * Vector2(1.05, 1.0))
	draw_colored_polygon(dome, Color("B5583A"))
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
	draw_rect(Rect2(base.x - 86 * k, top, 172 * k, 12 * k), Color("A0703F"))
	draw_rect(Rect2(base.x - 86 * k, top, 172 * k, 2.5 * k), Color(1, 1, 1, 0.18))
	for lx in [-74, 74]: draw_rect(Rect2(base.x + (lx - 5) * k, top + 12 * k, 10 * k, base.y - top - 12 * k), Color("6E4A31"))
	# The crate; its lid lifts each time something drops in.
	var crate := Rect2(base.x - 46 * k, top - 52 * k, 92 * k, 52 * k)
	_round_rect(crate, 6 * k, Color("C08A4E"))
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
		_round_rect(bale, 8 * k, Color("E3C25A"))
		for j in 4: draw_line(bale.position + Vector2(6 * k, (7 + j * 8) * k), bale.position + Vector2(bale.size.x - 6 * k, (7 + j * 8) * k), Color(0.6, 0.45, 0.1, 0.35), 1.2 * k)
		draw_line(bale.position + Vector2(18 * k, 0), bale.position + Vector2(18 * k, bale.size.y), Color("8A5E3C"), 2 * k)
	# The manger the belt feeds, and a milk churn.
	var trough := Rect2(base.x - 64 * k, base.y - 34 * k, 128 * k, 28 * k)
	_round_rect(trough, 6 * k, Color("8A5A3B"))
	draw_rect(Rect2(trough.position.x + 6 * k, trough.position.y + 3 * k, trough.size.x - 12 * k, 8 * k), Color("E3C25A"))
	var churn := Vector2(base.x + size.x * 0.24, base.y - 8 * k)
	_round_rect(Rect2(churn.x - 16 * k, churn.y - 54 * k, 32 * k, 54 * k), 9 * k, Color("C9D3D6"))
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
	draw_colored_polygon(PackedVector2Array([Vector2(base.x - 80 * k, hood_y + 40 * k), Vector2(base.x + 80 * k, hood_y + 40 * k),
		Vector2(base.x + 30 * k, hood_y), Vector2(base.x - 30 * k, hood_y)]), Color("B87333"))
	draw_line(Vector2(base.x - 80 * k, hood_y + 40 * k), Vector2(base.x + 80 * k, hood_y + 40 * k), Color("E0A060"), 3 * k)
	draw_rect(Rect2(base.x - 12 * k, 0, 24 * k, hood_y), Color("8E5A2A"))
	var box := Rect2(base.x - 78 * k, base.y - 58 * k, 156 * k, 52 * k)
	_round_rect(box, 6 * k, Color("A04A32"))
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
	# Rolling hills, far then near.
	var far := PackedVector2Array([Vector2(0, h)])
	for i in 25: far.append(Vector2(w * i / 24.0, horizon - 18 * k - sin(i * 0.6) * 14 * k))
	far.append(Vector2(w, h))
	draw_colored_polygon(far, HILL_FAR)
	var near := PackedVector2Array([Vector2(0, h)])
	for i in 25: near.append(Vector2(w * i / 24.0, horizon + 10 * k - sin(i * 0.4 + 1.5) * 10 * k))
	near.append(Vector2(w, h))
	draw_colored_polygon(near, HILL_NEAR)
	draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color("7DB06A"))
	if kind == "field": _draw_fields()
	else: _draw_orchard()
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
		_round_rect(bed.grow(3 * k), 12 * k, SOIL_DARK)
		_round_rect(bed, 10 * k, SOIL)
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
	_round_rect(Rect2(cart.x - 44 * k, cart.y - 30 * k, 88 * k, 30 * k), 6 * k, Color("A0703F"))
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
	draw_colored_polygon(PackedVector2Array([basket + Vector2(-40, -26) * k, basket + Vector2(40, -26) * k, basket + Vector2(30, 6) * k, basket + Vector2(-30, 6) * k]), Color("C08A4E"))
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
	var fs := int(19 * k)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(size.x / 2 - (tw + 56 * k) / 2, 12 * k, tw + 56 * k, 34 * k)
	var box: StyleBoxFlat = ui.glass(17, WorldUI.GLASS_DEEP, false)
	if done: box.border_color = Color(WorldUI.MINT, 0.8)
	draw_style_box(box, pill)
	var clock := pill.position + Vector2(20 * k, pill.size.y / 2)
	WorldUI.draw_clock(self, clock, 9 * k, WorldUI.MINT if done else WorldUI.GOLD, 1.0 if progress < 0 else progress)
	draw_string(font, Vector2(pill.position.x + 36 * k, pill.position.y + 24 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WorldUI.MINT if done else WorldUI.IVORY)
	if progress >= 0 and not done:
		# A fine progress line along the pill's foot.
		var foot := Rect2(pill.position.x + 14 * k, pill.end.y - 4 * k, (pill.size.x - 28 * k), 2.5 * k)
		draw_rect(foot, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(foot.position, Vector2(foot.size.x * clampf(progress, 0, 1), foot.size.y)), WorldUI.GOLD)
