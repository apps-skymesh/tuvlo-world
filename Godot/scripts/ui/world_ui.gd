class_name WorldUI
extends CanvasLayer

## Step-1 game UI: wallet and level, goods, Build tray, place panel and market.
## Plain Godot controls; the designed cards come in step 2 (docs/PORTING-PLAN.md).

const C = preload("res://scripts/game/catalogue.gd")
signal panel_changed(open: bool)

var main  # game_main.gd
var s := 1.0
var root: Control
var wallet_label: Label
var goods_label: Label
var toast: Label
var toast_left := 0.0
var hud: Array[Control] = []
var panel: PanelContainer
var panel_title: Label
var panel_body: VBoxContainer
var panel_kind := ""
var panel_arg := ""

func setup(owner_main) -> void:
	main = owner_main
	s = clampf(main.get_viewport().get_visible_rect().size.y / 720.0, 1.0, 3.0)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	var top := _card(Color(1, 0.98, 0.93, 0.92))
	top.position = Vector2(16, 14) * s
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	wallet_label = Label.new()
	wallet_label.add_theme_font_size_override("font_size", int(22 * s))
	top_box.add_child(wallet_label)
	goods_label = Label.new()
	top_box.add_child(goods_label)
	root.add_child(top)
	hud.append(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(12 * s))
	for entry in [["Build", "build"], ["Market", "market"]]:
		var button := _button(entry[0], func(): open(entry[1]))
		button.custom_minimum_size = Vector2(120, 56) * s
		bar.add_child(button)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(18 * s))
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bar)
	hud.append(bar)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(20 * s))
	toast.add_theme_color_override("font_color", Color("4a3826"))
	toast.add_theme_font_size_override("font_size", int(20 * s))
	root.add_child(toast)
	panel = _card(Color(1, 0.98, 0.93, 0.97))
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(10 * s))
	panel.add_child(column)
	var head := HBoxContainer.new()
	panel_title = Label.new()
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title.add_theme_font_size_override("font_size", int(24 * s))
	head.add_child(panel_title)
	head.add_child(_button("Close", close))
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 340) * s
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", int(8 * s))
	scroll.add_child(panel_body)
	column.add_child(scroll)
	root.add_child(panel)
	refresh()

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = int(18 * s)
	theme.set_color("font_color", "Label", Color("3d3024"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color("f2b84b"), "hover": Color("f5c565"), "pressed": Color("d99c33"), "disabled": Color("ddd5c4"), "focus": Color("f2b84b")}[state]
		box.set_corner_radius_all(int(14 * s))
		box.content_margin_left = 14 * s; box.content_margin_right = 14 * s
		box.content_margin_top = 8 * s; box.content_margin_bottom = 8 * s
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", Color("3d2a14"))
	theme.set_color("font_disabled_color", "Button", Color("8f8577"))
	return theme

func _card(color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(18 * s))
	box.set_content_margin_all(14 * s)
	box.shadow_color = Color(0, 0, 0, 0.15)
	box.shadow_size = int(6 * s)
	card.add_theme_stylebox_override("panel", box)
	return card

func _button(text: String, action: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button

func _row(text: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(10 * s))
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	for button in buttons: row.add_child(button)
	panel_body.add_child(row)

## True when a screen point belongs to the UI, so the world ignores the tap.
func blocks(point: Vector2) -> bool:
	if panel.visible: return true
	for control in hud:
		if control.get_global_rect().has_point(point): return true
	return false

func show_toast(text: String) -> void:
	toast.text = text
	toast_left = 2.5

func _process(delta: float) -> void:
	if toast_left > 0:
		toast_left -= delta
		if toast_left <= 0: toast.text = ""

func refresh() -> void:
	var game: WorldGame = main.game
	wallet_label.text = "Coins %d   ·   Level %d" % [game.host.wallet(), game.host.progress()]
	var parts := []
	for good in C.GOODS:
		if game.state.stock.get(good, 0) > 0: parts.append("%s %d" % [C.title(good), game.state.stock[good]])
	goods_label.text = "  ".join(parts) if not parts.is_empty() else "Tap the farm to plant wheat"
	if panel.visible: _fill()

func open(kind: String, arg := "") -> void:
	panel_kind = kind
	panel_arg = arg
	panel.visible = true
	_fill()
	panel.reset_size()
	panel.position = (root.size - panel.size) / 2
	panel_changed.emit(true)

func close() -> void:
	panel.visible = false
	panel_kind = ""
	panel_changed.emit(false)

func _fill() -> void:
	for child in panel_body.get_children(): child.queue_free()
	match panel_kind:
		"build": _fill_build()
		"market": _fill_market()
		"place": _fill_place(panel_arg)
		"land": _fill_land(panel_arg)

func _act(result: String) -> void: main.after_action(result)

func _fill_build() -> void:
	var game: WorldGame = main.game
	panel_title.text = "Build"
	var level := game.host.progress()
	for kind in C.BUILD_ORDER:
		var spec: Dictionary = C.BUILDS[kind]
		var blocker := game.state.build_blocker(kind, level)
		var label := "%s · %d coins" % [C.title(kind), spec.price]
		var text := "Build"
		match blocker:
			"owned": text = "Built"
			"locked": text = "Level %d" % spec.gate
			"land": text = "Needs %s" % C.title(spec.land)
			"full": text = "No room"
		var ok: bool = blocker == "" and game.host.wallet() >= int(spec.price)
		_row(label, [_button(text, func(): _act(game.build(kind)), ok)])
	for side in C.LAND:
		_fill_land_row(side)

func _fill_land_row(side: String) -> void:
	var game: WorldGame = main.game
	var spec: Dictionary = C.LAND[side]
	var owned: bool = side in game.state.land
	var text := "Owned" if owned else ("Buy" if game.host.progress() >= spec.gate else "Level %d" % spec.gate)
	var ok: bool = not owned and game.host.progress() >= spec.gate and game.host.wallet() >= spec.price
	_row("%s (land) · %d coins" % [C.title(side), spec.price], [_button(text, func(): _act(game.buy_land(side)), ok)])

func _fill_land(side: String) -> void:
	panel_title.text = C.title(side) if C.LAND.has(side) else "Future land"
	if C.LAND.has(side): _fill_land_row(side)
	else: _row("This land opens in a later update.", [])

func _fill_market() -> void:
	var game: WorldGame = main.game
	panel_title.text = "Market"
	var any := false
	for good in C.GOODS:
		var count: int = game.state.stock.get(good, 0)
		if count <= 0: continue
		any = true
		var price: int = C.SELL_PRICE[good]
		_row("%s ×%d · %d each" % [C.title(good), count, price],
			[_button("Sell 1", func(): _act(game.sell(good, 1))), _button("Sell all", func(): _act(game.sell(good, count)))])
	if not any: _row("Nothing to sell yet. Grow wheat at the farm.", [])

func _fill_place(id: String) -> void:
	var game: WorldGame = main.game
	var state := game.state
	var item := state.find(id)
	if item.is_empty(): close(); return
	panel_title.text = C.title(item.kind)
	var now := game.now()
	if state.is_building(id, now):
		var c: Dictionary = state.construction[id]
		_row("Building · %ds" % ceili(c.started + c.seconds - now), [])
		return
	if item.kind == "garden":
		for i in state.fields.size():
			var stage := state.field_stage(i, now)
			var labels := ["Empty field", "Planted", "Growing · %ds" % state.field_remaining(i, now), "Growing · %ds" % state.field_remaining(i, now), "Wheat is ready"]
			var actions := ["Plant", "Water", "", "", "Harvest"]
			_row("Field %d · %s" % [i + 1, labels[stage]], [_button(actions[stage] if actions[stage] != "" else "Wait", func(): _act(game.tend(i)), actions[stage] != "")])
	elif item.kind == "orchard":
		var left := state.orchard_remaining(now)
		var text := "Water" if state.orchard_watered < 0 else ("Pick" if left == 0 else "Wait")
		_row("Fruit trees" + ("" if state.orchard_watered < 0 or left == 0 else " · %ds" % left), [_button(text, func(): _act(game.tend_orchard()), text != "Wait")])
	for station in C.stations_for(item.kind):
		if C.stations_for(item.kind).size() > 1: _row("— %s —" % C.title(station), [])
		if state.jobs.has(station):
			var job: Dictionary = state.jobs[station]
			var left := state.job_remaining(station, now)
			var spec: Dictionary = C.RECIPES[job.recipe]
			if left > 0: _row("Making %s · %ds" % [C.title(spec.output).to_lower(), left], [])
			else: _row("%d %s ready" % [spec.quantity, C.title(spec.output).to_lower()], [_button("Collect", func(): _act(game.collect(station)))])
			continue
		for recipe in C.recipes_for(station):
			var spec: Dictionary = C.RECIPES[recipe]
			var needs := []
			var enough := true
			for good in spec.input:
				needs.append("%d %s" % [spec.input[good], C.title(good).to_lower()])
				if state.stock[good] < spec.input[good]: enough = false
			_row("%s → %d %s · %ds" % [", ".join(needs), spec.quantity, C.title(spec.output).to_lower(), spec.seconds],
				[_button("Make", func(): _act(game.make(recipe)), enough)])
	if panel_body.get_child_count() == 0: _row("A lovely spot. More to do here later.", [])
