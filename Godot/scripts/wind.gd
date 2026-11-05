class_name HomesteadWind
extends RefCounted

## Swaps matte leaf and crop materials for wind-swayed twins. One twin per
## source material and profile, so draw calls and batching are unchanged; the
## sway runs entirely in the vertex shader. The source stays on the node as
## "wind_source" for camera fading.
const SHADER := preload("res://scripts/wind.gdshader")
## amplitude (metres at full bend), bend_from/bend_to (world height where the
## sway starts and reaches full strength), speed.
const PROFILES := {
	"tree": {"amplitude": 0.07, "bend_from": 0.5, "bend_to": 2.8, "speed": 1.0},
	"crop": {"amplitude": 0.06, "bend_from": 0.3, "bend_to": 0.9, "speed": 1.35},
	"valley": {"amplitude": 0.11, "bend_from": 0.8, "bend_to": 3.2, "speed": 0.8},
}
static var twins := {}
static var still := false
static var gust := 1.0

static func apply(node: Node, profile: String) -> void:
	if node is MeshInstance3D and node.mesh != null:
		if node.mesh.get_surface_count() == 1:
			var source = node.material_override if node.material_override else node.get_active_material(0)
			var twin := twin_of(source, profile)
			if twin:
				node.set_meta("wind_source", source)
				node.material_override = twin
		else:
			for i in node.mesh.get_surface_count():
				var twin := twin_of(node.get_active_material(i), profile)
				if twin: node.set_surface_override_material(i, twin)
	for child in node.get_children(): apply(child, profile)

static func twin_of(source: Material, profile: String) -> ShaderMaterial:
	if not source is StandardMaterial3D: return null
	var base := source as StandardMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.albedo_texture != null: return null
	var key := "%d:%s" % [base.get_instance_id(), profile]
	if twins.has(key) and is_instance_valid(twins[key]): return twins[key]
	var twin := ShaderMaterial.new()
	twin.shader = SHADER
	twin.set_shader_parameter("albedo", base.albedo_color)
	twin.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
	twin.set_shader_parameter("roughness", base.roughness)
	for name in PROFILES[profile]: twin.set_shader_parameter(name, PROFILES[profile][name])
	twin.set_shader_parameter("strength", 0.0 if still else gust)
	twins[key] = twin
	return twin

## Reduce Motion: hold every swaying surface still.
static func set_still(on: bool) -> void:
	still = on
	for key in twins.keys():
		if is_instance_valid(twins[key]): twins[key].set_shader_parameter("strength", 0.0 if on else gust)
		else: twins.erase(key)

## Weather: scales every sway (1 is a calm day). Ignored under Reduce Motion.
static func set_gust(level: float) -> void:
	if still or absf(level - gust) < 0.03: return  # coarse steps: a gust easing in touches every twin only a few times
	gust = level
	for key in twins.keys():
		if is_instance_valid(twins[key]): twins[key].set_shader_parameter("strength", gust)
		else: twins.erase(key)
