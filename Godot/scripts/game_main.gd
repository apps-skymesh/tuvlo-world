extends Node

## Standalone Tuvlo World: the renderer, the rules and the UI, with a host that
## saves on this device. Runs on Mac, iPhone and iPad from the same project.

const REASONS := {
	"short": "Not enough yet", "locked": "Reach a higher level first", "land": "Buy that land first",
	"full": "No free spot", "owned": "Already built", "busy": "Already making something",
	"not-ready": "Not ready yet", "growing": "Still growing", "save": "Couldn't save. Try again.",
	"read-only": "Read only", "invalid": "Can't do that now", "occupied": "That spot is taken",
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

func after_action(result: String) -> void:
	if result == "":
		if game.state.notice != "": ui.show_toast(game.state.notice)
		push()
	else:
		ui.show_toast(REASONS.get(result, "Can't do that now"))

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
			ui.open("place", str(payload.id))
		"landRequested": ui.open("land", str(payload.get("side", "")))
		"error": push_warning("World renderer: " + str(payload))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN: push()
