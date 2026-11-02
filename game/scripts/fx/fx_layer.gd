class_name FxLayer
extends Node2D
## Everything drawn over the animals: particles (sparks, stars, puffs,
## sparkles, confetti, coins), short effects (claw slashes, bites, rings,
## tool blasts, words), bouncy damage numbers, chunky health bars and thrown
## projectiles with trails. Drawn in one pass for speed. How many particles
## and how big things are comes from data/feel.json ("combat", "effects").
##
## Ground effects (rings on the ground, dust, an area that lasts) are drawn
## by the field under the animals through draw_ground().

const STAR_POINTS := 5

var field: BattleField
var particles: Array = []
var effects: Array = []
var numbers: Array = []
var projectiles: Array = []
var time := 0.0


func _init(owner_field: BattleField) -> void:
	field = owner_field


func _process_fx(dt: float) -> void:
	time += dt
	for p in particles:
		p.age += dt
		p.vel *= maxf(0.0, 1.0 - float(p.drag) * dt)
		p.vel.y += float(p.gravity) * dt
		p.pos += p.vel * dt
		p.rot += float(p.spin) * dt
	particles = particles.filter(func(p): return p.age < p.life)
	for fx in effects:
		fx.age += dt
	effects = effects.filter(func(fx): return fx.age < fx.life)
	for n in numbers:
		n.age += dt
	numbers = numbers.filter(func(n): return n.age < n.life)
	projectiles = projectiles.filter(func(pr): return time < pr.land)


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


# --- Short effects -------------------------------------------------------------

func effect(kind: String, at: Vector2, radius: float, color: Color, life: float, text := "", ground := false) -> Dictionary:
	var fx := {"kind": kind, "at": at, "radius": radius, "color": color, "life": life, "age": 0.0,
		"text": text, "dir": Vector2.UP, "seed": randi(), "ground": ground}
	effects.append(fx)
	return fx


## A number popping up off a hit. `kind`: "hurt_enemy", "hurt_own" or "heal".
## Quick hits on the same animal (`source`) add up into one number that
## pops again, instead of a pile of numbers.
func number(at: Vector2, amount: int, kind: String, big: bool, source: Variant = null) -> void:
	if not Feel.on("combat", "numbers") or amount <= 0:
		return
	var window := Feel.num("combat", "number_merge_seconds", 0.35)
	if source != null:
		for n in numbers:
			if n.source == source and n.kind == kind and float(n.age) < window:
				n.amount = int(n.amount) + amount
				n.text = ("+%d" if kind == "heal" else "%d") % int(n.amount)
				n.age = 0.0
				n.big = bool(n.big) or big
				n.at = at
				if n.big and kind == "hurt_enemy":
					n.color = Color("#ffe14d")
				return
	if numbers.size() >= Feel.count("combat", "number_max_on_screen", 12):
		numbers.pop_front()
	var color := Color.WHITE
	match kind:
		"hurt_own":
			color = Color("#ffb3b3")
		"heal":
			color = Color("#7dffb0")
	if big:
		color = Color("#ffe14d") if kind == "hurt_enemy" else color
	numbers.append({"at": at, "drift": randf_range(-14.0, 14.0), "text": ("+%d" if kind == "heal" else "%d") % amount,
		"color": color, "big": big, "age": 0.0, "life": Feel.num("combat", "number_seconds", 0.85),
		"source": source, "kind": kind, "amount": amount})


## A ranged animal's throw: leaves its paw before the hit and lands on it.
func throw(f: BattleSim.Fighter, to_hit: float) -> void:
	var flight := minf(0.28, to_hit + 0.15)
	projectiles.append({"from": Vector2(f.x, f.y), "to_uid": f.target.uid, "to": Vector2(f.target.x, f.target.y),
		"launch": time + to_hit - flight, "land": time + to_hit, "trail": []})


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	for fx in effects:
		if not fx.ground:
			_draw_effect(self, fx)
	for pr in projectiles:
		_draw_projectile(pr)
	_draw_bars()
	for p in particles:
		_draw_particle(p)
	for n in numbers:
		_draw_number(n)


## Effects that sit on the ground, drawn under the animals.
func draw_ground(canvas: CanvasItem) -> void:
	for fx in effects:
		if fx.ground:
			_draw_effect(canvas, fx)


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


func _draw_number(n: Dictionary) -> void:
	var t: float = n.age / n.life
	var size := float(Feel.count("combat", "number_big_size" if n.big else "number_size", 30 if n.big else 22))
	# Pop in big, settle, then float up and fade.
	var grow: float = Ease.out_back(minf(1.0, t * 5.0), 3.0)
	var font_size := int(size * lerpf(0.4, 1.0, grow))
	var rise := Ease.out_cubic(t) * Feel.num("combat", "number_rise_pixels", 38.0)
	var at: Vector2 = n.at + Vector2(float(n.drift) * t, -rise)
	var alpha := 1.0 - Ease.in_cubic(maxf(0.0, (t - 0.55) / 0.45))
	_draw_text(self, at, n.text, font_size, Color(n.color, alpha), maxi(3, font_size / 4))


