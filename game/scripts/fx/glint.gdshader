shader_type canvas_item;
// A band of light that sweeps across shiny things (brass, gold, gems) now
// and then: quickly, once every `period` seconds (feel.json "ui").

uniform float period = 3.5;
uniform float offset = 0.0;
uniform float width = 0.22;
uniform float strength = 0.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float t = fract((TIME + offset) / period);
	// The band crosses the icon during the first sixth of each period.
	float sweep = t * 6.0 - 0.6;
	float d = (UV.x + UV.y * 0.7) / 1.7 - sweep;
	float band = 1.0 - smoothstep(0.0, width, abs(d));
	c.rgb += band * strength * c.a;
	COLOR = c;
}
