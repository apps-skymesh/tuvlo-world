shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// A restrained SDR finish: hold highlights below white and reduce the
// yellow-green wash without blurring, UV distortion, bloom or grain.
void fragment() {
    vec3 source = clamp(textureLod(screen_texture, SCREEN_UV, 0.0).rgb, vec3(0.0), vec3(1.0));
    float luminance = dot(source, vec3(0.2126, 0.7152, 0.0722));
    vec3 palette = mix(vec3(luminance), source, 0.88);
    vec3 graded = pow(palette, vec3(1.12)) * vec3(0.86, 0.88, 0.90);
    COLOR = vec4(graded, 1.0);
}
