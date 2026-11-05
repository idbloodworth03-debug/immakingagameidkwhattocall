class_name ShotLooks
extends RefCounted
## How Ranged animals' shots look in flight (data/shots.json): a nut or a
## fruit on an arc, a drop of spit or venom, a bubble, a blue foxfire flame,
## a volley of quills or darts, a squirt or spray, sonar rings, a lightning
## bolt, a shining beam, a frog's tongue. One draw call per shape kind, in
## the field's effects layer.

const DEFAULT := "nut"


## The look for card `id` (its "shot", or the default).
static func look_for(card: Dictionary) -> Dictionary:
	var id := String(card.get("shot", DEFAULT))
	var looks: Dictionary = GameData.shots
	return looks.get(id, looks.get(DEFAULT, {}))


## Draws a shot `t` of the way (0-1) from `from` to `to` (screen points).
## `s` is screen pixels per field unit; `trail` keeps recent points for
## balls; `now` is a running clock for flicker.
static func draw(canvas: CanvasItem, look: Dictionary, from: Vector2, to: Vector2, t: float, trail: Array, s: float, now: float) -> void:
	var tile := float(BattleSim.TILE) * s
	var size := maxf(3.0, float(look.get("size", 0.2)) * tile)
	var colors := _colors(look)
	match String(look.get("style", "ball")):
		"ball":
			_ball(canvas, look, colors, from, to, t, trail, size, now)
		"volley":
			_volley(canvas, look, colors, from, to, t, size, tile)
		"jet":
			_jet(canvas, look, colors, from, to, t, size, now)
		"wave":
			_wave(canvas, look, colors, from, to, t, size)
		"zap":
			_zap(canvas, colors, from, to, t, size, now)
		"beam":
			_beam(canvas, look, colors, from, to, t, size)
		"tongue":
			_tongue(canvas, colors, from, to, t, size)


## How long the shot is in the air, as a share of the usual flight: bolts
## and beams are nearly instant, a frog's tongue is quick.
static func flight_scale(look: Dictionary) -> float:
	match String(look.get("style", "ball")):
		"zap", "beam":
			return 0.45
		"tongue", "jet":
			return 0.7
	return 1.0


static func _colors(look: Dictionary) -> Array:
	var out := []
	for c in look.get("colors", ["#ffffff"]):
		out.append(Color(String(c)))
	while out.size() < 4:
		out.append(out[-1])
	return out


static func _arc_point(look: Dictionary, from: Vector2, to: Vector2, t: float) -> Vector2:
	var lift := from.distance_to(to) * float(look.get("arc", 0.3)) + 10.0
	return from.lerp(to, t) + Vector2(0, -lift * Ease.arc(t))


