shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// A camera-facing collect bubble: 0 wood, 1 stone, 2 food. No textures.
uniform int kind = 0;

float capsule(vec2 p, vec2 a, vec2 b, float r) {
 vec2 pa = p - a, ba = b - a;
 float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
 return length(pa - ba * h) - r;
}

void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
 vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
 // Round bubble with a small pointer underneath.
 float body = length(p - vec2(0.0, 0.12)) - 0.82;
 float pointer = max(abs(p.x) - (p.y + 0.98) * 0.55, -p.y - 0.98);
 pointer = max(pointer, p.y + 0.55);
 float shape = min(body, pointer);
 if (shape > 0.0) discard;
 vec3 ink = vec3(0.16, 0.24, 0.23);
 vec3 col = vec3(0.98, 0.95, 0.86);
 if (shape > -0.09) col = ink;
 vec2 q = p - vec2(0.0, 0.12);
 float icon = 1.0;
 vec3 tint = col;
 if (kind == 0) {
  float a = capsule(q, vec2(-0.40, -0.18), vec2(0.40, -0.18), 0.17);
  float b = capsule(q, vec2(-0.30, 0.16), vec2(0.30, 0.16), 0.17);
  icon = min(a, b);
  tint = vec3(0.62, 0.40, 0.25);
  float ring = min(length(q - vec2(0.40, -0.18)), length(q - vec2(0.30, 0.16)));
  if (icon < 0.0 && ring < 0.11) tint = vec3(0.93, 0.79, 0.56);
 } else if (kind == 1) {
  icon = length((q - vec2(-0.14, -0.08)) * vec2(1.0, 1.35)) - 0.38;
  float small = length((q - vec2(0.30, -0.16)) * vec2(1.0, 1.4)) - 0.26;
  tint = icon < 0.0 ? vec3(0.66, 0.69, 0.66) : vec3(0.78, 0.80, 0.76);
  icon = min(icon, small);
 } else if (kind == 3) {
  icon = capsule(q, vec2(0.0,-0.48), vec2(0.0,0.48), 0.045);
  for (int i = 0; i < 3; i++) {
   float y = -0.12 + float(i) * 0.20;
   icon = min(icon, capsule(q, vec2(-0.22,y+0.14), vec2(0.0,y), 0.08));
   icon = min(icon, capsule(q, vec2(0.22,y+0.14), vec2(0.0,y), 0.08));
  }
  tint = vec3(0.79,0.61,0.29);
 } else {
  icon = length((q - vec2(0.0, -0.06)) * vec2(1.0, 1.08)) - 0.42;
  float leaf = length((q - vec2(0.17, 0.44)) * vec2(1.0, 2.0)) - 0.16;
  tint = icon < 0.0 ? vec3(0.84, 0.33, 0.27) : vec3(0.46, 0.61, 0.51);
  icon = min(icon, leaf);
 }
 if (icon < 0.0 && shape < -0.09) col = icon > -0.05 ? ink : tint;
 ALBEDO = col;
}
