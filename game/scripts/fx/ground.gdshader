// The arena picture: saturation and brightness knobs (1 = as painted).
// Values from data/feel.json ("background").
shader_type canvas_item;

uniform float saturation = 1.0;
uniform float brightness = 1.02;

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(l), c.rgb, saturation) * brightness;
	COLOR = c;
}
