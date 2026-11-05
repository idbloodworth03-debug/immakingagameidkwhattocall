class_name StyleLook
extends Node2D
## What an animal's attack style looks like on the animal itself
## (styles.json; the fight's side is BattleStyles): poses and props that read
## without any text, drawn over its body. The one-off effects of a style
## (a swipe, a ground pound, a hit bouncing back) are the field's
## (battle_field.gd).
##   shell (Snapping Turtle): squashed flat under a green domed shell.
##   snack (Giant Panda): sitting down, munching a bamboo stalk, leaves
##     dropping.
##   rhino_charge (Black Rhino): low and leaning into the charge, dust
##     kicked up behind.
##   pound (Yeti): the hit before a ground pound, it glows icy blue with
##     frost rising off it (the tell).
##   rush (Wild Boar): head down, sprinting at a Tank, dust behind.
##   stalk (Tiger): low and crouched as it circles, an orange streak behind;
##     stretched out as it pounces.
##   fearless (Honey Badger): angry red steam puffing off it in a fight.
##   triple (Cerberus): flames flickering off its heads in a fight.
##   dive (Peregrine Falcon): high up, then stretched out with speed lines as
##     it dives, dropping (its shadow growing) as it closes in; climbing back
##     up after the hit.
##   hunt (Barn Owl): pale, with a ghostly trail behind it; its eyes glint as
##     it strikes.
##   grab (Harpy Eagle): flying higher with its catch dangling from its
##     talons.
##   feast (California Condor): bigger with every fall it feasts on.
##   strafe (Dragon): fire pouring from its mouth on a fire-breath run.
## And on any animal: a golden glow while a Lion's roar has it roused, a
## sickly green with drips while it's poisoned, a blue crack mark while a
## Macaw has cracked its armor, dangling and wriggling while an eagle carries
## it off.
## Sizes and colors: feel.json "styles".

var view: UnitView
var kind := ""
var _state := ""
var _time := 0.0
var _puff_in := 0.0
## How high the Falcon is (eased toward where it's heading).
var _high := 0.0
## The Owl's ghostly trail: where it was lately ([position on the field, age]).
var _trail: Array = []
var _trail_in := 0.0
## Showing a crack mark (a Macaw's), and the moment it struck (for the Owl's
## eye glint).
var _cracked := false
var _glint_at := -10.0


static func make(v: UnitView) -> StyleLook:
	var look := StyleLook.new()
	look.view = v
	look.kind = String(GameData.styles.get(v.id, {}).get("kind", ""))
	return look


func _num(key: String, fallback: float) -> float:
	return Feel.num("styles", key, fallback)


func _color(key: String, fallback: String) -> Color:
	return Color(String(GameData.feel.get("styles", {}).get(key, fallback)))


