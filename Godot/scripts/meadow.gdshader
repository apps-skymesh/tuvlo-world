shader_type spatial;
render_mode specular_disabled;
uniform vec4 grass_color : source_color = vec4(0.53, 0.67, 0.39, 1.0);
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
    vec2 drift = vec2(noise(ground * 0.13), noise(ground * 0.13 + vec2(31.4, 7.2)));
    float broad = noise(ground * 0.24 + drift * 1.8);
    float mottling = noise(ground * 0.85 + drift * 2.4);
    float detail = noise(vec2(ground.x * 24.0 + ground.y * 3.0, ground.y * 9.0));
    float detail_visibility = 1.0 - smoothstep(0.04, 0.18, length(fwidth(ground)));
    vec3 cool = grass_color.rgb * vec3(0.88, 0.96, 0.91);
    vec3 warm = grass_color.rgb * vec3(1.08, 1.03, 0.96);
    vec3 grass = mix(cool, warm, smoothstep(0.15, 0.85, broad));
    grass *= 0.96 + mottling * 0.08 + (detail - 0.5) * 0.035 * detail_visibility;
    vec3 quiet = mix(grass, vec3(dot(grass, vec3(0.299, 0.587, 0.114))), 0.62) * 0.90;
    ALBEDO = mix(grass, quiet, dormant);
    ROUGHNESS=1.0;
}
