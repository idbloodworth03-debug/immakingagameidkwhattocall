class_name CardShow
extends RefCounted
## How much a card shows off, by rarity (feel.json "card_show"; colors in
## ui_style.json "show_*"), the same on every card (AnimalCard on Your Deck,
## the bans, the Animals tab and cage openings; GameCard in a match):
##
##   Common     plain.
##   Rare       a soft shine on the frame (still: it costs nothing).
##   Epic       a band of light sweeping across the picture now and then,
##              and a soft glow.
##   Legendary  a glowing, pulsing edge and sparkles drifting off the frame.
##   Mythic     the rose pink frame with its rainbow sheen, a shimmering
##              border, a spark running round the rim, lots of sparkles,
##              light rays turning behind the animal, and a moment (a flash,
##              a burst and a sound) when it's offered, picked or freed.
##
## `full`: the whole show (offers, picks, cage openings, single cards);
## otherwise the lighter version for cards in a big grid: fewer sparkles
## and rays, redrawn only grid_fps times a second. Cards only move while
## they're on screen (on_screen()). Nothing is drawn over a card's name or
## level: sparkles start above `clear_y` (the top of the name plate), the
## sweep and the rays stay inside the picture, under the name plate.


static func cfg(rarity: String) -> Dictionary:
	return GameData.feel.get("card_show", {}).get(rarity, {})


static func _num(rarity: String, key: String, fallback: float) -> float:
	return float(cfg(rarity).get(key, fallback))


## Whether a card of this rarity moves (and so redraws while on screen).
static func moves(rarity: String) -> bool:
	return rarity in ["epic", "legendary", "mythic"]


## How often a grid card redraws (a second); a full-show card every frame.
static func grid_fps() -> float:
	return maxf(1.0, float(GameData.feel.get("card_show", {}).get("grid_fps", 20)))


## How many of something there are: the full count, or the grid one.
static func count(rarity: String, key: String, full: bool) -> int:
	var c := cfg(rarity)
	return int(c.get(key, 0)) if full else int(c.get(key + "_grid", c.get(key, 0)))


## Whether `card` is on screen: inside the window and inside every scrolling
## list it sits in (a card scrolled out of view doesn't move).
static func on_screen(card: Control) -> bool:
	if not card.is_visible_in_tree():
		return false
	var rect := card.get_global_rect()
	if not card.get_viewport_rect().intersects(rect):
		return false
	var node := card.get_parent()
	while node != null:
		if node is ScrollContainer and not (node as Control).get_global_rect().intersects(rect):
			return false
		node = node.get_parent()
	return true


# --- Behind the card ---------------------------------------------------------------

## The glow round the card, drawn before its frame: soft for Epic, a pulsing
## glowing edge for Legendary and Mythic (steady in a grid, pulsing in full).
static func draw_glow(canvas: CanvasItem, rect: Rect2, radius: int, rarity: String, color: Color, t: float, full: bool) -> void:
	if not moves(rarity):
		return
	var strength := _num(rarity, "glow", 0.5)
	var spread := _num(rarity, "glow_size", 8.0)
	if rarity != "epic" and full:
		var pulse := 0.5 + 0.5 * sin(t * TAU / maxf(0.1, _num(rarity, "pulse_seconds", 2.0)))
		strength *= 0.6 + 0.4 * pulse
		spread *= 0.8 + 0.4 * pulse
	var aura := UIKit.box(Color(color, 0.0), radius + 2)
	aura.shadow_color = Color(color, strength)
	aura.shadow_size = int(spread)
	canvas.draw_style_box(aura, rect)


## The Mythic rim's color right now: rose pink, tinted by a turning rainbow.
static func rim_color(color: Color, t: float) -> Color:
	var hue := fmod(t / maxf(0.1, _num("mythic", "rainbow_seconds", 9.0)), 1.0)
	return color.lerp(Color.from_hsv(hue, _num("mythic", "rainbow_saturation", 0.85), 1.0), _num("mythic", "rainbow", 0.35))


# --- Inside the picture --------------------------------------------------------------