## How the body is posed this frame ({"sx", "sy", "lift", "rot", "tint"}),
## and the props and particles that go with it.
func pose(f: BattleSim.Fighter, now: float, dt: float) -> Dictionary:
	var p := {"sx": 1.0, "sy": 1.0, "lift": 0.0, "rot": 0.0, "tint": Color.WHITE}
	_time = now
	var state := ""
	if f != null and view.defeat < 0.0 and kind != "":
		match kind:
			"shell":
				if int(f.memory.get("shell", 0)) > 0:
					state = "shell"
					p.sx = 1.14
					p.sy = 0.5
					p.tint = Color(0.78, 0.84, 0.78)
			"snack":
				if int(f.memory.get("snack", 0)) > 0:
					state = "snack"
					p.sx = 1.1
					p.sy = 0.84 + sin(now * 14.0) * 0.025
					_puffs(dt, "leaf", _color("bamboo_leaf", "#6fcf4a"), Vector2(0.25, -0.55), Vector2(30, 40), 0.35)
			"rhino_charge":
				if int(f.memory.get("charge_state", 0)) == 1:
					state = "charge"
					p.sx = 1.08
					p.sy = 0.9
					# Dust kicked up behind it as it thunders along.
					var behind := -view.move_dir * 0.45
					_puffs(dt, "puff", _color("charge_dust", "#c9b08a"), Vector2(behind.x, behind.y * 0.6 - 0.05), -view.move_dir * 120.0 + Vector2(0, -30), 0.04, 14.0)
			"rush":
				if view.field != null and view.field.sim != null and BattleStyles.speed_bonus(view.field.sim, f) > 0 and view.moving > 0.05:
					state = "rush"
					p.sx = 1.06
					p.sy = 0.88
					var behind := -view.move_dir * 0.4
					_puffs(dt, "puff", _color("charge_dust", "#c9b08a"), Vector2(behind.x, behind.y * 0.6 - 0.05), -view.move_dir * 90.0, 0.06, 10.0)
			"stalk":
				var t := f.target
				if t != null and t.alive and not f.memory.get("pounced", []).has(t.uid) and view.moving > 0.05:
					if int(f.memory.get("stalk_phase", 0)) == 0:
						state = "crouch"
						p.sx = 1.08
						p.sy = 0.84
					else:
						state = "leap"
						p.sx = 0.92
						p.sy = 1.1
						p.lift = 6.0
					_puffs(dt, "spark", _color("pounce", "#ff9a2e"), Vector2(-view.move_dir.x * 0.3, -0.25), -view.move_dir * 160.0, 0.05, 8.0)
			"fearless":
				if _fighting(f):
					_puffs(dt, "puff", _color("rage", "#ff5a3c"), Vector2(0.0, -0.9), Vector2(0, -70), 0.5, 8.0)
			"spit":
				var at := int(f.memory.get("spit_at", -1))
				var sim := view.field.sim if view.field != null else null
				if at >= 0 and sim != null:
					# Cheeks puffing up as it charges, a green glow.
					var total := maxf(1.0, float(f.sp("charge", 1.5)) * sim.tps)
					var charged := clampf(1.0 - float(at - sim.tick) / total, 0.0, 1.0)
					state = "spit"
					p.sx = 1.0 + 0.2 * charged
					p.sy = 1.0 - 0.06 * charged
					p.tint = Color(1.0, 1.0, 1.0).lerp(Color("#c8f0d8"), 0.4 * charged)
					_puffs(dt, "sparkle", Color("#e6f5f0"), Vector2(0.0, -0.75), Vector2(0, -30), 0.15, 6.0)
			"sniper":
				if view.attacking(now):
					# Its hood flares as it takes aim.
					p.sx = 1.14
					p.sy = 1.04
			"triple":
				if _fighting(f):
					_puffs(dt, "glow", _color("fire", "#ff6a2a"), Vector2(0.0, -0.85), Vector2(0, -60), 0.4, 4.5)
			"dive":
				var sim := view.field.sim if view.field != null else null
				var want := 0.0
				var high := _num("climb_pixels", 40.0)
				if sim != null and int(f.memory.get("climb_until", -1)) > sim.tick:
						# Climbing back up after a dive, its shadow shrinking.
					state = "climb"
					want = high
					p.rot = -view.move_dir.x * 10.0
				elif sim != null and BattleStyles.speed_bonus(sim, f) > 0:
					# Diving at its prey: stretched out, speed lines behind it,
					# dropping lower (its shadow growing) as it closes in.
					state = "dive"
					var t := f.target
					var gap := float(BattleSim.dist(f, t) - f.attack_range - f.radius - t.radius) / BattleSim.TILE
					want = high * clampf(gap / 3.0, 0.0, 1.0)
					p.sx = 0.84
					p.sy = 1.16
					p.rot = view.move_dir.x * 16.0
				_high = move_toward(_high, want, dt * high * (6.0 if state == "dive" else 2.5))
				p.lift = _high
			"hunt":
				# Pale as a ghost, a misty trail behind it.
				state = "ghost"
				p.tint = Color(1.0, 1.0, 1.0).lerp(_color("owl_trail", "#e4e0ff"), 0.18)
				_trail_in -= dt
				if _trail_in <= 0.0 and view.moving > 0.05:
					_trail_in = 0.05
					_trail.append([view.position + position + Vector2(0, -_height() * 0.45), 0.0])
				if view.attacking(now) and now - _glint_at > 0.6:
					_glint_at = now
			"grab":
				var carry := int(f.memory.get("carry", -1))
				if carry >= 0:
					# Flying high with its catch dangling below (high enough to
					# lift it clear of the ground).
					state = "carry"
					var victim := view.field.view_for_uid(carry) if view.field != null else null
					var below := victim.look._height() if victim != null else 0.0
					p.lift = maxf(_height() * _num("carry_lift", 0.75), below * 1.15)
					p.sy = 1.04
			"feast":
				var grow := 1.0 + int(f.memory.get("feasts", 0)) * _num("feast_grow", 0.05)
				p.sx = grow
				p.sy = grow
				if int(f.memory.get("feasts", 0)) > 0:
					_puffs(dt, "glow", _color("feast", "#b48cff"), Vector2(0.0, -0.5), Vector2(0, -40), 0.5, 6.0)
			"strafe":
				if int(f.memory.get("run_left", 0)) > 0:
					# A fire-breath run: leaning in, flames pouring down ahead.
					state = "breath"
					p.rot = view.move_dir.x * 12.0
					p.lift = 6.0
					var ahead := view.move_dir * 0.35
					var fire := _color("fire", "#ff6a2a") if randf() < 0.5 else _color("flame", "#ffc23a")
					_puffs(dt, "glow", fire, Vector2(ahead.x, ahead.y * 0.6 - 0.55), view.move_dir * 140.0 + Vector2(0, 170), 0.025, 11.0)
			"pound":
				var every := maxi(1, int(f.sp("every", 3)))
				if int(f.memory.get("pounds", 0)) % every == every - 1:
					state = "frost"
					var glow := 0.5 + 0.5 * sin(now * 8.0)
					p.tint = Color(1.0, 1.0, 1.0).lerp(_color("frost", "#9fe6ff"), 0.35 + 0.2 * glow)
					_puffs(dt, "sparkle", _color("frost", "#9fe6ff"), Vector2(0.0, -0.3), Vector2(0, -60), 0.12)
	if f != null and view.defeat < 0.0 and view.field != null and view.field.sim != null:
		# Roused by a Lion's roar: a golden glow and sparkles.
		if int(f.memory.get("roared", -1)) > view.field.sim.tick:
			p.tint = p.tint * Color(1.0, 1.0, 1.0).lerp(_color("roar", "#ffc93c"), 0.35)
			_status_puffs(dt, "sparkle", _color("roar", "#ffc93c"), 0.3)
		# Sprayed by a Skunk: stink lines rising.
		if int(f.memory.get("stink_until", -1)) > view.field.sim.tick:
			_status_puffs(dt, "puff", _color("stink", "#c8d84a"), 0.2)
		# Poisoned: green, dripping.
		if f.poison > 0:
			p.tint = p.tint * Color(1.0, 1.0, 1.0).lerp(_color("venom", "#7ee04a"), 0.45)
			_status_puffs(dt, "glow", _color("venom", "#7ee04a"), 0.25)
		# Carried off by an eagle: dangling below it, wriggling.
		if f.memory.has("carried_by"):
			var eagle := view.field.view_for_uid(int(f.memory.carried_by))
			if eagle != null:
				# Its top just under the eagle's feet, in its talons.
				p.lift = maxf(4.0, -eagle.body.position.y - _height() * 0.8)
				p.rot = sin(now * 13.0) * 14.0
				p.sx = 0.92
				p.sy = 1.08
	var cracked := f != null and view.defeat < 0.0 and view.field != null and view.field.sim != null \
			and int(f.memory.get("cracked_until", -1)) > view.field.sim.tick
	if cracked:
		p.tint = p.tint * Color(1.0, 1.0, 1.0).lerp(_color("crack", "#3d8bff"), 0.15)
	# The Owl's trail fades as it goes.
	for dot in _trail:
		dot[1] += dt
	_trail = _trail.filter(func(dot: Array) -> bool: return float(dot[1]) < 0.45)
	if state != _state or cracked != _cracked or state in ["snack", "shell", "dive", "carry"] or not _trail.is_empty() or now - _glint_at < 0.35:
		_state = state
		_cracked = cracked
		queue_redraw()
	return p


