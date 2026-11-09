class_name FxLayer
extends ParticleLayer
## Everything drawn over the animals: particles (sparks, stars, puffs,
## sparkles, confetti, coins), short effects (claw slashes, bites, rings,
## tool blasts, words), bouncy damage numbers, chunky health bars and thrown
## projectiles with trails. Drawn in one pass for speed. How many particles
## and how big things are comes from data/feel.json ("combat", "effects").
##
## Ground effects (rings on the ground, dust, an area that lasts) are drawn
## by the field under the animals through draw_ground().
##
## Big fights stay readable (feel.json "crowd"): only so many hit sparks and
## damage numbers at once, the biggest hits first, and fewer particles each
## once the field is crowded.

var field: BattleField
var effects: Array = []
var numbers: Array = []
var projectiles: Array = []
## A crowded fight (see the field): simpler effects.
var crowded := false
## Hit-spark bursts on screen now: {"amount", "until"}.
var _sparks: Array = []
## Damage numbers go on top of the particles (which draw as a child).
var _over: Node2D
## Health bar pieces, made once per color and size (a big fight draws
## dozens of bars every frame).
var _boxes := {}


func _init(owner_field: BattleField) -> void:
	field = owner_field
	# The field moves it along (so hit-stop freezes it too).
	self_driven = false
	_ensure_mesh()
	_over = Node2D.new()
	_over.draw.connect(func() -> void:
		for n in numbers:
			_draw_number(n))
	add_child(_over)


func _process_fx(dt: float) -> void:
	step_particles(dt)
	for fx in effects:
		fx.age += dt
	effects = effects.filter(func(fx): return fx.age < fx.life)
	var had_numbers := not numbers.is_empty()
	for n in numbers:
		n.age += dt
	numbers = numbers.filter(func(n): return n.age < n.life)
	if had_numbers:
		_over.queue_redraw()
	projectiles = projectiles.filter(func(pr): return time < pr.land)


# --- Short effects -------------------------------------------------------------

func effect(kind: String, at: Vector2, radius: float, color: Color, life: float, text := "", ground := false) -> Dictionary:
	var fx := {"kind": kind, "at": at, "radius": radius, "color": color, "life": life, "age": 0.0,
		"text": text, "dir": Vector2.UP, "seed": randi(), "ground": ground}
	effects.append(fx)
	return fx


## A number popping up off a hit. `kind`: "hurt_enemy", "hurt_own" or "heal".
## Quick hits on the same animal (`source`) add up into one number that
## pops again, instead of a pile of numbers. `only_add`: a small or quiet
## hit: it adds to a number already showing on that animal (without making
## it pop again or stay longer), but never makes a new one. `room`: how big
## (pixels, width and height) the number may get on the screen: no bigger
## than the animal that struck (ZERO: no limit).
func number(at: Vector2, amount: int, kind: String, big: bool, source: Variant = null, only_add := false, room := Vector2.ZERO) -> void:
	if not Feel.on("combat", "numbers") or amount <= 0:
		return
	var window := Feel.num("combat", "number_merge_seconds", 0.35)
	if source != null:
		for n in numbers:
			if n.source == source and n.kind == kind and float(n.age) < window:
				n.amount = int(n.amount) + amount
				n.text = ("+%d" if kind == "heal" else "%d") % int(n.amount)
				if only_add:
					return  # counted, but it doesn't pop again or linger
				n.age = 0.0
				n.big = bool(n.big) or big
				n.at = at
				if room != Vector2.ZERO:
					n.room = room
				if n.big and kind == "hurt_enemy":
					n.color = Color("#ffe14d")
				return
	if only_add:
		return
	# Too many on screen: a bigger hit takes the place of the smallest number
	# (a smaller one isn't shown).
	var most := Feel.count("crowd", "numbers_when_crowded", 6) if crowded else Feel.count("combat", "number_max_on_screen", 12)
	if numbers.size() >= most:
		var smallest := 0
		for i in numbers.size():
			if int(numbers[i].amount) < int(numbers[smallest].amount):
				smallest = i
		if amount <= int(numbers[smallest].amount) and not big:
			return
		numbers.remove_at(smallest)
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
		"source": source, "kind": kind, "amount": amount, "room": room})


## Whether a hit of `amount` gets sparks: only so many bursts at once
## (feel.json "crowd"); when that many are showing, a bigger hit takes the
## place of the smallest.
func allow_sparks(amount: int) -> bool:
	_sparks = _sparks.filter(func(s): return float(s.until) > time)
	var most := Feel.count("crowd", "hit_sparks_when_crowded", 6) if crowded else Feel.count("crowd", "hit_sparks_max", 12)
	var entry := {"amount": amount, "until": time + Feel.num("crowd", "spark_seconds", 0.25)}
	if _sparks.size() < most:
		_sparks.append(entry)
		return true
	var smallest := 0
	for i in _sparks.size():
		if int(_sparks[i].amount) < int(_sparks[smallest].amount):
			smallest = i
	if amount <= int(_sparks[smallest].amount):
		return false
	_sparks[smallest] = entry
	return true


