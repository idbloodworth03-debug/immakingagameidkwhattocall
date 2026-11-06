// The little 3D scenery round an animal in the viewer (trees, rocks, ice,
// reeds): one flat color, lit like the animal, and swaying gently in the
// breeze if `sway` is set (grass, leaves, reeds). data/viewer.json.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 color : source_color = vec3(0.5);
uniform vec3 key_dir = vec3(-0.45, 0.7, 0.55);
uniform vec3 key_color : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 shade_color : source_color = vec3(0.62, 0.58, 0.72);
uniform float soft = 0.45;
uniform float sway = 0.0;
uniform float sway_speed = 1.4;
uniform float rim = 0.12;

void vertex() {
	if (sway > 0.0) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float h = max(VERTEX.y, 0.0);
		float t = TIME * sway_speed + origin.x * 2.3 + origin.z * 1.7;
		VERTEX.x += sin(t) * sway * h * h;
		VERTEX.z += cos(t * 0.8) * sway * 0.5 * h * h;
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float lit = smoothstep(-soft, soft, dot(n, normalize(key_dir)));
	vec3 col = color * mix(shade_color, key_color, lit);
	float edge = 1.0 - clamp(dot(n, VIEW), 0.0, 1.0);
	col += vec3(rim) * smoothstep(0.6, 1.0, edge) * lit;
	ALBEDO = col;
}
