shader_type spatial;
// Gentle wind for leaves and crops: a matte, vertex-coloured lit surface that
// sways with height above the ground. All motion is in the vertex stage, so the
// CPU does nothing per frame and draw calls match the original material.
render_mode world_vertex_coords;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform float roughness = 0.86;
uniform float amplitude = 0.06;
uniform float bend_from = 0.4;
uniform float bend_to = 2.6;
uniform float speed = 1.0;
uniform float strength = 1.0; // 0 holds everything still (Reduce Motion).

void vertex() {
	float weight = smoothstep(bend_from, bend_to, VERTEX.y) * amplitude * strength;
	float phase = VERTEX.x * 0.35 + VERTEX.z * 0.27;
	float t = TIME * speed;
	float gust = 0.7 + 0.3 * sin(t * 0.31 + VERTEX.x * 0.04);
	VERTEX += vec3(sin(t * 1.3 + phase) + 0.35 * sin(t * 2.9 + phase * 1.7), 0.0, 0.45 * sin(t * 1.1 + phase * 1.3)) * weight * gust;
}

void fragment() {
	ALBEDO = albedo.rgb * (use_vertex_color ? COLOR.rgb : vec3(1.0));
	ROUGHNESS = roughness;
}
