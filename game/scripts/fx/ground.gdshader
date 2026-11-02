// The arena picture, toned down a little so the animals pop off it.
// Values from data/feel.json ("background").
shader_type canvas_item;

uniform float saturation = 0.82;
uniform float brightness = 1.02;

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(l), c.rgb, saturation) * brightness;
	COLOR = c;
}