## A Mythic's light rays turning slowly behind the animal: draw after the
## picture's window and before the animal. They stay inside `art`.
static func draw_rays(canvas: CanvasItem, art: Rect2, rarity: String, t: float, full: bool) -> void:
	if rarity != "mythic":
		return
	for piece in ray_polygons(art, t, full):
		canvas.draw_colored_polygon(piece, Color(UIStyle.color("show_ray"), _num("mythic", "ray_alpha", 0.34)))


## The rays' shapes, cut to the picture's window.
static func ray_polygons(art: Rect2, t: float, full: bool) -> Array:
	var rays := maxi(1, count("mythic", "rays", full))
	var center := art.get_center() - Vector2(0, art.size.y * 0.08)
	var reach := art.size.length()
	var half := PI / rays * _num("mythic", "ray_width", 0.42)
	var turn := t * TAU / maxf(0.1, _num("mythic", "ray_seconds", 14.0))
	var window := PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)])
	var out := []
	for i in rays:
		var a := turn + TAU * i / rays
		var ray := PackedVector2Array([center, center + Vector2.from_angle(a - half) * reach, center + Vector2.from_angle(a + half) * reach])
		out.append_array(Geometry2D.intersect_polygons(ray, window))
	return out


## Over the picture, after the animal: Epic and up get a band of light
## sweeping across it now and then (only while the card moves).
static func draw_sweep(canvas: CanvasItem, art: Rect2, rarity: String, t: float, moving: bool) -> void:
	if not moves(rarity) or not moving:
		return
	for piece in sweep_polygons(art, t):
		canvas.draw_colored_polygon(piece, Color(UIStyle.color("show_sweep"), _num("epic", "sweep_alpha", 0.32)))


## The sweep's shape right now, cut to the picture's window (none between
## sweeps).
static func sweep_polygons(art: Rect2, t: float) -> Array:
	var period := maxf(0.1, _num("epic", "sweep_seconds", 4.2))
	var share := clampf(_num("epic", "sweep_share", 0.3), 0.05, 1.0)
	var phase := fmod(t, period) / period
	if phase > share:
		return []
	var w := art.size.x * _num("epic", "sweep_width", 0.24)
	var x := lerpf(art.position.x - art.size.x * 0.7, art.end.x + art.size.x * 0.1, phase / share)
	var band := PackedVector2Array([
		Vector2(x, art.end.y), Vector2(x + w, art.end.y),
		Vector2(x + w + art.size.x * 0.4, art.position.y), Vector2(x + art.size.x * 0.4, art.position.y)])
	var window := PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)])
	return Geometry2D.intersect_polygons(band, window)


# --- On the frame ----------------------------------------------------------------------

## The frame's own shine: none on a Common; on a Rare and up, a soft gloss
## along the top of the frame and a bright line round its inside edge (draw
## before the picture), then glint() on top.
static func draw_shine(canvas: CanvasItem, inner: Rect2, radius: int, rarity: String) -> void:
	if rarity == "common" or rarity == "":
		return
	var shine := _num("rare", "shine", 0.42)
	var gloss := UIKit.box(Color(UIStyle.color("show_shine"), shine * 0.55), radius)
	gloss.corner_radius_bottom_left = 4
	gloss.corner_radius_bottom_right = 4
	canvas.draw_style_box(gloss, Rect2(inner.position, Vector2(inner.size.x, inner.size.y * _num("rare", "shine_height", 0.42))))
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.set_border_width_all(int(_num("rare", "rim_line", 2)))
	line.border_color = Color(UIStyle.color("show_shine"), shine * 1.6)
	line.set_corner_radius_all(maxi(0, radius - 2))
	line.anti_aliasing = true
	canvas.draw_style_box(line, inner.grow(-2.0))


## A Rare and up: a little glint twinkling on the top of the frame, between
## the badges (still; drawn last, over the frame's edge).
static func draw_glint(canvas: CanvasItem, inner: Rect2, rarity: String) -> void:
	if rarity == "common" or rarity == "":
		return
	var r := inner.size.x * _num("rare", "glint", 0.11)
	var at := Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y + 1.0)
	star(canvas, at, r, Color(UIStyle.color("show_shine"), minf(1.0, _num("rare", "shine", 0.42) * 2.0)))