## Particles every `every` seconds at a spot on the animal (`spot`: a share
## of its width and height from its feet), drifting at `vel`.
func _puffs(dt: float, particle: String, color: Color, spot: Vector2, vel: Vector2, every: float, size := 7.0) -> void:
	_puff_in -= dt
	if _puff_in > 0.0 or view.field == null:
		return
	_puff_in = every
	var h := _height()
	var at := view.position + position + Vector2(spot.x * h + randf_range(-0.15, 0.15) * h, spot.y * h)
	view.field.fx.particle(particle, at, vel + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 0.6, size, color, 60.0 if particle == "leaf" else -20.0, 2.0, randf_range(-4, 4))


var _status_in := 0.0


## A particle now and then somewhere on the animal (a status: roused,
## poisoned), drifting down.
func _status_puffs(dt: float, particle: String, color: Color, every: float) -> void:
	_status_in -= dt
	if _status_in > 0.0:
		return
	_status_in = every
	var h := _height()
	var at := view.position + position + Vector2(randf_range(-0.3, 0.3) * h, -randf_range(0.2, 0.8) * h)
	view.field.fx.particle(particle, at, Vector2(0, 40), 0.5, 6.0, color, 80.0, 2.0)


## In reach of what it's fighting.
func _fighting(f: BattleSim.Fighter) -> bool:
	return f.target != null and f.target.alive and view.field != null and view.field.sim != null and view.field.sim.in_range(f, f.target)