## A ranged animal's shot: leaves `attacker` when its strike lands (in
## `delay` seconds) and flies `flight` seconds (or so: some looks fly
## slower, data/shots.json) to `target`, following it, or to `to` (field
## units) if it has no view. Gives the real flight time.
## `scale`: its size (a giant spit, little pinecones); `origin`: where it
## flies from if not the attacker (a fruit bouncing on from the last one hit).
func shoot(attacker: UnitView, target: UnitView, to: Vector2, delay: float, flight: float, arc := 1.0, scale := 1.0, origin: UnitView = null) -> float:
	var look := ShotLooks.look_for(GameData.cards.get(attacker.id, {}))
	if arc != 1.0 or scale != 1.0:
		look = look.duplicate()
		look.arc = float(look.get("arc", 0.3)) * arc
		look.size = float(look.get("size", 0.2)) * scale
	flight *= ShotLooks.flight_scale(look)
	projectiles.append({"attacker": attacker, "target": target, "to": to, "from": Vector2.ZERO, "origin": origin,
		"launch": time + delay, "land": time + delay + flight, "trail": [], "look": look,
		"team": attacker.team if is_instance_valid(attacker) else -1, "team_trail": []})
	return flight


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	for fx in effects:
		if not fx.ground:
			_draw_effect(self, fx)
	for pr in projectiles:
		_draw_projectile(pr)
	_draw_bars()


## Effects that sit on the ground, drawn under the animals.
func draw_ground(canvas: CanvasItem) -> void:
	for fx in effects:
		if fx.ground:
			_draw_effect(canvas, fx)