static func _ball(canvas: CanvasItem, look: Dictionary, colors: Array, from: Vector2, to: Vector2, t: float, trail: Array, r: float, now: float) -> void:
	var p := _arc_point(look, from, to, t)
	var ahead := _arc_point(look, from, to, minf(1.0, t + 0.05))
	var dir := (ahead - p).normalized() if ahead.distance_to(p) > 0.01 else (to - from).normalized()
	trail.append(p)
	while trail.size() > int(look.get("trail", 6)):
		trail.pop_front()
	var trail_color := Color(String(look.get("trail_color", "#ffffff")))
	for i in trail.size():
		var k := float(i + 1) / float(trail.size())
		canvas.draw_circle(trail[i], r * 0.85 * k, Color(trail_color, 0.35 * k))
	var glow := float(look.get("glow", 0.4))
	if glow > 0.0:
		canvas.draw_circle(p, r * 2.1, Color(colors[0].lightened(0.4), 0.22 * glow))
	# Its shadow on the ground, under the arc.
	var ground := from.lerp(to, t)
	canvas.draw_circle(ground + Vector2(0, 4), r * 0.7, Color(0, 0, 0, 0.18))
	if bool(look.get("flame", false)):
		# Foxfire: a flickering ball of blue flame with licks trailing behind.
		for i in 4:
			var wob := Vector2(sin(now * 23.0 + i * 1.7), cos(now * 19.0 + i * 2.3)) * r * 0.25
			canvas.draw_circle(p - dir * r * (0.5 + i * 0.45) + wob, r * (0.95 - i * 0.2), Color(colors[1], 0.55 - i * 0.1))
		canvas.draw_circle(p, r * 1.05, colors[0])
		canvas.draw_circle(p, r * 0.55, colors[3])
		return
	if bool(look.get("hollow", false)):
		# A bubble: see-through, with a bright rim and a shine.
		canvas.draw_circle(p, r, Color(colors[0], 0.35))
		canvas.draw_arc(p, r, 0, TAU, 24, colors[2], 2.0)
		canvas.draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.85))
		return
	if bool(look.get("drop", false)):
		# A drop, pointed at the back.
		var tail := p - dir * r * 2.2
		var side := Vector2(-dir.y, dir.x) * r * 0.85
		canvas.draw_colored_polygon(PackedVector2Array([p + side, tail, p - side]), colors[2])
		canvas.draw_colored_polygon(PackedVector2Array([p + side * 0.75, tail + dir * r * 0.4, p - side * 0.75]), colors[0])
	canvas.draw_circle(p, r + 1.5, colors[2])
	canvas.draw_circle(p, r, colors[0])
	canvas.draw_circle(p + Vector2(0, -r * 0.45), r * 0.7, colors[1])
	canvas.draw_circle(p + Vector2(-r * 0.3, -r * 0.2), r * 0.32, Color(colors[3], 0.55))
	if look.has("leaf"):
		canvas.draw_circle(p + Vector2(r * 0.35, -r * 1.0), r * 0.38, Color(String(look.leaf)))


static func _volley(canvas: CanvasItem, look: Dictionary, colors: Array, from: Vector2, to: Vector2, t: float, length: float, tile: float) -> void:
	var count := int(look.get("count", 3))
	var spread := float(look.get("spread", 0.12)) * tile
	var across := Vector2(-(to - from).y, (to - from).x).normalized()
	for i in count:
		var off := across * spread * (i - (count - 1) / 2.0)
		var lag := 0.06 * absf(i - (count - 1) / 2.0)
		var u := clampf(t - lag, 0.0, 1.0)
		var p := _arc_point(look, from + off, to + off * 0.3, u)
		var q := _arc_point(look, from + off, to + off * 0.3, minf(1.0, u + 0.04))
		var dir := (q - p).normalized() if q.distance_to(p) > 0.01 else (to - from).normalized()
		var back := p - dir * length
		canvas.draw_line(back, p, colors[1], 4.0)
		canvas.draw_line(back, p, colors[0], 2.2)
		canvas.draw_circle(p, 2.2, colors[1])
		# Fletching at the back.
		var side := Vector2(-dir.y, dir.x) * length * 0.18
		canvas.draw_line(back, back - dir * length * 0.2 + side, colors[1], 2.0)
		canvas.draw_line(back, back - dir * length * 0.2 - side, colors[1], 2.0)


static func _jet(canvas: CanvasItem, look: Dictionary, colors: Array, from: Vector2, to: Vector2, t: float, width: float, now: float) -> void:
	var stream := float(look.get("length", 0.5))
	var head := from.lerp(to, t)
	var tail := from.lerp(to, maxf(0.0, t - stream))
	if bool(look.get("cloud", false)):
		# A puffy spray cloud rolling toward the target.
		for i in 5:
			var u := float(i) / 4.0
			var at := tail.lerp(head, u) + Vector2(sin(now * 9.0 + i), cos(now * 7.0 + i * 2.0)) * width * 0.3
			canvas.draw_circle(at, width * (0.6 + u * 0.9), Color(colors[0], 0.28 + 0.12 * u))
			canvas.draw_circle(at, width * (0.35 + u * 0.5), Color(colors[1], 0.3))
		return
	canvas.draw_line(tail, head, colors[0], width)
	canvas.draw_line(tail.lerp(head, 0.3), head, colors[1], width * 0.45)
	canvas.draw_circle(head, width * 0.75, colors[0])
	for i in 3:
		var u := fposmod(now * 4.0 + i * 0.33, 1.0)
		canvas.draw_circle(tail.lerp(head, u) + Vector2(0, -width * 1.2), width * 0.3, colors[1])