## After everything else: the Mythic's shimmering border and the spark
## running round it, and the Legendary's and Mythic's sparkles.
static func draw_frame(canvas: CanvasItem, rect: Rect2, inner: Rect2, border: float, clear_y: float, rarity: String, t: float, full: bool) -> void:
	if rarity == "mythic":
		_draw_shimmer(canvas, inner.grow(-border * 0.5), border, t)
		_draw_spark(canvas, inner.grow(-1.5), t)
	if rarity == "legendary" or rarity == "mythic":
		var color := UIStyle.color("show_mythic_sparkle" if rarity == "mythic" else "show_legendary_sparkle")
		for s in sparkles(rect, clear_y, rarity, t, full):
			star(canvas, s[0], s[1], Color(color, s[2]))


## Bands of rainbow light running round the Mythic's frame.
static func _draw_shimmer(canvas: CanvasItem, rim: Rect2, width: float, t: float) -> void:
	var points := int(_num("mythic", "shimmer_points", 64))
	var bands := maxi(1, int(_num("mythic", "shimmer_bands", 2)))
	var span := clampf(_num("mythic", "shimmer_width", 0.16), 0.02, 0.5)
	var run := t / maxf(0.1, _num("mythic", "shimmer_seconds", 2.6))
	var alpha := _num("mythic", "shimmer_alpha", 0.9)
	var line := PackedVector2Array()
	var colors := PackedColorArray()
	for i in points + 1:
		var u := float(i) / points
		line.append(around(rim, fmod(u, 1.0)))
		# How far this point is from the nearest band's middle (in turns
		# round the frame): full light there, none `span` away.
		var gap := 1.0 / bands
		var d := absf(fposmod(u - run + gap * 0.5, gap) - gap * 0.5)
		var on := clampf(1.0 - d / span, 0.0, 1.0)
		colors.append(Color.from_hsv(fmod(u + run * 0.5, 1.0), 0.55, 1.0, alpha * on))
	canvas.draw_polyline_colors(line, colors, maxf(2.0, width), true)


## A spark of light running round the rim.
static func _draw_spark(canvas: CanvasItem, rect: Rect2, t: float) -> void:
	var u := fmod(t / maxf(0.1, _num("mythic", "spark_seconds", 3.2)), 1.0)
	var r := rect.size.x * _num("mythic", "spark_size", 0.05)
	for k in 5:
		var at := around(rect, fmod(u - k * 0.012 + 1.0, 1.0))
		canvas.draw_circle(at, r * (1.0 - k * 0.17), Color(1, 1, 1, 0.75 - k * 0.14))


## Where the sparkles are right now: [position, size, alpha] each. Each one
## pops up at a spot on the top or sides of the frame (above `clear_y`, so
## never over the name or level), drifts outward and up, and fades.
static func sparkles(rect: Rect2, clear_y: float, rarity: String, t: float, full: bool) -> Array:
	var n := count(rarity, "sparkles", full)
	var period := maxf(0.1, _num(rarity, "sparkle_seconds", 1.6))
	var size := rect.size.x * _num(rarity, "sparkle_size", 0.07)
	var drift := rect.size.x * _num(rarity, "drift", 0.2)
	# The part of the edge they start from: the top and the sides down to
	# clear_y, less a sparkle's size.
	var side := maxf(0.0, clear_y - rect.position.y - size * 1.5)
	var edge := rect.size.x + side * 2.0
	var out := []
	for i in n:
		var phase := t / period + float(i) / maxf(1, n)
		var cycle := floori(phase)
		var life := phase - cycle
		var key := float(i * 7919 + cycle * 104729)
		var d := fposmod(sin(key) * 43758.5453, 1.0) * edge
		var at: Vector2
		var away: Vector2
		if d < side:
			at = Vector2(rect.position.x, rect.position.y + side - d)
			away = Vector2(-1, -0.6)
		elif d < side + rect.size.x:
			at = Vector2(rect.position.x + d - side, rect.position.y)
			away = Vector2((d - side) / rect.size.x - 0.5, -1.0)
		else:
			at = Vector2(rect.end.x, rect.position.y + d - side - rect.size.x)
			away = Vector2(1, -0.6)
		at += away.normalized() * drift * life
		var grow := sin(life * PI)
		var r := size * grow
		if r < 0.5:
			continue
		out.append([at, r, grow])
	return out


