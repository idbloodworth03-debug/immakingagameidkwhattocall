// Fake-3D finishing touches for an animal sprite, in screen space so mirrored
// sprites are lit the same way:
//  - a soft warm highlight along the edge facing the light (top-left),
//  - a soft cool rim light along the far edge (bottom-right),
//  - a little extra color punch (vibrance, contrast) and gentle volume,
//  - a white flash when it's hit,
//  - in battle, a bold band in its team's color round the outside (blue
//    yours, red the enemy's), so sides read at a glance.
// The outline is the render's own single deep line; the shader leaves it be
// (line_tint > 0 tints it toward a dark shade of the body's color instead).
// Everything follows the sprite's smooth (filtered) alpha, never a hard
// cut-off, so edges stay smooth at any zoom; widths are in texels at 56
// pixels a tile and scaled by texel_scale for sharper sheets.
// The numbers come from data/feel.json ("characters" and "combat").
shader_type canvas_item;

uniform float vibrance = 0.25;
uniform float contrast = 0.08;
uniform float brightness = 0.02;
uniform float highlight = 0.25;
uniform vec4 highlight_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float rim = 0.25;
uniform vec4 rim_color : source_color = vec4(0.72, 0.88, 1.0, 1.0);
// In texels of a 56-pixels-a-tile sheet; times texel_scale.
uniform float edge_width = 2.0;
// The sheet's pixels per tile / 56.
uniform float texel_scale = 1.0;
// 0: outlines stay the render's deep dark; up to 1: tinted toward a dark
// shade of the body color next to them.
uniform float line_tint = 0.0;
uniform float line_darkness = 0.2;
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
// A 3-star animal's golden glow: gold rim (0 = none).
uniform float gold = 0.0;
uniform vec4 gold_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
// The team band: its color (alpha 0: none) and width in texels (times
// texel_scale).
uniform vec4 team_color : source_color = vec4(0.0);
uniform float team_width = 3.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// How solid a texel is: the animal itself, not the soft baked ground shadow
// under it (smooth, so edges never step).
float solid(float alpha) {
	return smoothstep(0.72, 0.97, alpha);
}

void fragment() {
	vec4 c = COLOR;
	float a = c.a;
	vec2 px = TEXTURE_PIXEL_SIZE * texel_scale;
	float mirror = flip > 0.5 ? -1.0 : 1.0;
	// Toward the light, in texture space.
	vec2 to_light = normalize(vec2(-1.0 * mirror, -1.0)) * px * edge_width;
	float me = solid(a);

	// The outline: dark pixels of the body. Left as rendered (deep dark), or
	// tinted toward a dark shade of the body color.
	float dark = 1.0 - smoothstep(0.1, 0.22, luma(c.rgb));
	if (line_tint > 0.0) {
		vec3 body = texture(TEXTURE, UV + to_light * 0.6).rgb;
		c.rgb = mix(c.rgb, body * line_darkness, dark * me * line_tint);
	}
	// A 3-star animal: a gold outline.
	c.rgb = mix(c.rgb, gold_color.rgb * 0.95, dark * me * gold * 0.75);

	// Color punch: more saturation for duller colors, a touch of contrast
	// (the body only, not the outline).
	float body_mask = me * (1.0 - dark);
	float l = luma(c.rgb);
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	vec3 punched = mix(vec3(l), c.rgb, 1.0 + vibrance * (1.0 - sat));
	punched = (punched - 0.5) * (1.0 + contrast) + 0.5 + brightness;
	c.rgb = mix(c.rgb, punched, body_mask);

	// Volume: brighter toward the light, a little darker away from it.
	vec2 local = (UV - region.xy) / max(region.zw, vec2(0.0001));
	local.x = flip > 0.5 ? 1.0 - local.x : local.x;
	float toward = 1.0 - (local.x * 0.6 + local.y * 0.8) / 1.4;
	c.rgb *= 1.0 + gradient * body_mask * (toward * 2.0 - 1.0);

	// Light from the top-left: a soft warm band on the near edge, a soft
	// cool rim on the far edge (from the filtered alpha: smooth at any zoom).
	float lit = body_mask * (1.0 - solid(texture(TEXTURE, UV + to_light).a));
	float back = body_mask * (1.0 - solid(texture(TEXTURE, UV - to_light).a));
	c.rgb += mix(highlight_color.rgb, gold_color.rgb, gold * 0.6) * lit * (highlight + gold * 0.4) * 0.6;
	c.rgb = mix(c.rgb, mix(rim_color.rgb, gold_color.rgb, gold), back * (rim + gold * 0.3) * 0.55);

	c.rgb = mix(c.rgb, flash_color.rgb, clamp(flash, 0.0, 1.0));
	// The team band: just outside the body (sampled round it, within its
	// own frame so neighbors on the sheet never bleed in).
	float band = 0.0;
	if (team_color.a > 0.0) {
		vec2 reach = px * team_width;
		vec2 lo = region.xy;
		vec2 hi = region.xy + region.zw;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			vec2 at = clamp(UV + vec2(cos(ang), sin(ang)) * reach, lo, hi);
			band = max(band, solid(texture(TEXTURE, at).a));
		}
		band *= (1.0 - me) * team_color.a;
	}
	c.rgb = mix(c.rgb, team_color.rgb, band);
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), max(a, band) * opacity);
}
