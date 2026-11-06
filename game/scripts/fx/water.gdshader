// Water round the viewer's stage (Ocean, Wetlands): a flat color with soft
// rings of light drifting outward. data/viewer.json.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 deep : source_color = vec3(0.12, 0.45, 0.8);
uniform vec3 shine : source_color = vec3(0.6, 0.85, 1.0);
uniform float rings = 9.0;
uniform float speed = 0.6;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(world.xz);
	float wave = sin(r * rings - TIME * speed * 6.2832 + sin(world.x * 3.0 + TIME) * 0.6);
	float band = smoothstep(0.82, 0.98, wave);
	ALBEDO = mix(deep, shine, band * 0.55);
}
