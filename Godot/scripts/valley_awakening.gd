class_name HomesteadAwakening
extends Node3D

## The valley wakes up as the homestead levels: each tier adds a piece of
## life around the clearing and stays for good. Scenery only: no colliders,
## no cells, nothing tappable, nothing inside a building spot.
## Reduce Motion keeps every tier visible but holds it still.

const TIERS := [
	{"level": 1, "key": "flowers", "line": "Wildflowers bloom"},
	{"level": 2, "key": "butterflies", "line": "Butterflies find the flowers"},
	{"level": 3, "key": "lanterns", "line": "Someone lit the lanterns"},
	{"level": 4, "key": "birds", "line": "Songbirds come home"},
	{"level": 5, "key": "kite", "line": "A kite tugs at the wind"},
	{"level": 6, "key": "neighbours", "line": "A neighbour's lights come on"},
	{"level": 8, "key": "balloon", "line": "A balloon drifts by"},
	{"level": 10, "key": "rainbow", "line": "A rainbow over the hills"},
	{"level": 12, "key": "sailboat", "line": "A sail on the sea"},
]
const REVEAL_TIME := 0.7
const FLOWER_TONES := ["f2a6b8", "f6d36b", "ffffff", "c9a7ec", "f4a259"]
# Flower beds sit just outside the starter clearing (world x −9…11, z −8…12),
# along its north and east edges, where no fixed building spot reaches.
const FLOWER_BEDS := [Vector2(-8.0, -9.6), Vector2(-3.5, -9.5), Vector2(1.5, -9.7), Vector2(6.0, -9.5), Vector2(10.5, -9.6), Vector2(12.6, -4.5), Vector2(12.7, 0.5), Vector2(12.5, 5.5)]
const BUTTERFLY_COUNT := 5
const BIRD_COUNT := 4
const BIRD_HEIGHT := 7.5
const BIRD_ORBIT := Vector3(1, 0, -2)
const NEIGHBOUR_FARM := Vector3(17, 0, -15)
const BALLOON_HEIGHT := 6.0
const BALLOON_SWEEP := 26.0
const BALLOON_PERIOD := 70.0
const RAINBOW_CENTRE := Vector3(2, -3, -21)
const RAINBOW_RADIUS := 10.0
const RAINBOW_BANDS := ["e86a6a", "f2a65a", "f6d36b", "8fcf7a", "6fb3e0", "9b87d9"]
# Lanterns stand between the flower beds along the clearing's north and east
# edges, outside every building spot. They glow with the evening windows.
const LANTERNS := [Vector2(-5.75, -9.3), Vector2(-1.0, -9.3), Vector2(3.75, -9.3), Vector2(8.25, -9.3), Vector2(12.4, -2.0), Vector2(12.4, 3.0)]
const LANTERN_DAY_GLOW := 0.25
const LANTERN_NIGHT_GLOW := 2.4
# The kite flies over the far west meadow on a long string.
const KITE_ANCHOR := Vector3(-15.0, 0.0, 9.0)
const KITE_HEIGHT := 7.0
# The sailboat crosses the sea beyond the barge's cove, slowly.
const SAIL_X := 37.0
const SAIL_SWEEP := 16.0
const SAIL_PERIOD := 120.0

var level := -1
var reduced_motion := false
var clock := 0.0
var parts := {}  # tier key -> Node3D
var flutter: Array[Node3D] = []
var birds: Array[Node3D] = []
var balloon: Node3D
var kite: Node3D
var sailboat: Node3D
var lantern_glow: StandardMaterial3D
var glow := 0.0

## Tiers newly reached when the level rises from `before` to `after`.
static func woken(before: int, after: int) -> Array:
	return TIERS.filter(func(tier): return tier.level > before and tier.level <= after)

static func awake_keys(at_level: int) -> Array:
	return TIERS.filter(func(tier): return tier.level <= at_level).map(func(tier): return tier.key)