static func _wave(canvas: CanvasItem, look: Dictionary, colors: Array, from: Vector2, to: Vector2, t: float, r: float) -> void:
	var count := int(look.get("count", 3))
	var dir := (to - from).normalized()
	var angle := dir.angle()
	for i in count:
		var u := clampf(t - i * 0.12, 0.0, 1.0)
		if u <= 0.0:
			continue
		var at := from.lerp(to, u)
		var radius := r * (0.5 + u * 0.8)
		var fade := 1.0 - 0.5 * u
		canvas.draw_arc(at, radius, angle - 0.9, angle + 0.9, 16, Color(colors[1], 0.7 * fade), 5.0)
		canvas.draw_arc(at, radius, angle - 0.9, angle + 0.9, 16, Color(colors[0], 0.95 * fade), 2.5)


static func _zap(canvas: CanvasItem, colors: Array, from: Vector2, to: Vector2, t: float, width: float, now: float) -> void:
	if t < 0.35:
		# Charging: a crackle at the horn.
		canvas.draw_circle(from, width * (2.0 + 6.0 * t), Color(colors[0], 0.5 + t))
		return
	var fade := 1.0 - clampf((t - 0.85) / 0.15, 0.0, 1.0)
	var points := PackedVector2Array()
	var across := Vector2(-(to - from).y, (to - from).x).normalized()
	var steps := 7
	for i in steps + 1:
		var u := float(i) / steps
		var jag := 0.0 if i == 0 or i == steps else sin(now * 60.0 + i * 2.7) * from.distance_to(to) * 0.06
		points.append(from.lerp(to, u) + across * jag)
	canvas.draw_polyline(points, Color(colors[1], 0.6 * fade), width * 3.0)
	canvas.draw_polyline(points, Color(colors[0], fade), width * 1.5)
	canvas.draw_polyline(points, Color(colors[2], fade), maxf(1.0, width * 0.6))
	canvas.draw_circle(to, width * 4.0 * fade, Color(colors[0], 0.6 * fade))


static func _beam(canvas: CanvasItem, look: Dictionary, colors: Array, from: Vector2, to: Vector2, t: float, width: float) -> void:
	var grow := clampf(t / 0.35, 0.0, 1.0)
	var fade := 1.0 - clampf((t - 0.8) / 0.2, 0.0, 1.0)
	var end := from.lerp(to, grow)
	var across := Vector2(-(to - from).y, (to - from).x).normalized()
	if bool(look.get("rainbow", false)):
		for i in 3:
			var off := across * width * (i - 1) * 0.8
			canvas.draw_line(from + off, end + off, Color(colors[i + 1], 0.75 * fade), width)
	canvas.draw_line(from, end, Color(colors[0], fade), width * 0.7)
	canvas.draw_circle(end, width * 1.6 * fade, Color(colors[0], 0.8 * fade))
	canvas.draw_circle(from, width * 1.2, Color(colors[0], 0.8 * fade))


static func _tongue(canvas: CanvasItem, colors: Array, from: Vector2, to: Vector2, t: float, width: float) -> void:
	var reach := sin(PI * clampf(t, 0.0, 1.0)) if t < 1.0 else 0.0
	var tip := from.lerp(to, minf(1.0, reach * 1.05))
	canvas.draw_line(from, tip, colors[1], width * 1.4)
	canvas.draw_line(from, tip, colors[0], width)
	canvas.draw_circle(tip, width * 1.3, colors[0])
