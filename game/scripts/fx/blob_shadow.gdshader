// The soft round shadow under an animal in the viewer.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 color : source_color = vec3(0.1, 0.12, 0.2);
uniform float strength = 0.35;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = color;
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * strength;
}
