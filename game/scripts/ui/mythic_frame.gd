class_name MythicFrame
extends RefCounted
## The animated frame on Mythic cards (rarities.json "mythic" "frame"): a
## pulsing rose-pink glow, the rim's color drifting through a soft rainbow,
## a spark of light running round the rim and a few twinkling sparkles.


static func settings() -> Dictionary:
	return GameData.rarities.get("mythic", {}).get("frame", {})


## The pulsing glow behind the card.
static func draw_glow(canvas: CanvasItem, rect: Rect2, radius: int, color: Color, t: float) -> void:
	var s := settings()
	var pulse := 0.5 + 0.5 * sin(t * TAU / maxf(0.1, float(s.get("pulse_seconds", 2.4))))
	var aura := UIKit.box(Color(color, 0.0), radius + 2)
	aura.shadow_color = Color(color, float(s.get("glow", 0.55)) * (0.6 + 0.4 * pulse))
	aura.shadow_size = int(float(s.get("glow_size", 10)) * (0.8 + 0.4 * pulse))
	canvas.draw_style_box(aura, rect)


## The rim's color right now: rose pink, tinted by a slowly turning rainbow.
static func rim_color(color: Color, t: float) -> Color:
	var s := settings()
	var hue := fmod(t / maxf(0.1, float(s.get("rainbow_seconds", 9.0))), 1.0)
	return color.lerp(Color.from_hsv(hue, float(s.get("rainbow_saturation", 0.85)), 1.0), float(s.get("rainbow", 0.35)))


## A spark of light running round the rim.
static func draw_spark(canvas: CanvasItem, rect: Rect2, t: float) -> void:
	var s := settings()
	var u := fmod(t / maxf(0.1, float(s.get("spark_seconds", 3.2))), 1.0)
	var r := rect.size.x * float(s.get("spark_size", 0.05))
	for k in 5:
		var at := _around(rect, fmod(u - k * 0.012 + 1.0, 1.0))
		canvas.draw_circle(at, r * (1.0 - k * 0.17), Color(1, 1, 1, 0.75 - k * 0.14))


## Little four-pointed sparkles twinkling on and around the frame.
static func draw_sparkles(canvas: CanvasItem, rect: Rect2, t: float) -> void:
	var s := settings()
	var count := int(s.get("sparkles", 5))
	var period := maxf(0.1, float(s.get("sparkle_seconds", 1.6)))
	var color := Color(String(s.get("sparkle_color", "#fff4fb")))
	for i in count:
		# Each sparkle lives for one period at a spot picked from its index
		# and how many times it has twinkled, so it pops up somewhere new.
		var phase := t / period + float(i) / count
		var cycle := floori(phase)
		var life := phase - cycle
		var key := float(i * 7919 + cycle * 104729)
		var at := _around(rect, fposmod(sin(key) * 43758.5453, 1.0)) + Vector2(cos(key), sin(key * 1.3)) * rect.size.x * 0.03
		var grow := sin(life * PI)
		var side := rect.size.x * float(s.get("sparkle_size", 0.07)) * grow
		if side < 0.5:
			continue
		_star(canvas, at, side, Color(color, grow))


static func _star(canvas: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 8:
		var a := k * PI / 4.0
		var d := r if k % 2 == 0 else r * 0.28
		points.append(at + Vector2(sin(a), -cos(a)) * d)
	canvas.draw_colored_polygon(points, color)
	canvas.draw_circle(at, r * 0.22, Color(1, 1, 1, color.a))


## A point `u` (0-1) of the way round the rectangle's edge, clockwise from
## the top-left corner.
static func _around(rect: Rect2, u: float) -> Vector2:
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