## The animal's drawn height in pixels.
func _height() -> float:
	return UnitSprites.top(view.id) * view.body.k


func _draw() -> void:
	if not _trail.is_empty():
		_draw_trail()
	match _state:
		"shell":
			_draw_shell()
		"snack":
			_draw_bamboo()
		"dive":
			_draw_speed_lines()
		"carry":
			_draw_talons()
	if _cracked:
		_draw_crack()
	if _time - _glint_at < 0.35:
		_draw_glint((_time - _glint_at) / 0.35)


## White speed lines streaming off the Falcon as it dives.
func _draw_speed_lines() -> void:
	var h := _height()
	var back := -view.move_dir if view.move_dir.length() > 0.1 else Vector2.UP
	var across := Vector2(-back.y, back.x)
	var white := _color("speed_lines", "#ffffff")
	for i in 4:
		var phase := fposmod(_time * 5.0 + i * 0.37, 1.0)
		var start := Vector2(0, -h * 0.5) + across * (i - 1.5) * h * 0.22 + back * h * (0.35 + phase * 0.5)
		var length := h * (0.5 + 0.3 * float(i % 2))
		draw_line(start, start + back * length, Color(white, 0.9 * (1.0 - phase)), maxf(3.0, h * 0.05))


## The Owl's misty trail: pale puffs where it was, fading.
func _draw_trail() -> void:
	var h := _height()
	var color := _color("owl_trail", "#e4e0ff")
	var here := view.position + position
	for dot in _trail:
		var u := float(dot[1]) / 0.45
		var at: Vector2 = dot[0] - here
		draw_set_transform(at, 0.0, Vector2(1.0, 0.65))
		draw_circle(Vector2.ZERO, h * 0.34 * (1.0 - u * 0.5), Color(color, 0.45 * (1.0 - u)))
	draw_set_transform(Vector2.ZERO)


## A glint in the Owl's eyes as it strikes.
func _draw_glint(u: float) -> void:
	var h := _height()
	var at := Vector2(view.move_dir.x * h * 0.12, -h * 0.72)
	var size := h * 0.2 * Ease.arc(u)
	var white := Color(1, 1, 1, 1.0 - u * 0.5)
	for d: Vector2 in [Vector2(1, 0), Vector2(0, 1)]:
		draw_line(at - d * size, at + d * size, white, maxf(2.0, h * 0.04))
	draw_circle(at, maxf(0.5, size * 0.25), white)


## The Harpy Eagle's talons gripping its catch below it.
func _draw_talons() -> void:
	var h := _height()
	var claw := Color("#f2c14e")
	for side: float in [-1.0, 1.0]:
		var top := Vector2(side * h * 0.12, -h * 0.05)
		var foot := top + Vector2(side * h * 0.04, h * 0.2)
		draw_line(top, foot, UIKit.INK, maxf(4.0, h * 0.07))
		draw_line(top, foot, claw, maxf(2.5, h * 0.045))
		var from := 0.0 if side > 0 else PI * 0.5
		draw_arc(foot + Vector2(-side * h * 0.05, 0), h * 0.07, from, from + PI * 0.5, 6, UIKit.INK, maxf(2.0, h * 0.03))


