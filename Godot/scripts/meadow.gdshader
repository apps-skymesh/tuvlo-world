shader_type spatial;
render_mode specular_disabled;
uniform vec4 grass_color : source_color = vec4(0.61, 0.70, 0.45, 1.0);
varying vec3 world_point;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 cell=floor(p), t=fract(p);
    t=t*t*(3.0-2.0*t);
    return mix(mix(hash(cell),hash(cell+vec2(1.0,0.0)),t.x),mix(hash(cell+vec2(0.0,1.0)),hash(cell+vec2(1.0)),t.x),t.y);
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float variation=noise(world_point.xz*0.48)*0.10+noise(world_point.xz*5.0)*0.025;
    ALBEDO=grass_color.rgb*(0.95+variation);
    ROUGHNESS=1.0;
}
