// A soft round dot facing the camera: snowflakes, pollen, bubbles and
// fireflies drifting round the viewer's stage, in the particle's color.
// data/viewer.json.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float ring = 0.0;    // 1: a bubble (a ring), 0: a solid dot

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float w = fwidth(d);
	float solid = 1.0 - smoothstep(1.0 - w * 1.5, 1.0, d);
	float hole = smoothstep(0.62, 0.62 + w * 1.5, d);
	ALBEDO = COLOR.rgb;
	ALPHA = solid * mix(1.0, hole, ring) * COLOR.a;
}
