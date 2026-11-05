class_name HomesteadBarge
extends Node3D

## Rowan's barge at the east cove: a flat river boat with a cabin, a striped
## sail and crates that stack up as the hold is loaded. It glides in when it
## docks, bobs while it waits and sails off when it leaves. Built once from
## shared low-poly parts; display only, never part of the save.

const DOCK := Vector3(26.8, 0.0, -1.6)
const TRAVEL := 11.0      # how far along the coast it appears from and sails to
const ARRIVE_TIME := 3.2
const LEAVE_TIME := 2.6
const CRATE_SLOTS := [Vector3(-0.22, 0.52, 0.42), Vector3(0.22, 0.52, 0.42), Vector3(-0.22, 0.52, 0.86),
	Vector3(0.22, 0.52, 0.86), Vector3(0.0, 0.84, 0.64), Vector3(0.0, 0.52, 1.24)]

var hull: Node3D
var crates: Array[MeshInstance3D] = []
var docked := false
var reduced_motion := false
var travel: Tween
var bob_time := 0.0

func _ready() -> void:
	name = "Barge"
	position = DOCK
	hull = Node3D.new()
	add_child(hull)
	var M := HomesteadMesh
	M.box(hull, Vector3(0, 0.13, 0), Vector3(1.06, 0.36, 2.5), "7a4b2c", 0.16)
	M.ellipsoid(hull, Vector3(0, 0.15, 1.24), Vector3(0.53, 0.19, 0.42), "7a4b2c")
	M.ellipsoid(hull, Vector3(0, 0.15, -1.22), Vector3(0.53, 0.17, 0.30), "6c4126")
	M.box(hull, Vector3(0, 0.33, 0), Vector3(1.13, 0.07, 2.62), "553119", 0.03)
	M.box(hull, Vector3(0, 0.35, 0.05), Vector3(0.92, 0.04, 2.36), "c99a62", 0.02)
	# Cabin at the stern, with Rowan's red roof and a warm lantern.
	M.box(hull, Vector3(0, 0.6, -0.78), Vector3(0.72, 0.46, 0.74), "efe3c8", 0.05)
	M.box(hull, Vector3(0, 0.86, -0.78), Vector3(0.84, 0.08, 0.86), "c8553d", 0.03)
	M.box(hull, Vector3(0, 0.62, -0.40), Vector3(0.26, 0.24, 0.02), "6b4426", 0.01)
	M.ellipsoid(hull, Vector3(0.38, 0.72, -0.40), Vector3(0.06, 0.08, 0.06), "ffd27a")
	# Mast, a furled-cream sail with a terracotta band, and a pennant.
	M.cylinder(hull, Vector3(0, 1.3, 0.05), 0.035, 1.9, "6b4426")
	var sail := M.box(hull, Vector3(0.03, 1.45, 0.05), Vector3(0.03, 1.0, 0.86), "f4ecd8", 0.01)
	sail.rotation.y = 0.12
	var band := M.box(hull, Vector3(0.05, 1.18, 0.05), Vector3(0.035, 0.16, 0.87), "c8553d", 0.01)
	band.rotation.y = 0.12
	M.box(hull, Vector3(0, 2.2, 0.17), Vector3(0.02, 0.12, 0.26), "c8553d", 0.01)
	for i in CRATE_SLOTS.size():
		var crate := M.box(hull, CRATE_SLOTS[i], Vector3(0.34, 0.3, 0.34), "b98a52" if i % 2 == 0 else "a8773f", 0.03)
		crate.visible = false
		crates.append(crate)
	visible = false

## Shows the barge docked or away; `animate` glides it in or out.
func set_docked(next: bool, animate: bool) -> void:
	if next == docked: return
	docked = next
	if travel and travel.is_valid(): travel.kill()
	if reduced_motion or not animate:
		visible = docked
		position = DOCK
		return
	visible = true
	travel = create_tween()
	if docked:
		position = DOCK + Vector3(0, 0, -TRAVEL)
		travel.tween_property(self, "position", DOCK, ARRIVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		travel.tween_property(self, "position", DOCK + Vector3(0, 0, TRAVEL), LEAVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		travel.tween_callback(func(): visible = false; position = DOCK)

## Stacks crates on deck for the share of the manifest already loaded.
func set_cargo(share: float) -> void:
	var shown := roundi(clampf(share, 0.0, 1.0) * crates.size())
	for i in crates.size():
		var was := crates[i].visible
		crates[i].visible = i < shown
		if crates[i].visible and not was and not reduced_motion:
			crates[i].scale = Vector3(1, 0.2, 1)
			create_tween().tween_property(crates[i], "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not visible or reduced_motion:
		hull.position.y = 0.0; hull.rotation = Vector3.ZERO
		return
	bob_time += delta
	hull.position.y = sin(bob_time * 1.4) * 0.03
	hull.rotation.z = sin(bob_time * 0.9) * 0.025
	hull.rotation.x = sin(bob_time * 1.1 + 1.0) * 0.012