func _draw_number(n: Dictionary) -> void:
	var t: float = n.age / n.life
	var size := float(Feel.count("combat", "number_big_size" if n.big else "number_size", 30 if n.big else 22))
	# Pop in big, settle, then float up and fade.
	var grow: float = Ease.out_back(minf(1.0, t * 5.0), 3.0)
	# Never bigger than the animal that struck: no taller, no wider.
	var room: Vector2 = n.get("room", Vector2.ZERO)
	if room != Vector2.ZERO:
		size = minf(size, room.y)
		var wide := UIKit.DISPLAY_FONT.get_string_size(String(n.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		if wide > room.x and wide > 0.0:
			size *= room.x / wide
	var font_size := int(size * lerpf(0.4, 1.0, grow))
	var rise := Ease.out_cubic(t) * Feel.num("combat", "number_rise_pixels", 38.0)
	var at: Vector2 = n.at + Vector2(float(n.drift) * t, -rise)
	var alpha := 1.0 - Ease.in_cubic(maxf(0.0, (t - 0.55) / 0.45))
	_draw_text(_over, at, n.text, font_size, Color(n.color, alpha), maxi(3, font_size / 4))


func _draw_bars() -> void:
	var c := "combat"
	# As wide as the animal (health_bar_body_share of its footprint), but
	# between health_bar_width and health_bar_max_width pixels; at least
	# health_bar_height tall, or health_bar_height_share of its width.
	var w := Feel.num(c, "health_bar_width", 44.0)
	var w_most := maxf(w, Feel.num(c, "health_bar_max_width", w))
	var share := Feel.num(c, "health_bar_body_share", 0.0)
	var h := Feel.num(c, "health_bar_height", 9.0)
	var h_share := Feel.num(c, "health_bar_height_share", 0.0)
	var field_px := field.field_scale()
	var stars_at := []
	# A bar shows once an animal is hurt, and fades away when it hasn't been
	# hit for a while (it comes back with the next hit).
	var hide_after := Feel.num(c, "health_bar_hide_after", 2.5)
	var fade := maxf(0.05, Feel.num(c, "health_bar_fade_seconds", 0.5))
	var now := field.now()
	for view in field.views():
		if view.defeat >= 0.0 or view.pop < 1.0:
			continue
		var hurt: bool = view.bar_shown < 0.999 or view.bar_trail > view.bar_shown + 0.002
		var a := clampf(1.0 - (now - float(view.hurt_time()) - hide_after) / fade, 0.0, 1.0) if hurt else 0.0
		if a > 0.0:
			var width := w
			if share > 0.0 and view.fighter != null:
				width = clampf(float(view.fighter.radius) * field_px * 2.0 * share, w, w_most)
			width *= 0.8 if view.swarm else 1.0
			var tall := roundf(maxf(h, width * h_share))
			var top: Vector2 = view.position + view.head() + Vector2(0, -6.0 - tall)
			var rect := Rect2(top - Vector2(width / 2.0, tall / 2.0), Vector2(width, tall))
			var team_color := BattleField.team_color(view.team)
			var radius := int(tall / 2.0)
			draw_style_box(_box(Color(UIKit.INK, a), radius + 2), rect.grow(2.0))
			draw_style_box(_box(Color(0.12, 0.14, 0.2, a), radius), rect)
			var trail := Rect2(rect.position, Vector2(width * clampf(view.bar_trail, 0.0, 1.0), tall))
			if trail.size.x > 1.0:
				draw_style_box(_box(Color("#fff1c2", a), radius), trail)
			var fill := Rect2(rect.position, Vector2(width * clampf(view.bar_shown, 0.0, 1.0), tall))
			if fill.size.x > 1.0:
				draw_style_box(_box(Color(team_color, a), radius), fill)
				var gloss := Rect2(fill.position + Vector2(1, 1), Vector2(maxf(fill.size.x - 2, 0.0), tall * 0.38))
				draw_style_box(_box(Color(1, 1, 1, 0.35 * a), radius), gloss)
			if view.stars > 1 and view.shows_stars():
				stars_at.append([top + Vector2(0, -tall - 1.0), view.stars, 5.5])
		elif view.stars > 1 and view.shows_stars():
			stars_at.append([view.position + view.head() + Vector2(0, -14.0), view.stars, 6.5])
		# Stunned: dizzy stars circling over its head.
		if view.fighter != null and view.fighter.stun > 0:
			var over: Vector2 = view.position + view.head() + Vector2(0, -4.0)
			for i in 3:
				var ang := time * 5.0 + i * TAU / 3.0
				stars_at.append([over + Vector2(cos(ang) * 14.0, sin(ang) * 5.0), 1, 5.5])
	# All the stars after all the bars, so each draws in one batch.
	for s in stars_at:
		var count: int = s[1]
		var gap: float = float(s[2]) * 1.85
		for i in count:
			UIStyle.draw_particle(self, "star", s[0] + Vector2((i - (count - 1) / 2.0) * gap, 0), float(s[2]), Color("#ffe14d"))


## A rounded box for a health bar, reused (its opacity rounded a little so
## a fading bar doesn't make a new one every frame).
func _box(color: Color, radius: int) -> StyleBoxFlat:
	color.a = snappedf(color.a, 0.05)
	var key := "%s/%d" % [color.to_html(), radius]
	if not _boxes.has(key):
		_boxes[key] = UIKit.box(color, radius)
	return _boxes[key]


func _draw_projectile(pr: Dictionary) -> void:
	if time < pr.launch:
		return
	var t := clampf((time - float(pr.launch)) / maxf(float(pr.land) - float(pr.launch), 0.01), 0.0, 1.0)
	# From its mouth or paws as it lets go, to the middle of the target,
	# following it as it moves (data/shots.json for the look).
	if not pr.has("launched"):
		pr.launched = true
		var shooter: UnitView = pr.attacker if is_instance_valid(pr.attacker) else null
		if pr.get("origin") != null and is_instance_valid(pr.origin):
			shooter = pr.origin
		pr.from = shooter.middle() if shooter != null else field.to_screen(pr.to.x, pr.to.y)
	var target: UnitView = pr.target if is_instance_valid(pr.target) else null
	var to: Vector2 = target.middle() if target != null else field.to_screen(pr.to.x, pr.to.y) + Vector2(0, -10.0)
	var look: Dictionary = pr.get("look", {})
	var team := int(pr.get("team", -1))
	if team >= 0:
		_team_trail(pr, look, to, t, BattleField.team_color(team))
	ShotLooks.draw(self, look, pr.from, to, t, pr.trail, field.field_scale(), time)
	if t >= 0.97 and not pr.get("burst", false):
		pr.burst = true
		var color := Color(String(look.get("burst_color", "#fff6b0")))
		var second := BattleField.team_color(team).lightened(0.25) if team >= 0 else Color.WHITE
		burst(String(look.get("burst", "spark")), to, 5, 200.0, 0.25, 6.0, [color, second], 0.0, 6.0)


## Who's shooting at whom: a streak in the shooter's team color (blue yours,
## red the enemy's) behind every shot, and a ring of it round the shot
## (feel.json "readability" shot_*).
func _team_trail(pr: Dictionary, look: Dictionary, to: Vector2, t: float, color: Color) -> void:
	var r := "readability"
	var size := maxf(3.0, float(look.get("size", 0.2)) * float(BattleSim.TILE) * field.field_scale())
	var head := trail_step(pr, look, to, t)
	var trail: Array = pr.team_trail
	var width := Feel.num(r, "shot_trail_width", 4.0)
	var alpha := Feel.num(r, "shot_trail_alpha", 0.75)
	for i in range(1, trail.size()):
		var k := float(i) / float(trail.size() - 1)
		draw_line(trail[i - 1][0], trail[i][0], Color(color, alpha * k), maxf(1.0, width * k), true)
	draw_arc(head, size * Feel.num(r, "shot_ring_scale", 1.5), 0.0, TAU, 18, Color(color, alpha), Feel.num(r, "shot_ring_px", 2.5), true)


## Where a shot is now (at `t` of its flight to `to`), noted in its streak,
## which keeps only the last shot_trail_seconds (the same at any frame rate).
func trail_step(pr: Dictionary, look: Dictionary, to: Vector2, t: float) -> Vector2:
	var head: Vector2
	match String(look.get("style", "ball")):
		"ball", "volley", "wave":
			head = ShotLooks._arc_point(look, pr.from, to, t)
		_:
			head = (pr.from as Vector2).lerp(to, t)
	var trail: Array = pr.team_trail
	if trail.is_empty() or (trail[-1][0] as Vector2).distance_to(head) > 0.5:
		trail.append([head, time])
	var keep := Feel.num("readability", "shot_trail_seconds", 0.12)
	while trail.size() > 2 and time - float(trail[1][1]) > keep:
		trail.pop_front()
	return head


static func _draw_effect(canvas: CanvasItem, fx: Dictionary) -> void:
	if float(fx.age) < 0.0:
		return  # not started yet (a staggered effect)
	var p: Vector2 = fx.at
	var t: float = fx.age / fx.life
	var color: Color = fx.color
	var r: float = fx.radius
	# One that rides along over an animal's head.
	var rider: Variant = fx.get("follow")
	if rider != null and is_instance_valid(rider):
		var v := rider as UnitView
		if v != null:
			p = v.position + v.head()
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
			canvas.draw_arc(Vector2.ZERO, r, 0, TAU, 40, color, 4.0)
			canvas.draw_set_transform(Vector2.ZERO)
		"flash":
			canvas.draw_circle(p, r * (1.0 - t), Color(color, 0.8 * (1.0 - t)))
		"text":
			var grow := Ease.out_back(minf(1.0, t * 4.0), 2.5)
			_draw_text(canvas, p + Vector2(0, -26 - 30 * Ease.out_cubic(t)), fx.text, int(22 * lerpf(0.5, 1.0, grow)), Color(color, 1.0 - Ease.in_cubic(t)), 4)
		"sweep":
			# One wide swipe: an arc from the first target round to the second.
			var a: float = fx.get("a_ang", 0.0)
			var b: float = fx.get("b_ang", 0.0)
			var span := wrapf(b - a, -PI, PI)
			var reach := Ease.out_cubic(clampf(t * 2.5, 0.0, 1.0))
			var fade := 1.0 - Ease.in_cubic(t)
			var from := a - span * 0.15
			var to := from + (span * 1.3) * reach
			canvas.draw_arc(p, r, minf(from, to), maxf(from, to), 18, Color(UIKit.INK, 0.45 * fade), 14.0)
			canvas.draw_arc(p, r, minf(from, to), maxf(from, to), 18, Color(color, 0.95 * fade), 8.0)
			canvas.draw_arc(p, r * 0.86, minf(from, to), maxf(from, to), 18, Color(color, 0.95 * fade), 4.0)
		"cone":
			# A spray fanning out toward its target.
			var ang: float = fx.dir.angle()
			var half := deg_to_rad(float(fx.get("spread", 60.0)) / 2.0)
			var reach := r * Ease.out_cubic(clampf(t * 3.0, 0.0, 1.0))
			var fan := PackedVector2Array([p])
			for i in 9:
				var u := ang - half + 2.0 * half * i / 8.0
				fan.append(p + Vector2(cos(u), sin(u) * 0.75) * reach)
			canvas.draw_colored_polygon(fan, Color(color, 0.6 * (1.0 - t)))
			canvas.draw_polyline(fan + PackedVector2Array([p]), Color(color.lightened(0.3), 1.0 - t), 3.0)
		"rainbow":
			# A rainbow beam right through the line.
			var end: Vector2 = fx.get("end", p)
			var dir := (end - p).normalized()
			var across := Vector2(-dir.y, dir.x)
			var bands := [Color("#ff6b6b"), Color("#ffb347"), Color("#fff176"), Color("#7ee08a"), Color("#6ec6ff"), Color("#b39ddb")]
			var fade := 1.0 - Ease.in_cubic(t)
			var width := r * (1.0 - 0.5 * t)
			for i in bands.size():
				var off := across * (i - 2.5) * width / bands.size()
				canvas.draw_line(p + off, end + off, Color(bands[i], fade), maxf(2.0, width / bands.size() + 1.0))
			canvas.draw_line(p, end, Color(1, 1, 1, 0.9 * fade), maxf(1.5, width * 0.15))
		"fire_line":
			# A line of fire burning along the ground (the Dragon's run): it
			# sweeps out along the line, flickers, and dies down at the end.
			var end: Vector2 = fx.get("end", p)
			var age: float = fx.age
			var tip := p.lerp(end, clampf(age / maxf(0.01, float(fx.get("reveal", 0.35))), 0.0, 1.0))
			var fade := 1.0 - clampf((t - 0.75) / 0.25, 0.0, 1.0)
			var flame: Color = fx.get("flame", Color("#ffc23a"))
			canvas.draw_line(p, tip, Color(color.darkened(0.45), 0.4 * fade), r * 2.0)
			canvas.draw_line(p, tip, Color(color, 0.5 * fade), r * 1.1)
			var length := p.distance_to(tip)
			var count := int(length / maxf(6.0, r * 0.7))
			var dir := (end - p).normalized()
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			for i in count + 1:
				var u := i / float(maxi(count, 1))
				var at := p.lerp(tip, u) + Vector2(dir.y, -dir.x) * rng.randf_range(-0.5, 0.5) * r
				var flick := 0.6 + 0.4 * sin(age * 14.0 + rng.randf() * TAU)
				var high := r * (0.9 + 0.7 * rng.randf()) * flick * fade
				if high < 2.0:
					continue
				for layer in 2:
					var w := r * (0.45 if layer == 0 else 0.25)
					var hh := high * (1.0 if layer == 0 else 0.6)
					var shape := PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w * 0.55, -hh * 0.55), at + Vector2(0, -hh),
						at + Vector2(w * 0.55, -hh * 0.55), at + Vector2(w, 0), at + Vector2(0, w * 0.45)])
					canvas.draw_colored_polygon(shape, Color(color if layer == 0 else flame, fade))
		"tentacle":
			# A tentacle reaching from `at` to `end`: it rises in an arc, slams
			# down, then pulls back.
			var end: Vector2 = fx.get("end", p)
			var reach := Ease.out_cubic(clampf(t * 2.5, 0.0, 1.0)) * (1.0 - Ease.in_cubic(clampf((t - 0.6) / 0.4, 0.0, 1.0)))
			var tip := p.lerp(end, reach)
			var rise := (1.0 - clampf(t * 2.5, 0.0, 1.0)) * p.distance_to(end) * 0.6 + 6.0
			var mid := p.lerp(tip, 0.5) + Vector2(0, -rise)
			var curve := PackedVector2Array()
			for i in 13:
				var u := i / 12.0
				curve.append(p.lerp(mid, u).lerp(mid.lerp(tip, u), u))
			for i in 12:
				var width := r * (1.0 - i / 13.0) + 2.0
				canvas.draw_line(curve[i], curve[i + 1], UIKit.INK, width + 4.0)
			for i in 12:
				var width := r * (1.0 - i / 13.0) + 2.0
				canvas.draw_line(curve[i], curve[i + 1], color, width)
				if i % 3 == 1:
					canvas.draw_circle(curve[i] + (curve[i + 1] - curve[i]).orthogonal().normalized() * width * 0.3, width * 0.18, color.lightened(0.45))
		"lightning":
			# A jagged bolt from point to point, flickering.
			var points: PackedVector2Array = fx.get("points", PackedVector2Array())
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed) + int(t * 12.0)
			var fade := 1.0 - Ease.in_cubic(t)
			for k in range(points.size() - 1):
				var a := points[k]
				var b := points[k + 1]
				var bolt := PackedVector2Array([a])
				var across := (b - a).orthogonal().normalized()
				for j in range(1, 6):
					bolt.append(a.lerp(b, j / 6.0) + across * rng.randf_range(-1.0, 1.0) * r * 0.35)
				bolt.append(b)
				canvas.draw_polyline(bolt, Color(color, 0.35 * fade), r * 0.9)
				canvas.draw_polyline(bolt, Color(color, fade), r * 0.35)
				canvas.draw_polyline(bolt, Color(1, 1, 1, fade), maxf(2.0, r * 0.14))
		"slow_zone":
			# A Sloth's slow-motion zone on the ground round it: a soft disc with
			# a slowly turning dashed edge and a clock hand.
			var turn: float = fx.get("turn", 0.0)
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
			canvas.draw_circle(Vector2.ZERO, r, Color(color, 0.24))
			canvas.draw_circle(Vector2.ZERO, r * 0.6, Color(color, 0.1))
			for i in 24:
				var a0 := turn + TAU * i / 24.0
				canvas.draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 48.0, 4, Color(color.lightened(0.3), 0.95), 7.0)
			canvas.draw_line(Vector2.ZERO, Vector2.from_angle(turn * 3.0 - PI / 2) * r * 0.55, Color(color, 0.85), 4.0)
			canvas.draw_line(Vector2.ZERO, Vector2.from_angle(turn * 0.25 - PI / 2) * r * 0.35, Color(color, 0.85), 5.0)
			canvas.draw_set_transform(Vector2.ZERO)
		"frost_patch":
			# The Yeti's frost on the ground: an icy disc with a glassy sheen and
			# little crystals standing round its edge, frosting over quickly and
			# melting away at the end.
			var grow := Ease.out_cubic(clampf(t * 8.0, 0.0, 1.0))
			var melt := 1.0 - clampf((t - 0.8) / 0.2, 0.0, 1.0)
			var edge: Color = fx.get("edge", color)
			var rr := r * grow
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
			canvas.draw_circle(Vector2.ZERO, rr, Color(color, 0.42 * melt))
			canvas.draw_circle(Vector2.ZERO, rr * 0.65, Color(1, 1, 1, 0.2 * melt))
			canvas.draw_arc(Vector2.ZERO, rr * 0.8, PI * 1.1, PI * 1.45, 12, Color(1, 1, 1, 0.5 * melt), maxf(2.0, rr * 0.04))
			canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(edge, 0.95 * melt), 5.0)
			canvas.draw_set_transform(Vector2.ZERO)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			for i in 10:
				var a := TAU * i / 10.0 + rng.randf() * 0.3
				var d := rr * rng.randf_range(0.6, 0.95)
				var base := p + Vector2(cos(a) * d, sin(a) * d * 0.6)
				var h := rr * rng.randf_range(0.12, 0.2) * grow * melt
				var w := h * 0.35
				var lean := rng.randf_range(-0.3, 0.3) * h
				_shard(canvas, base, h, w, lean, edge.darkened(0.35), color.lightened(0.4), Color.WHITE, melt)
		"blast":
			# An impact in an element's look (feel.json "elements"; docs/
			# ART_DIRECTION.md, effects), in layers: a white-hot core flash, the
			# element's glow swelling and thinning, a shockwave ring racing out
			# (two for a Mythic's big one) and the element's bits flying out of
			# it: rocks and drops arc and fall, flames and wisps rise, leaves and
			# streaks drift, shards and stars spin.
			var core: Color = fx.get("core", Color.WHITE)
			var dark: Color = fx.get("dark", color.darkened(0.5))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			var reach := Ease.out_cubic(clampf(t * 1.6, 0.0, 1.0))
			var fade := 1.0 - Ease.in_cubic(t)
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.7))
			canvas.draw_circle(Vector2.ZERO, r * (0.35 + 0.65 * reach), Color(color, 0.3 * fade))
			var flash := 1.0 - clampf(t * 3.0, 0.0, 1.0)
			if flash > 0.0:
				canvas.draw_circle(Vector2.ZERO, r * 0.5 * (0.5 + 0.5 * flash), Color(core, 0.9 * flash))
			for k in int(fx.get("rings", 1)):
				var kk := Ease.out_cubic(clampf(t * 1.6 - k * 0.3, 0.0, 1.0))
				if kk <= 0.0:
					continue
				var rr := r * (0.3 + 0.8 * kk)
				var width := maxf(2.5, r * 0.09 * (1.0 - 0.6 * kk))
				var a := (1.0 - kk) * fade
				canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(dark, 0.6 * a), width + 3.0)
				canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(core, 0.95 * a), width)
			canvas.draw_set_transform(Vector2.ZERO)
			var bits := String(fx.get("bits", "spark"))
			var count := int(fx.get("count", 7))
			var push: Vector2 = fx.dir
			var gravity := 0.0
			match bits:
				"rock", "drop":
					gravity = 1.8
				"flame", "wisp":
					gravity = -0.8
				"leaf", "streak":
					gravity = 0.35
			for i in count:
				var ang := TAU * (i + rng.randf() * 0.6) / maxi(count, 1)
				var far := r * rng.randf_range(0.6, 1.25)
				var u := Ease.out_cubic(t)
				var hop := r * 0.35 * sin(u * PI) if gravity >= 0.0 else 0.0
				var at := p + Vector2(cos(ang), sin(ang) * 0.6) * far * u + push * r * 0.25 * u + Vector2(0, gravity * r * t * t - hop)
				var size := r * rng.randf_range(0.1, 0.2) * (1.0 - 0.35 * t)
				_bit(canvas, bits, at, size, ang + t * 6.0 * (1.0 if i % 2 == 0 else -1.0), dark, color, core, fade)
		"linger":
			# The fade an impact leaves on the ground (feel.json "elements"
			# linger_seconds): a stain of the element's glow thinning away, with
			# a few of its bits settled in it, flickering out (embers, frost,
			# drops, leaves).
			var dark: Color = fx.get("dark", color.darkened(0.5))
			var fade := (1.0 - Ease.in_cubic(t)) * minf(1.0, t * 6.0)
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
			canvas.draw_circle(Vector2.ZERO, r, Color(dark, 0.16 * fade))
			canvas.draw_circle(Vector2.ZERO, r * 0.7, Color(color, 0.14 * fade))
			canvas.draw_set_transform(Vector2.ZERO)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			var bits := String(fx.get("bits", "spark"))
			for i in 5:
				var a := TAU * i / 5.0 + rng.randf()
				var d := r * rng.randf_range(0.3, 0.9)
				var at := p + Vector2(cos(a) * d, sin(a) * d * 0.55)
				var flick := 0.6 + 0.4 * sin(float(fx.age) * 9.0 + i * 1.7)
				_bit(canvas, bits, at, r * 0.09 * flick, a, dark, color, Color.WHITE, fade * 0.9)
		"ice_blast":
			# The Yeti's ground pound (docs/ART_DIRECTION.md, effects). The
			# build-up is the frost gathering on its fists (style_look.gd); this
			# is the impact and the fade, in layers: a white core flash, an icy
			# glow, a shockwave ring racing out, ice shards bursting up out of
			# the ground round it and frost cracks across it, all melting back
			# at the end. Values: feel.json "styles" ice_*.
			var dark: Color = fx.get("dark", color.darkened(0.5))
			var core: Color = fx.get("core", Color.WHITE)
			var reach := Ease.out_cubic(clampf(t * 1.8, 0.0, 1.0))
			var fade := 1.0 - clampf((t - 0.45) / 0.55, 0.0, 1.0)
			var rr := r * (0.2 + 0.8 * reach)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
			canvas.draw_circle(Vector2.ZERO, rr * 0.95, Color(color, 0.28 * fade))
			var flash := 1.0 - clampf(t * 3.5, 0.0, 1.0)
			if flash > 0.0:
				canvas.draw_circle(Vector2.ZERO, r * 0.55 * (0.4 + 0.6 * flash), Color(core, 0.85 * flash))
			# The shockwave: a thick bright ring thinning as it spreads.
			var width := maxf(3.0, r * 0.1 * (1.0 - 0.6 * reach))
			canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(dark, 0.7 * fade), width + 4.0)
			canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(core, 0.95 * fade), width)
			# Frost cracks racing out across the ground.
			var cracks := int(fx.get("cracks", 6))
			for i in cracks:
				var a := TAU * (i + rng.randf() * 0.5) / cracks
				var far := rr * rng.randf_range(0.7, 1.0)
				var pts := PackedVector2Array([Vector2.ZERO])
				for k in range(1, 5):
					pts.append(Vector2.from_angle(a + rng.randf_range(-0.12, 0.12)) * far * k / 4.0)
				canvas.draw_polyline(pts, Color(core, 0.8 * fade), maxf(1.5, r * 0.02))
			canvas.draw_set_transform(Vector2.ZERO)
			# Ice shards shooting up out of the ground round the ring, then
			# sinking back as they melt.
			var shards := int(fx.get("shards", 10))
			var grow := Ease.out_back(clampf((t - 0.04) / 0.3, 0.0, 1.0), 2.0)
			var melt := 1.0 - Ease.in_cubic(clampf((t - 0.5) / 0.5, 0.0, 1.0))
			for i in shards:
				var a := TAU * i / shards + rng.randf_range(-0.2, 0.2)
				var d := r * rng.randf_range(0.4, 0.85)
				var base := p + Vector2(cos(a) * d, sin(a) * d * 0.6)
				var h := r * rng.randf_range(0.22, 0.45) * grow * melt
				var w := h * rng.randf_range(0.28, 0.4)
				var lean := rng.randf_range(-0.25, 0.25) * h
				_shard(canvas, base, h, w, lean, dark, color.lightened(0.45), core, melt)
		"ink_cloud":
			# The Kraken's ink: a dark, swirling cloud spreading out, then
			# thinning away.
			var grow := Ease.out_cubic(clampf(t * 6.0, 0.0, 1.0))
			var thin := 1.0 - clampf((t - 0.7) / 0.3, 0.0, 1.0)
			var rr := r * grow
			canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
			canvas.draw_circle(Vector2.ZERO, rr, Color(color, 0.36 * thin))
			canvas.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(color.lightened(0.25), 0.9 * thin), 4.0)
			canvas.draw_set_transform(Vector2.ZERO)
			var puffs := int(fx.get("puffs", 7))
			for i in puffs:
				var a := float(fx.age) * 0.9 + TAU * i / puffs
				var at := p + Vector2(cos(a) * rr * 0.55, sin(a) * rr * 0.33 - rr * 0.15)
				canvas.draw_circle(at, rr * (0.28 + 0.06 * sin(float(fx.age) * 3.0 + i)), Color(color.lightened(0.12), 0.42 * thin))
		"wisp":
			# A glowing wisp flying from `at` to `end`, a little trail behind.
			var end: Vector2 = fx.get("end", p)
			for i in 5:
				var u := clampf(t - i * 0.06, 0.0, 1.0)
				var at := p.lerp(end, u * u) + Vector2(0, -sin(u * PI) * r * 1.5)
				var size := r * (0.5 - i * 0.08)
				canvas.draw_circle(at, size * 1.8, Color(color, 0.18 * (1.0 - i * 0.18)))
				canvas.draw_circle(at, size, Color(color.lightened(0.3), 1.0 - i * 0.18))
			var head := p.lerp(end, t * t) + Vector2(0, -sin(t * PI) * r * 1.5)
			canvas.draw_circle(head, r * 0.18, Color.WHITE)
		"shield":
			# A curved shield flashing up on the side a shot came from.
			var ang: float = fx.dir.angle()
			var fade := 1.0 - Ease.in_cubic(t)
			var grow := 0.85 + 0.15 * Ease.out_back(minf(1.0, t * 4.0))
			var arc := PackedVector2Array()
			for i in 13:
				var u := ang - 1.1 + 2.2 * i / 12.0
				arc.append(p + Vector2(cos(u), sin(u)) * r * grow)
			for i in range(12, -1, -1):
				var u := ang - 1.1 + 2.2 * i / 12.0
				arc.append(p + Vector2(cos(u), sin(u)) * r * grow * 0.82)
			canvas.draw_colored_polygon(arc, Color(color, 0.35 * fade))
			canvas.draw_arc(p, r * grow, ang - 1.1, ang + 1.1, 14, Color(color.lightened(0.4), 0.95 * fade), 4.0)
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
		"drop":
			# A sweat drop sliding off a worried animal.
			var at := p + Vector2(0, 10.0 * Ease.in_cubic(t))
			var a := 1.0 - Ease.in_cubic(t)
			var tip := at + Vector2(0, -r * 1.3)
			canvas.draw_colored_polygon(PackedVector2Array([tip, at + Vector2(-r * 0.7, -r * 0.2), at + Vector2(r * 0.7, -r * 0.2)]), Color(color, a))
			canvas.draw_circle(at, r * 0.72, Color(color, a))
			canvas.draw_circle(at + Vector2(-r * 0.25, -r * 0.2), r * 0.22, Color(1, 1, 1, a * 0.9))
		"alert":
			# A cartoon "!" popping up over an animal that's just noticed
			# someone biting it: a spiky yellow burst with a fat "!",
			# springing in, wobbling, then shrinking away.
			var pop := Ease.out_back(minf(1.0, t * 5.0), float(fx.get("pop", 3.0)))
			var gone := Ease.in_cubic(clampf((t - 0.75) / 0.25, 0.0, 1.0))
			var size := r * pop * (1.0 - gone)
			if size <= 1.0:
				return
			var at := p + Vector2(0, -size * 0.7 - 6.0)
			var tilt := sin(t * 18.0) * 0.12 * (1.0 - t)
			canvas.draw_set_transform(at, tilt, Vector2.ONE)
			var spikes := PackedVector2Array()
			for i in 20:
				var ang := TAU * i / 20.0 - PI / 2.0
				var reach := size * (0.62 if i % 2 == 0 else 0.46)
				spikes.append(Vector2(cos(ang) * reach * 0.86, sin(ang) * reach))
			var ink := Color(UIKit.INK, 1.0 - gone)
			var outline := spikes.duplicate()
			outline.append(spikes[0])
			canvas.draw_colored_polygon(spikes, Color(color, 1.0 - gone))
			canvas.draw_polyline(outline, ink, maxf(2.0, size * 0.07), true)
			# The "!": a tapering bar and a dot.
			var w := size * 0.13
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-w, -size * 0.36), Vector2(w, -size * 0.36),
				Vector2(w * 0.55, size * 0.1), Vector2(-w * 0.55, size * 0.1)]), ink)
			canvas.draw_circle(Vector2(0, size * 0.26), w * 0.85, ink)
			canvas.draw_set_transform(Vector2.ZERO)
		"zzz":
			# Sleepy Zzz drifting up and away.
			for i in 3:
				var u := clampf(t * 1.4 - i * 0.18, 0.0, 1.0)
				if u <= 0.0 or u >= 1.0:
					continue
				var at := p + Vector2(i * r * 0.9 + sin(u * 5.0) * 3.0, -u * r * 3.5)
				_draw_text(canvas, at, "z", int(r * (1.2 + i * 0.35)), Color(color, 1.0 - Ease.in_cubic(u)), 3)
		"icon":
			var texture := UIKit.icon(fx.text)
			if texture != null:
				var side: float = r * (0.6 + 0.4 * Ease.out_back(minf(1.0, t * 3.0)))
				canvas.draw_texture_rect(texture, Rect2(p - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(color, 1.0 - Ease.in_cubic(t)))


## One ice crystal standing on the ground at `base`: `h` tall, `w` wide at
## the foot, leaning `lean` sideways; a dark edge, a pale face and a white
## shine down one side.
static func _shard(canvas: CanvasItem, base: Vector2, h: float, w: float, lean: float, dark: Color, pale: Color, shine: Color, alpha: float) -> void:
	if h < 1.0:
		return
	var tip := base + Vector2(lean, -h)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), tip, base + Vector2(w, 0), base + Vector2(0, w * 0.5)]), Color(dark, 0.95 * alpha))
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.55, -w * 0.1), base + Vector2(lean * 0.9, -h * 0.9), base + Vector2(w * 0.45, -w * 0.1)]), Color(pale, 0.95 * alpha))
	canvas.draw_line(base + Vector2(-w * 0.2, -w * 0.3), base + Vector2(lean * 0.75, -h * 0.78), Color(shine, 0.9 * alpha), maxf(1.5, w * 0.22))



