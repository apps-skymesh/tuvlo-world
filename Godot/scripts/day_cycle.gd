class_name HomesteadDayCycle
extends RefCounted

## The homestead's light follows the player's local clock: morning gold, a
## crisp afternoon, then a dusky amber hearth-glow with lit windows. It only
## retunes the existing sun, ambient and haze, so it adds no lights, passes or
## draw calls. The changes are slow enough that sampling every few seconds is
## seamless. Night stays bright enough to play; it is a glow, not darkness.
## Colour script: green-gold morning, crisp afternoon, amber dusk, then a cool
## blue hour where only the windows, the hearth pool and fireflies stay warm.
## Dusk pairs the warm sun with a cool ambient so shade reads cool instead of
## the whole frame going olive.
## The sun never drops below about 38 degrees: a lower sun stretches shadows
## across more of the valley and costs extra shadow draw calls on phones.
const KEYS := [
	# hour, sun colour, sun energy, sun pitch, sun yaw, ambient colour, ambient energy, haze, window glow
	[0.0, "c4ceee", 0.56, -38.0, -20.0, "aeb8dc", 0.48, "cfd3de", 1.0],
	[5.5, "ffd3a2", 0.76, -40.0, -58.0, "e2d8d6", 0.47, "efdcc2", 0.35],
	[8.5, "fff4d0", 0.92, -48.0, -38.0, "f6ead0", 0.50, "ede5c7", 0.0], # morning gold: the original look
	[13.0, "fff8ec", 0.93, -54.0, -30.0, "eef0e8", 0.52, "e8eadb", 0.0], # crisp afternoon
	[17.5, "ffc892", 0.82, -42.0, -22.0, "dcd4d8", 0.48, "f1d9b9", 0.25], # dusky amber
	[20.5, "c8d0ee", 0.60, -38.0, -20.0, "aeb8dc", 0.48, "cfd3de", 1.0], # blue hour: cool moonlight, warm windows and hearth
	[24.0, "c4ceee", 0.56, -38.0, -20.0, "aeb8dc", 0.48, "cfd3de", 1.0],
]
## The ground's colour script (GroundLight), on the same hours as KEYS:
## ground tint, cloud-shadow depth, edge dimming and edge coolness of the lit
## clearing. Evenings cool the far ground so the warm hearth reads as warm.
const GROUND := [
	[0.0, "e2e8ee", 0.00, 0.26, 0.60],
	[5.5, "eef0f0", 0.08, 0.18, 0.40],
	[8.5, "ffffff", 0.17, 0.12, 0.22],
	[13.0, "fbfffb", 0.18, 0.12, 0.22],
	[17.5, "e4eef0", 0.13, 0.17, 0.42],
	[20.5, "e2e8ee", 0.00, 0.26, 0.60],
	[24.0, "e2e8ee", 0.00, 0.26, 0.60],
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
		"ground_tint": Color(GROUND[i][1]).lerp(Color(GROUND[i + 1][1]), t),
		"cloud_depth": lerpf(GROUND[i][2], GROUND[i + 1][2], t),
		"pool_dim": lerpf(GROUND[i][3], GROUND[i + 1][3], t),
		"pool_cool": lerpf(GROUND[i][4], GROUND[i + 1][4], t),
	}

## A name for the hour, for sound and tests.
static func phase(hour: float) -> String:
	hour = fposmod(hour, 24.0)
	if hour >= 5.0 and hour < 8.0: return "dawn"
	if hour >= 8.0 and hour < 12.0: return "morning"
	if hour >= 12.0 and hour < 17.0: return "afternoon"
	if hour >= 17.0 and hour < 20.0: return "dusk"
	return "evening"
