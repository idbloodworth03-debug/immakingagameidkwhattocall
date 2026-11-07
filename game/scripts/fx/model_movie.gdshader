// An animal with the movie look (tools/creatures/movie.py, the style guide
// in docs/ART_DIRECTION.md): its painted vertex colors under the studio
// lighting the card portraits use (a soft warm key from the front-left
// above, a cool fill from the right, a sky-to-ground ambient that keeps
// shadows colored, and a rim of light round the edge), its fur as sculpted
// locks with strand detail that fades out before it is small enough to
// shimmer, and eyes with a colored iris, a big pupil and a catchlight.
// Everything the battle does with the cartoon shader (model_skin.gdshader)
// works the same: tint, fade, gold, flash, blinks and faces.
// Values: data/viewer.json "movie_look".
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 key_dir = vec3(-0.45, 0.7, 0.55);      // toward the key light, in view space
uniform vec3 key_color : source_color = vec3(1.0, 0.96, 0.9);
uniform float key = 0.95;
uniform float wrap = 0.55;          // how far round the form the key light reaches
uniform vec3 fill_dir = vec3(0.75, 0.15, 0.45);
uniform vec3 fill_color : source_color = vec3(0.7, 0.8, 1.0);
uniform float fill = 0.3;
uniform vec3 sky_color : source_color = vec3(0.8, 0.86, 1.0);
uniform vec3 ground_color : source_color = vec3(0.55, 0.5, 0.6);
uniform float ambient = 0.42;
uniform float rim = 0.32;
uniform float rim_width = 0.32;
uniform vec3 rim_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float highlight = 0.1;
uniform float vibrance = 0.1;
// Fur locks: strands round each lock and how deep the grooves between them
// look; a soft sheen along the lock.
uniform float strands = 18.0;
uniform float strand_depth = 0.25;
uniform float lock_sheen = 0.08;
// Each lock's sides in soft shadow (the gaps between clumps), and how much of
// the rim light a lock gets (less than the body's edge, or every lock glows).
uniform float lock_edge = 0.3;
uniform float lock_rim = 0.35;
// The color those shadows take (cool, so a white coat stays white and bold).
uniform vec3 lock_shadow : source_color = vec3(0.6, 0.75, 1.0);
// Eyes: the white, the iris (its color is the eye's vertex color), the pupil
// and the catchlight, in the eyeball's own coordinates (+Z out, +Y up).
uniform vec3 eye_white : source_color = vec3(0.97, 0.96, 0.93);
uniform vec3 pupil_color : source_color = vec3(0.02, 0.02, 0.035);
uniform float iris_size = 0.66;
uniform float pupil_share = 0.5;
uniform vec2 catchlight = vec2(-0.2, 0.24);
uniform float catchlight_size = 0.15;
uniform float silhouette = 0.0;
uniform vec3 silhouette_color : source_color = vec3(0.1, 0.16, 0.32);
uniform float flash = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 1.0;
uniform float gold = 0.0;
uniform vec3 gold_color : source_color = vec3(1.0, 0.82, 0.25);
uniform float blink = 0.0;
uniform vec3 lid_color : source_color = vec3(0.45, 0.3, 0.2);
uniform float lid = 0.0;
uniform float pupil_size = 1.0;
uniform float happy = 0.0;
uniform float dizzy = 0.0;
uniform float spin = 0.0;

// Feather cards: darker at the base, a pale edge, a shaft down the middle.
uniform float feather_base = 0.3;
uniform float feather_edge = 0.25;
uniform float feather_shaft = 0.2;
// Scales: how deep the grooves between them look, and their color.
uniform float scale_groove = 0.45;
uniform float scale_dome = 0.12;
uniform vec3 scale_shadow : source_color = vec3(0.35, 0.5, 0.3);

varying vec3 v_color;
varying vec3 v_eye;
varying float v_kind;     // 0 skin and coat, 1 an eye, 2 a fur lock, 3 scaly skin
varying vec2 v_lock;      // a lock: (round it, root to tip)
varying float v_seed;     // a lock: its random number; scales: the cell size
varying vec3 v_pos;       // model-space position (scales)