# --- The Mythic moment ---------------------------------------------------------------

## A Mythic offered, picked or freed: a white flash over the card, a burst
## of sparkles and stars, a pop and a sound (feel.json card_show mythic
## "moment"). After `delay` seconds if given (to land after a pop-in).
static func moment(card: Control, delay := -1.0) -> void:
	if not card.is_inside_tree():
		return
	var m: Dictionary = cfg("mythic").get("moment", {})
	var wait := float(m.get("delay", 0.25)) if delay < 0.0 else delay
	if wait > 0.0:
		card.get_tree().create_timer(wait).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.is_inside_tree():
				moment(card, 0.0))
		return
	var flash := _Flash.new()
	flash.name = "MythicFlash"
	flash.radius = card.size.x * 0.11
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.start = float(m.get("flash_alpha", 0.85))
	flash.alpha = flash.start
	flash.ring = float(m.get("ring", 1.5))
	flash.ring_width = float(m.get("ring_width", 10.0))
	card.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "alpha", 0.0, float(m.get("flash_seconds", 0.45))).set_ease(Tween.EASE_OUT)
	fade.tween_callback(flash.queue_free)
	card.pivot_offset = card.size / 2.0
	var pop := card.create_tween()
	var seconds := float(m.get("pop_seconds", 0.32))
	pop.tween_property(card, "scale", Vector2.ONE * float(m.get("pop_scale", 1.12)), seconds * 0.35).set_trans(Tween.TRANS_SINE)
	pop.tween_property(card, "scale", Vector2.ONE, seconds * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var at := card.get_global_rect().get_center()
	var colors := [UIStyle.color("show_burst_1"), UIStyle.color("show_burst_2"), UIStyle.color("show_burst_3"), UIStyle.color("show_burst_4")]
	var speed := float(m.get("speed", 340.0))
	var life := float(m.get("life", 0.8))
	var size := float(m.get("size", 11.0))
	UIFx.particles.burst("sparkle", at, int(m.get("sparkles", 26)), speed, life, size, colors, -60.0, 2.5)
	UIFx.particles.burst("star", at, int(m.get("stars", 12)), speed * 0.8, life, size * 1.1, colors, 420.0, 1.2, 160.0)
	Sound.play(String(m.get("sound", "star3")), float(m.get("volume_db", 0.0)))


## The flash: the card's shape in white, fading, and a ring in the Mythic
## pink bursting out from it to `ring` times the card's size.
class _Flash:
	extends Control
	var radius := 16.0
	var start := 0.85
	var ring := 1.5
	var ring_width := 10.0
	var alpha := 0.85:
		set(value):
			alpha = value
			queue_redraw()

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UIStyle.color("show_flash"), alpha)
		box.set_corner_radius_all(int(radius))
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var done := 1.0 - alpha / maxf(0.01, start)
		var r := size.length() * 0.5 * lerpf(0.6, ring, done)
		var fade := 1.0 - done
		draw_arc(size / 2.0, r, 0.0, TAU, 48, Color(UIStyle.color("rarity_mythic"), fade), ring_width * (0.4 + 0.6 * fade), true)
		draw_arc(size / 2.0, r * 0.82, 0.0, TAU, 48, Color(UIStyle.color("show_burst_2"), fade * 0.8), ring_width * 0.4 * fade, true)


# --- Shapes ---------------------------------------------------------------------------

## A little four-pointed sparkle.
static func star(canvas: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 8:
		var a := k * PI / 4.0
		var d := r if k % 2 == 0 else r * 0.28
		points.append(at + Vector2(sin(a), -cos(a)) * d)
	canvas.draw_colored_polygon(points, color)
	canvas.draw_circle(at, r * 0.22, Color(1, 1, 1, color.a))


## A point `u` (0-1) of the way round the rectangle's edge, clockwise from
## the top-left corner.
static func around(rect: Rect2, u: float) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	var d := u * 2.0 * (w + h)
	if d < w:
		return rect.position + Vector2(d, 0)
	d -= w
	if d < h:
		return rect.position + Vector2(w, d)
	d -= h
	if d < w:
		return rect.position + Vector2(w - d, h)
	return rect.position + Vector2(0, h - (d - w))
