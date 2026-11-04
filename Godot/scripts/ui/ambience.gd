class_name WorldAmbience
extends Node

## Environmental sound under the interface effects: a distant river that
## always runs, wooden mill gears creaking while the mill grinds, and soft bird
## calls that gather at dawn and thin out through the day. Three players and
## three small mono clips; nothing streams or allocates while playing.
const F = preload("res://scripts/ui/feel.gd")
var river: AudioStreamPlayer
var mill: AudioStreamPlayer
var birds: AudioStreamPlayer
var enabled := true
var mill_running := false
var next_creak := 0.0
var next_bird := 3.0
var fade: Tween

func _ready() -> void:
	river = _player("ambient_river", F.AMBIENT_SILENT_DB)
	mill = _player("ambient_mill", F.AMBIENT_MILL_DB)
	birds = _player("ambient_birds", F.AMBIENT_BIRDS_DB)
	if river and river.stream is AudioStreamWAV:
		var loop: AudioStreamWAV = river.stream
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
	set_enabled(enabled)

func _player(name: String, db: float) -> AudioStreamPlayer:
	var path := "res://assets/audio/%s.wav" % name
	if not ResourceLoader.exists(path): return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = db
	add_child(player)
	return player

## Follows the Sound effects setting; the river fades rather than cuts.
func set_enabled(on: bool) -> void:
	enabled = on
	if river == null: return
	if fade: fade.kill()
	fade = create_tween()
	if on:
		if not river.playing: river.play()
		fade.tween_property(river, "volume_db", F.AMBIENT_RIVER_DB, F.AMBIENT_FADE_TIME)
	else:
		fade.tween_property(river, "volume_db", F.AMBIENT_SILENT_DB, F.AMBIENT_FADE_TIME * 0.5)
		fade.tween_callback(river.stop)
		if mill: mill.stop()
		if birds: birds.stop()

## Called by the interface each frame with whether the mill is grinding.
func tick(delta: float, milling: bool) -> void:
	if not enabled: return
	if milling != mill_running:
		mill_running = milling
		next_creak = 0.3
	if mill_running and mill:
		next_creak -= delta
		if next_creak <= 0.0:
			next_creak = randf_range(F.MILL_CREAK_EVERY.x, F.MILL_CREAK_EVERY.y)
			_play(mill)
	var gap = F.BIRD_CALL_EVERY.get(HomesteadDayCycle.phase(HomesteadDayCycle.local_hour()))
	if gap != null and birds:
		next_bird -= delta
		if next_bird <= 0.0:
			next_bird = randf_range(gap.x, gap.y)
			_play(birds)

func _play(player: AudioStreamPlayer) -> void:
	player.pitch_scale = 1.0 + randf_range(-F.AMBIENT_PITCH_JITTER, F.AMBIENT_PITCH_JITTER)
	player.play()
