class_name HomesteadDayCycle
extends RefCounted

## The homestead's light follows the player's local clock: morning gold, a
## crisp afternoon, then a dusky amber hearth-glow with lit windows. It only
## retunes the existing sun, ambient and haze, so it adds no lights, passes or
## draw calls. The changes are slow enough that sampling every few seconds is
## seamless. Night stays bright enough to play; it is a glow, not darkness.
## The sun never drops below about 38 degrees: a lower sun stretches shadows
## across more of the valley and costs extra shadow draw calls on phones.
const KEYS := [
	# hour, sun colour, sun energy, sun pitch, sun yaw, ambient colour, ambient energy, haze, window glow
	[0.0, "ffb27a", 0.58, -38.0, -20.0, "cdbcc6", 0.44, "e6d6c4", 1.0],
	[5.5, "ffd3a2", 0.76, -40.0, -58.0, "efddc8", 0.47, "efdcc2", 0.35],
	[8.5, "fff4d0", 0.92, -48.0, -38.0, "f6ead0", 0.50, "ede5c7", 0.0], # morning gold: the original look
	[13.0, "fff8ec", 0.93, -54.0, -30.0, "eef0e8", 0.52, "e8eadb", 0.0], # crisp afternoon
	[17.5, "ffc892", 0.82, -42.0, -22.0, "f3d4b2", 0.48, "f1d9b9", 0.25], # dusky amber
	[20.5, "ffb478", 0.64, -38.0, -20.0, "dac3c2", 0.45, "e9d3c2", 1.0], # hearth-glow
	[24.0, "ffb27a", 0.58, -38.0, -20.0, "cdbcc6", 0.44, "e6d6c4", 1.0],
]
const SAMPLE_SECONDS := 4.0
## Captures and tests can pin the hour; -1 follows the clock.
static var hour_override := -1.0

static func local_hour() -> float:
	if hour_override >= 0.0: return fposmod(hour_override, 24.0)
	var now := Time.get_datetime_dict_from_system()
	return float(now.hour) + float(now.minute) / 60.0 + float(now.second) / 3600.0

static func at(hour: float) -> Dictionary:
	hour = fposmod(hour, 24.0)
	var i := 0
	while i < KEYS.size() - 2 and hour >= KEYS[i + 1][0]: i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var t := smoothstep(0.0, 1.0, (hour - a[0]) / (b[0] - a[0]))
	return {
		"sun_color": Color(a[1]).lerp(Color(b[1]), t),
		"sun_energy": lerpf(a[2], b[2], t),
		"sun_pitch": lerpf(a[3], b[3], t),
		"sun_yaw": lerpf(a[4], b[4], t),
		"ambient_color": Color(a[5]).lerp(Color(b[5]), t),
		"ambient_energy": lerpf(a[6], b[6], t),
		"haze": Color(a[7]).lerp(Color(b[7]), t),
		"glow": lerpf(a[8], b[8], t),
	}

## A name for the hour, for sound and tests.
static func phase(hour: float) -> String:
	hour = fposmod(hour, 24.0)
	if hour >= 5.0 and hour < 8.0: return "dawn"
	if hour >= 8.0 and hour < 12.0: return "morning"
	if hour >= 12.0 and hour < 17.0: return "afternoon"
	if hour >= 17.0 and hour < 20.0: return "dusk"
	return "evening"
