// An animal from a flat-color art pack (tools/packs): its palette colors
// (vertex colors) in two soft cartoon tones, light and shade, with a cool
// tint in the shade, a little darker underneath (the belly, under the chin:
// a soft shadow without any real lights), a rim of light round the edge
// and bolder color. No engine lights, so it looks the same on every phone.
// Its face is real geometry moved by blendshapes (ModelStage sets them), so
// nothing is drawn over the eyes here. Values: data/viewer.json "toon_look".
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 key_dir = vec3(-0.45, 0.72, 0.55);     // toward the light, in view space
uniform vec3 key_color : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 shade_color : source_color = vec3(0.68, 0.64, 0.84);
uniform float band = 0.05;          // where light turns to shade (-1 to 1)
uniform float soft = 0.14;          // how soft that edge is (0: a hard cel edge)
uniform float under = 0.16;         // how much darker a face looking down is
uniform float rim = 0.22;
uniform float rim_width = 0.3;
uniform vec3 rim_color : source_color = vec3(1.0, 0.98, 0.92);
uniform float saturation = 1.2;
uniform float brightness = 1.04;
uniform float silhouette = 0.0;     // 1: a solid shape (an animal not found yet)
uniform vec3 silhouette_color : source_color = vec3(0.1, 0.16, 0.32);
uniform float flash = 0.0;          // a quick brightening when tapped (or hit)
// In battle (as model_skin.gdshader): a tint, a dithered fade, a 3-star glow.
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 1.0;
uniform float gold = 0.0;
uniform vec3 gold_color : source_color = vec3(1.0, 0.82, 0.25);

varying vec3 v_color;

void vertex() {
	v_color = COLOR.rgb;
}

void fragment() {
	// The compatibility renderer works in sRGB, like the vertex colors.
	vec3 base = v_color;
	float grey = dot(base, vec3(0.299, 0.587, 0.114));
	base = clamp(mix(vec3(grey), base, saturation) * brightness, vec3(0.0), vec3(1.0));
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(key_dir);
	float lit = smoothstep(band - soft, band + soft, dot(n, l));
	vec3 col = base * mix(shade_color, key_color, lit);
	// Darker where it faces the ground.
	float down = clamp(-(INV_VIEW_MATRIX * vec4(n, 0.0)).y, 0.0, 1.0);
	col *= 1.0 - under * down * down;
	float edge = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	col += rim_color * rim * smoothstep(1.0 - rim_width, 1.0, edge) * (0.3 + 0.7 * lit);
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
