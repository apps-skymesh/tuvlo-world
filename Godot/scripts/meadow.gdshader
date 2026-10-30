shader_type spatial;
render_mode specular_disabled;
// Match valley.gdshader's source-colour palette before the shared noon grade.
// A separate vivid green here becomes neon under its 1.22 saturation boost.
uniform vec4 grass_color : source_color = vec4(0.56, 0.64, 0.45, 1.0);
uniform float dormant : hint_range(0.0, 1.0) = 0.0;
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
    // The same world-space variation as the valley keeps adjoining turf in
    // phase. Zoom only fades the fine blades; it never changes the base green.
    float broad = noise(ground * 0.11);
    float mottling = noise(ground * 0.5 + vec2(17.0, 3.0));
    float detail = noise(vec2(ground.x * 24.0 + ground.y * 3.0, ground.y * 9.0));
    float detail_visibility = 1.0 - smoothstep(0.04, 0.18, length(fwidth(ground)));
    vec3 grass = grass_color.rgb * (0.90 + broad * 0.14 + (mottling - 0.5) * 0.06);
    grass *= 1.0 + (detail - 0.5) * 0.035 * detail_visibility;
    vec3 quiet = mix(grass, vec3(dot(grass, vec3(0.299, 0.587, 0.114))), 0.62) * 0.90;
    ALBEDO = mix(grass, quiet, dormant);
    ROUGHNESS=1.0;
}
