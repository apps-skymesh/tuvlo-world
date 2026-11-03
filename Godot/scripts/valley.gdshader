shader_type spatial;
render_mode specular_disabled;
// Scenery around the homestead: soft countryside that fades into haze, with a
// calm sea beyond the east cove. Display only; nothing here is buildable.
uniform vec4 grass_color : source_color = vec4(0.56, 0.64, 0.45, 1.0);
uniform vec4 sand_color : source_color = vec4(0.88, 0.80, 0.60, 1.0);
uniform vec4 sea_color : source_color = vec4(0.48, 0.70, 0.70, 1.0);
uniform vec4 haze_color : source_color = vec4(0.93, 0.90, 0.78, 1.0);
uniform vec2 center = vec2(3.0, -3.0);
uniform float shore_x = 27.6;
uniform float haze_start = 20.0;
uniform float haze_end = 62.0;
varying vec3 world_point;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 cell=floor(p), t=fract(p);
    t=t*t*(3.0-2.0*t);
    return mix(mix(hash(cell),hash(cell+vec2(1.0,0.0)),t.x),mix(hash(cell+vec2(0.0,1.0)),hash(cell+vec2(1.0)),t.x),t.y);
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 ground = world_point.xz;
    float broad = noise(ground * 0.11);
    float mottling = noise(ground * 0.5 + vec2(17.0, 3.0));
    vec3 grass = grass_color.rgb * (0.90 + broad * 0.14 + (mottling - 0.5) * 0.06);
    float shoreline = shore_x + (noise(vec2(0.0, ground.y * 0.18)) - 0.5) * 2.2;
    float sand = smoothstep(shoreline - 1.4, shoreline - 0.6, ground.x);
    float sea = smoothstep(shoreline - 0.1, shoreline + 0.3, ground.x);
    vec3 color = mix(mix(grass, sand_color.rgb, sand), sea_color.rgb * (0.96 + broad * 0.08), sea);
    float distance = length((ground - center) * vec2(0.8, 1.0));
    float haze = smoothstep(haze_start, haze_end, distance);
    ALBEDO = mix(color, haze_color.rgb, haze * 0.85);
    ROUGHNESS = 1.0;
}
