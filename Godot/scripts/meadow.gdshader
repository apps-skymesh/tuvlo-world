shader_type spatial;
render_mode specular_disabled;
// Match valley.gdshader's source-colour palette before the shared noon grade.
// A separate vivid green here becomes neon under its 1.22 saturation boost.
uniform vec4 grass_color : source_color = vec4(0.47, 0.56, 0.39, 1.0);
uniform float dormant : hint_range(0.0, 1.0) = 0.0;
// A locked plot's half size: its muted tint feathers into the grass over a
// wobbling band, so the plot stays distinct without a straight cut edge.
uniform vec2 half_size = vec2(6.0, 6.0);
// The valley's distance haze, so turf and countryside agree at every edge.
uniform vec4 haze_color : source_color = vec4(0.93, 0.90, 0.78, 1.0);
uniform vec2 center = vec2(3.0, -3.0);
uniform float haze_start = 20.0;
uniform float haze_end = 62.0;
#include "res://scripts/ground_light.gdshaderinc"
varying vec3 world_point;
varying vec2 node_center;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 cell=floor(p), t=fract(p);
    t=t*t*(3.0-2.0*t);
    return mix(mix(hash(cell),hash(cell+vec2(1.0,0.0)),t.x),mix(hash(cell+vec2(0.0,1.0)),hash(cell+vec2(1.0)),t.x),t.y);
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; node_center=NODE_POSITION_WORLD.xz; }
void fragment() {
    vec2 ground = world_point.xz;
    // The same world-space variation as the valley keeps adjoining turf in
    // phase. Zoom only fades the fine blades; it never changes the base green.
    float broad = noise(ground * 0.11);
    float mottling = noise(ground * 0.5 + vec2(17.0, 3.0));
    float detail = noise(vec2(ground.x * 24.0 + ground.y * 3.0, ground.y * 9.0));
    float detail_visibility = 1.0 - smoothstep(0.04, 0.18, length(fwidth(ground)));
    vec3 grass = grass_color.rgb * (0.90 + broad * 0.14 + (mottling - 0.5) * 0.06);
    grass *= 1.0 + (detail - 0.5) * 0.035 * detail_visibility;
    vec3 quiet = mix(grass, vec3(dot(grass, vec3(0.299, 0.587, 0.114))), 0.62) * 0.90;
    vec2 local = abs(ground - node_center);
    float inside = min(half_size.x - local.x, half_size.y - local.y);
    float wobble = (noise(ground * 0.55 + vec2(5.0, 9.0)) - 0.5) * 1.0;
    float core = smoothstep(0.1, 1.5, inside + wobble);
    vec3 color = ground_light(mix(grass, quiet, dormant * core), ground);
    float haze = smoothstep(haze_start, haze_end, length((ground - center) * vec2(0.8, 1.0)));
    ALBEDO = mix(color, haze_color.rgb, haze * 0.85);
    ROUGHNESS=1.0;
}
