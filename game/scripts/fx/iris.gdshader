shader_type canvas_item;
// The screen transition: a leafy-edged circle closing over the screen
// (progress 0 = open, 1 = covered), then opening again on the next screen.

uniform float progress = 0.0;
uniform float aspect = 0.5;
uniform vec4 rim_color : source_color = vec4(0.25, 0.45, 0.12, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float angle = atan(p.y, p.x);
	float r = (1.0 - progress) * 0.75 + 0.012 * sin(angle * 11.0 + progress * 5.0);
	float d = length(p) - r;
	if (d < 0.0) {
		discard;
	}
	COLOR = mix(rim_color, COLOR, smoothstep(0.004, 0.02, d));
}
