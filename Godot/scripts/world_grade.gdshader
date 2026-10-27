shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// Noon finish: more color, less darkening, a warm cap still below white.
// No blur, UV distortion, bloom, or grain.
void fragment() {
    vec3 source = clamp(textureLod(screen_texture, SCREEN_UV, 0.0).rgb, vec3(0.0), vec3(1.0));
    float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
    vec3 palette = clamp(mix(vec3(luminance), source, 1.22), vec3(0.0), vec3(1.0));
    vec3 graded = pow(palette, vec3(1.05)) * vec3(0.96, 0.94, 0.90);
    COLOR = vec4(graded, 1.0);
}