## Shows every tier the level has reached. The first call (opening the game)
## places them quietly; later rises reveal the new ones with a grow-in.
func wake(at_level: int, reduce: bool) -> void:
	reduced_motion = reduce
	var first := level < 0
	level = at_level
	for tier in TIERS:
		if tier.level > at_level or parts.has(tier.key): continue
		var node := Node3D.new()
		node.name = "Awake_" + tier.key
		add_child(node)
		parts[tier.key] = node
		call("_build_" + tier.key, node)
		for child in node.find_children("*", "GeometryInstance3D", true, false):
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not first and not reduced_motion: _reveal(node)

func _reveal(node: Node3D) -> void:
	for child in node.get_children():
		if not child is Node3D: continue
		var rest: Vector3 = child.scale
		child.scale = rest * 0.01
		var tween := child.create_tween()
		tween.tween_interval(randf_range(0.0, 0.35))
		tween.tween_property(child, "scale", rest, REVEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_flowers(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7713
	for bed: Vector2 in FLOWER_BEDS:
		var patch := Node3D.new()
		patch.position = Vector3(bed.x, -0.1, bed.y)
		root.add_child(patch)
		HomesteadMesh.ellipsoid(patch, Vector3(0, 0.05, 0), Vector3(1.1, 0.16, 0.8), "86ad62")
		for i in 7:
			var spot := Vector3(rng.randf_range(-0.85, 0.85), 0, rng.randf_range(-0.55, 0.55))
			var height := rng.randf_range(0.22, 0.42)
			HomesteadMesh.cylinder(patch, spot + Vector3(0, height / 2, 0), 0.025, height, "5f8f55")
			HomesteadMesh.ellipsoid(patch, spot + Vector3(0, height, 0), Vector3.ONE * rng.randf_range(0.09, 0.14), FLOWER_TONES[rng.randi_range(0, FLOWER_TONES.size() - 1)])

func _build_butterflies(root: Node3D) -> void:
	var tones := ["f6d36b", "ffffff", "f2a6b8", "8fc9ef", "f4a259"]
	for i in BUTTERFLY_COUNT:
		var fly := Node3D.new()
		var bed: Vector2 = FLOWER_BEDS[(i * 3) % FLOWER_BEDS.size()]
		fly.set_meta("home", Vector3(bed.x, 0.9, bed.y))
		fly.set_meta("phase", i * 1.7)
		fly.position = fly.get_meta("home")
		root.add_child(fly)
		for side in [-1, 1]:
			var wing := Node3D.new()
			wing.name = "Wing"
			fly.add_child(wing)
			HomesteadMesh.ellipsoid(wing, Vector3(side * 0.09, 0, 0), Vector3(0.09, 0.015, 0.07), tones[i])
		flutter.append(fly)

func _build_birds(root: Node3D) -> void:
	for i in BIRD_COUNT:
		var bird := Node3D.new()
		bird.set_meta("phase", TAU * i / BIRD_COUNT)
		bird.set_meta("radius", 5.0 + i * 1.3)
		root.add_child(bird)
		HomesteadMesh.ellipsoid(bird, Vector3.ZERO, Vector3(0.1, 0.08, 0.2), "4a5560")
		for side in [-1, 1]:
			var wing := Node3D.new()
			wing.name = "Wing"
			bird.add_child(wing)
			HomesteadMesh.ellipsoid(wing, Vector3(side * 0.22, 0, 0), Vector3(0.22, 0.02, 0.08), "4a5560")
		birds.append(bird)
	_place_birds()

func _build_neighbours(root: Node3D) -> void:
	var farm := Node3D.new()
	farm.position = NEIGHBOUR_FARM
	farm.rotation.y = 0.4
	root.add_child(farm)
	HomesteadMesh.box(farm, Vector3(0, 0.7, 0), Vector3(2.4, 1.4, 1.8), "efe2c6", 0.08)
	var roof := HomesteadMesh.cylinder(farm, Vector3(0, 1.75, 0), 1.45, 1.9, "d9774f", 0.0)
	roof.scale = Vector3(1.0, 0.55, 0.8)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd27a")
	glow.emission_enabled = true
	glow.emission = Color("ffc35a")
	glow.emission_energy_multiplier = 1.6
	for x in [-0.6, 0.6]:
		var window := HomesteadMesh.box(farm, Vector3(x, 0.75, 0.91), Vector3(0.38, 0.38, 0.04), "ffd27a", 0.02)
		window.material_override = glow
	HomesteadMesh.cylinder(farm, Vector3(-1.8, 0.9, 0.4), 0.55, 1.8, "c7d9a0", 0.0)

func _build_balloon(root: Node3D) -> void:
	balloon = Node3D.new()
	root.add_child(balloon)
	HomesteadMesh.ellipsoid(balloon, Vector3(0, 1.1, 0), Vector3(1.0, 1.2, 1.0), "e86a6a")
	HomesteadMesh.ellipsoid(balloon, Vector3(0, 1.1, 0), Vector3(1.02, 0.35, 1.02), "f6d36b")
	HomesteadMesh.box(balloon, Vector3(0, -0.35, 0), Vector3(0.42, 0.32, 0.42), "8a6d4f", 0.04)
	for x in [-0.17, 0.17]:
		HomesteadMesh.rod(balloon, Vector3(x, -0.2, 0), Vector3(x * 2.4, 0.3, 0), 0.015, "6a5640")
	_place_balloon()

func _build_rainbow(root: Node3D) -> void:
	var arc := Node3D.new()
	arc.position = RAINBOW_CENTRE
	arc.rotation = Vector3(PI / 2, 0.25, 0)
	root.add_child(arc)
	for i in RAINBOW_BANDS.size():
		var band := HomesteadMesh.torus(arc, Vector3.ZERO, RAINBOW_RADIUS - i * 0.42, 0.22, RAINBOW_BANDS[i])
		band.material_override = HomesteadMesh.transparent(Color(RAINBOW_BANDS[i], 0.45))

func _build_lanterns(root: Node3D) -> void:
	lantern_glow = StandardMaterial3D.new()
	lantern_glow.albedo_color = Color("ffe2a0")
	lantern_glow.emission_enabled = true
	lantern_glow.emission = Color("ffb84d")
	set_glow(glow)
	for spot: Vector2 in LANTERNS:
		var post := Node3D.new()
		post.position = Vector3(spot.x, 0, spot.y)
		root.add_child(post)
		HomesteadMesh.cylinder(post, Vector3(0, 0.6, 0), 0.05, 1.2, "5b4636")
		HomesteadMesh.box(post, Vector3(0, 1.24, 0), Vector3(0.3, 0.06, 0.3), "3f3128", 0.02)
		var lamp := HomesteadMesh.box(post, Vector3(0, 1.4, 0), Vector3(0.22, 0.26, 0.22), "ffe2a0", 0.03)
		lamp.material_override = lantern_glow
		HomesteadMesh.cylinder(post, Vector3(0, 1.58, 0), 0.19, 0.12, "3f3128", 0.02)

## Lanterns follow the windows: a faint glow by day, warm at night.
func set_glow(level: float) -> void:
	glow = level
	if lantern_glow: lantern_glow.emission_energy_multiplier = lerpf(LANTERN_DAY_GLOW, LANTERN_NIGHT_GLOW, clampf(level, 0.0, 1.0))

func _build_kite(root: Node3D) -> void:
	kite = Node3D.new()
	root.add_child(kite)
	# A diamond: a square turned on its corner, then narrowed.
	var face := Node3D.new()
	face.scale = Vector3(0.7, 1.0, 1.0)
	kite.add_child(face)
	HomesteadMesh.box(face, Vector3.ZERO, Vector3(0.9, 0.9, 0.04), "e86a6a", 0.02).rotation.z = PI / 4
	HomesteadMesh.box(face, Vector3(0, 0, 0.03), Vector3(0.06, 1.25, 0.02), "f6d36b", 0.01)
	HomesteadMesh.box(face, Vector3(0, 0, 0.03), Vector3(1.25, 0.06, 0.02), "f6d36b", 0.01)
	for i in 4:
		HomesteadMesh.ellipsoid(kite, Vector3(sin(i * 1.3) * 0.12, -0.8 - i * 0.32, 0), Vector3(0.08, 0.05, 0.02), ["8fc9ef", "f6d36b", "f2a6b8", "ffffff"][i])
	# One unit-long string, stretched and turned each frame (no new meshes).
	var string := Node3D.new()
	string.name = "String"
	string.position = KITE_ANCHOR
	root.add_child(string)
	HomesteadMesh.cylinder(string, Vector3(0, 0.5, 0), 0.012, 1.0, "f4ead6")
	kite.set_meta("string", string)
	_place_kite()

func _build_sailboat(root: Node3D) -> void:
	sailboat = Node3D.new()
	root.add_child(sailboat)
	HomesteadMesh.box(sailboat, Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 1.9), "8a5a3a", 0.12)
	HomesteadMesh.rod(sailboat, Vector3(0, 0.3, 0.1), Vector3(0, 2.6, 0.1), 0.04, "5b4636")
	HomesteadMesh.box(sailboat, Vector3(0, 1.45, -0.35), Vector3(0.04, 2.0, 0.85), "fff4e0", 0.01)
	HomesteadMesh.box(sailboat, Vector3(0, 2.7, 0.1), Vector3(0.03, 0.18, 0.36), "e86a6a", 0.01)
	_place_sailboat()

func _place_kite() -> void:
	var sway := Vector3(sin(clock * 0.5) * 1.2, sin(clock * 0.9) * 0.4, cos(clock * 0.35) * 0.6)
	kite.position = KITE_ANCHOR + Vector3(2.5, KITE_HEIGHT, -2.0) + sway
	kite.rotation = Vector3(0, 0.6, sin(clock * 1.3) * 0.25)
	var string: Node3D = kite.get_meta("string")
	var reach := kite.position - KITE_ANCHOR
	string.basis = Basis(Quaternion(Vector3.UP, reach.normalized())) * Basis.from_scale(Vector3(1, reach.length(), 1))

func _place_sailboat() -> void:
	var t := fposmod(clock / SAIL_PERIOD, 1.0)
	var along := sin(t * TAU)
	sailboat.position = Vector3(SAIL_X, sin(clock * 1.1) * 0.05, along * SAIL_SWEEP)
	sailboat.rotation = Vector3(0, PI if cos(t * TAU) < 0 else 0.0, sin(clock * 0.9) * 0.05)

func _place_birds() -> void:
	for bird in birds:
		var angle: float = bird.get_meta("phase") + clock * 0.22
		var radius: float = bird.get_meta("radius")
		bird.position = BIRD_ORBIT + Vector3(cos(angle) * radius, BIRD_HEIGHT + sin(angle * 2.0) * 0.4, sin(angle) * radius * 0.6)
		bird.rotation.y = -angle
		for wing in bird.get_children():
			if wing.name.begins_with("Wing"): wing.rotation.z = (sin(clock * 6.0 + angle) * 0.45) * (1 if wing.get_index() % 2 == 0 else -1)

func _place_balloon() -> void:
	var t := fposmod(clock / BALLOON_PERIOD, 1.0)
	balloon.position = Vector3(lerpf(-BALLOON_SWEEP, BALLOON_SWEEP, t), BALLOON_HEIGHT + sin(clock * 0.4) * 0.3, -7)

func _process(delta: float) -> void:
	if reduced_motion or parts.is_empty(): return
	clock += delta
	for fly in flutter:
		var phase: float = fly.get_meta("phase")
		var home: Vector3 = fly.get_meta("home")
		var t := clock * 0.7 + phase
		fly.position = home + Vector3(sin(t) * 0.9, sin(t * 2.3) * 0.25, cos(t * 0.8) * 0.6)
		fly.rotation.y = -t
		var beat := absf(sin(clock * 14.0 + phase)) * 1.1
		for i in fly.get_child_count():
			fly.get_child(i).rotation.z = beat * (1 if i == 0 else -1)
	if not birds.is_empty(): _place_birds()
	if balloon: _place_balloon()
	if kite: _place_kite()
	if sailboat: _place_sailboat()
