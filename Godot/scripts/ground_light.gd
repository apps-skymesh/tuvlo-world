class_name GroundLight
extends RefCounted

## Feeds the ground's light (scripts/ground_light.gdshaderinc): the day's colour
## script, the lit clearing, the evening hearth pool around the cottage and slow
## cloud shadows. Four global shader uniforms, so the turf and valley read them
## without per-material updates, extra lights or draw calls.

## Cloud drift in noise cells per second along the wind (about 0.25 m/s: a
## cloud takes over a minute to cross the clearing).
const CLOUD_SPEED := Vector2(0.0135, 0.0045)
const CLOUD_PERIOD := 48.0 # matches GROUND_CLOUD_PERIOD in the shader include
## The lit clearing: the middle of the starting land, in metres.
const POOL_CENTER := Vector2(1.0, 2.0)
const POOL_INNER := 11.0
const POOL_OUTER := 26.0
## Hearth-glow radius in metres and its strength at full evening glow.
const HEARTH_RADIUS := 9.0
const HEARTH_STRENGTH := 0.40

static var cloud := Vector2(7.0, 19.0)
static var edge := Vector2.ZERO
static var _sent := {}

## Day values come from HomesteadDayCycle.at(); `overcast` (0–1) fades the
## cloud shadows when the whole sky is grey, as in rain.
static func apply(day: Dictionary, hearth: Vector3, overcast: float) -> void:
	var tint: Color = day.get("ground_tint", Color.WHITE)
	_send("ground_grade", Vector4(tint.r, tint.g, tint.b, float(day.get("cloud_depth", 0.0)) * (1.0 - clampf(overcast, 0.0, 1.0))))
	_send("ground_hearth", Vector4(hearth.x, hearth.z, HEARTH_RADIUS, float(day.get("glow", 0.0)) * HEARTH_STRENGTH))
	_send("ground_pool", Vector4(POOL_CENTER.x, POOL_CENTER.y, POOL_INNER, POOL_OUTER))
	edge = Vector2(float(day.get("pool_dim", 0.0)), float(day.get("pool_cool", 0.0)))
	_send("ground_air", Vector4(cloud.x, cloud.y, edge.x, edge.y))

## Moves the cloud shadows on with the wind. Reduce Motion holds them where
## they are (no jump back), and the offset wraps at the noise period so it
## never seams.
static func advance(delta: float, gust: float, still: bool) -> void:
	if still: return
	cloud += CLOUD_SPEED * delta * clampf(gust, 0.5, 2.0)
	cloud = Vector2(fposmod(cloud.x, CLOUD_PERIOD), fposmod(cloud.y, CLOUD_PERIOD))
	_send("ground_air", Vector4(cloud.x, cloud.y, edge.x, edge.y))

static func _send(name: String, value: Vector4) -> void:
	if _sent.has(name) and (_sent[name] as Vector4).is_equal_approx(value): return
	_sent[name] = value
	RenderingServer.global_shader_parameter_set(name, value)