## A blue crack across the animal (the Macaw cracked its armor).
func _draw_crack() -> void:
	var h := _height()
	var mid := Vector2(0, -h * 0.5)
	var blue := _color("crack", "#3d8bff")
	var arms := [
		[Vector2(0, 0), Vector2(-0.1, -0.12), Vector2(-0.06, -0.24), Vector2(-0.16, -0.34)],
		[Vector2(0, 0), Vector2(0.12, 0.06), Vector2(0.1, 0.18), Vector2(0.22, 0.26)],
		[Vector2(0, 0), Vector2(0.14, -0.1), Vector2(0.26, -0.08)],
		[Vector2(0, 0), Vector2(-0.12, 0.1), Vector2(-0.24, 0.08)],
	]
	for arm: Array in arms:
		var points := PackedVector2Array()
		for a: Vector2 in arm:
			points.append(mid + a * h)
		draw_polyline(points, UIKit.INK, maxf(4.0, h * 0.07))
		draw_polyline(points, blue, maxf(2.5, h * 0.045))
		draw_polyline(points, Color(1, 1, 1, 0.7), maxf(1.0, h * 0.015))
	draw_circle(mid, h * 0.05, blue.lightened(0.4))


## A green domed shell over the flattened turtle, with plates and a shine.
func _draw_shell() -> void:
	var h := _height()
	var w := h * _num("shell_width", 1.25)
	var tall := w * 0.42
	var base := Vector2(0, -h * 0.05)
	var points := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		points.append(base + Vector2(cos(a) * w * 0.5, sin(a) * tall))
	var dark := _color("shell_dark", "#3d6b2c")
	var light := _color("shell_light", "#7fb04a")
	draw_colored_polygon(points, dark)
	var inner := PackedVector2Array()
	for point in points:
		inner.append(base + (point - base) * 0.82)
	draw_colored_polygon(inner, light)
	# Plates.
	var top := base + Vector2(0, -tall * 0.82)
	for x in [-0.22, 0.0, 0.22]:
		draw_line(base + Vector2(x * w, -tall * 0.05), top + Vector2(x * w * 0.6, tall * 0.25), dark, maxf(2.0, h * 0.025))
	draw_line(base + Vector2(-w * 0.38, -tall * 0.45), base + Vector2(w * 0.38, -tall * 0.45), dark, maxf(2.0, h * 0.025))
	draw_polyline(points, UIKit.INK, maxf(2.0, h * 0.03))
	draw_circle(top + Vector2(-w * 0.12, tall * 0.18), h * 0.05, Color(1, 1, 1, 0.45))


## A bamboo stalk held up to the mouth, bobbing as it munches.
func _draw_bamboo() -> void:
	var h := _height()
	var bob := sin(_time * 14.0) * h * 0.03
	var a := Vector2(h * 0.18, -h * 0.05 + bob)
	var b := Vector2(h * 0.42, -h * 1.0 + bob)
	var width := maxf(6.0, h * 0.11)
	var green := _color("bamboo", "#8fd14f")
	var dark := green.darkened(0.35)
	draw_line(a, b, UIKit.INK, width + 4.0)
	draw_line(a, b, green, width)
	for u in [0.3, 0.62]:
		var at: Vector2 = a.lerp(b, u)
		var across := (b - a).normalized().orthogonal() * width * 0.55
		draw_line(at - across, at + across, dark, maxf(2.0, width * 0.3))
	var leaf := _color("bamboo_leaf", "#6fcf4a")
	for side in [-1.0, 1.0]:
		var tip := b + Vector2(side * h * 0.26, -h * 0.08)
		var leaf_shape := PackedVector2Array([b, b.lerp(tip, 0.5) + Vector2(0, -h * 0.07), tip, b.lerp(tip, 0.5) + Vector2(0, h * 0.05)])
		draw_colored_polygon(leaf_shape, leaf)
		draw_polyline(leaf_shape + PackedVector2Array([b]), UIKit.INK, 2.0)
