shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center = vec2(0.5,0.5);
uniform float phase = 0.0;
uniform float strength = 0.0;
uniform vec2 extent = vec2(0.08,0.12);
uniform vec2 distortion = vec2(0.0015,0.002);
void fragment() {
    vec2 p = (SCREEN_UV-center)/max(extent,vec2(0.001));
    float mask = (1.0-smoothstep(0.2,1.0,length(p))) * strength;
    vec2 shimmer = vec2(sin(p.y*115.0-phase*22.0),cos(p.x*90.0+phase*14.0));
    vec2 uv = clamp(SCREEN_UV+shimmer*mask*distortion,vec2(0.001),vec2(0.999));
    COLOR = vec4(textureLod(screen_texture,uv,0.0).rgb,1.0);
}
