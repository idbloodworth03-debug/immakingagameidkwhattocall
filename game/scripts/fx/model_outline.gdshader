// The dark cartoon outline round a 3D model: the back faces pushed out along
// their normals by the same number of screen pixels everywhere (an "inverted
// hull"), drawn as a second pass. Values: data/viewer.json "look".
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width_px = 2.5;
uniform vec3 color : source_color = vec3(0.07, 0.04, 0.03);
uniform float silhouette = 0.0;
uniform vec3 silhouette_color : source_color = vec3(0.04, 0.07, 0.16);
// In battle: a 3-star animal's golden outline, and the same dithered fade
// as its body (model_skin.gdshader).
uniform float gold = 0.0;
uniform vec3 gold_color : source_color = vec3(1.0, 0.82, 0.25);
uniform float opacity = 1.0;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec4 clip = PROJECTION_MATRIX * view_pos;
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float len = length(dir);
	if (len > 1e-5) {
		clip.xy += dir / len * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = mix(mix(color, gold_color, clamp(gold * 2.5, 0.0, 1.0)), silhouette_color, silhouette);
	if (opacity < 0.999) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		int index = p.x + p.y * 4;
		float limits[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (opacity * 16.0 <= limits[index] + 0.5) {
			discard;
		}
	}
}
