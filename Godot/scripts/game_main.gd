extends Node

## Standalone Tuvlo World: the renderer, the rules and the UI, with a host that
## saves on this device. Runs on Mac, iPhone and iPad from the same project.

const REASONS := {
	"short": "Not enough yet", "locked": "Opens at a higher level", "land": "Needs more land first",
	"full": "No room left for that", "owned": "You already have one", "busy": "Busy. Let this one finish",
	"not-ready": "Not ready yet", "growing": "Still growing", "save": "Couldn't save. Try again.",
	"read-only": "Read only", "invalid": "That won't work just now", "occupied": "That spot is taken",
	"claimed": "Today's basket is already in",
	"price": "The market moved. Try again",
	"departed": "The barge has sailed", "hold-full": "That crate is already full",
	"stars": "Not enough stars", "not-running": "Nothing to finish",
}
var host: WorldHost
var game: WorldGame
var world: Node3D
var ui: WorldUI
var tick := 0.0

func _ready() -> void:
	host = LocalHost.new()
	host.name = "Host"
	add_child(host)
	game = WorldGame.new(host)
	world = preload("res://scenes/homestead.tscn").instantiate()
	world.host_message.connect(_on_world_message)
	add_child(world)
	ui = WorldUI.new()
	add_child(ui)
	ui.setup(self)
	ui.panel_changed.connect(func(open): world.set_paused(open, open))
	world.input_blocker = ui.blocks
	push()

func push() -> void:
	if world.ready_for_snapshot:
		world.receive_host_json(JSON.stringify({"version": 1, "session": "solo", "type": "snapshot", "payload": game.snapshot()}))
	if ui: ui.refresh()

func send(type: String, payload: Dictionary) -> void:
	if world.ready_for_snapshot:
		world.receive_host_json(JSON.stringify({"version": 1, "session": "solo", "type": type, "payload": payload}))

func camera(payload: Dictionary) -> void: send("camera", payload)
func spot_preview(payload: Dictionary) -> void:
	send("spotPreview", payload if not payload.is_empty() else {"clear": true})
func land_preview(side: String) -> void: send("landPreview", {"side": side})

func after_action(result: String) -> void:
	if result == "":
		# Gains fly to the HUD and fields change in place; only builds need words.
		# New land is a story beat; a build starting is a plain note.
		if game.state.notice.ends_with("is yours"):
			var side: String = game.state.land[-1]
			ui.show_story(WorldCatalogue.title(side), WorldStory.PLACE_LINES.get(side, game.state.notice))
		elif game.state.notice.ends_with("built"): ui.show_toast(game.state.notice)
		if not game.state.speech.is_empty(): ui.show_speech(game.state.speech.name, game.state.speech.line)
		push()
	else:
		ui.show_toast(REASONS.get(result, REASONS.invalid))

func _process(delta: float) -> void:
	tick += delta
	if tick >= 1.0:
		tick = 0.0
		push()

func _on_world_message(json: String) -> void:
	var packet = JSON.parse_string(json)
	if not packet is Dictionary: return
	var payload: Dictionary = packet.get("payload", {})
	match packet.get("type", ""):
		"ready": push()
		"productionRequested", "visited":
			if game.state.find(str(payload.get("id", ""))).is_empty(): return
			ui.place_tapped(str(payload.id), str(payload.get("station", "")))
		"landRequested": ui.open("build")
		"feedbackAnchor": if str(payload.get("event", "")) == "goal": ui.point_at(float(payload.get("x", 0.5)), float(payload.get("y", 0.5)))
		"error": push_warning("World renderer: " + str(payload))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN: push()