void vertex() {
	v_color = COLOR.rgb;
	v_eye = vec3(UV, UV2.x);
	v_kind = UV2.y;
	v_lock = UV;
	v_seed = UV2.x;
	v_pos = VERTEX;
}

// Scales: a cell pattern from the model's own position, each scale a dome
// with a groove round it, fading out when the cells get smaller than a few
// pixels (then the skin reads as its plain color).
float scales(vec3 p, float cell, out float dome) {
	vec3 q = p / cell;
	vec3 base = floor(q);
	float best = 8.0;
	float second = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 b = base + vec3(float(x), float(y), float(z));
				vec3 r = fract(sin(vec3(dot(b, vec3(127.1, 311.7, 74.7)), dot(b, vec3(269.5, 183.3, 246.1)), dot(b, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
				float d = length(q - (b + r));
				if (d < best) {
					second = best;
					best = d;
				} else if (d < second) {
					second = d;
				}
			}
		}
	}
	dome = clamp(1.0 - best, 0.0, 1.0);
	// The groove is where the two nearest cells are about as close.
	return clamp((second - best) / 0.35, 0.0, 1.0);
}

float disc(vec2 p, vec2 center, float radius) {
	float d = length(p - center);
	float w = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(radius - w, radius + w, d);
}

vec3 eye(vec3 iris_color) {
	vec2 e = v_eye.xy;
	float front = smoothstep(-0.03, 0.03, v_eye.z);
	float r = length(e);
	float iris = disc(e, vec2(0.0), iris_size) * front;
	// The iris: a darker ring at its edge, lighter toward the pupil, fine rays.
	float t = clamp(r / iris_size, 0.0, 1.0);
	vec3 ring = mix(iris_color * 1.25, iris_color * 0.55, smoothstep(0.55, 1.0, t));
	float rays = 0.06 * sin(atan(e.y, e.x) * 22.0) * smoothstep(0.2, 0.6, t) * (1.0 - smoothstep(0.85, 1.0, t));
	vec3 col = mix(eye_white, ring + rays, iris);
	float pupil = disc(e, vec2(0.0, -0.02), iris_size * pupil_share * pupil_size) * front * (1.0 - dizzy);
	col = mix(col, pupil_color, pupil);
	float shine = disc(e, catchlight, catchlight_size) * front * (1.0 - dizzy);
	col = mix(col, vec3(1.0), shine);
	if (dizzy > 0.5) {
		float a = atan(e.y, e.x);
		float band = fract((a + spin) / 6.2832 + r * 1.7);
		float w = fwidth(band) * 1.5 + 0.02;
		float ink = (smoothstep(0.0, w, band) - smoothstep(0.2, 0.2 + w, band)) * step(r, 0.92) * front;
		col = mix(col, pupil_color, ink);
	}
	// Eyelids in the skin's color: closed (a blink, or happy), or partly down.
	float closed = max(max(blink, happy), step(0.99, lid));
	float cover = max(lid, closed);
	float edge = 1.0 - cover * 2.0;
	col = mix(col, lid_color, step(edge, e.y) * front);
	float lw = 0.09;
	float fw = fwidth(e.y) * 1.2;
	if (closed > 0.5) {
		float curve = happy > 0.5 ? (0.12 - 0.5 * e.x * e.x) : (-0.12 + 0.35 * e.x * e.x);
		float line = 1.0 - smoothstep(lw, lw + fw, abs(e.y - curve));
		col = mix(col, pupil_color, line * step(abs(e.x), 0.72) * front);
	} else if (cover > 0.01) {
		float line = 1.0 - smoothstep(lw * 0.8, lw * 0.8 + fw, abs(e.y - edge));
		col = mix(col, lid_color * 0.45, line * front);
	}
	return col;
}

void fragment() {
	// The compatibility renderer works in sRGB, like the vertex colors.
	vec3 base = v_color;
	bool is_eye = v_kind > 0.5 && v_kind < 1.5;
	bool is_lock = v_kind > 1.5 && v_kind < 2.5;
	bool is_scaly = v_kind > 2.5 && v_kind < 3.5;
	bool is_feather = v_kind > 3.5;
	if (is_eye) {
		base = eye(v_color);
	}
	if (is_feather) {
		// (across 0-1, along 0-1): darker toward the base, lighter at the
		// edges, a pale shaft line, fading out when the card is tiny.
		float across = abs(v_lock.x - 0.5) * 2.0;
		float fade = 1.0 - smoothstep(0.3, 0.9, fwidth(v_lock.x));
		base *= 1.0 - feather_base * (1.0 - v_lock.y) * fade;
		base = mix(base, mix(base, vec3(1.0), feather_edge), pow(across, 3.0) * fade);
		float shaft = 1.0 - smoothstep(0.0, 0.08 + fwidth(v_lock.x) * 2.0, abs(v_lock.x - 0.5));
		base = mix(base, mix(base, vec3(1.0), feather_shaft), shaft * fade * (1.0 - v_lock.y * 0.5));
	}
	if (is_scaly) {
		float dome;
		float groove = scales(v_pos, max(v_seed, 0.001), dome);
		float fade = 1.0 - smoothstep(0.15, 0.5, fwidth(length(v_pos)) / max(v_seed, 0.001));
		base = mix(base, base * scale_shadow, (1.0 - groove) * scale_groove * fade);
		base *= 1.0 + scale_dome * (dome - 0.5) * fade;
	}
	if (is_lock) {
		// Strands round the lock: grooves between them, fading out before
		// they get smaller than a couple of pixels (no shimmer when small).
		float s = v_lock.x * strands + v_seed * 13.0;
		float fade = 1.0 - smoothstep(0.25, 0.6, fwidth(s));
		float groove = 0.5 + 0.5 * sin(s * 6.2832 + sin(v_lock.y * 5.0 + v_seed * 20.0) * 0.8);
		float shade = strand_depth * fade * groove * (0.4 + 0.6 * v_lock.y);
		// Round the lock (0 and 0.5: its sides; 0.25: its top).
		shade += lock_edge * pow(abs(cos(v_lock.x * 6.2832)), 2.0);
		base *= mix(vec3(1.0), lock_shadow, clamp(shade, 0.0, 1.0));
	}
	vec3 n = normalize(NORMAL);
	vec3 l = normalize(key_dir);
	float lit = clamp((dot(n, l) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float filled = pow(clamp((dot(n, normalize(fill_dir)) + 1.0) * 0.5, 0.0, 1.0), 2.0);
	vec3 hemi = mix(ground_color, sky_color, n.y * 0.5 + 0.5);
	vec3 light = key_color * lit * key + fill_color * filled * fill + hemi * ambient;
	if (is_eye) {
		// Eyes stay bright and clear.
		light = mix(light, vec3(1.0), 0.45);
	}
	vec3 col = base * light;
	vec3 h = normalize(l + VIEW);
	float spec = pow(max(dot(n, h), 0.0), is_eye ? 60.0 : 22.0);
	col += (is_lock ? lock_sheen : highlight) * spec * key_color;
	float edge = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	col += rim_color * rim * (is_lock ? lock_rim : 1.0) * smoothstep(1.0 - rim_width, 1.0, edge) * (0.45 + 0.55 * lit);
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(grey), col, 1.0 + vibrance);
	col *= tint;
	col += gold_color * gold * (0.25 + 0.75 * smoothstep(0.4, 1.0, edge));
	if (is_feather && !FRONT_FACING) {
		// A feather card's back: the card's own color, lit flat.
		col = v_color * (key_color * key * 0.6 + sky_color * ambient) * tint;
	}
	col = mix(col, silhouette_color, silhouette);
	col = mix(col, vec3(1.0), flash);
	ALBEDO = max(col, vec3(0.0));
	if (opacity < 0.999) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		int index = p.x + p.y * 4;
		float limits[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (opacity * 16.0 <= limits[index] + 0.5) {
			discard;
		}
	}
}
