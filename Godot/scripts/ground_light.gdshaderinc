// Ground light: the one place the valley's colour script, focal pool, hearth
// glow and drifting cloud shadows are painted. Shared by the turf (meadow) and
// the countryside (valley) so every edge stays in phase. It only retints the
// ground's albedo, so it costs a few ALU ops and no lights, passes or draws.
// Values come from GroundLight (scripts/ground_light.gd) through four global
// uniforms declared in project.godot.

// rgb: colour-script tint for the ground; a: cloud-shadow depth (0 = none).
global uniform vec4 ground_grade;
// xy: the cottage on the ground plane; z: hearth-glow radius; w: hearth strength.
global uniform vec4 ground_hearth;
// The lit clearing. xy: its centre; z: lit radius; w: where the falloff ends.
global uniform vec4 ground_pool;
// xy: cloud offset in noise cells, advanced on the CPU and wrapped at
// GROUND_CLOUD_PERIOD so Reduce Motion can hold it exactly where it is.
// z: dimming beyond the clearing; w: coolness beyond the clearing.
global uniform vec4 ground_air;

const float GROUND_CLOUD_PERIOD = 48.0;
const float GROUND_CLOUD_SCALE = 0.055; // noise cells per metre: clouds ~15 m across

float ground_cloud_hash(vec2 cell, float period) {
    cell = mod(cell, period);
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
// Value noise that tiles every `period` cells, so the wrapped drift never seams.
float ground_cloud_noise(vec2 p, float period) {
    vec2 cell = floor(p), t = fract(p);
    t = t * t * (3.0 - 2.0 * t);
    return mix(mix(ground_cloud_hash(cell, period), ground_cloud_hash(cell + vec2(1.0, 0.0), period), t.x),
               mix(ground_cloud_hash(cell + vec2(0.0, 1.0), period), ground_cloud_hash(cell + vec2(1.0), period), t.x), t.y);
}

vec3 ground_light(vec3 color, vec2 ground) {
    color *= ground_grade.rgb;
    // The lit clearing: the homestead holds the light and the far ground
    // settles darker and cooler, so the eye stays on the buildings.
    float edge = smoothstep(ground_pool.z, ground_pool.w, length(ground - ground_pool.xy));
    color *= 1.0 - edge * ground_air.z;
    color = mix(color, color * vec3(0.90, 0.97, 1.10), edge * ground_air.w);
    // Slow cloud shadows: soft, cool and only on the ground.
    vec2 p = ground * GROUND_CLOUD_SCALE + ground_air.xy;
    float n = ground_cloud_noise(p, GROUND_CLOUD_PERIOD) * 0.68
            + ground_cloud_noise(p * 2.0 + vec2(7.0, 3.0), GROUND_CLOUD_PERIOD * 2.0) * 0.32;
    float shade = smoothstep(0.47, 0.68, n) * ground_grade.a;
    color *= 1.0 - shade;
    color = mix(color, color * vec3(0.88, 0.96, 1.12), shade * 1.6);
    // The hearth: a warm pool of window and lantern light around the cottage
    // once evening comes, painted rather than lit.
    float warmth = 1.0 - smoothstep(0.0, ground_hearth.z, length(ground - ground_hearth.xy));
    color += vec3(1.0, 0.58, 0.26) * warmth * warmth * ground_hearth.w;
    return color;
}
