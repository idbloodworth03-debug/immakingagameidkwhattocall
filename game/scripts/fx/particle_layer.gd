class_name ParticleLayer
extends Node2D
## Bright cartoon particles: sparks, puffs, stars, sparkles, confetti, coins
## and petals. Drawn in one pass, with a cap on how many there can be at once
## (data/feel.json, "effects"). On its own it moves itself along every frame;
## the battlefield's effects layer (FxLayer) builds on it and is moved along
## by the field instead, so hit-stop freezes it too.

const STAR_POINTS := 5

var particles: Array = []
var time := 0.0
## False when something else calls step_particles() (the battlefield).
var self_driven := true


var _was_busy := false


func _process(delta: float) -> void:
	if self_driven:
		step_particles(delta)
		if not particles.is_empty() or _was_busy:
			queue_redraw()
		_was_busy = not particles.is_empty()


func step_particles(dt: float) -> void:
	time += dt
	for p in particles:
		p.age += dt
		p.vel *= maxf(0.0, 1.0 - float(p.drag) * dt)
		p.vel.y += float(p.gravity) * dt
		p.pos += p.vel * dt
		p.rot += float(p.spin) * dt
	particles = particles.filter(func(p): return p.age < p.life)


func _draw() -> void:
	draw_particles()


func draw_particles() -> void:
	for p in particles:
		_draw_particle(p)


# --- Particles ---------------------------------------------------------------

## Adds one particle. `kind`: "spark", "puff", "star", "sparkle", "confetti",
## "coin" or "petal". Positions are in field-layer pixels.
func particle(kind: String, at: Vector2, vel: Vector2, life: float, size: float, color: Color,
		gravity := 0.0, drag := 2.0, spin := 0.0) -> void:
	if particles.size() >= Feel.count("effects", "max_particles", 320):
		return
	particles.append({"kind": kind, "pos": at, "vel": vel, "life": life, "age": 0.0, "size": size,
		"color": color, "gravity": gravity, "drag": drag, "rot": randf() * TAU, "spin": spin})


## A ring of particles flying out from `at`.
func burst(kind: String, at: Vector2, count: int, speed: float, life: float, size: float, colors: Array,
		gravity := 0.0, drag := 3.0, upward := 0.0) -> void:
	for i in count:
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang) * 0.75) * speed * randf_range(0.55, 1.1) + Vector2(0, -upward)
		particle(kind, at, v, life * randf_range(0.75, 1.15), size * randf_range(0.7, 1.2),
			colors[i % colors.size()], gravity, drag, randf_range(-8.0, 8.0))


func burst_hit(at: Vector2, strong: bool, dir: Vector2) -> void:
	var e := "effects"
	var count := Feel.count(e, "strong_hit_sparks" if strong else "hit_sparks", 8 if strong else 5)
	for i in count:
		var ang := dir.angle() + randf_range(-1.1, 1.1)
		var speed := randf_range(140.0, 300.0) * (1.3 if strong else 1.0)
		particle("spark", at, Vector2.from_angle(ang) * speed, randf_range(0.14, 0.24), randf_range(5.0, 9.0),
			Color("#fff6b0") if i % 2 == 0 else Color.WHITE, 0.0, 6.0)
	particle("puff", at, Vector2.ZERO, 0.12, 8.0 if strong else 5.0, Color(1, 1, 1, 0.8), 0.0, 0.0)
	if strong:
		burst("star", at, 3, 160.0, 0.45, 7.0, [Color("#ffe14d"), Color.WHITE], 380.0, 1.5, 90.0)


func burst_defeat(at: Vector2) -> void:
	var e := "effects"
	burst("puff", at, Feel.count(e, "defeat_puffs", 7), 95.0, 0.45, Feel.num(e, "defeat_puff_size", 8.0), [Color(1, 1, 1, 0.9), Color("#e8eef7", 0.85)], -40.0, 3.5)
	burst("star", at, Feel.count(e, "defeat_stars", 6), 230.0, 0.7, 8.0, [Color("#ffe14d"), Color("#ffb03b"), Color.WHITE], 520.0, 1.2, 160.0)


func burst_spawn(at: Vector2) -> void:
	burst("sparkle", at, Feel.count("effects", "spawn_sparkles", 9), 110.0, 0.55, 7.0, [Color.WHITE, Color("#fff3a8"), Color("#bff0ff")], -30.0, 3.0)
	burst("puff", at + Vector2(0, 2), 5, 70.0, 0.4, 9.0, [Color(0.85, 0.78, 0.62, 0.7)], 0.0, 4.0)


