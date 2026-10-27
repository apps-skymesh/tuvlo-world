shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque, shadows_disabled;
// A camera-facing token: 0 wood, 1 stone, 2 food. The face keeps the icon.
// A short lower edge and a soft shadow give it thickness. No textures.
uniform int kind = 0;
// -1 preserves family material bubbles; prototype states: idle/work/ready.
uniform int production_state = -1;
uniform float progress = 0.0;

float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float token_shape(vec2 p) {
	float body = length(p - vec2(0.0, 0.12)) - 0.82;
	float pointer = max(abs(p.x) - (p.y + 0.98) * 0.55, -p.y - 0.98);
	pointer = max(pointer, p.y + 0.55);
	return min(body, pointer);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float face = token_shape(p);
	if (face > 0.0) discard;

	vec3 ink = vec3(0.22, 0.16, 0.12);
	vec3 col = vec3(0.99, 0.97, 0.93);
	float alpha = 1.0;
	{
		float shape = face;
		if (shape > -0.026) col = vec3(0.63, 0.57, 0.47);
		vec2 q = p - vec2(0.0, 0.12);
		if (shape <= -0.026) col += vec3(smoothstep(-0.05, 0.45, q.y) * 0.035);
		float icon = 1.0;
		vec3 tint = col;
		if (kind == 9) {
			icon = length(q * vec2(0.9, 1.3)) - 0.47;
			tint = vec3(0.67, 0.37, 0.30);
			if (icon < -0.025 && length(q - vec2(0.18, -0.04)) < 0.12) tint = vec3(0.96, 0.88, 0.72);
		} else if (kind == 8) {
			icon = capsule(q, vec2(-0.22, -0.37), vec2(0.18, 0.23), 0.07);
			icon = min(icon, capsule(q, vec2(-0.12, 0.32), vec2(0.35, 0.02), 0.12));
			tint = q.y > 0.02 ? vec3(0.38, 0.48, 0.43) : vec3(0.66, 0.46, 0.25);
		} else if (kind == 0) {
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
		} else if (kind == 4) {
			icon = max(abs(q.x) - (0.31 + q.y * 0.11), abs(q.y + 0.04) - 0.41);
			tint = vec3(0.88, 0.75, 0.48);
			if (abs(q.y - 0.30) < 0.045) tint = ink;
		} else if (kind == 5 || kind == 7) {
			icon = length(q * vec2(0.88, 1.45)) - 0.48;
			tint = kind == 7 ? vec3(0.74, 0.37, 0.25) : vec3(0.78, 0.52, 0.23);
			float scoring = min(min(abs(q.x + 0.22 + q.y * 0.25), abs(q.x + q.y * 0.25)), abs(q.x - 0.22 + q.y * 0.25));
			if (icon < -0.06 && scoring < 0.035 && abs(q.y) < 0.17) tint = vec3(0.99, 0.87, 0.61);
		} else if (kind == 6) {
			icon = max(abs(q.x) - 0.38, abs(q.y + 0.12) - 0.22);
			icon = min(icon, abs(length((q - vec2(0.0, 0.03)) * vec2(1.0, 1.45)) - 0.30) - 0.04);
			tint = vec3(0.35, 0.52, 0.39);
		} else if (kind == 3) {
			icon = capsule(q, vec2(0.0, -0.48), vec2(0.0, 0.48), 0.045);
			for (int i = 0; i < 3; i++) {
				float y = -0.12 + float(i) * 0.20;
				icon = min(icon, capsule(q, vec2(-0.22, y + 0.14), vec2(0.0, y), 0.08));
				icon = min(icon, capsule(q, vec2(0.22, y + 0.14), vec2(0.0, y), 0.08));
			}
			tint = vec3(0.79, 0.61, 0.29);
		} else {
			icon = length((q - vec2(0.0, -0.06)) * vec2(1.0, 1.08)) - 0.42;
			float leaf = length((q - vec2(0.17, 0.44)) * vec2(1.0, 2.0)) - 0.16;
			tint = icon < 0.0 ? vec3(0.84, 0.33, 0.27) : vec3(0.46, 0.61, 0.51);
			icon = min(icon, leaf);
		}
		if (icon < 0.0 && shape < -0.026) col = icon > -0.045 ? ink : tint;
		if (icon < -0.04) {
			vec2 shine = q - vec2(-0.12, 0.18);
			float gloss = smoothstep(0.2, 0.0, length(shine * vec2(1.15, 1.45)));
			col = mix(col, min(col + vec3(0.45), vec3(1.0)), gloss);
		}
		if (production_state >= 0) {
			float ring = abs(length(q) - 0.70);
			if (ring < 0.035) {
				float angle = mod(atan(q.x, q.y) + 6.2831853, 6.2831853) / 6.2831853;
				col = production_state == 2 ? vec3(0.81, 0.57, 0.17) : production_state == 1 && angle < progress ? vec3(0.20, 0.46, 0.33) : vec3(0.75, 0.77, 0.68);
			}
			if (production_state == 0) col = mix(col, vec3(0.88, 0.87, 0.79), 0.38);
			vec2 badge = q - vec2(0.43, -0.43);
			if (length(badge) < 0.23) {
				col = production_state == 2 ? vec3(0.91, 0.69, 0.26) : vec3(0.17, 0.34, 0.27);
				float mark = 1.0;
				if (production_state == 2) mark = min(capsule(badge, vec2(-0.11, 0.0), vec2(-0.02, -0.08), 0.028), capsule(badge, vec2(-0.02, -0.08), vec2(0.12, 0.10), 0.028));
				else if (production_state == 1) {
					mark = abs(length(badge) - 0.14) - 0.018;
					mark = min(mark, min(capsule(badge, vec2(0.0), vec2(0.0, 0.09), 0.018), capsule(badge, vec2(0.0), vec2(0.07, -0.03), 0.018)));
				} else mark = min(capsule(badge, vec2(-0.10, 0), vec2(0.10, 0), 0.022), capsule(badge, vec2(0, -0.10), vec2(0, 0.10), 0.022));
				if (mark < 0.0) col = vec3(1.0, 0.97, 0.86);
			}
		}
	}
	ALBEDO = col;
	ALPHA = alpha;
}
