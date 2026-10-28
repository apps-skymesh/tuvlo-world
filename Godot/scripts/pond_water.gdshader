shader_type spatial;
render_mode specular_schlick_ggx;
uniform float clock = 0.0;
uniform float motion = 1.0;
uniform vec4 deep_color : source_color = vec4(0.22,0.49,0.48,1.0);
uniform vec4 shallow_color : source_color = vec4(0.61,0.73,0.61,1.0);
uniform vec4 sky_color : source_color = vec4(0.78,0.87,0.79,1.0);
varying vec2 pond_position;
float ring(vec2 point,vec2 origin,float age) {
 float radius=length(point-origin);
 float envelope=smoothstep(0.0,0.3,age)*(1.0-smoothstep(1.5,2.5,age));
 return exp(-pow((radius-age*0.13)*95.0,2.0))*envelope;
}
float pebble(vec2 p,vec2 center,vec2 size) {
 return 1.0-smoothstep(.70,1.0,length((p-center)/size));
}
void vertex() {
 pond_position=VERTEX.xz;
 float edge=smoothstep(0.0,0.20,COLOR.r);
 VERTEX.y += sin(VERTEX.x*3.1+clock*0.62)*cos(VERTEX.z*2.7-clock*0.43)*0.004*motion*edge;
}
void fragment() {
 float t=clock*motion;
 float depth=clamp(COLOR.r,0.0,1.0);
 float basin=smoothstep(0.02,0.60,depth);
 vec3 water=mix(shallow_color.rgb,deep_color.rgb,basin);
 float stones=pebble(pond_position,vec2(-.37,.65),vec2(.085,.055))
  +pebble(pond_position,vec2(-.14,.74),vec2(.055,.045))
  +pebble(pond_position,vec2(.12,.68),vec2(.07,.05))
  +pebble(pond_position,vec2(-.84,-.12),vec2(.06,.09))
  +pebble(pond_position,vec2(.72,-.27),vec2(.07,.05));
 water=mix(water,shallow_color.rgb*.76,clamp(stones,0.0,1.0)*(1.0-smoothstep(.13,.43,depth))*.36);
 // Broad caustics and a soft sky sheen leave quiet areas between highlights.
 float light_field=sin(pond_position.x*8.0+sin(pond_position.y*6.0+t*.24))*sin(pond_position.y*9.0-t*.27);
 float caustic=pow(max(0.0,light_field),5.0)*(1.0-basin)*0.065;
 float sheen=pow(max(0.0,sin(pond_position.x*2.8+pond_position.y*1.3+t*.17)),10.0)*0.085;
 float circles=ring(pond_position,vec2(.30,.02),mod(t+0.9,6.0))+ring(pond_position,vec2(-.65,-.26),mod(t+3.7,7.0));
 float shore=(1.0-smoothstep(.006,.07,depth))*.10;
 ALBEDO=mix(water,sky_color.rgb,sheen+circles*.10+shore)+vec3(caustic);
 ROUGHNESS=0.27;
 METALLIC=0.08;
 SPECULAR=0.52;
}