func _draw_bars() -> void:
	var c := "combat"
	var w := Feel.num(c, "health_bar_width", 44.0)
	var h := Feel.num(c, "health_bar_height", 9.0)
	for view in field.views():
		var show: bool = view.bar_shown < 0.999 or view.bar_trail > view.bar_shown + 0.002
		if not show or view.defeat >= 0.0 or view.pop < 1.0:
			continue
		var top: Vector2 = view.position + view.head() + Vector2(0, -12.0)
		var width := w * (0.8 if view.swarm else 1.0)
		var rect := Rect2(top - Vector2(width / 2.0, h / 2.0), Vector2(width, h))
		var team_color := BattleField.OWN_COLOR if view.team == 0 else BattleField.ENEMY_COLOR
		var radius := int(h / 2.0)
		draw_style_box(UIKit.box(Color(UIKit.INK, 0.9), radius + 2), rect.grow(2.0))
		draw_style_box(UIKit.box(Color(0.12, 0.14, 0.2), radius), rect)
		var trail := Rect2(rect.position, Vector2(width * clampf(view.bar_trail, 0.0, 1.0), h))
		if trail.size.x > 1.0:
			draw_style_box(UIKit.box(Color("#fff1c2"), radius), trail)
		var fill := Rect2(rect.position, Vector2(width * clampf(view.bar_shown, 0.0, 1.0), h))
		if fill.size.x > 1.0:
			draw_style_box(UIKit.box(team_color.lightened(0.15), radius), fill)
			var gloss := Rect2(fill.position + Vector2(1, 1), Vector2(maxf(fill.size.x - 2, 0.0), h * 0.38))
			draw_style_box(UIKit.box(Color(1, 1, 1, 0.35), radius), gloss)
		if view.stars > 1:
			UIKit.draw_stars(self, top + Vector2(0, -h - 1.0), view.stars, 5.5)
	# Animals at full health still show their stars over their heads.
	for view in field.views():
		var full: bool = view.bar_shown >= 0.999 and view.bar_trail <= view.bar_shown + 0.002
		if full and view.stars > 1 and view.defeat < 0.0 and view.pop >= 1.0:
			UIKit.draw_stars(self, view.position + view.head() + Vector2(0, -14.0), view.stars, 6.0)
		# Stunned: dizzy stars circling over its head.
		if view.fighter != null and view.fighter.stun > 0 and view.defeat < 0.0:
			var over: Vector2 = view.position + view.head() + Vector2(0, -4.0)
			for i in 3:
				var ang := time * 5.0 + i * TAU / 3.0
				var spot := over + Vector2(cos(ang) * 14.0, sin(ang) * 5.0)
				_draw_star(spot, 6.0, ang, Color(UIKit.INK, 0.8))
				_draw_star(spot, 4.5, ang, Color("#ffe14d"))


func _draw_projectile(pr: Dictionary) -> void:
	if time < pr.launch:
		return
	var t := clampf((time - float(pr.launch)) / maxf(float(pr.land) - float(pr.launch), 0.01), 0.0, 1.0)
	var goal: Vector2 = pr.to
	var target := field.view_for_uid(int(pr.to_uid))
	if target != null:
		goal = target.pos
	var from := field.to_screen(pr.from.x, pr.from.y)
	var to := field.to_screen(goal.x, goal.y)
	var s := field.field_scale()
	# An arc: up and over, a little higher for longer throws.
	var lift := from.distance_to(to) * 0.35 + 10.0
	var p := from.lerp(to, t) + Vector2(0, -lift * Ease.arc(t) - 10.0)
	var trail: Array = pr.trail
	trail.append(p)
	if trail.size() > Feel.count("effects", "projectile_trail", 7):
		trail.pop_front()
	var r := maxf(3.5, 230.0 * s)
	# A glowing trail behind it.
	for i in trail.size():
		var k := float(i + 1) / float(trail.size())
		draw_circle(trail[i], r * 0.9 * k, Color(1.0, 0.92, 0.6, 0.35 * k))
	var glow := Feel.num("effects", "projectile_glow", 0.55)
	draw_circle(p, r * 2.0, Color(1.0, 0.95, 0.7, 0.25 * glow))
	draw_circle(p + Vector2(0, 10.0 + lift * Ease.arc(t)) * 0.4, r * 0.8, Color(0, 0, 0, 0.22))
	draw_circle(p, r + 1.5, Color("#3b2410"))
	draw_circle(p, r, Color("#a8682c"))
	draw_circle(p + Vector2(0, -r * 0.45), r * 0.75, Color("#6b4019"))
	draw_circle(p + Vector2(-r * 0.3, r * 0.15), r * 0.35, Color(1, 1, 1, 0.5))
	if t >= 0.97 and not pr.get("burst", false):
		pr.burst = true
		burst("spark", to + Vector2(0, -12), 5, 200.0, 0.2, 6.0, [Color("#fff6b0")], 0.0, 6.0)


