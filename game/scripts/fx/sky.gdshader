// The sky behind the viewer's stage: a soft top-to-bottom gradient on a big
// card far behind it. data/viewer.json habitats "sky".
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 top : source_color = vec3(0.45, 0.75, 1.0);
uniform vec3 bottom : source_color = vec3(0.9, 0.96, 1.0);

void fragment() {
	ALBEDO = mix(top, bottom, smoothstep(0.0, 1.0, UV.y));
}
