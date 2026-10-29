shader_type spatial;
render_mode cull_disabled;

uniform vec4 cloth_color : source_color = vec4(0.3, 0.5, 0.6, 1.0);
uniform vec4 trouser_color : source_color = vec4(0.6, 0.45, 0.3, 1.0);
uniform int pattern = 0;
uniform int outfit = 0;
uniform bool skirt = false;
uniform float seated = 0.0;
uniform float gait_phase = 0.0;
uniform float moving = 0.0;
uniform vec3 left_knee = vec3(-0.135, -0.32, 0.0);
uniform vec3 right_knee = vec3(0.135, -0.32, 0.0);

float rounded_box(vec2 p, vec2 half_size, float radius) {
    vec2 q = abs(p) - half_size + radius;
    return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void vertex() {
    if (skirt) {
        // Keep the waist attached; only the cloth over the thighs settles forward.
        float hem = 1.0 - smoothstep(-0.30, 0.13, VERTEX.y);
        float along = clamp((0.15 - VERTEX.y) / 0.48, 0.0, 1.0);
        float front = smoothstep(-0.08, 0.12, VERTEX.z);
        float bend = seated * front;
        // The front rests over the tops of the thighs; the back hangs behind
        // the seat. A uniform upward offset leaves knees through the middle.
        VERTEX.y = mix(VERTEX.y, 0.15 - 0.105 * along, bend);
        VERTEX.z += 0.34 * along * bend;
        VERTEX.x += sin(gait_phase) * moving * hem * 0.009;
        // Fit over the actual moving thighs instead of inflating the whole dress.
        for (int side = 0; side < 2; side++) {
            vec3 hip = vec3(side == 0 ? -0.135 : 0.135, 0.0, 0.0);
            vec3 knee = side == 0 ? left_knee : right_knee;
            if (VERTEX.y <= 0.0 && knee.y < -0.04 && VERTEX.y >= knee.y - 0.06) {
                float t = clamp(VERTEX.y / knee.y, 0.0, 1.0);
                vec3 leg = mix(hip, knee, t);
                float across = VERTEX.x - leg.x;
                float radius = 0.112;
                if (abs(across) < radius) {
                    float depth = sqrt(max(0.0, radius * radius - across * across)) + 0.014;
                    VERTEX.z = VERTEX.z >= 0.0 ? max(VERTEX.z, leg.z + depth) : min(VERTEX.z, leg.z - depth);
                }
            }
        }
    }
}

void fragment() {
    vec3 color = cloth_color.rgb;
    if (!skirt) {
        // Cylindrical UVs are authored on the shirt itself. Every seam and print
        // follows the fabric, including body-shape changes and animation.
        // glTF's texture origin reverses the authoring V axis.
        vec2 p = vec2((UV.x - 0.25) * 1.28, (1.0 - UV.y) * 0.577 + 0.018);
        float aa = max(fwidth(p.y), 0.001);
        float front = 1.0 - smoothstep(0.22, 0.27, abs(p.x));
        if (outfit == 4) {
            float bib = 1.0 - smoothstep(-aa, aa, rounded_box(p - vec2(0.0, 0.28), vec2(0.15, 0.17), 0.025));
            float straps = (1.0 - smoothstep(0.016, 0.022, abs(abs(p.x) - 0.10))) * step(0.30, p.y) * (1.0 - step(0.54, p.y));
            color = mix(color, trouser_color.rgb, max(bib, straps) * front);
        }
        float print_mask = 0.0;
        vec2 badge = p - vec2(outfit == 5 ? -0.095 : 0.0, 0.34);
        if (outfit == 5) { badge /= 0.58; }
        if (pattern == 1) {
            print_mask = 1.0 - smoothstep(0.010, 0.010 + aa, abs(mod(p.y - 0.015, 0.085) - 0.0425));
            print_mask *= smoothstep(0.10, 0.13, p.y) * (1.0 - smoothstep(0.45, 0.49, p.y));
        } else if (pattern == 2) {
            float nearest = 1.0;
            bool inside = false;
            for (int i = 0; i < 10; i++) {
                float a = 1.5707963 + float(i) * 0.6283185;
                float b = a + 0.6283185;
                float ra = i % 2 == 0 ? 0.079 : 0.035;
                float rb = i % 2 == 0 ? 0.035 : 0.079;
                vec2 start = vec2(cos(a), sin(a)) * ra;
                vec2 end = vec2(cos(b), sin(b)) * rb;
                vec2 edge = end - start;
                float t = clamp(dot(badge - start, edge) / dot(edge, edge), 0.0, 1.0);
                nearest = min(nearest, length(badge - start - edge * t));
                if ((start.y > badge.y) != (end.y > badge.y)) {
                    float crossing = start.x + (badge.y - start.y) * edge.x / edge.y;
                    if (badge.x < crossing) { inside = !inside; }
                }
            }
            print_mask = 1.0 - smoothstep(-aa, aa, nearest * (inside ? -1.0 : 1.0));
        } else if (pattern == 3) {
            for (int i = 0; i < 5; i++) {
                float angle = float(i) * 1.2566371;
                vec2 petal = vec2(sin(angle), cos(angle)) * 0.039;
                print_mask = max(print_mask, 1.0 - smoothstep(0.022, 0.022 + aa, length(badge - petal)));
            }
            print_mask = max(print_mask, 1.0 - smoothstep(0.017, 0.017 + aa, length(badge)));
        } else if (pattern == 4) {
            vec2 dot = mod(p - vec2(0.0, 0.02), vec2(0.085)) - vec2(0.0425);
            print_mask = (1.0 - smoothstep(0.012, 0.012 + aa, length(dot))) * step(0.12, p.y) * (1.0 - step(0.47, p.y));
        }
        color = mix(color, mix(cloth_color.rgb, vec3(0.91, 0.84, 0.64), 0.72), print_mask * front);
        // Tonal stitching and flush buttons never intersect necklaces or prints.
        float stitch = 0.0;
        if (outfit != 2) {
            stitch = 1.0 - smoothstep(0.0015, 0.0015 + aa, abs(p.y - 0.042));
        }
        if (pattern == 0 && (outfit == 0 || outfit == 1)) {
            float pocket = abs(rounded_box(p - vec2(0.105, 0.35), vec2(0.037, 0.040), 0.006));
            stitch = 1.0 - smoothstep(0.0012, 0.0012 + aa, pocket);
        }
        if (outfit == 3 || outfit == 5) {
            float opening = 1.0 - smoothstep(0.0015, 0.0015 + aa, abs(p.x));
            stitch = max(stitch, opening * step(outfit == 5 ? 0.08 : 0.39, p.y) * (1.0 - step(0.53, p.y)));
        }
        color = mix(color, cloth_color.rgb * 0.68, stitch * front);
    }
    ALBEDO = color * COLOR.rgb;
    ROUGHNESS = 0.88;
}
