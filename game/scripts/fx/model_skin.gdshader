// The animal in the 3D viewer: its painted vertex colors, lit like the
// sprites (a warm key light from the front and above, soft violet shade, a
// gentle rim and highlight) without the engine's lights, so it looks the
// same on every phone. The big cartoon eyes are drawn here, from their own
// eyeball coordinates (UV and UV2, see tools/creatures/export_gltf.py), so the
// pupil and its shine stay crisp at any zoom. Values: data/viewer.json "look".
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 key_dir = vec3(-0.45, 0.7, 0.55);      // toward the light, in view space
uniform vec3 key_color : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 shade_color : source_color = vec3(0.62, 0.58, 0.72);
uniform float soft = 0.45;          // how gently light turns to shade
uniform float rim = 0.3;
uniform float rim_width = 0.35;
uniform vec3 rim_color : source_color = vec3(1.0);
uniform float highlight = 0.12;
uniform float vibrance = 0.15;
uniform vec3 eye_white : source_color = vec3(0.95, 0.95, 0.93);
uniform vec3 pupil_color : source_color = vec3(0.04, 0.035, 0.035);
uniform float silhouette = 0.0;     // 1: a solid shape (an animal not found yet)
uniform vec3 silhouette_color : source_color = vec3(0.1, 0.16, 0.32);
uniform float flash = 0.0;          // a quick brightening when tapped (or hit)
// In battle: a tint (stunned, a style's pose), a fade (a knockout, a hidden
// animal) by screen-door dithering so it stays in the fast opaque pass, a
// 3-star animal's golden glow, and a blink (eyelids of lid_color).
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 1.0;
uniform float gold = 0.0;
uniform vec3 gold_color : source_color = vec3(1.0, 0.82, 0.25);
uniform float blink = 0.0;
uniform vec3 lid_color : source_color = vec3(0.45, 0.3, 0.2);

varying vec3 v_color;
varying vec3 v_eye;
varying float v_is_eye;

void vertex() {
	v_color = COLOR.rgb;
	v_eye = vec3(UV, UV2.x);
	v_is_eye = UV2.y;
}

float disc(vec2 p, vec2 center, float radius) {
	float d = length(p - center);
	float w = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(radius - w, radius + w, d);
}

void fragment() {
	// The compatibility renderer works in sRGB, like the vertex colors.
	vec3 base = v_color;
	if (v_is_eye > 0.5) {
		float front = smoothstep(-0.03, 0.03, v_eye.z);
		float pupil = disc(v_eye.xy, vec2(0.0, -0.04), 0.5) * front;
		float shine = disc(v_eye.xy, vec2(0.17, 0.2), 0.16) * front;
		base = mix(mix(eye_white, pupil_color, pupil), vec3(1.0), shine);
		// The lid comes down from the top.
		base = mix(base, lid_color, step(1.0 - blink * 2.2, v_eye.y) * front);
	}
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(key_dir);
	float lit = smoothstep(-soft, soft, dot(n, l));
	vec3 col = base * mix(shade_color, key_color, lit);
	// A soft highlight and a rim of light round the edge.
	vec3 h = normalize(l + VIEW);
	col += highlight * pow(max(dot(n, h), 0.0), 28.0) * key_color;
	float edge = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	col += rim_color * rim * smoothstep(1.0 - rim_width, 1.0, edge) * (0.35 + 0.65 * lit);
	// A little more color, the same hues.
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, 1.0 + vibrance);
	col *= tint;
	col += gold_color * gold * (0.25 + 0.75 * smoothstep(0.4, 1.0, edge));
	col = mix(col, silhouette_color, silhouette);
	col = mix(col, vec3(1.0), flash);
	ALBEDO = max(col, vec3(0.0));
	if (opacity < 0.999) {
		// A 4x4 ordered dither: fades without leaving the opaque pass.
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		int index = p.x + p.y * 4;
		float limits[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (opacity * 16.0 <= limits[index] + 0.5) {
			discard;
		}
	}
}