func burst_upgrade(view: UnitView) -> void:
	var at := view.position + Vector2(0, -UnitSprites.top(view.id) * view.body.k * 0.5)
	burst("sparkle", at, Feel.count("effects", "upgrade_sparkles", 14), 170.0, 0.7, 9.0, [Color("#ffe14d"), Color.WHITE, Color("#ffd27a")], -60.0, 2.5)
	burst("star", at, 4, 140.0, 0.6, 8.0, [Color("#ffe14d")], 300.0, 1.2, 120.0)


func burst_confetti(at: Vector2, count: int) -> void:
	var colors := [Color("#ff5d73"), Color("#ffd23f"), Color("#4be38b"), Color("#3b8ff0"), Color("#c86bff"), Color("#ff9f43")]
	for i in count:
		var v := Vector2(randf_range(-220.0, 220.0), randf_range(-420.0, -160.0))
		particle("confetti", at, v, randf_range(0.9, 1.5), randf_range(6.0, 10.0), colors[i % colors.size()], 520.0, 1.6, randf_range(-12.0, 12.0))


func burst_coins(at: Vector2, count: int) -> void:
	for i in count:
		var v := Vector2(randf_range(-150.0, 150.0), randf_range(-380.0, -200.0))
		particle("coin", at, v, randf_range(0.7, 1.0), randf_range(8.0, 11.0), Color("#ffd23f"), 900.0, 0.8, randf_range(6.0, 12.0))


func burst_heal(at: Vector2) -> void:
	burst("sparkle", at, Feel.count("effects", "heal_sparkles", 6), 70.0, 0.7, 7.0, [Color("#7dffb0"), Color.WHITE], -90.0, 2.0)


func _draw_particle(p: Dictionary) -> void:
	var t: float = p.age / p.life
	var col: Color = p.color
	var size: float = p.size
	match p.kind:
		"spark":
			var v: Vector2 = p.vel
			var len := clampf(v.length() * 0.05, 3.0, 22.0) * (1.0 - t)
			var dir := v.normalized()
			draw_line(p.pos - dir * len, p.pos + dir * len * 0.3, Color(col, 1.0 - t), size * 0.5 * (1.0 - t) + 1.0)
		"puff":
			var r := size * (0.6 + 1.1 * Ease.out_cubic(t))
			draw_circle(p.pos, r + 1.5, Color(0.35, 0.4, 0.5, 0.25 * col.a * (1.0 - t)))
			draw_circle(p.pos, r, Color(col, col.a * (1.0 - t * t)))
			draw_circle(p.pos - Vector2(r * 0.3, r * 0.35), r * 0.45, Color(1, 1, 1, 0.5 * (1.0 - t)))
		"star":
			var r := size * (1.0 - 0.3 * t)
			_draw_star(p.pos, r + 1.8, p.rot, Color(UIKit.INK, 0.8 * (1.0 - t * t)))
			_draw_star(p.pos, r, p.rot, Color(col, 1.0 - t * t))
		"sparkle":
			var r := size * Ease.arc(t) * 1.3
			var a := Color(col, 1.0 - t * 0.5)
			draw_line(p.pos - Vector2(r, 0), p.pos + Vector2(r, 0), a, maxf(1.5, r * 0.35))
			draw_line(p.pos - Vector2(0, r), p.pos + Vector2(0, r), a, maxf(1.5, r * 0.35))
			draw_circle(p.pos, r * 0.3, Color.WHITE)
		"confetti":
			var w := size
			var h := size * 0.55 * absf(cos(float(p.rot) * 1.7))
			draw_set_transform(p.pos, p.rot, Vector2.ONE)
			draw_rect(Rect2(-w / 2.0, -h / 2.0, w, maxf(h, 1.0)), Color(col, 1.0 - Ease.in_cubic(t)))
			draw_set_transform(Vector2.ZERO)
		"coin":
			var squish := absf(cos(float(p.rot)))
			draw_set_transform(p.pos, 0.0, Vector2(maxf(squish, 0.15), 1.0))
			draw_circle(Vector2.ZERO, size + 1.5, Color("#9a6a00", 1.0 - Ease.in_cubic(t)))
			draw_circle(Vector2.ZERO, size, Color(col, 1.0 - Ease.in_cubic(t)))
			draw_circle(Vector2(-size * 0.3, -size * 0.3), size * 0.35, Color(1, 1, 1, 0.6 * (1.0 - t)))
			draw_set_transform(Vector2.ZERO)
		"petal":
			draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, size, Color(col, col.a * minf(1.0, (1.0 - t) * 3.0) * minf(1.0, t * 5.0)))
			draw_set_transform(Vector2.ZERO)


func _draw_star(center: Vector2, radius: float, rot: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in STAR_POINTS * 2:
		var r := radius if i % 2 == 0 else radius * 0.45
		var ang := rot - PI / 2.0 + i * PI / STAR_POINTS
		points.append(center + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(points, color)


