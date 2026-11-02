// Fake-3D finishing touches for an animal sprite, in screen space so mirrored
// sprites are lit the same way:
//  - a warm highlight along the edge facing the light (top-left),
//  - a cool rim light along the far edge (bottom-right),
//  - outlines recolored to a dark shade of the animal's own colors, and
//    thickened by a pixel,
//  - a little extra color punch (vibrance, contrast),
//  - a white flash when it's hit.
// The numbers come from data/feel.json ("characters" and "combat").
shader_type canvas_item;

uniform float vibrance = 0.3;
uniform float contrast = 0.1;
uniform float brightness = 0.03;
uniform float highlight = 0.45;
uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float rim = 0.6;
uniform vec4 rim_color : source_color = vec4(0.72, 0.88, 1.0, 1.0);
// In texels of the sprite sheet.
uniform float edge_width = 2.0;
uniform float outline_darkness = 0.42;
uniform float outline_thicken = 1.0;
// 1 when the sprite is drawn mirrored, so the light stays top-left on screen.
uniform float flip = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
// See-through (stealth, fading out); use this, not the modulate alpha.
uniform float opacity = 1.0;
// Soft shading across the whole animal: lighter toward the top-left,
// darker toward the bottom-right. `region` is the frame's rectangle in UV
// (x, y, width, height) so the gradient fits the animal.
uniform float gradient = 0.12;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

const float LINE_LUMA = 0.16;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Solid pixels: the animal itself, not the soft baked ground shadow under it.
float solid(float alpha) {
	return smoothstep(0.7, 0.95, alpha);
}

// How much of a texel is "body" (solid and not an outline line).
float body_of(vec4 t) {
	return solid(t.a) * step(LINE_LUMA, luma(t.rgb));
}

void fragment() {
	vec4 c = COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float mirror = flip > 0.5 ? -1.0 : 1.0;
	// Toward the light, in texture space.
	vec2 to_light = normalize(vec2(-1.0 * mirror, -1.0)) * px * edge_width;

	// Eight neighbors, for outlines.
	vec2 r = px * max(outline_thicken, 1.0);
	vec4 n0 = texture(TEXTURE, UV + vec2(r.x, 0.0));
	vec4 n1 = texture(TEXTURE, UV - vec2(r.x, 0.0));
	vec4 n2 = texture(TEXTURE, UV + vec2(0.0, r.y));
	vec4 n3 = texture(TEXTURE, UV - vec2(0.0, r.y));
	vec4 n4 = texture(TEXTURE, UV + r * 0.75);
	vec4 n5 = texture(TEXTURE, UV - r * 0.75);
	vec4 n6 = texture(TEXTURE, UV + vec2(r.x, -r.y) * 0.75);
	vec4 n7 = texture(TEXTURE, UV + vec2(-r.x, r.y) * 0.75);
	// The brightest neighbor: the body color next to an outline.
	vec4 best = n0;
	best = luma(n1.rgb) * n1.a > luma(best.rgb) * best.a ? n1 : best;
	best = luma(n2.rgb) * n2.a > luma(best.rgb) * best.a ? n2 : best;
	best = luma(n3.rgb) * n3.a > luma(best.rgb) * best.a ? n3 : best;
	best = luma(n4.rgb) * n4.a > luma(best.rgb) * best.a ? n4 : best;
	best = luma(n5.rgb) * n5.a > luma(best.rgb) * best.a ? n5 : best;
	best = luma(n6.rgb) * n6.a > luma(best.rgb) * best.a ? n6 : best;
	best = luma(n7.rgb) * n7.a > luma(best.rgb) * best.a ? n7 : best;
	vec3 line_color = best.rgb * outline_darkness;

	float a = texture(TEXTURE, UV).a;
	float is_line = solid(a) * (1.0 - step(LINE_LUMA, luma(c.rgb)));
	if (a < 0.5 && outline_thicken > 0.0) {
		// Just outside the sprite: a thicker outline in the darkened color.
		float around = max(max(max(n0.a, n1.a), max(n2.a, n3.a)), max(max(n4.a, n5.a), max(n6.a, n7.a)));
		float edge = solid(around);
		vec3 col = a > 0.01 ? c.rgb : line_color;
		c = vec4(mix(col, line_color, edge * (1.0 - a)), max(a, edge));
	} else {
		c.a = a;
		// Outline lines take on a dark shade of the color next to them.
		c.rgb = mix(c.rgb, line_color, is_line);

		// Color punch: more saturation for duller colors, a touch of contrast.
		float l = luma(c.rgb);
		float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
		c.rgb = mix(vec3(l), c.rgb, 1.0 + vibrance * (1.0 - sat));
		c.rgb = (c.rgb - 0.5) * (1.0 + contrast) + 0.5 + brightness;

		// Volume: brighter toward the light, a little darker away from it.
		vec2 local = (UV - region.xy) / max(region.zw, vec2(0.0001));
		local.x = flip > 0.5 ? 1.0 - local.x : local.x;
		float toward = 1.0 - (local.x * 0.6 + local.y * 0.8) / 1.4;
		c.rgb *= 1.0 + gradient * (toward * 2.0 - 1.0);

		// Light from the top-left: a warm band on the near edge, a cool rim on
		// the far edge.
		float me = body_of(texture(TEXTURE, UV));
		float lit = me * (1.0 - body_of(texture(TEXTURE, UV + to_light)));
		float back = me * (1.0 - body_of(texture(TEXTURE, UV - to_light)));
		c.rgb += highlight_color.rgb * lit * highlight * 0.6;
		c.rgb = mix(c.rgb, rim_color.rgb, back * rim * 0.55);
	}
	c.rgb = mix(c.rgb, flash_color.rgb, clamp(flash, 0.0, 1.0));
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), c.a * opacity);
}
