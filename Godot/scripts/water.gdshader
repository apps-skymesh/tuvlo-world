shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 water_color : source_color = vec4(0.36, 0.65, 0.68, 1.0);
uniform float clock = 0.0;
uniform float motion = 1.0;
void vertex() {
 VERTEX.y += sin(VERTEX.x*2.2+clock*0.7)*cos(VERTEX.z*1.8+clock*0.55)*0.018*motion;
}
void fragment() {
 float ripple = sin((UV.x+UV.y)*60.0+clock*0.6*motion)*0.025;
 ALBEDO=water_color.rgb+vec3(ripple);
 ROUGHNESS=0.42;
 METALLIC=0.03;
}