static func _draw_effect(canvas: CanvasItem, fx: Dictionary) -> void:
	var p: Vector2 = fx.at
	var t: float = fx.age / fx.life
	var color: Color = fx.color
	var r: float = fx.radius
	match fx.kind:
		"ring":
			var rr := r * (0.5 + 0.5 * Ease.out_cubic(t))
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
			canvas.draw_circle(Vector2.ZERO, rr, Color(color, 0.22 * (1.0 - t)))
			canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(color, 0.95 * (1.0 - t)), 6.0)
			canvas.draw_set_transform(Vector2.ZERO)
		"area":
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
			canvas.draw_circle(Vector2.ZERO, r, Color(color, 0.14))
			canvas.draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(color, 0.55), 4.0)
			canvas.draw_set_transform(Vector2.ZERO)
		"flash":
			canvas.draw_circle(p, r * (1.0 - t), Color(color, 0.8 * (1.0 - t)))
		"text":
			var grow := Ease.out_back(minf(1.0, t * 4.0), 2.5)
			_draw_text(canvas, p + Vector2(0, -26 - 30 * Ease.out_cubic(t)), fx.text, int(22 * lerpf(0.5, 1.0, grow)), Color(color, 1.0 - Ease.in_cubic(t)), 4)
		"slash":
			# Three claw marks raking across the target.
			var d: Vector2 = fx.dir
			var across := Vector2(-d.y, d.x)
			var reach := Ease.out_cubic(clampf(t * 2.2, 0.0, 1.0))
			for i in 3:
				var offset := across * (float(i) - 1.0) * r * 0.32
				var a := p + offset - d * r * 0.6 + across * r * 0.25
				var b := p + offset + d * r * 0.6 - across * r * 0.25
				var tip := a.lerp(b, reach)
				canvas.draw_line(a, tip, Color(UIKit.INK, 0.55 * (1.0 - t)), 7.0)
				canvas.draw_line(a, tip, Color(color, 1.0 - t), 3.5)
		"chomp":
			# Two jaws snapping shut on the target.
			var gap := (1.0 - Ease.out_back(clampf(t * 2.5, 0.0, 1.0))) * r * 0.5
			var ang: float = fx.dir.angle()
			var col := Color(color, 1.0 - t * t)
			canvas.draw_arc(p - Vector2.from_angle(ang + PI / 2) * gap, r, ang + PI * 0.15, ang + PI * 0.85, 12, Color(UIKit.INK, col.a * 0.5), 6.0)
			canvas.draw_arc(p + Vector2.from_angle(ang + PI / 2) * gap, r, ang - PI * 0.85, ang - PI * 0.15, 12, Color(UIKit.INK, col.a * 0.5), 6.0)
			canvas.draw_arc(p - Vector2.from_angle(ang + PI / 2) * gap, r, ang + PI * 0.15, ang + PI * 0.85, 12, col, 3.5)
			canvas.draw_arc(p + Vector2.from_angle(ang + PI / 2) * gap, r, ang - PI * 0.85, ang - PI * 0.15, 12, col, 3.5)
		"dust":
			# Puffs of dust bursting out from the impact.
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			for i in 7:
				var ang := rng.randf() * TAU
				var dist: float = r * (0.3 + 0.7 * Ease.out_cubic(t)) * (0.5 + rng.randf() * 0.5)
				var puff: float = r * (0.12 + 0.2 * t) * (0.7 + rng.randf() * 0.6)
				var at := p + Vector2(cos(ang), sin(ang) * 0.55) * dist
				canvas.draw_circle(at, puff, Color(color, 0.6 * (1.0 - t)))
		"feathers":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			for i in 6:
				var ang := rng.randf() * TAU
				var dist: float = r * (0.2 + 0.8 * t) * (0.5 + rng.randf() * 0.5)
				var at := p + Vector2(cos(ang), sin(ang)) * dist + Vector2(0, 14.0 * t)
				canvas.draw_set_transform(at, ang + t * 3.0, Vector2(1.0, 0.35))
				canvas.draw_circle(Vector2.ZERO, 6.0, Color(color, 1.0 - t))
				canvas.draw_set_transform(Vector2.ZERO)
		"icon":
			var texture := UIKit.icon(fx.text)
			if texture != null:
				var side: float = r * (0.6 + 0.4 * Ease.out_back(minf(1.0, t * 3.0)))
				canvas.draw_texture_rect(texture, Rect2(p - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(color, 0.9 * (1.0 - Ease.in_cubic(t))))


static func _draw_text(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, outline := 4) -> void:
	if font_size < 6:
		return
	var font := UIKit.DISPLAY_FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-width / 2.0, font_size * 0.36)
	canvas.draw_string_outline(font, baseline + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline + 2, Color(UIKit.INK, color.a * 0.5))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(UIKit.INK, color.a))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