## One bit of an element flying out of an impact or lying in its fade
## (feel.json "elements" bits): `size` across, turned `ang`, in the
## element's dark, glow and core colors.
static func _bit(canvas: CanvasItem, kind: String, at: Vector2, size: float, ang: float, dark: Color, glow: Color, core: Color, alpha: float) -> void:
	if size < 1.0 or alpha <= 0.0:
		return
	match kind:
		"shard":
			_shard(canvas, at + Vector2(0, size), size * 2.2, size * 0.6, sin(ang) * size * 0.4, dark, glow.lightened(0.4), core, alpha)
		"flame":
			# A teardrop of fire, a paler flame inside it.
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 0.8, size * 0.4), at + Vector2(-size * 0.55, -size * 0.5), at + Vector2(0, -size * 1.7),
				at + Vector2(size * 0.55, -size * 0.5), at + Vector2(size * 0.8, size * 0.4), at + Vector2(0, size * 0.9)]), Color(glow, alpha))
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 0.4, size * 0.3), at + Vector2(0, -size * 0.9), at + Vector2(size * 0.4, size * 0.3), at + Vector2(0, size * 0.6)]), Color(core, alpha))
		"leaf":
			canvas.draw_set_transform(at, ang, Vector2(1.0, 0.45))
			canvas.draw_circle(Vector2.ZERO, size, Color(glow, alpha))
			canvas.draw_line(Vector2(-size * 0.8, 0), Vector2(size * 0.8, 0), Color(dark, alpha), maxf(1.0, size * 0.18))
			canvas.draw_set_transform(Vector2.ZERO)
		"rock":
			# A chunk of earth: a dark lump with a lit facet.
			var lump := PackedVector2Array()
			for i in 6:
				var a := ang + TAU * i / 6.0
				lump.append(at + Vector2(cos(a), sin(a)) * size * (0.9 if i % 2 == 0 else 1.1))
			canvas.draw_colored_polygon(lump, Color(dark, alpha))
			canvas.draw_colored_polygon(PackedVector2Array([lump[0], lump[1], at]), Color(glow, alpha))
		"drop":
			var tail := at + Vector2.from_angle(ang) * size * 1.6
			canvas.draw_colored_polygon(PackedVector2Array([tail, at + Vector2.from_angle(ang + PI / 2) * size * 0.75, at + Vector2.from_angle(ang - PI / 2) * size * 0.75]), Color(glow, alpha))
			canvas.draw_circle(at, size * 0.78, Color(glow, alpha))
			canvas.draw_circle(at + Vector2(-size * 0.25, -size * 0.25), size * 0.25, Color(core, alpha * 0.9))
		"star":
			var pts := PackedVector2Array()
			for i in 8:
				var a := ang + TAU * i / 8.0
				pts.append(at + Vector2(cos(a), sin(a)) * size * (1.4 if i % 2 == 0 else 0.55))
			canvas.draw_colored_polygon(pts, Color(glow, alpha))
			canvas.draw_circle(at, size * 0.4, Color(core, alpha))
		"wisp":
			canvas.draw_circle(at, size * 1.5, Color(glow, 0.25 * alpha))
			canvas.draw_circle(at, size * 0.75, Color(glow.lightened(0.3), 0.8 * alpha))
		"streak":
			var along := Vector2.from_angle(ang) * size * 2.2
			canvas.draw_line(at - along, at + along, Color(glow, 0.5 * alpha), maxf(2.0, size * 0.7))
			canvas.draw_line(at - along, at + along, Color(core, alpha), maxf(1.0, size * 0.3))
		"bolt":
			var across := Vector2.from_angle(ang + PI / 2)
			var zig := PackedVector2Array([at - Vector2.from_angle(ang) * size * 1.5, at - Vector2.from_angle(ang) * size * 0.5 + across * size * 0.5,
				at + Vector2.from_angle(ang) * size * 0.5 - across * size * 0.5, at + Vector2.from_angle(ang) * size * 1.5])
			canvas.draw_polyline(zig, Color(glow, 0.6 * alpha), maxf(2.0, size * 0.6))
			canvas.draw_polyline(zig, Color(core, alpha), maxf(1.0, size * 0.25))
		_:
			canvas.draw_line(at, at + Vector2.from_angle(ang) * size * 1.6, Color(core, alpha), maxf(1.5, size * 0.35))

static func _draw_text(canvas: CanvasItem, center: Vector2, text: String, font_size: int, color: Color, outline := 4) -> void:
	if font_size < 6:
		return
	var font := UIKit.DISPLAY_FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-width / 2.0, font_size * 0.36)
	canvas.draw_string_outline(font, baseline + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline + 2, Color(UIKit.INK, color.a * 0.5))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(UIKit.INK, color.a))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
