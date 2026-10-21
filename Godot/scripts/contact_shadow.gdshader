shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 shadow_color : source_color = vec4(0.20, 0.27, 0.19, 0.20);
void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float falloff = 1.0 - smoothstep(0.18, 1.0, length(p));
    ALBEDO = shadow_color.rgb;
    ALPHA = shadow_color.a * falloff * falloff;
}
